#!/usr/bin/env python3
"""Download authenticated NAP GTFS-ZIP feeds listed in the OTP manifest.

Credentials are read from NAP_USER and NAP_PASS. Do not store them in files.
"""

from __future__ import annotations

import csv
import html
import os
import re
import sys
import zipfile
from pathlib import Path
from urllib.parse import urljoin

import requests


BASE_URL = "https://nap.transportes.gob.es"
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data" / "raw" / "otp" / "nap_burgos_madrid_candidates.tsv"
GTFS_DIR = ROOT / "data" / "raw" / "otp" / "graph"


def slugify(value: str) -> str:
    value = html.unescape(value).strip().lower()
    value = re.sub(r"[^a-z0-9áéíóúüñ]+", "_", value)
    value = value.strip("_")
    value = value.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u")
    value = value.replace("ü", "u").replace("ñ", "n")
    return value[:90] or "nap_feed"


def find_token(text: str) -> str:
    match = re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"', text)
    if not match:
        raise RuntimeError("No se encontro __RequestVerificationToken")
    return html.unescape(match.group(1))


def login(session: requests.Session, user: str, password: str) -> None:
    login_url = f"{BASE_URL}/Account/Login?returnUrl=/Files/List"
    response = session.get(login_url, timeout=30)
    response.raise_for_status()
    token = find_token(response.text)
    payload = {
        "ReturnUrl": "/Files/List",
        "Email": user,
        "Password": password,
        "Remember": "false",
        "__RequestVerificationToken": token,
    }
    response = session.post(f"{BASE_URL}/Account/LogIn", data=payload, allow_redirects=True, timeout=30)
    response.raise_for_status()
    if "frmLogin" in response.text:
        raise RuntimeError("Login rechazado por NAP")


def parse_download_forms(detail_html: str) -> list[dict[str, str]]:
    forms = []
    for form_match in re.finditer(r'<form[^>]+action="/Files/Download"[^>]*>(.*?)</form>', detail_html, flags=re.S):
        form = form_match.group(1)
        id_match = re.search(r'name="id"[^>]*value="([^"]+)"', form)
        profile_match = re.search(r'name="perfil"[^>]*value="([^"]+)"', form)
        token_match = re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"', form)
        size_match = re.search(r'Descargar\s*\(([^)]+)\)', form)
        if not id_match or not token_match:
            continue
        forms.append(
            {
                "id": html.unescape(id_match.group(1)),
                "perfil": html.unescape(profile_match.group(1)) if profile_match else "Usuario",
                "token": html.unescape(token_match.group(1)),
                "size_label": html.unescape(size_match.group(1)) if size_match else "",
            }
        )
    return forms


def detail_title(detail_html: str) -> str:
    match = re.search(r'<div class="card-header text-left container-Blue card-title ">\s*(.*?)\s*</div>', detail_html, flags=re.S)
    if match:
        return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", match.group(1)))).strip()
    match = re.search(r"<title>(.*?)</title>", detail_html, flags=re.S)
    return html.unescape(match.group(1)).strip() if match else "nap_feed"


def download_form(session: requests.Session, form: dict[str, str], output: Path) -> bool:
    payload = {
        "id": form["id"],
        "perfil": form["perfil"],
        "__RequestVerificationToken": form["token"],
    }
    response = session.post(f"{BASE_URL}/Files/Download", data=payload, stream=True, timeout=120)
    response.raise_for_status()
    content_type = response.headers.get("content-type", "")
    if "text/html" in content_type.lower():
        print(f"[nap] respuesta HTML inesperada para id={form['id']}; se omite", file=sys.stderr)
        return False

    tmp = output.with_suffix(output.suffix + ".tmp")
    with tmp.open("wb") as fh:
        for chunk in response.iter_content(chunk_size=1024 * 256):
            if chunk:
                fh.write(chunk)
    if tmp.stat().st_size == 0:
        tmp.unlink(missing_ok=True)
        return False
    if not zipfile.is_zipfile(tmp):
        print(f"[nap] no parece ZIP: {output.name}", file=sys.stderr)
        tmp.unlink(missing_ok=True)
        return False
    tmp.replace(output)
    return True


def read_manifest() -> list[dict[str, str]]:
    if not MANIFEST.exists():
        raise RuntimeError(f"No existe manifest: {MANIFEST}")
    with MANIFEST.open(encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh, delimiter="\t"))
    extra_ids = [x.strip() for x in os.environ.get("NAP_DETAIL_IDS", "").split(",") if x.strip()]
    seen = {row["detail_id"] for row in rows}
    for detail_id in extra_ids:
        if detail_id in seen:
            continue
        rows.append(
            {
                "detail_id": detail_id,
                "detail_url": f"{BASE_URL}/Files/Detail/{detail_id}",
                "label": "extra",
            }
        )
    return rows


def main() -> int:
    user = os.environ.get("NAP_USER")
    password = os.environ.get("NAP_PASS")
    if not user or not password:
        print("Define NAP_USER y NAP_PASS en el entorno.", file=sys.stderr)
        return 2

    GTFS_DIR.mkdir(parents=True, exist_ok=True)
    rows = read_manifest()
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 opencode-otp-downloader"})
    login(session, user, password)
    print(f"[nap] login OK; candidatos: {len(rows)}")

    downloaded = 0
    for row in rows:
        detail_id = row["detail_id"]
        detail_url = row["detail_url"]
        response = session.get(detail_url, timeout=30)
        response.raise_for_status()
        if "frmLogin" in response.text:
            raise RuntimeError("La sesion NAP expiro durante la descarga")
        title = detail_title(response.text)
        forms = parse_download_forms(response.text)
        if not forms:
            print(f"[nap] sin formulario GTFS: {detail_id} {title}")
            continue
        for idx, form in enumerate(forms, start=1):
            stem = slugify(f"nap_{detail_id}_{form['id']}_{title}")
            if len(forms) > 1:
                stem = f"{stem}_{idx}"
            output = GTFS_DIR / f"{stem}.gtfs.zip"
            if output.exists() and output.stat().st_size > 0:
                print(f"[nap] existe: {output.name}")
                continue
            print(f"[nap] descargando {detail_id}/{form['id']}: {title} ({form['size_label']})")
            if download_form(session, form, output):
                downloaded += 1
                print(f"[nap] guardado: {output.name}")

    print(f"[nap] descargas nuevas: {downloaded}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

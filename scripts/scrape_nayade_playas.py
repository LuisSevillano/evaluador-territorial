#!/usr/bin/env python3
"""Scraper de zonas de bano (Nayade Ciudadano).

Piloto inicial: Castilla y Leon (codCCAA=8).
Extrae listado, entra en cada ficha y guarda coordenadas + metadatos basicos.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import requests


BASE_URL = "https://nayadeciudadano.sanidad.gob.es/Splayas/ciudadano/"


CCAA_CODES = {
    "castilla_y_leon": "8",
    "cantabria": "6",
    "asturias": "3",
    "pais_vasco": "16",
    "la_rioja": "17",
    "madrid": "13",
    "galicia": "12",
}

PROVINCE_TARGETS = {
    "lugo": {"cod_ccaa": "12", "cod_provincia": "27", "name": "Lugo"},
    "ourense": {"cod_ccaa": "12", "cod_provincia": "32", "name": "Ourense"},
    "guadalajara": {"cod_ccaa": "7", "cod_provincia": "19", "name": "Guadalajara"},
    "madrid_provincia": {"cod_ccaa": "13", "cod_provincia": "28", "name": "Madrid"},
}

PRESET_TARGETS = {
    "objetivo_usuario": [
        "castilla_y_leon",
        "cantabria",
        "asturias",
        "pais_vasco",
        "la_rioja",
        "lugo",
        "ourense",
        "guadalajara",
        "madrid_provincia",
    ]
}


@dataclass
class ZonaListItem:
    cod_zona: str
    zona_listado: str


def clean_text(value: str) -> str:
    stripped = re.sub(r"\s+", " ", value).strip()
    return html.unescape(stripped)


def parse_list_items(list_html: str) -> list[ZonaListItem]:
    pattern = re.compile(
        r"javascript:verZona\('(?P<cod>\d+)'\)" r"[^>]*>(?P<name>.*?)</a>",
        re.IGNORECASE | re.DOTALL,
    )
    out: list[ZonaListItem] = []
    seen: set[str] = set()
    for match in pattern.finditer(list_html):
        cod = match.group("cod")
        if cod in seen:
            continue
        seen.add(cod)
        out.append(ZonaListItem(cod_zona=cod, zona_listado=clean_text(match.group("name"))))
    return out


def _extract_label_value(html_doc: str, label: str) -> str:
    pattern = re.compile(
        rf"{re.escape(label)}:</td>\s*<td[^>]*>(.*?)</td>",
        re.IGNORECASE | re.DOTALL,
    )
    match = pattern.search(html_doc)
    if not match:
        return ""
    return clean_text(re.sub(r"<br\s*/?>", " ", match.group(1), flags=re.IGNORECASE))


def _extract_first_point_utm(html_doc: str) -> tuple[float, float, int] | None:
    pattern = re.compile(
        r"Coordenadas UTM</td>.*?X:</td>\s*<td[^>]*>([\d.,]+)</td>.*?"
        r"Y:</td>\s*<td[^>]*>([\d.,]+)</td>.*?Huso:</td>\s*<td[^>]*>(\d+)</td>",
        re.IGNORECASE | re.DOTALL,
    )
    match = pattern.search(html_doc)
    if not match:
        return None
    x = float(match.group(1).replace(".", "").replace(",", ".")) if "," in match.group(1) else float(match.group(1))
    y = float(match.group(2).replace(".", "").replace(",", ".")) if "," in match.group(2) else float(match.group(2))
    huso = int(match.group(3))
    return (x, y, huso)


def utm_to_wgs84_latlon(easting: float, northing: float, zone_number: int, northern: bool = True) -> tuple[float, float]:
    # Formula de conversion UTM -> geograficas (WGS84).
    a = 6378137.0
    f = 1 / 298.257223563
    e_sq = f * (2 - f)
    e_prime_sq = e_sq / (1 - e_sq)
    k0 = 0.9996

    x = easting - 500000.0
    y = northing if northern else northing - 10000000.0
    m = y / k0

    mu = m / (a * (1 - e_sq / 4 - 3 * e_sq**2 / 64 - 5 * e_sq**3 / 256))

    e1 = (1 - math.sqrt(1 - e_sq)) / (1 + math.sqrt(1 - e_sq))
    j1 = 3 * e1 / 2 - 27 * e1**3 / 32
    j2 = 21 * e1**2 / 16 - 55 * e1**4 / 32
    j3 = 151 * e1**3 / 96
    j4 = 1097 * e1**4 / 512

    fp = mu + j1 * math.sin(2 * mu) + j2 * math.sin(4 * mu) + j3 * math.sin(6 * mu) + j4 * math.sin(8 * mu)

    c1 = e_prime_sq * math.cos(fp) ** 2
    t1 = math.tan(fp) ** 2
    n1 = a / math.sqrt(1 - e_sq * (math.sin(fp) ** 2))
    r1 = a * (1 - e_sq) / ((1 - e_sq * (math.sin(fp) ** 2)) ** 1.5)
    d = x / (n1 * k0)

    q1 = n1 * math.tan(fp) / r1
    q2 = d**2 / 2
    q3 = (5 + 3 * t1 + 10 * c1 - 4 * c1**2 - 9 * e_prime_sq) * d**4 / 24
    q4 = (61 + 90 * t1 + 298 * c1 + 45 * t1**2 - 252 * e_prime_sq - 3 * c1**2) * d**6 / 720
    lat = fp - q1 * (q2 - q3 + q4)

    q5 = d
    q6 = (1 + 2 * t1 + c1) * d**3 / 6
    q7 = (5 - 2 * c1 + 28 * t1 - 3 * c1**2 + 8 * e_prime_sq + 24 * t1**2) * d**5 / 120
    lon = (q5 - q6 + q7) / math.cos(fp)

    lon_origin = math.radians((zone_number - 1) * 6 - 180 + 3)
    lon = lon_origin + lon

    return math.degrees(lat), math.degrees(lon)


def fetch_list(session: requests.Session, cod_ccaa: str) -> str:
    session.get(BASE_URL + "ciudadanoZonaAction.do", timeout=60)
    payload = {
        "codZona": "",
        "provinciaMapa": "",
        "actionProcedencia": "",
        "codCCAA": cod_ccaa,
        "codProvincia": "",
        "codMunicipio": "",
        "denZona": "",
    }
    response = session.post(BASE_URL + "ciudadanoListaZonaAction.do", data=payload, timeout=60)
    response.raise_for_status()
    return response.text


def fetch_list_by_province(session: requests.Session, cod_ccaa: str, cod_provincia: str) -> str:
    session.get(BASE_URL + "ciudadanoZonaAction.do", timeout=60)
    payload = {
        "codZona": "",
        "provinciaMapa": "",
        "actionProcedencia": "",
        "codCCAA": cod_ccaa,
        "codProvincia": cod_provincia,
        "codMunicipio": "",
        "denZona": "",
    }
    response = session.post(BASE_URL + "ciudadanoListaZonaAction.do", data=payload, timeout=60)
    response.raise_for_status()
    return response.text


def fetch_detail(session: requests.Session, cod_zona: str, cod_ccaa: str) -> str:
    payload = {
        "codZona": cod_zona,
        "actionProcedencia": "ciudadanoListaZonaAction",
        "codCCAA": cod_ccaa,
        "codProvincia": "",
        "codMunicipio": "",
    }
    response = session.post(BASE_URL + "ciudadanoVerZonaAction.do", data=payload, timeout=60)
    response.raise_for_status()
    return response.text


def parse_detail(detail_html: str) -> dict[str, str | float | int | None]:
    ccaa = _extract_label_value(detail_html, "Comunidad Aut\u00f3noma")
    provincia = _extract_label_value(detail_html, "Provincia")
    municipio = _extract_label_value(detail_html, "Municipio")
    localidad = _extract_label_value(detail_html, "Localidad")
    zona = _extract_label_value(detail_html, "Zona Agua Ba\u00f1o")
    tipo_zb = _extract_label_value(detail_html, "Tipo ZB")
    tipo_recurso = _extract_label_value(detail_html, "Tipo Recurso")
    recurso_hidrico = _extract_label_value(detail_html, "Recurso H\u00eddrico")

    utm = _extract_first_point_utm(detail_html)
    if utm:
        utm_x, utm_y, utm_zone = utm
        lat, lon = utm_to_wgs84_latlon(utm_x, utm_y, utm_zone, northern=True)
    else:
        utm_x = utm_y = lat = lon = None
        utm_zone = None

    return {
        "ccaa": ccaa,
        "provincia": provincia,
        "municipio": municipio,
        "localidad": localidad,
        "zona": zona,
        "tipo_zb": tipo_zb,
        "tipo_recurso": tipo_recurso,
        "recurso_hidrico": recurso_hidrico,
        "utm_x": utm_x,
        "utm_y": utm_y,
        "utm_zone": utm_zone,
        "lat": lat,
        "lon": lon,
    }


def scrape_scope(scope: str) -> list[dict[str, str | float | int | None]]:
    cod_ccaa = CCAA_CODES[scope]
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 (compatible; NayadePilot/1.0)",
            "Accept-Language": "es-ES,es;q=0.9",
        }
    )

    list_html = fetch_list(session, cod_ccaa)
    list_items = parse_list_items(list_html)

    rows: list[dict[str, str | float | int | None]] = []
    for item in list_items:
        detail_html = fetch_detail(session, item.cod_zona, cod_ccaa)
        parsed = parse_detail(detail_html)
        parsed["id_origen"] = item.cod_zona
        parsed["zona_listado"] = item.zona_listado
        parsed["source_url"] = BASE_URL + "ciudadanoVerZonaAction.do"
        rows.append(parsed)
    return rows


def scrape_province(target: str) -> list[dict[str, str | float | int | None]]:
    cfg = PROVINCE_TARGETS[target]
    cod_ccaa = cfg["cod_ccaa"]
    cod_provincia = cfg["cod_provincia"]

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 (compatible; NayadePilot/1.0)",
            "Accept-Language": "es-ES,es;q=0.9",
        }
    )

    list_html = fetch_list_by_province(session, cod_ccaa, cod_provincia)
    list_items = parse_list_items(list_html)

    rows: list[dict[str, str | float | int | None]] = []
    for item in list_items:
        detail_html = fetch_detail(session, item.cod_zona, cod_ccaa)
        parsed = parse_detail(detail_html)
        parsed["id_origen"] = item.cod_zona
        parsed["zona_listado"] = item.zona_listado
        parsed["source_url"] = BASE_URL + "ciudadanoVerZonaAction.do"
        parsed["target_scope"] = target
        rows.append(parsed)
    return rows


def write_outputs(rows: Iterable[dict[str, str | float | int | None]], output_prefix: Path) -> None:
    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    rows_list = list(rows)

    json_path = output_prefix.with_suffix(".json")
    json_path.write_text(json.dumps(rows_list, ensure_ascii=False, indent=2), encoding="utf-8")

    csv_path = output_prefix.with_suffix(".csv")
    if rows_list:
        headers = list(rows_list[0].keys())
    else:
        headers = []
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows_list)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scraper Nayade ciudadano por CCAA")
    all_scopes = sorted(list(CCAA_CODES.keys()) + list(PROVINCE_TARGETS.keys()))
    parser.add_argument(
        "--scope",
        default="castilla_y_leon",
        choices=all_scopes,
        help="Ambito de extraccion",
    )
    parser.add_argument(
        "--output-prefix",
        default="output/nayade/nayade_castilla_y_leon_pilot",
        help="Ruta sin extension para exportar JSON y CSV",
    )
    parser.add_argument(
        "--preset",
        choices=sorted(PRESET_TARGETS.keys()),
        help="Ejecuta un conjunto predefinido de ambitos",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.preset:
        rows: list[dict[str, str | float | int | None]] = []
        for target in PRESET_TARGETS[args.preset]:
            if target in CCAA_CODES:
                block = scrape_scope(target)
                for row in block:
                    row["target_scope"] = target
                rows.extend(block)
            else:
                rows.extend(scrape_province(target))
    elif args.scope in CCAA_CODES:
        rows = scrape_scope(args.scope)
    else:
        rows = scrape_province(args.scope)

    dedup: dict[str, dict[str, str | float | int | None]] = {}
    for row in rows:
        key = str(row.get("id_origen", ""))
        dedup[key] = row
    rows = list(dedup.values())

    write_outputs(rows, Path(args.output_prefix))
    print(f"Extraidas {len(rows)} zonas. Archivo base: {args.output_prefix}")


if __name__ == "__main__":
    main()

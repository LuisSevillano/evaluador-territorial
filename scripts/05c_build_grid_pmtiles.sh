#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GRID_GEOJSON="$ROOT_DIR/frontend/static/data/municipios_grid_2km.geojson"
GRID_DIR="$ROOT_DIR/frontend/static/tiles/grid"
PROV_DIR="$GRID_DIR/provincias"

GRID_MBTILES="$GRID_DIR/grid_norte.mbtiles"
GRID_PMTILES="$GRID_DIR/grid_norte.pmtiles"

if ! command -v tippecanoe >/dev/null 2>&1; then
  echo "Error: tippecanoe no esta instalado."
  exit 1
fi

if ! command -v pmtiles >/dev/null 2>&1; then
  echo "Error: pmtiles CLI no esta instalado."
  exit 1
fi

if [[ ! -f "$GRID_GEOJSON" ]]; then
  echo "Error: no existe $GRID_GEOJSON"
  echo "Ejecuta antes: Rscript scripts/04j_grid_2km.R o run_pipeline_v2.R"
  exit 1
fi

mkdir -p "$GRID_DIR"
mkdir -p "$PROV_DIR"

echo "[grid] Construyendo grid_norte.mbtiles"
tippecanoe \
  -f \
  -o "$GRID_MBTILES" \
  -Z0 -z12 \
  --drop-densest-as-needed \
  --no-feature-limit \
  --no-tile-size-limit \
  -l grid \
  "$GRID_GEOJSON"

echo "[grid] Convirtiendo a grid_norte.pmtiles"
pmtiles convert "$GRID_MBTILES" "$GRID_PMTILES"

echo "[grid] Construyendo PMTiles provinciales"
python3 - "$GRID_GEOJSON" "$PROV_DIR" <<'PY'
import json, re, subprocess, sys
from pathlib import Path

grid_geojson = Path(sys.argv[1])
prov_dir = Path(sys.argv[2])

with grid_geojson.open("r", encoding="utf-8") as f:
    data = json.load(f)

provinces = sorted({
    (feat.get("properties", {}) or {}).get("provincia", "").strip()
    for feat in data.get("features", [])
    if (feat.get("properties", {}) or {}).get("provincia")
})

def slugify(name: str) -> str:
    repl = (
        ("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"),
        ("Á", "a"), ("É", "e"), ("Í", "i"), ("Ó", "o"), ("Ú", "u"),
        ("ñ", "n"), ("Ñ", "n"), ("/", "_")
    )
    out = name
    for a, b in repl:
        out = out.replace(a, b)
    out = out.lower().strip()
    out = re.sub(r"[^a-z0-9_]+", "_", out)
    out = re.sub(r"_+", "_", out).strip("_")
    return out

for prov in provinces:
    slug = slugify(prov)
    if not slug:
        continue
    mb = prov_dir / f"grid_{slug}.mbtiles"
    pm = prov_dir / f"grid_{slug}.pmtiles"
    filter_expr = json.dumps({"*": ["==", "provincia", prov]})
    subprocess.run([
        "tippecanoe", "-f", "-o", str(mb), "-Z0", "-z12",
        "--drop-densest-as-needed", "--no-feature-limit", "--no-tile-size-limit",
        "-l", "grid", "-j", filter_expr, str(grid_geojson)
    ], check=True)
    subprocess.run(["pmtiles", "convert", str(mb), str(pm)], check=True)
    print(f"[grid] OK provincia: {prov} -> {pm.name}")
PY

echo "[grid] OK: grid_norte y PMTiles provinciales generados en $GRID_DIR"

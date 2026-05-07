#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_DIR="$ROOT_DIR/frontend/static/data/isochrones"
OUTPUT_DIR="$ROOT_DIR/output/tiles"
FRONTEND_TILES_DIR="$ROOT_DIR/frontend/static/tiles"

ISO_MBTILES="$OUTPUT_DIR/isochrones.mbtiles"
ISO_PMTILES="$OUTPUT_DIR/isochrones.pmtiles"
ISO_SIMPLIFY_PCT="${ISO_SIMPLIFY_PCT:-0}"

if ! command -v tippecanoe >/dev/null 2>&1; then
  echo "Error: tippecanoe no esta instalado."
  exit 1
fi

if ! command -v pmtiles >/dev/null 2>&1; then
  echo "Error: pmtiles CLI no esta instalado."
  exit 1
fi

if ! command -v mapshaper >/dev/null 2>&1; then
  echo "Error: mapshaper no esta instalado."
  echo "Instala con: npm i -g mapshaper"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 no esta instalado."
  exit 1
fi

declare -a iso_specs=(
  "distance_01h30m_filled.json:iso_01h30m"
  "distance_02h00m_filled.json:iso_02h00m"
  "distance_02h30m_filled.json:iso_02h30m"
  "distance_03h30m_filled.json:iso_03h30m"
  "distance_04h00m_filled.json:iso_04h00m"
)

for spec in "${iso_specs[@]}"; do
  file_name="${spec%%:*}"
  if [[ ! -f "$ISO_DIR/$file_name" ]]; then
    echo "Error: falta $ISO_DIR/$file_name"
    echo "Ejecuta antes: Rscript scripts/03_isochrones.R"
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"
mkdir -p "$FRONTEND_TILES_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

optimized_files=()

echo "[iso] Preparando y optimizando isocronas filled"
for spec in "${iso_specs[@]}"; do
  file_name="${spec%%:*}"
  iso_key="${spec##*:}"
  src="$ISO_DIR/$file_name"
  raw="$TMP_DIR/${iso_key}_raw.geojson"
  opt="$TMP_DIR/${iso_key}_opt.geojson"

  python3 - "$src" "$raw" "$iso_key" <<'PY'
import json
import sys

src, dst, iso_key = sys.argv[1], sys.argv[2], sys.argv[3]

with open(src, "r", encoding="utf-8") as f:
    data = json.load(f)

features = []
if data.get("type") == "GeometryCollection":
    geoms = data.get("geometries", [])
    for geom in geoms:
        if not geom or geom.get("type") not in {"Polygon", "MultiPolygon"}:
            continue
        features.append({
            "type": "Feature",
            "properties": {"iso_key": iso_key},
            "geometry": geom,
        })
elif data.get("type") == "FeatureCollection":
    for ft in data.get("features", []):
        geom = (ft or {}).get("geometry")
        if not geom or geom.get("type") not in {"Polygon", "MultiPolygon"}:
            continue
        features.append({
            "type": "Feature",
            "properties": {"iso_key": iso_key},
            "geometry": geom,
        })
else:
    raise SystemExit(f"Formato no soportado: {data.get('type')}")

fc = {"type": "FeatureCollection", "features": features}
with open(dst, "w", encoding="utf-8") as f:
    json.dump(fc, f, ensure_ascii=False)
PY

  if [[ "$ISO_SIMPLIFY_PCT" == "0" || "$ISO_SIMPLIFY_PCT" == "0.0" ]]; then
    mapshaper \
      -i "$raw" \
      -clean \
      -snap \
      -filter-fields iso_key \
      -o format=geojson "$opt"
  else
    mapshaper \
      -i "$raw" \
      -clean \
      -snap \
      -simplify "${ISO_SIMPLIFY_PCT}%" weighted keep-shapes \
      -filter-fields iso_key \
      -o format=geojson "$opt"
  fi

  optimized_files+=("$opt")
  echo "[iso] OK $iso_key"
done

merged="$TMP_DIR/isochrones_merged.geojson"
python3 - "$merged" "${optimized_files[@]}" <<'PY'
import json
import sys

out_path = sys.argv[1]
paths = sys.argv[2:]

features = []
for path in paths:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if data.get("type") != "FeatureCollection":
        continue
    for ft in data.get("features", []):
        geom = (ft or {}).get("geometry")
        props = (ft or {}).get("properties") or {}
        if not geom or geom.get("type") not in {"Polygon", "MultiPolygon"}:
            continue
        if "iso_key" not in props or not props["iso_key"]:
            continue
        features.append({
            "type": "Feature",
            "properties": {"iso_key": props["iso_key"]},
            "geometry": geom,
        })

with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"type": "FeatureCollection", "features": features}, f, ensure_ascii=False)
PY

cp "$merged" "$OUTPUT_DIR/isochrones_merged_debug.geojson"

tippecanoe \
  -f \
  -o "$ISO_MBTILES" \
  -l isochrones \
  -Z0 \
  -z11 \
  -y iso_key \
  --no-feature-limit \
  --no-tile-size-limit \
  -pk \
  -pf \
  "$merged"

pmtiles convert "$ISO_MBTILES" "$ISO_PMTILES"
cp "$ISO_PMTILES" "$FRONTEND_TILES_DIR/isochrones.pmtiles"

echo "OK: PMTiles isocronas en $ISO_PMTILES"
echo "OK: Copiado a frontend/static/tiles/isochrones.pmtiles"

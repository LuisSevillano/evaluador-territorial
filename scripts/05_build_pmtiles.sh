#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output/tiles"
FRONTEND_TILES_DIR="$ROOT_DIR/frontend/static/tiles"

MUNI_GEOJSON_V2="$ROOT_DIR/output/municipios_v2.geojson"
MUNI_GEOJSON_FALLBACK="$ROOT_DIR/output/municipios_final.geojson"
CCAA_GEOJSON="$ROOT_DIR/output/ccaa_boundaries.geojson"
PROV_GEOJSON="$ROOT_DIR/output/provincias_boundaries.geojson"

MUNI_MBTILES="$OUTPUT_DIR/municipios.mbtiles"
MUNI_PMTILES="$OUTPUT_DIR/municipios.pmtiles"
CCAA_MBTILES="$OUTPUT_DIR/ccaa.mbtiles"
CCAA_PMTILES="$OUTPUT_DIR/ccaa.pmtiles"
PROV_MBTILES="$OUTPUT_DIR/provincias.mbtiles"
PROV_PMTILES="$OUTPUT_DIR/provincias.pmtiles"

if ! command -v tippecanoe >/dev/null 2>&1; then
  echo "Error: tippecanoe no esta instalado."
  exit 1
fi

if ! command -v pmtiles >/dev/null 2>&1; then
  echo "Error: pmtiles CLI no esta instalado."
  exit 1
fi

MUNI_INPUT="$MUNI_GEOJSON_V2"
if [[ ! -f "$MUNI_INPUT" ]]; then
  MUNI_INPUT="$MUNI_GEOJSON_FALLBACK"
fi

if [[ ! -f "$MUNI_INPUT" ]]; then
  echo "Error: no existe dataset municipal para tiles."
  echo "Ejecuta antes: Rscript scripts/run_pipeline_v2.R"
  exit 1
fi

if [[ ! -f "$CCAA_GEOJSON" ]]; then
  echo "Error: no existe $CCAA_GEOJSON"
  echo "Ejecuta antes: Rscript scripts/07_ccaa_boundaries.R"
  exit 1
fi

if [[ ! -f "$PROV_GEOJSON" ]]; then
  echo "Error: no existe $PROV_GEOJSON"
  echo "Ejecuta antes: Rscript scripts/08_provincias_boundaries.R"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$FRONTEND_TILES_DIR"

tippecanoe \
  -f \
  -o "$MUNI_MBTILES" \
  -l municipios \
  -z12 \
  -Z0 \
  -y id \
  -y codigo \
  -y precip_annual_mm \
  -y mixed_score \
  -S 6 \
  -pk \
  -pf \
  "$MUNI_INPUT"

tippecanoe \
  -f \
  -o "$CCAA_MBTILES" \
  -l ccaa \
  -z10 \
  -Z0 \
  -S 6 \
  -pk \
  -pf \
  "$CCAA_GEOJSON"

tippecanoe \
  -f \
  -o "$PROV_MBTILES" \
  -l provincias \
  -z11 \
  -Z0 \
  -S 6 \
  -pk \
  -pf \
  "$PROV_GEOJSON"

pmtiles convert "$MUNI_MBTILES" "$MUNI_PMTILES"
pmtiles convert "$CCAA_MBTILES" "$CCAA_PMTILES"
pmtiles convert "$PROV_MBTILES" "$PROV_PMTILES"

cp "$MUNI_PMTILES" "$FRONTEND_TILES_DIR/municipios.pmtiles"
cp "$CCAA_PMTILES" "$FRONTEND_TILES_DIR/ccaa.pmtiles"
cp "$PROV_PMTILES" "$FRONTEND_TILES_DIR/provincias.pmtiles"

echo "OK: PMTiles municipios en $MUNI_PMTILES"
echo "OK: PMTiles CCAA en $CCAA_PMTILES"
echo "OK: PMTiles provincias en $PROV_PMTILES"
echo "OK: Copiados a frontend/static/tiles/"

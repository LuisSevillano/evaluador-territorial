#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output/tiles"
FRONTEND_TILES_DIR="$ROOT_DIR/frontend/static/tiles"

MUNI_GEOJSON_V2="$ROOT_DIR/output/municipios_v2.geojson"
MUNI_GIFOJSON_FALLBACK="$ROOT_DIR/output/municipios_final.geojson"
CCAA_GEOJSON="$ROOT_DIR/output/ccaa_boundaries.geojson"
PROV_GEOJSON="$ROOT_DIR/output/provincias_boundaries.geojson"
LANDUSE_GEOJSON="$ROOT_DIR/output/usos_suelo.geojson"

MUNI_MBTILES="$OUTPUT_DIR/municipios.mbtiles"
MUNI_PMTILES="$OUTPUT_DIR/municipios.pmtiles"
CCAA_MBTILES="$OUTPUT_DIR/ccaa.mbtiles"
CCAA_PMTILES="$OUTPUT_DIR/ccaa.pmtiles"
PROV_MBTILES="$OUTPUT_DIR/provincias.mbtiles"
PROV_PMTILES="$OUTPUT_DIR/provincias.pmtiles"
LANDUSE_MBTILES="$OUTPUT_DIR/usos_suelo.mbtiles"
LANDUSE_PMTILES="$OUTPUT_DIR/usos_suelo.pmtiles"

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

MUNI_INPUT="$MUNI_GEOJSON_V2"
if [[ ! -f "$MUNI_INPUT" ]]; then
  MUNI_INPUT="$MUNI_GIFOJSON_FALLBACK"
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

MUNI_SIMPLIFY_PCT="${MUNI_SIMPLIFY_PCT:-0}"
PROV_SIMPLIFY_PCT="${PROV_SIMPLIFY_PCT:-0}"
CCAA_SIMPLIFY_PCT="${CCAA_SIMPLIFY_PCT:-0}"

MUNI_SIMPLIFIED="$OUTPUT_DIR/municipios_simplified.geojson"
PROV_SIMPLIFIED="$OUTPUT_DIR/provincias_simplified.geojson"
CCAA_SIMPLIFIED="$OUTPUT_DIR/ccaa_simplified.geojson"
PROV_FROM_MUNI="$OUTPUT_DIR/provincias_from_municipios.geojson"
CCAA_FROM_MUNI="$OUTPUT_DIR/ccaa_from_municipios.geojson"

if [[ "$MUNI_SIMPLIFY_PCT" != "0" ]]; then
  mapshaper \
    -i "$MUNI_INPUT" \
    -clean \
    -snap \
    -simplify "$MUNI_SIMPLIFY_PCT%" weighted keep-shapes \
    -o format=geojson "$MUNI_SIMPLIFIED"
else
  cp "$MUNI_INPUT" "$MUNI_SIMPLIFIED"
fi

if [[ "$PROV_SIMPLIFY_PCT" != "0" ]]; then
  mapshaper -i "$PROV_GEOJSON" -clean -snap -simplify "$PROV_SIMPLIFY_PCT%" -o format=geojson "$PROV_SIMPLIFIED"
else
  cp "$PROV_GEOJSON" "$PROV_SIMPLIFIED"
fi

if [[ "$CCAA_SIMPLIFY_PCT" != "0" ]]; then
  mapshaper -i "$CCAA_GEOJSON" -clean -snap -simplify "$CCAA_SIMPLIFY_PCT%" -o format=geojson "$CCAA_SIMPLIFIED"
else
  cp "$CCAA_GEOJSON" "$CCAA_SIMPLIFIED"
fi

mapshaper \
  -i "$MUNI_SIMPLIFIED" name=municipios \
  -i "$PROV_SIMPLIFIED" name=provincias \
  combine-files \
  -target municipios \
  -join provincias fields=id_prov,nombre_prov largest-overlap \
  -filter '!!id_prov' \
  -dissolve id_prov copy-fields=nombre_prov \
  -o format=geojson "$PROV_FROM_MUNI"

mapshaper \
  -i "$MUNI_SIMPLIFIED" name=municipios \
  -i "$CCAA_SIMPLIFIED" name=ccaa \
  combine-files \
  -target municipios \
  -join ccaa fields=id_ccaa,nombre_ccaa largest-overlap \
  -filter '!!id_ccaa' \
  -dissolve id_ccaa copy-fields=nombre_ccaa \
  -o format=geojson "$CCAA_FROM_MUNI"

tippecanoe \
  -f \
  -o "$MUNI_MBTILES" \
  -l municipios \
  -z12 \
  -Z0 \
  -y id \
  --detect-shared-borders \
  -S 12 \
  -pk \
  -pf \
  "$MUNI_SIMPLIFIED"

tippecanoe \
  -f \
  -o "$CCAA_MBTILES" \
  -l ccaa \
  -z10 \
  -Z0 \
  -S 6 \
  -pk \
  -pf \
  "$CCAA_FROM_MUNI"

tippecanoe \
  -f \
  -o "$PROV_MBTILES" \
  -l provincias \
  -z11 \
  -Z0 \
  -S 6 \
  -pk \
  -pf \
  "$PROV_FROM_MUNI"

pmtiles convert "$MUNI_MBTILES" "$MUNI_PMTILES"
pmtiles convert "$CCAA_MBTILES" "$CCAA_PMTILES"
pmtiles convert "$PROV_MBTILES" "$PROV_PMTILES"

if [[ -f "$LANDUSE_GEOJSON" ]]; then
  tippecanoe \
    -f \
    -o "$LANDUSE_MBTILES" \
    -l usos_suelo \
    -z12 \
    -Z5 \
    -y fclass \
    -y code \
    -S 6 \
    -pk \
    -pf \
    "$LANDUSE_GEOJSON"
  pmtiles convert "$LANDUSE_MBTILES" "$LANDUSE_PMTILES"
  cp "$LANDUSE_PMTILES" "$FRONTEND_TILES_DIR/usos_suelo.pmtiles"
fi

cp "$MUNI_PMTILES" "$FRONTEND_TILES_DIR/municipios.pmtiles"
cp "$CCAA_PMTILES" "$FRONTEND_TILES_DIR/ccaa.pmtiles"
cp "$PROV_PMTILES" "$FRONTEND_TILES_DIR/provincias.pmtiles"

echo "OK: PMTiles municipios en $MUNI_PMTILES"
echo "OK: PMTiles CCAA en $CCAA_PMTILES"
echo "OK: PMTiles provincias en $PROV_PMTILES"
if [[ -f "$LANDUSE_PMTILES" ]]; then
  echo "OK: PMTiles usos de suelo en $LANDUSE_PMTILES"
fi
echo "OK: Copiados a frontend/static/tiles/"

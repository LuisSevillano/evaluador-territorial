#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/data/raw/climate/terraclimate"
BASE_URL="https://climate.northwestknowledge.net/TERRACLIMATE-DATA"

START_YEAR="${1:-2014}"
END_YEAR="${2:-2023}"

VARS=(ppt tmin tmax)

mkdir -p "$OUT_DIR"

validate_nc() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    return 1
  fi

  if command -v gdalinfo >/dev/null 2>&1; then
    gdalinfo "$path" >/dev/null 2>&1
    return $?
  fi

  return 0
}

download_one() {
  local var="$1"
  local year="$2"
  local file="TerraClimate_${var}_${year}.nc"
  local tmp="$OUT_DIR/${file}.part"
  local dest="$OUT_DIR/$file"
  local url="$BASE_URL/$file"

  if [[ -f "$dest" ]]; then
    if validate_nc "$dest"; then
      echo "[SKIP] $file"
      return 0
    fi
    echo "[BAD ] $file (se re-descarga)"
    rm -f "$dest"
  fi

  echo "[GET ] $file"
  rm -f "$tmp"

  curl \
    --fail \
    --location \
    --retry 8 \
    --retry-delay 4 \
    --retry-all-errors \
    --connect-timeout 20 \
    --max-time 0 \
    --continue-at - \
    --output "$tmp" \
    "$url"

  mv "$tmp" "$dest"

  if ! validate_nc "$dest"; then
    echo "[FAIL] $file descargado pero invalido"
    rm -f "$dest"
    return 1
  fi

  echo "[ OK ] $file"
}

for year in $(seq "$START_YEAR" "$END_YEAR"); do
  for var in "${VARS[@]}"; do
    download_one "$var" "$year"
  done
done

echo "Descargas completadas en: $OUT_DIR"

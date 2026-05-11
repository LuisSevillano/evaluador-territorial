#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/data/raw/climate/terraclimate"
BASE_URL="https://climate.northwestknowledge.net/TERRACLIMATE-DATA"

START_YEAR="${1:-2014}"
END_YEAR="${2:-2023}"
PARALLEL_JOBS="${3:-8}"

VARS=(ppt pet tmin tmax)

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

is_valid_nc() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    return 1
  fi
  if command -v gdalinfo >/dev/null 2>&1; then
    gdalinfo "$path" >/dev/null 2>&1 2>&1
    local layers=$(gdalinfo "$path" 2>/dev/null | grep -c "SUBDATASET" || true)
    if [[ "$layers" -gt 0 ]]; then
      gdalinfo "$path" 2>/dev/null | head -5 | grep -q "NETCDF" && return 0
    fi
    gdalinfo "$path" >/dev/null 2>&1 && return 0
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

  if [[ -f "$dest" ]] && is_valid_nc "$dest"; then
    echo "[SKIP] $file"
    return 0
  fi

  if [[ -f "$dest" ]]; then
    echo "[BAD ] $file (se re-descarga)"
    rm -f "$dest"
  fi

  echo "[GET ] $file"
  rm -f "$tmp"

  if curl \
    --fail \
    --location \
    --retry 8 \
    --retry-delay 4 \
    --retry-all-errors \
    --connect-timeout 20 \
    --max-time 0 \
    --output "$tmp" \
    "$url" 2>/dev/null; then
    mv "$tmp" "$dest"
    if is_valid_nc "$dest"; then
      echo "[ OK ] $file"
      return 0
    else
      echo "[FAIL] $file invalido"
      rm -f "$dest"
      return 1
    fi
  else
    echo "[ERR ] $file"
    rm -f "$tmp"
    return 1
  fi
}

export -f download_one is_valid_nc validate_nc
export OUT_DIR BASE_URL

years=($(seq "$START_YEAR" "$END_YEAR"))
jobs=()

for var in "${VARS[@]}"; do
  for year in "${years[@]}"; do
    jobs+=("$var $year")
  done
done

echo "Descargando ${#jobs[@]} archivos con hasta $PARALLEL_JOBS trabajos en paralelo..."
printf '%s\n' "${jobs[@]}" | \
  xargs -P "$PARALLEL_JOBS" -I {} bash -c 'read var year <<< "{}"; download_one "$var" "$year"'

total=$(ls -1 "$OUT_DIR"/TerraClimate_*.nc 2>/dev/null | wc -l)
echo "Completado. Archivos en cache: $total"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Pipeline norte + tiles =="
cd "$ROOT_DIR"

ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R
bash scripts/05_build_pmtiles.sh

echo "== Validacion frontend =="
cd "$ROOT_DIR/frontend"
npx svelte-check --tsconfig ./tsconfig.json
npm run build

echo "OK: ejecucion completa para scope norte"

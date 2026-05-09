#!/usr/bin/env bash
set -euo pipefail

export ANALYSIS_SCOPE="${ANALYSIS_SCOPE:-norte}"
export PIPELINE_USE_BATHING_SOURCES=1

cache_file="data/intermediate/hydro/banio_access/scope_${ANALYSIS_SCOPE}_rivers_candidates.rds"

if [[ ! -f "$cache_file" ]]; then
  echo "[bathing] No existe cache proxy ($cache_file); generando candidatos fluviales legacy una vez..."
  BANIO_WRITE_DIAG="${BANIO_WRITE_DIAG:-0}" Rscript scripts/04g_banio_score_simple.R
fi

echo "[bathing] Ejecutando pipeline con score hibrido oficial + proxy capado..."
Rscript scripts/run_pipeline_v2.R

echo "[bathing] Resumen generado en output/bathing_access_summary.csv"

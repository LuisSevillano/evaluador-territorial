# Runbook operativo

Esta página resume la secuencia recomendada para generar datos, validar y compilar.

Sirve como guía de operación rápida para ejecuciones repetibles.

## Corrida completa recomendada

```bash
ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R
./scripts/05_build_pmtiles.sh
```

## Export frontend

```bash
Rscript scripts/05_export_frontend_v2.R
```

## Build app

```bash
cd frontend
npm run check
npm run build
```

## Build docs

```bash
cd docs-site
npm run docs:build
```

## Nota operativa

Si la ejecución termina bien pero aparecen resultados atípicos, revisar primero QA metodológico antes de desplegar.

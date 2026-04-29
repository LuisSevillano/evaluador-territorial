# Runbook operativo

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

# Runbook operativo

Esta página resume la secuencia recomendada para generar datos, validar resultados y compilar.
Sirve como guía rápida para ejecuciones repetibles.

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

Si la ejecución termina bien pero aparecen resultados atípicos, conviene revisar QA metodológico antes de desplegar.

## Qué no asumir

- Una ejecución sin errores no garantiza resultados razonables.
- Antes de publicar, conviene revisar distribución de scores y coherencia espacial.

# Getting Started

Está página queda en el anexo técnico. Está pensada para quien necesita ejecutar, depurar o desplegar el proyecto.

## Requisitos

- Node 20+
- R 4.3+
- Dependencias GIS (`sf`, `terra`, `exactextractr`, `tippecanoe`)

## Ejecutar frontend

```bash
cd frontend
npm install
npm run dev
```

## Ejecutar pipeline completo

```bash
ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R
./scripts/05_build_pmtiles.sh
```

## Ejecutar documentación

```bash
cd docs-site
npm install
npm run docs:dev
```

## Publicacion docs en `/docs/`

La documentación se compila con VitePress y se copia a `frontend/build/docs` antes del deploy productivo.

## Recorrido recomendado de lectura

1. [Arquitectura del atlas](/arquitectura)
2. [Pipeline](/pipeline/)
3. [Indicadores](/indicadores/)
4. [Por qué confiar en el análisis](/analisis-objetividad)

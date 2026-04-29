# Getting Started técnico

Esta página contiene los comandos mínimos para ejecutar, depurar y compilar el proyecto.

Si solo se necesita entender el Atlas, conviene empezar por la sección conceptual y volver aquí cuando haga falta ejecutar algo.

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

## Publicación de docs en `/docs/`

La documentación se compila con VitePress y se copia a `frontend/build/docs` antes del despliegue productivo.

## Recorrido recomendado de lectura

1. [Arquitectura del Atlas](/arquitectura)
2. [Visión general del pipeline](/pipeline/)
3. [Indicadores](/indicadores/)
4. [Cómo leer los resultados con criterio](/analisis-objetividad)

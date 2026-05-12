# Arquitectura Persistente

## Capas Reales
- `frontend/`: SvelteKit 2 con Svelte 5, app estatica con `@sveltejs/adapter-static`; salida en `frontend/build` con fallback SPA `200.html`.
- `scripts/`: pipeline de datos en R y utilidades shell; entrada vigente `scripts/run_pipeline_v2.R`.
- `docs-site/`: documentacion VitePress publicada bajo `/docs/` y embebida dentro del build del frontend.
- `output/`: artefactos de pipeline, features intermedias, cache de pasos, GeoJSON/JSON finales y tiles temporales.
- `docs/`: documentacion de proyecto y contexto persistente para agentes; no confundir con `docs-site/`, que es el sitio publico.

## Frontend
- Stack: SvelteKit 2, Svelte 5, TypeScript, Vite, MapLibre GL, PMTiles y D3.
- Estado UI actual: stores/runes bajo `frontend/src/lib/state/`.
- Componentes principales: mapa en `frontend/src/lib/components/MapView.svelte`, inspector en `InspectorPanel.svelte`, sidebar/mobile sheets y modulos de mapa bajo `frontend/src/lib/components/map/`.
- Datos estaticos consumidos desde `frontend/static/data/` y tiles desde `frontend/static/tiles/`.
- La app carga primero `municipios_v2.compact.json` + `municipios_v2.dictionary.json`; `municipios_v2.json` es fallback legible. Los tres se generan desde `scripts/05_export_frontend_v2.R`.
- Si se toca Svelte 5, usar patrones de Svelte 5 y no reintroducir APIs antiguas si el archivo ya usa runes.

## Pipeline De Datos
- `scripts/run_pipeline_v2.R` orquesta pasos incrementales y usa cache en `output/pipeline_step_hashes.json`.
- `scripts/run_pipeline.R` es legado; no usarlo para trabajo nuevo.
- Configuracion central en `scripts/00_config.R`, incluyendo `ANALYSIS_SCOPE`, rutas absolutas locales y paths frontend/output.
- El ensamblado vigente pasa por features RDS en `output/features/` y export final via `scripts/05_export_frontend_v2.R`.
- Si `score_source` es `cell_agg`, el score municipal publicado usa medianas de la rejilla 2x2 km agregadas al municipio.
- Transporte OSM/Renfe es opt-in con `PIPELINE_INCLUDE_TRANSPORT=1`.
- Fuentes de bano/agua hibrida son opt-in con `PIPELINE_USE_BATHING_SOURCES=1`.

## Tiles Y Mapas
- PMTiles municipales y fronteras se generan con `scripts/05_build_pmtiles.sh`.
- El script usa `output/municipios_v2.geojson` y cae a `output/municipios_final.geojson` como fallback.
- Para alinear fronteras en tiles, `provincias.pmtiles` y `ccaa.pmtiles` se disuelven desde la geometria municipal simplificada por mapshaper; la provincia/CCAA se asigna antes mediante join espacial contra las capas oficiales, no por prefijos de codigo municipal.
- PMTiles finales se copian a `frontend/static/tiles/`: `municipios.pmtiles`, `ccaa.pmtiles`, `provincias.pmtiles` y opcionalmente `usos_suelo.pmtiles`.
- Los tiles de isocronas y grid tienen scripts propios (`05d_build_isochrones_pmtiles.sh`, `05c_build_grid_pmtiles.sh`) llamados desde el pipeline v2.

## Docs Publicas
- `docs-site/.vitepress/config.mjs` debe mantener `base: '/docs/'`.
- `frontend/package.json` define `build:with-docs`, que borra `frontend/build`, compila app, compila docs y copia `docs-site/.vitepress/dist` a `frontend/build/docs`.
- La fuente de verdad de Netlify para la app es `frontend/netlify.toml`, no `.netlify/netlify.toml`.

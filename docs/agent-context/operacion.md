# Operacion Y Verificacion

## Arranque De Sesion
- Leer primero este sistema modular: `AGENTS.md`, `producto.md`, `arquitectura.md`, `operacion.md`, `decisiones-recientes.md` y `no-repetir.md`.
- Clasificar el cambio como `frontend`, `docs-site`, `scripts/pipeline`, `datos/tiles` o mixto.
- Si el cambio mezcla capas, validar en este orden: datos, tiles, frontend, docs.
- Si algo no cuadra, revisar primero rutas absolutas en `scripts/00_config.R`, artefactos en `output/` y exports en `frontend/static/data/`.

## Politica De Decisiones Y Documentacion
- Cualquier decision nueva de producto, arquitectura, metodologia, datos u operacion debe documentarse en la misma sesion.
- Si la decision afecta a miembros del proyecto, usuarios internos o explicacion publica, actualizar `docs-site/` en la pagina mas cercana.
- Si la decision afecta a como debe comportarse OpenCode en futuras sesiones, actualizar `docs/agent-context/` en el modulo correspondiente.
- Si una decision afecta a ambas audiencias, actualizar ambas capas: `docs-site/` y `docs/agent-context/`.
- No dejar decisiones relevantes solo en el chat: el chat no es memoria persistente del proyecto.

## Comandos Canonicos
- Frontend dev: `npm run dev` desde `frontend/`.
- Frontend typecheck: `npm run check` desde `frontend/`.
- Frontend build: `npm run build` desde `frontend/`.
- Build prod app + docs: `npm run build:with-docs` desde `frontend/`.
- Deploy prod: `npm run deploy` desde `frontend/`.
- Docs local: `npm run docs:dev` desde `docs-site/`.
- Docs build: `npm run docs:build` desde `docs-site/`.
- Pipeline por defecto: `ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R` desde la raiz.
- Rebuild total pipeline: `PIPELINE_FORCE=1 ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Solo ensamblado/export: `PIPELINE_MODE=assemble-only ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Atajo end-to-end validado: `./scripts/run_norte_full.sh` desde la raiz.

## Prerrequisitos Conocidos
- Node 20 para Netlify y frontend.
- R 4.3+ para pipeline.
- `tippecanoe`, `pmtiles` y `mapshaper` para `scripts/05_build_pmtiles.sh`.
- `scripts/00_config.R` contiene rutas absolutas locales a shapefiles e isocronas; en otra maquina hay que reconfigurar antes de correr pipeline.

## Verificacion Minima
- Si se toca frontend: `npm run check` y `npm run build` desde `frontend/`.
- Si se toca docs publicas: `npm run docs:build` desde `docs-site/`; si afecta integracion final, tambien `npm run build:with-docs` desde `frontend/`.
- Si se documenta una decision en `docs-site/`, ejecutar `npm run docs:build` desde `docs-site/` cuando sea razonable para el cambio.
- Si se toca pipeline o salidas geoespaciales: `ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R` y despues `./scripts/05_build_pmtiles.sh`.
- Si se toca scoring, indicadores o copy metodologico: verificar que `mixed_score` siga explicandose como comparativo del scope y que `river_access_score` no se describa como calidad sanitaria.

## Diagnostico Rapido
- Build OK pero `/docs` roto: revisar `docs-site/.vitepress/config.mjs` y reconstruir con `npm run build:with-docs` desde `frontend/`.
- Mapa sin datos nuevos: confirmar export a `frontend/static/data/`, no solo a `output/`.
- Capa municipal no carga: comprobar `frontend/static/tiles/municipios.pmtiles`, `ccaa.pmtiles` y `provincias.pmtiles`.
- Pipeline falla en maquina nueva: sospechar rutas absolutas o CLIs faltantes antes de redisenar codigo.
- Cambios de transporte no aparecen: recordar `PIPELINE_INCLUDE_TRANSPORT=1`.
- Cambios de scripts no se reflejan: sospechar cache incremental y usar `PIPELINE_FORCE=1` si procede.

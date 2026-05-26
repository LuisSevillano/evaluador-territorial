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
- Frontend dev: `pnpm run dev` desde `frontend/`.
- Frontend typecheck: `pnpm run check` desde `frontend/`.
- Frontend build: `pnpm run build` desde `frontend/`.
- Build prod app + docs: `pnpm run build:with-docs` desde `frontend/`.
- Deploy prod: `pnpm run deploy` desde `frontend/`.
- Docs local: `pnpm run docs:dev` desde `docs-site/`.
- Docs build: `pnpm run docs:build` desde `docs-site/`.
- Pipeline por defecto: `ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R` desde la raiz.
- Rebuild total pipeline: `PIPELINE_FORCE=1 ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Solo ensamblado/export: `PIPELINE_MODE=assemble-only ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Preparar inputs OTP: `./scripts/04c_otp_download_inputs.sh` desde la raiz.
- Descargar GTFS NAP autenticados: definir `NAP_USER`/`NAP_PASS` solo en el entorno y ejecutar `./scripts/04c_otp_download_nap_gtfs.py`; admite detalles extra con `NAP_DETAIL_IDS=1364,1559`.
- Construir/servir OTP: `./scripts/04d_otp_server.sh build` y `./scripts/04d_otp_server.sh serve` desde la raiz.
- Pipeline con piloto OTP Burgos-Madrid: `PIPELINE_INCLUDE_OTP_TRANSIT=1 ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Playground rapido OTP: `OTP_ENDPOINT=http://localhost:8081/otp/gtfs/v1 ANALYSIS_SCOPE=norte Rscript scripts/04c_otp_playground.R`; por defecto prueba Aranda de Duero, Burgos, Lerma y Medina de Pomar, y admite `OTP_PLAYGROUND_MUNICIPIOS="Aranda de Duero,Burgos"`.
- Si el puerto local 8080 esta ocupado, servir OTP mapeando otro puerto Docker y pasar `OTP_ENDPOINT`, por ejemplo `OTP_ENDPOINT=http://localhost:8081/otp/gtfs/v1`.
- El piloto OTP usa por defecto `OTP_SEARCH_WINDOW=PT24H`, `OTP_N_ROUTES=5`, `OTP_NEAREST_STOP_RADIUS_M=15000`, `OTP_NEAREST_STOP_CANDIDATES=10` y `OTP_PARALLEL_WORKERS=6`. Procesa 7 días (lun-dom) con ventana 00:00-23:59, paralelizando con `mclapply`. Enfoque **stop-first**: destino es la mejor parada GTFS del municipio (por nombre o cercanía), no el centroide. Orígenes: 4 intercambiadores Madrid (Avenida de América, Moncloa, Estación Sur, Chamartín). Estrategia: prueba origen primario por parada, si encuentra ruta refina con los 3 restantes. Primer día hábil con ruta gana. Configurable por provincia vía `OTP_SCOPE_PROVINCE=09`.
- Atajo end-to-end validado: `./scripts/run_norte_full.sh` desde la raiz.

## Prerrequisitos Conocidos
- Node 20 para Netlify y frontend.
- R 4.3+ para pipeline.
- `tippecanoe`, `pmtiles` y `mapshaper` para `scripts/05_build_pmtiles.sh`.
- Docker para construir/servir el grafo OpenTripPlanner del piloto OTP; el helper usa por defecto `opentripplanner/opentripplanner:2.8.1` porque `latest` puede romper por entrypoint incompleto.
- `scripts/04d_otp_server.sh serve` usa TTY solo en sesiones interactivas; puede ejecutarse tambien desde automatizacion sin `-t`.
- El grafo OTP piloto usa extractos OSM Geofabrik de Castilla y Leon y Madrid, no `spain-latest.osm.pbf`, para evitar builds inviables por memoria.
- Los GTFS-ZIP de NAP requieren sesion autenticada para descarga directa; `scripts/04c_otp_download_inputs.sh` deja un manifest de candidatos y `scripts/04c_otp_download_nap_gtfs.py` los baja si recibe `NAP_USER`/`NAP_PASS` por entorno. Para OTP 2.8.1, los `.gtfs.zip` deben quedar directamente en `data/raw/otp/graph/`, no dentro de una subcarpeta `gtfs/`.
- Para el piloto Burgos-Madrid, no cargar todos los GTFS NAP a la vez en OTP: mantener activos solo feeds relevantes (ALSA, AISA Madrid-Aranda, urbano Burgos/Aranda y Renfe media/larga) y archivar el resto fuera de `data/raw/otp/graph/` para evitar OOM.
- `scripts/00_config.R` contiene rutas absolutas locales a shapefiles e isocronas; en otra maquina hay que reconfigurar antes de correr pipeline.

## Verificacion Minima
- Si se toca frontend: `pnpm run check` y `pnpm run build` desde `frontend/`.
- Si se toca docs publicas: `pnpm run docs:build` desde `docs-site/`; si afecta integracion final, tambien `pnpm run build:with-docs` desde `frontend/`.
- Si se documenta una decision en `docs-site/`, ejecutar `pnpm run docs:build` desde `docs-site/` cuando sea razonable para el cambio.
- Si se toca pipeline o salidas geoespaciales: `ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R` y despues `./scripts/05_build_pmtiles.sh`.
- Si se toca scoring, indicadores o copy metodologico: verificar que `mixed_score` siga explicandose como comparativo del scope y que `river_access_score` no se describa como calidad sanitaria.

## Diagnostico Rapido
- Build OK pero `/docs` roto: revisar `docs-site/.vitepress/config.mjs` y reconstruir con `npm run build:with-docs` desde `frontend/`.
- Mapa sin datos nuevos: confirmar export a `frontend/static/data/`, no solo a `output/`.
- Capa municipal no carga: comprobar `frontend/static/tiles/municipios.pmtiles`, `ccaa.pmtiles` y `provincias.pmtiles`.
- Pipeline falla en maquina nueva: sospechar rutas absolutas o CLIs faltantes antes de redisenar codigo.
- Cambios de transporte no aparecen: recordar `PIPELINE_INCLUDE_TRANSPORT=1`.
- Cambios de scripts no se reflejan: sospechar cache incremental y usar `PIPELINE_FORCE=1` si procede.

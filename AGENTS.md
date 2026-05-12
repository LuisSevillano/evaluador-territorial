# AGENTS

## Rol De Este Archivo
- Este archivo es el indice operativo corto para sesiones nuevas de OpenCode.
- El contexto persistente completo se carga desde `opencode.json` mediante `instructions`.
- No duplicar aqui decisiones largas: actualizar el modulo correspondiente en `docs/agent-context/`.
- Toda decision nueva debe quedar documentada en la capa publica/de proyecto (`docs-site/`) y en la memoria de agentes (`docs/agent-context/`) si afecta a continuidad de OpenCode.

## Contexto Modular Obligatorio
- Producto y metodologia: `docs/agent-context/producto.md`.
- Arquitectura real: `docs/agent-context/arquitectura.md`.
- Operacion, comandos y verificacion: `docs/agent-context/operacion.md`.
- Estado actual y decisiones recientes: `docs/agent-context/decisiones-recientes.md`.
- Cosas que no deben repetirse: `docs/agent-context/no-repetir.md`.

## Arranque En 60 Segundos
- Clasificar el cambio como `frontend`, `docs-site`, `scripts/pipeline`, `datos/tiles` o mixto.
- Leer solo los archivos fuente concretos del area tocada despues de cargar el contexto modular.
- Si mezcla capas, validar en este orden: datos, tiles, frontend, docs.
- Si algo no cuadra, revisar primero `scripts/00_config.R`, `output/`, `frontend/static/data/` y `frontend/static/tiles/`.
- Si durante la sesion se toma una decision de producto, arquitectura, metodologia u operacion, actualizar inmediatamente la documentacion correspondiente.

## Comandos Canonicos
- Frontend check/build: desde `frontend/`, `npm run check` y `npm run build`.
- Build prod app + docs: desde `frontend/`, `npm run build:with-docs`.
- Docs build: desde `docs-site/`, `npm run docs:build`.
- Pipeline por defecto: desde raiz, `ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R`.
- Pipeline + tiles + frontend end-to-end: desde raiz, `./scripts/run_norte_full.sh`.

## Guardarrailes Criticos
- `scripts/run_pipeline_v2.R` es la entrada vigente; `scripts/run_pipeline.R` es legado.
- El scope `norte` vigente incluye Madrid segun `scripts/00_config.R`.
- `mixed_score` es comparativo dentro del scope activo, no absoluto universal.
- `river_access_score` es acceso fluvial recreativo potencial, no calidad sanitaria del agua.
- La UX objetivo es unificada; no reintroducir modos separados por defecto.
- No romper `base: '/docs/'` en VitePress ni la integracion `build:with-docs`.

# No Repetir

## Decisiones Ya Descartadas O Peligrosas
- No usar `scripts/run_pipeline.R` para cambios nuevos; es legado.
- No proponer separar la UX en modo exploracion y modo evaluacion como direccion por defecto.
- No presentar `mixed_score` como ranking absoluto universal.
- No presentar `river_access_score` como calidad sanitaria del agua.
- No volver a basar la humedad climatica solo en percentiles internos; mantener separado `precip_moisture_score` absoluto/hibrido y `precip_relative_score` relativo.
- No hacer que las gotas de humedad cambien por filtros o subconjuntos analizados.
- No asumir que `norte` excluye Madrid; el codigo vigente lo incluye.
- No romper `base: '/docs/'` en VitePress.
- No tratar `.netlify/netlify.toml` como fuente de verdad productiva.
- No proponer backend, base de datos o SSR dinamico para resolver problemas que la arquitectura estatica ya cubre.
- No regenerar todo el pipeline como primera reaccion ante datos obsoletos; revisar cache, exports y artefactos concretos.
- No actualizar solo `municipios_v2.json`: la app carga primero `municipios_v2.compact.json` y tambien debe regenerarse `municipios_v2.dictionary.json`.
- No modificar rutas absolutas de `scripts/00_config.R` sin confirmar impacto local.

## Diagnosticos Ya Conocidos
- Si `/docs` falla en deploy, revisar base VitePress e integracion `build:with-docs` antes de buscar problemas de router.
- Si el mapa no refleja datos nuevos, revisar `frontend/static/data/` antes de depurar componentes.
- Si ranking/municipio y rejilla discrepan, comparar `score_source`, `mixed_score` del compacto y mediana de celdas en `output/municipios_grid_2km.geojson`.
- Si faltan tiles, ejecutar o revisar `scripts/05_build_pmtiles.sh` y los PMTiles copiados al frontend.
- Si transporte no aparece, comprobar `PIPELINE_INCLUDE_TRANSPORT=1`.
- Si outputs no cambian tras tocar scripts, comprobar `output/pipeline_step_hashes.json` y usar `PIPELINE_FORCE=1` cuando corresponda.

## Anti-Patrones De Agente
- No empezar sesiones proponiendo arquitectura sin leer `opencode.json`, `AGENTS.md` y `docs/agent-context/`.
- No redescubrir el repo desde cero si el cambio es localizado; usar la arquitectura persistente como mapa inicial y luego verificar archivos concretos.
- No duplicar contexto largo en `AGENTS.md`; actualizar el modulo adecuado.
- No mezclar documentacion publica (`docs-site/`) con memoria interna de agentes (`docs/agent-context/`).
- No dejar decisiones relevantes solo en el chat; reflejarlas en `docs-site/` y/o `docs/agent-context/` segun audiencia.
- No borrar ni revertir cambios ajenos en un worktree sucio.

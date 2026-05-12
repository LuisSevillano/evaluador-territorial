# Decisiones Recientes Y Estado Actual

## Estado Del Producto
- La UX objetivo es una experiencia unificada; no dividir en modo exploracion y modo evaluacion salvo peticion explicita.
- El inspector y los graficos de clima ya existen; el roadmap anota mejorar graficos del inspector como siguiente area, no crear un inspector desde cero.
- El producto ya trabaja con mapa, ranking, filtros, capas, panel lateral y experiencia mobile con bottom sheets.

## Estado De Datos
- Dataset metadata vigente: `dataset_version` v3.0.0 en `docs/indicators.md` y `dataset_metadata_v3.json`.
- `analysis_scope` documentado en indicadores incluye Madrid; `scripts/00_config.R` tambien incluye Madrid en `norte`.
- El pipeline v2 confia por defecto en outputs existentes (`PIPELINE_TRUST_OUTPUTS=1`) y omite pasos por hash si entradas/salidas no cambian.
- El pipeline actual incluye relieve, grid 2km, PMTiles de grid, controles de calidad y metadatos.
- `scripts/05_export_frontend_v2.R` genera tambien `municipios_v2.compact.json` y `municipios_v2.dictionary.json`; no basta con actualizar solo `municipios_v2.json`.

## Estado De Arquitectura
- La app es estatica; evitar proponer backend persistente, SSR dinamico o base de datos si no existe un requerimiento nuevo.
- La documentacion publica vive en `docs-site/` y se integra en el build final; `docs/` es documentacion interna del repo.
- El deploy productivo debe ejecutar app + docs via `frontend` y `build:with-docs`.
- Netlify usa Node 20 segun configuracion frontend.

## Estado Metodologico
- `mixed_score` combina bloques de clima, accesibilidad y naturaleza segun `docs/indicators.md`; tratarlo como comparativo y sensible a scope.
- El scoring de pluviometria vigente es `v3.1_hybrid_moisture`: usa TerraClimate 2014-2023 como referencia climatica absoluta operativa, no AEMET como fuente principal inicial.
- AEMET queda para fase posterior de validacion, calibracion y documentacion publica del score de humedad.
- `precip_moisture_score` combina 60% humedad absoluta, 25% sequia estival y 15% ventaja relativa interna; `precip_relative_score` no debe dominar la interpretacion climatica.
- `water_drops_level` y `water_drops_label` se derivan de humedad absoluta y sequia estival con umbrales fijos; no deben cambiar por filtros ni percentiles internos.
- En municipios con `score_source=cell_agg`, `mixed_score` y bloques publicados proceden de la mediana de celdas 2x2 km para mantener coherencia con el modo rejilla.
- `accesibilidad_norm` tiene suelo metodologico de 0.20 para evitar colapso a cero en territorios lejanos.
- Las isocronas precalculadas son un input metodologico, no una API de routing en tiempo real.
- El acceso fluvial recreativo no equivale a calidad sanitaria ni aptitud legal de bano.
- En el inspector, `water_pct` no debe mostrarse como métrica principal aislada: representa láminas/superficie de agua MFE y queda como detalle secundario dentro de una lectura combinada de agua y ríos con distancia al tramo cercano y clase de acceso recreativo.
- Los Espacios Naturales Protegidos MITECO ENP 2025 se integran como informacion contextual opt-in (`PIPELINE_INCLUDE_PROTECTED_AREAS=1`): lista `ODESIGNATE: SITE_NAME` cruzada por rejilla 2x2 km y agregada a municipio. No crean metrica, no normalizan y no afectan a `mixed_score` ni `nature_block_score`.

## Estado Operativo
- Hay doble configuracion Netlify: `frontend/netlify.toml` es fuente operativa; `.netlify/netlify.toml` puede reflejar estado local de CLI.
- Los datos finales para frontend se escriben tanto en `output/` como en `frontend/static/data/`; revisar ambos si hay divergencias.
- Los tiles de municipios, provincias y CCAA deben compartir geometria base: `scripts/05_build_pmtiles.sh` simplifica municipios con mapshaper, asigna provincia/CCAA por join espacial contra capas oficiales y deriva provincias/CCAA por dissolve desde esa misma capa antes de tippecanoe.
- `output/` contiene artefactos grandes y cache; no borrar ni regenerar masivamente sin necesidad.

## Decision De Gobernanza Documental
- Las decisiones tomadas durante una sesion no deben quedar solo en la conversacion.
- Toda decision relevante debe tener reflejo inmediato en `docs-site/` si afecta al equipo/proyecto y en `docs/agent-context/` si afecta a continuidad de OpenCode.
- Cuando una decision tenga impacto operativo y tambien de producto/metodologia, actualizar ambas capas en el mismo cambio.

# Release Checklist

- [x] Pipeline `run_pipeline_v2.R` ejecuta completo sin errores.
- [x] PMTiles regenerados con `scripts/05_build_pmtiles.sh`.
- [x] Frontend `npm run check` sin errores ni warnings.
- [x] Frontend `npm run build` correcto (warning de chunk conocido).
- [x] Mapa coloreable por `mixed_score` y por precipitación.
- [x] Tooltip en hover con info básica municipal.
- [x] Capa de metodología colapsable y metadatos visibles.
- [x] Sensibilidad ligera top-10 activa en panel.
- [x] Sin comparador formal de municipios (requisito actual).

## Notas

- Para entorno natural real, cargar CORINE en `data/raw/corine/corine_cyl.geojson`.
- Las capas `masa_forestal`, `usos_suelo`, `cobertura_vegetal` quedan preparadas y se alimentan desde pipeline.

# Metodologia (fase 0)

Este repositorio implementa una fase 0 del visor territorial:

- unidad de analisis: municipio
- datos: dataset local sintetico
- objetivo: validar arquitectura y flujo de trabajo

## Flujo actual

1. `data/raw/municipios_sample.csv` define el dataset de entrada minimo.
2. `scripts/01_prepare_municipios.R` crea un JSON derivado con campos listos para frontend.
3. El frontend lee `frontend/static/data/municipios.sample.json`.

## Criterios de diseno

- Sin APIs externas obligatorias para que la demo funcione.
- Estructura preparada para incorporar capas reales (vector/raster/PMTiles).
- Reproducible: un script regenera el dataset de la demo.

## Limites conocidos

- El score de municipio es ilustrativo (`score_demo`).
- No hay comparador multicriterio completo ni sensibilidad en esta iteracion.
- No hay capas reales de clima/cobertura/agua todavia.

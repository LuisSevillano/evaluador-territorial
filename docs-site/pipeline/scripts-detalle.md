# Scripts detallados

## Orquestacion

### `scripts/run_pipeline_v2.R`

- Orquestá 14 pasos del pipeline v2.
- Registra ETA por paso y duracion total.
- Orden fijo de ejecución para reproducibilidad.

## Configuración

### `scripts/00_config.R`

- Define `ANALYSIS_SCOPE` (`avila`, `norte`, `cyl`, `espana`).
- Define rutas de entrada/salida del proyecto.
- Inicializa directoríos de salida.

## Construccion de datos

### `scripts/01_municipios_base.R`

- Construye geometría municipal base segun scope.
- Estandariza campos (`codigo`, `nombre`, `provincia`).

### `scripts/02_clima_real.R`

- Agrega clima mensual/anual por poligono municipal.
- Produce variables climaticas de referencia.

### `scripts/03_isochrones.R`

- Calcula pertenencia a isocronas.
- Deriva bucket de accesibilidad principal.

### `scripts/03b_isochrones_difference.R`

- Genera anillos diferenciales para representacion no solapada.

### `scripts/04_entorno_corine.R`

- Cruza municipios con CORINE.
- Deriva `forest_pct`, `water_pct`, `artificial_pct`, `naturality_index`, `landcover_diversity`.

### `scripts/04_transporte_distance.R`

- Distancia a nodos de transporte (OSM) y normalizacion base.

### `scripts/04b_transporte_renfe.R`

- Distancia y servicio ferroviarío (frecuencia y tipo).

### `scripts/04g_banio_score_simple.R`

- Filtrado conservador de tramos fluviales candidatos.
- Diagnostico por señales positivas y exclusiones.
- Calcula proximidad + confianza + clase de acceso fluvial.

### `scripts/04_quality_checks.R`

- Validaciones de integridad: geometrías, duplicados, buckets y nulos críticos.

### `scripts/05_export_frontend_v2.R`

- Consolida dataset final `municipios_v2`.
- Normaliza indicadores y calcula bloques/score.
- Exporta CSV/JSON/GeoJSON para frontend.

### `scripts/05_build_pmtiles.sh`

- Simplifica geometría, repara intersecciones y genera PMTiles.

### `scripts/06_metadata_indicators.R`

- Genera metadata de dataset y descripcion de indicadores.

### `scripts/07_ccaa_boundaries.R` y `scripts/08_provincias_boundaries.R`

- Generan límites administrativos para capas de contexto.

## Scripts auxiliares

- `scripts/run_norte_full.sh`: comando rapido pipeline+tiles.
- `scripts/download_terraclimate.sh`: soporte de datos climaticos.

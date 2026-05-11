# Scripts detallados

Esta página enumera los scripts del pipeline y su función principal.

Sirve como referencia rápida para ejecución, depuración y auditoría.

## Orquestación

### `scripts/run_pipeline_v2.R`

- Orquesta 14 pasos del pipeline v2.
- Registra ETA por paso y duración total.
- Mantiene orden fijo de ejecución para reproducibilidad.

## Configuración

### `scripts/00_config.R`

- Define `ANALYSIS_SCOPE` (`avila`, `norte`, `cyl`, `espana`).
- Define rutas de entrada/salida del proyecto.
- Inicializa directorios de salida.

## Construcción de datos

### `scripts/01_municipios_base.R`

- Construye geometría municipal base según alcance.
- Estandariza campos (`código`, `nombre`, `provincia`).

### `scripts/02_clima_real.R`

- Agrega clima mensual y anual por polígono municipal.
- Produce variables climáticas de referencia.

### `scripts/03_isochrones.R`

- Calcula pertenencia a isocronas.
- Deriva bucket principal de accesibilidad.

### `scripts/03b_isochrones_difference.R`

- Genera anillos diferenciales para representación no solapada.

### `scripts/04_entorno_mfe.R`

- Calcula métricas de entorno natural usando el Mapa Forestal de España.
- Deriva `forest_pct`, `water_pct`, `artificial_pct`, `naturality_index`, `landcover_diversity` y `forest_nature_quality`.
- `water_pct` representa láminas/superficie de agua cartografiada; la experiencia de agua se explica mejor con distancia y clase de acceso fluvial.

### `scripts/04_transporte_distance.R`

- Calcula distancia a nodos de transporte (OSM) y normalización base.
- Se conserva como diagnóstico opcional; no valida servicio activo real.

### `scripts/04b_transporte_renfe.R`

- Calcula conectividad ferroviaria directa con Madrid a partir del calendario GTFS disponible.
- Valida que las paradas tengan viajes activos hacia paradas Madrid y resume cobertura, frecuencia y disponibilidad de fin de semana.

### `scripts/04g_banio_score_simple.R`

- Filtra tramos fluviales candidatos con enfoque conservador.
- Genera diagnóstico por señales positivas y exclusiones.
- Calcula proximidad + confianza + clase de acceso fluvial.

### `scripts/04_quality_checks.R`

- Valida integridad: geometrías, duplicados, buckets y nulos críticos.

### `scripts/05_export_frontend_v2.R`

- Consolida dataset final `municipios_v2`.
- Normaliza indicadores y calcula bloques/score.
- Exporta CSV/JSON/GeoJSON para frontend.

### `scripts/05_build_pmtiles.sh`

- Simplifica geometría, repara intersecciones y genera PMTiles.

### `scripts/06_metadata_indicators.R`

- Genera metadata de dataset y descripción de indicadores.

### `scripts/07_ccaa_boundaries.R` y `scripts/08_provincias_boundaries.R`

- Generan límites administrativos para capas de contexto.

## Scripts auxiliares

- `scripts/run_norte_full.sh`: atajo para pipeline + tiles.
- `scripts/download_terraclimate.sh`: soporte de datos climáticos.

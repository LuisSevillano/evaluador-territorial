source("scripts/00_config.R")

library(jsonlite)
library(fs)

dataset_version <- Sys.getenv("DATASET_VERSION", unset = "v3.0.0")
generated_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)

metadata <- list(
  dataset_version = dataset_version,
  generated_at_utc = generated_at_utc,
  analysis_scope = scope_config$label,
  climate_source = "TerraClimate (tmin, tmax, ppt, pet)",
  climate_reference = "TerraClimate",
  environment_source = "OSM Geofabrik (landuse/natural/water)",
  protected_areas_source = "MITECO Espacios Naturales Protegidos 2025 (opt-in)",
  climate_period = "2014-2023",
  aggregation_method = "Analisis primario por celda de 2x2 km y agregacion posterior a municipio (medianas y estadisticos de celdas)",
  isochrones_definition = "Bucket de accesibilidad calculado por celda y agregado a municipio por mayoria de celdas",
  scoring_method = "v3.1_hybrid_moisture",
  accessibility_normalization_floor = 0.2,
  scoring_weights = list(climate = 0.4, accessibility = 0.3, nature = 0.3)
)

lines <- c(
  "# Indicadores v2 - Observatorio Territorial El Buen Vivir",
  "",
  "## Clima",
  "- `precip_annual_mm`: precipitacion anual (mm) agregada a municipio desde mediana de celdas 2x2 km.",
  "- `precip_summer_mm`: precipitacion acumulada de junio, julio y agosto (mm).",
  "- `precip_winter_mm`: precipitacion acumulada de diciembre, enero y febrero (mm).",
  "- `aridity_index`: relacion P/PET anual sobre normal TerraClimate 1991-2020.",
  "- `summer_aridity_index`: relacion P/PET de junio-agosto.",
  "- `dry_months_count`: numero de meses secos segun criterio precip_mm < 2 * temp_media_c.",
  "- `precip_seasonality_index`: coeficiente de variacion mensual de la precipitacion.",
  "- `moisture_absolute_score`: score absoluto de humedad climatica por umbrales fijos.",
  "- `summer_drought_score`: score de sequia estival y lluvia util de verano.",
  "- `precip_relative_score`: ventaja relativa interna dentro del alcance activo.",
  "- `precip_moisture_score`: score hibrido de pluviometria = 60% humedad absoluta + 25% sequia estival + 15% ventaja relativa.",
  "- `water_drops_level` y `water_drops_label`: lectura visual estable derivada de humedad absoluta y sequia estival, no de filtros.",
  "- `temp_winter_mean_c`: temperatura media invierno (C) agregada a municipio desde mediana de celdas.",
  "- `temp_summer_mean_c`: temperatura media verano (C) agregada a municipio desde mediana de celdas.",
  "- `temp_jan_mean_c`: temperatura media enero (C).",
  "- `temp_jul_mean_c`: temperatura media julio (C).",
  "",
  "## Accesibilidad",
  "- `iso_01h30m`, `iso_02h00m`, `iso_02h30m`, `iso_03h30m`, `iso_04h00m`: pertenencia booleana por centroide municipal dentro de isocrona precalculada.",
  "- `travel_bucket`: bucket de accesibilidad derivado por celdas y agregado a municipio por mayoria.",
  "- `accesibilidad_norm`: normalizacion por buckets con suelo metodologico de 0.20 para evitar que territorios lejanos colapsen a cero.",
  "",
  "## Limitaciones",
  "- La unidad de calculo es celda 2x2 km; el municipio resume distribuciones internas y no microclima de parcela.",
  "- Isocronas fijas precalculadas: no representan variacion horaria o de trafico en tiempo real.",
  "",
  "## Entorno natural",
  "- `forest_pct`: porcentaje municipal de coberturas forestales y matorral (OSM `landuse` + `natural`).",
  "- `water_pct`: porcentaje municipal de coberturas de agua (OSM `water` + `natural=water/wetland`).",
  "- `artificial_pct`: porcentaje municipal de coberturas artificiales (OSM `landuse`).",
  "- `naturality_index`: indice simple de naturalidad (0-100).",
  "- `landcover_diversity`: diversidad de coberturas (Shannon normalizado 0-100).",
  "- `protected_areas`: lista contextual opt-in de espacios naturales protegidos presentes en celdas 2x2 km del municipio. Usa `ODESIGNATE` y `SITE_NAME` de MITECO ENP 2025 y no participa en el scoring.",
  "- `protected_areas_source`: fuente textual de la lista anterior cuando se genera con `PIPELINE_INCLUDE_PROTECTED_AREAS=1`.",
  "",
  "## Scoring compuesto",
  "- `climate_block_score`: bloque clima (media de precip_moisture_score, temp_verano_norm, temp_invierno_norm).",
  "- `access_block_score`: bloque accesibilidad (accesibilidad_norm).",
  "- `nature_block_score`: bloque naturaleza (media de forest_norm, water_norm, naturality_norm, diversity_norm).",
  "- `mixed_score`: score mixto final = 0.4 * clima + 0.3 * accesibilidad + 0.3 * naturaleza.",
  "",
  "## Trazabilidad del dataset",
  paste0("- `dataset_version`: ", metadata$dataset_version),
  paste0("- `generated_at_utc`: ", metadata$generated_at_utc),
  paste0("- `analysis_scope`: ", metadata$analysis_scope)
)

writeLines(lines, paths$docs_indicators)
writeLines(toJSON(metadata, auto_unbox = TRUE, pretty = TRUE), con = paths$output_dataset_metadata_json, useBytes = TRUE)
file_copy(paths$output_dataset_metadata_json, paths$frontend_dataset_metadata_json, overwrite = TRUE)
message("OK: metadatos escritos en ", paths$docs_indicators)
message("OK: metadata dataset JSON en ", paths$output_dataset_metadata_json)

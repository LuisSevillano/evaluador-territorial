source("scripts/00_config.R")

library(jsonlite)
library(fs)

dataset_version <- Sys.getenv("DATASET_VERSION", unset = "v3.0.0")
generated_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)

metadata <- list(
  dataset_version = dataset_version,
  generated_at_utc = generated_at_utc,
  analysis_scope = scope_config$label,
  climate_source = "TerraClimate (tmin, tmax, ppt)",
  environment_source = "CORINE Land Cover (si disponible en data/raw/corine)",
  climate_period = "2014-2023",
  aggregation_method = "Media zonal por poligono municipal (exactextractr) sobre climatologia mensual",
  isochrones_definition = "Bucle de isocronas precalculadas y bucket por primera cobertura del centroide municipal",
  scoring_method = "Score mixto por bloques normalizados: clima 40%, accesibilidad 30%, naturaleza 30%. La accesibilidad usa suelo metodologico del 20% para evitar anulacion total por lejania extrema",
  accessibility_normalization_floor = 0.2,
  scoring_weights = list(climate = 0.4, accessibility = 0.3, nature = 0.3)
)

lines <- c(
  "# Indicadores v2 - Observatorio Territorial El Buen Vivir",
  "",
  "## Clima",
  "- `precip_annual_mm`: precipitacion anual (mm). Fuente: TerraClimate mensual. Periodo: 2014-2023. Metodo: suma de climatologia mensual agregada por poligono municipal.",
  "- `temp_winter_mean_c`: temperatura media invierno (C). Fuente: TerraClimate (`tmin`, `tmax`). Metodo: media de dic-ene-feb sobre climatologia mensual municipal.",
  "- `temp_summer_mean_c`: temperatura media verano (C). Metodo: media de jun-jul-ago sobre climatologia mensual municipal.",
  "- `temp_jan_mean_c`: temperatura media enero (C).",
  "- `temp_jul_mean_c`: temperatura media julio (C).",
  "",
  "## Accesibilidad",
  "- `iso_01h30m`, `iso_02h00m`, `iso_02h30m`, `iso_03h30m`, `iso_04h00m`: pertenencia booleana por centroide municipal dentro de isocrona precalculada.",
  "- `travel_bucket`: bucket de accesibilidad derivado por prioridad de isocrona minima que contiene el centroide.",
  "- `accesibilidad_norm`: normalizacion por buckets con suelo metodologico de 0.20 para evitar que territorios lejanos colapsen a cero.",
  "",
  "## Limitaciones",
  "- Clima agregado a escala municipal desde raster (no microclima de parcela).",
  "- Isocronas fijas precalculadas: no representan variacion horaria o de trafico en tiempo real.",
  "",
  "## Entorno natural",
  "- `forest_pct`: porcentaje municipal de coberturas forestales y matorral arbolado (CORINE 311-324).",
  "- `water_pct`: porcentaje municipal de coberturas de agua (CORINE 5xx).",
  "- `artificial_pct`: porcentaje municipal de coberturas artificiales (CORINE 1xx).",
  "- `naturality_index`: indice simple de naturalidad (0-100).",
  "- `landcover_diversity`: diversidad de coberturas (Shannon normalizado 0-100).",
  "",
  "## Scoring compuesto",
  "- `climate_block_score`: bloque clima (media de precip_norm, temp_verano_norm, temp_invierno_norm).",
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
write_file(toJSON(metadata, auto_unbox = TRUE, pretty = TRUE), paths$output_dataset_metadata_json)
file_copy(paths$output_dataset_metadata_json, paths$frontend_dataset_metadata_json, overwrite = TRUE)
message("OK: metadatos escritos en ", paths$docs_indicators)
message("OK: metadata dataset JSON en ", paths$output_dataset_metadata_json)

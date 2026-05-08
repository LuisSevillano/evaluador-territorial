source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(jsonlite)
  library(fs)
})

pipeline_mode <- tolower(trimws(Sys.getenv("PIPELINE_MODE", unset = "full")))
include_transport <- identical(Sys.getenv("PIPELINE_INCLUDE_TRANSPORT", unset = "0"), "1")
use_bathing_sources <- identical(Sys.getenv("PIPELINE_USE_BATHING_SOURCES", unset = "0"), "1")
force_rebuild <- identical(Sys.getenv("PIPELINE_FORCE", unset = "0"), "1")
trust_existing_outputs <- identical(Sys.getenv("PIPELINE_TRUST_OUTPUTS", unset = "1"), "1")
state_file <- path(paths$output_dir, "pipeline_step_hashes.json")

assemble_feature_inputs <- c(
  paths$output_feature_climate_rds,
  paths$output_feature_isochrones_rds,
  paths$output_feature_mfe_rds,
  paths$output_feature_relief_rds,
  paths$output_feature_transport_osm_rds,
  paths$output_feature_transport_renfe_rds
)

if (!use_bathing_sources) {
  assemble_feature_inputs <- c(assemble_feature_inputs, paths$output_feature_river_rds)
}

steps <- list(
  list(
    path = "scripts/01_municipios_base.R",
    label = "Base municipal",
    outputs = c(paths$output_base_geojson),
    inputs = c(paths$shapefile, paths$provinces_shapefile)
  ),
  list(
    path = "scripts/02_clima_real.R",
    label = "Clima real municipal",
    outputs = c(paths$output_clima_geojson, paths$output_climate_monthly_csv, paths$output_feature_climate_rds),
    inputs = c(paths$output_base_geojson)
  ),
  list(
    path = "scripts/04_entorno_mfe.R",
    label = "Entorno MFE",
    outputs = c(paths$output_entorno_geojson, paths$output_feature_mfe_rds),
    inputs = c(paths$output_clima_geojson, path(project_root, "data", "raw", "mfe"))
  ),
  list(
    path = "scripts/04h_relieve_scope.R",
    label = "Relieve Copernicus",
    outputs = c(paths$output_feature_relief_rds),
    inputs = c(paths$output_entorno_geojson, paths$relieve_raw_dir)
  ),
  list(
    path = "scripts/03_isochrones.R",
    label = "Isochronas",
    outputs = c(paths$output_final_geojson, paths$output_feature_isochrones_rds),
    inputs = c(paths$output_entorno_geojson, paths$output_clima_geojson, paths$isochrones_dir)
  ),
  list(
    path = "scripts/03b_isochrones_difference.R",
    label = "Isochronas diferenciales",
    outputs = c(
      path(paths$output_dir, "iso_diff_01h30m.geojson"),
      path(paths$output_dir, "iso_diff_01h30m_02h00m.geojson"),
      path(paths$output_dir, "iso_diff_02h00m_02h30m.geojson"),
      path(paths$output_dir, "iso_diff_02h30m_03h30m.geojson"),
      path(paths$output_dir, "iso_diff_03h30m_04h00m.geojson")
    ),
    inputs = c(paths$output_final_geojson, paths$isochrones_dir)
  ),
  list(
    path = "scripts/05d_build_isochrones_pmtiles.sh",
    label = "PMTiles isocronas",
    outputs = c(paths$frontend_isochrones_pmtiles),
    inputs = c(paths$frontend_isochrones_dir)
  ),
  if (!use_bathing_sources) list(
    path = "scripts/04c_download_rios.R",
    label = "Rios y cuencas (IGN WFS)",
    outputs = c(paths$output_rivers_geojson, paths$output_river_basins_geojson)
  ) else NULL,
  if (!use_bathing_sources) list(
    path = "scripts/04d_buffers_rios.R",
    label = "Buffers rios 10/20km",
    outputs = c(paths$output_river_indicators_csv),
    inputs = c(paths$output_rivers_geojson)
  ) else NULL,
  if (!use_bathing_sources) list(
    path = "scripts/04g_banio_score_simple.R",
    label = "Acceso fluvial recreativo",
    outputs = c(paths$output_feature_river_rds),
    inputs = c(paths$output_base_geojson, path(project_root, "data", "raw", "hydrography"), paths$rivers_raw_dir)
  ) else NULL,
  if (use_bathing_sources) list(
    path = "scripts/04y_bathing_sources_unified.R",
    label = "Zonas de bano unificadas",
    outputs = c(
      paths$output_bathing_areas_unified_geojson,
      paths$output_bathing_areas_unified_csv,
      paths$output_feature_bathing_areas_rds
    ),
    inputs = c(path(project_root, "data", "raw", "bathing_areas"))
  ) else NULL,
  list(
    path = "scripts/05b_assemble_features_fast.R",
    label = "Ensamblado rapido de features",
    outputs = c(paths$output_final_geojson),
    inputs = assemble_feature_inputs
  ),
  list(
    path = "scripts/04j_grid_2km.R",
    label = "Grid 2km y agregados",
    outputs = c(paths$output_grid_geojson, paths$frontend_grid_geojson, paths$output_feature_grid_agg_rds, paths$output_feature_grid_agg_parquet),
    inputs = c(paths$output_final_geojson)
  ),
  list(
    path = "scripts/05c_build_grid_pmtiles.sh",
    label = "PMTiles grid",
    outputs = c(path(paths$frontend_grid_pmtiles, "grid_norte.pmtiles")),
    inputs = c(paths$frontend_grid_geojson)
  ),
  list(
    path = "scripts/04_quality_checks.R",
    label = "Control de calidad",
    outputs = c(paths$output_quality_report_csv),
    inputs = c(paths$output_final_geojson)
  ),
  list(
    path = "scripts/05_export_frontend_v2.R",
    label = "Export frontend v2",
    outputs = c(paths$output_v2_csv, paths$output_v2_json, paths$output_v2_geojson),
    inputs = c(paths$output_final_geojson, paths$output_climate_monthly_csv)
  ),
  list(
    path = "scripts/06_metadata_indicators.R",
    label = "Metadatos",
    outputs = c(paths$output_dataset_metadata_json),
    inputs = c(paths$output_v2_csv)
  ),
  list(
    path = "scripts/07_ccaa_boundaries.R",
    label = "CCAA",
    outputs = c(paths$output_ccaa_geojson),
    inputs = c(paths$provinces_shapefile)
  ),
  list(
    path = "scripts/08_provincias_boundaries.R",
    label = "Provincias",
    outputs = c(paths$output_provincias_geojson),
    inputs = c(paths$provinces_shapefile)
  )
)
steps <- Filter(Negate(is.null), steps)

if (include_transport) {
  transport_steps <- list(
    list(
      path = "scripts/04_transporte_distance.R",
      label = "Transporte (OSM)",
      outputs = c(paths$output_feature_transport_osm_rds),
      inputs = c(paths$output_final_geojson)
    ),
    list(
      path = "scripts/04b_transporte_renfe.R",
      label = "Transporte (Renfe)",
      outputs = c(paths$output_feature_transport_renfe_rds),
      inputs = c(paths$output_final_geojson)
    )
  )
  steps <- append(steps, transport_steps, after = 9)
}

if (pipeline_mode == "assemble-only") {
  steps <- list(
    list(
      path = "scripts/05b_assemble_features_fast.R",
      label = "Ensamblado rapido de features",
      outputs = c(paths$output_final_geojson),
      inputs = assemble_feature_inputs
    ),
    list(
      path = "scripts/05d_build_isochrones_pmtiles.sh",
      label = "PMTiles isocronas",
      outputs = c(paths$frontend_isochrones_pmtiles),
      inputs = c(paths$frontend_isochrones_dir)
    ),
    list(
      path = "scripts/04j_grid_2km.R",
      label = "Grid 2km y agregados",
      outputs = c(paths$output_grid_geojson, paths$frontend_grid_geojson, paths$output_feature_grid_agg_rds, paths$output_feature_grid_agg_parquet),
      inputs = c(paths$output_final_geojson)
    ),
    list(
      path = "scripts/05c_build_grid_pmtiles.sh",
      label = "PMTiles grid",
      outputs = c(path(paths$frontend_grid_pmtiles, "grid_norte.pmtiles")),
      inputs = c(paths$frontend_grid_geojson)
    ),
    list(
      path = "scripts/04_quality_checks.R",
      label = "Control de calidad",
      outputs = c(paths$output_quality_report_csv),
      inputs = c(paths$output_final_geojson)
    ),
    list(
      path = "scripts/05_export_frontend_v2.R",
      label = "Export frontend v2",
      outputs = c(paths$output_v2_csv, paths$output_v2_json, paths$output_v2_geojson),
      inputs = c(paths$output_final_geojson, paths$output_climate_monthly_csv)
    ),
    list(
      path = "scripts/06_metadata_indicators.R",
      label = "Metadatos",
      outputs = c(paths$output_dataset_metadata_json),
      inputs = c(paths$output_v2_csv)
    )
  )
}

now_str <- function() format(Sys.time(), "%H:%M:%S")

fmt_seconds <- function(seconds) {
  h <- floor(seconds / 3600)
  m <- floor((seconds %% 3600) / 60)
  s <- round(seconds %% 60, 1)
  sprintf("%02d:%02d:%04.1f", h, m, s)
}

estimate_total_minutes <- function(scope_cfg) {
  per_province_min <- 0.35
  overhead_min <- 0.8
  round(overhead_min + (scope_cfg$n_provinces * per_province_min), 1)
}

load_state <- function() {
  if (!file.exists(state_file)) return(list())
  tryCatch(fromJSON(state_file, simplifyVector = FALSE), error = function(e) list())
}

save_state <- function(state) {
  writeLines(toJSON(state, auto_unbox = TRUE, pretty = TRUE), con = state_file, useBytes = TRUE)
}

input_signature <- function(path_item) {
  if (!file.exists(path_item) && !dir.exists(path_item)) return(paste0(path_item, ":missing"))
  if (file.exists(path_item) && !dir.exists(path_item)) {
    info <- file.info(path_item)
    return(paste0(path_item, ":", info$size, ":", as.numeric(info$mtime)))
  }
  files <- list.files(path_item, recursive = TRUE, full.names = TRUE)
  if (length(files) == 0) return(paste0(path_item, ":empty_dir"))
  info <- file.info(files)
  prefix <- paste0(path_item, .Platform$file.sep)
  rel <- ifelse(startsWith(files, prefix), substring(files, nchar(prefix) + 1), basename(files))
  paste(c(path_item, paste0(rel, ":", info$size, ":", as.numeric(info$mtime))), collapse = "|")
}

step_hash <- function(step) {
  script_hash <- unname(tools::md5sum(step$path))
  inputs_hash <- if (!is.null(step$inputs) && length(step$inputs) > 0) {
    paste(vapply(step$inputs, input_signature, character(1)), collapse = "||")
  } else {
    "no-inputs"
  }
  paste(script_hash, analysis_scope, pipeline_mode, include_transport, inputs_hash, sep = "::")
}

should_run_step <- function(step, state) {
  if (force_rebuild) return(list(run = TRUE, reason = "PIPELINE_FORCE=1"))

  outputs <- step$outputs
  has_outputs <- !is.null(outputs) && length(outputs) > 0
  if (has_outputs && !all(file.exists(outputs))) return(list(run = TRUE, reason = "faltan outputs"))

  current <- step_hash(step)
  previous <- state[[step$path]]$hash

  if (is.null(previous)) {
    if (has_outputs && trust_existing_outputs) {
      return(list(run = FALSE, reason = "bootstrap desde outputs existentes", hash = current, bootstrap = TRUE))
    }
    return(list(run = TRUE, reason = "sin estado previo"))
  }

  if (!identical(previous, current)) return(list(run = TRUE, reason = "script/inputs cambiados"))
  list(run = FALSE, reason = "cache valido", hash = current, bootstrap = FALSE)
}

cat("== Pipeline v2 iniciado ==\n")
cat(sprintf("[%s] Scope: %s (%s)\n", now_str(), scope_config$label, analysis_scope))
cat(sprintf("[%s] Modo: %s | Transporte: %s\n", now_str(), pipeline_mode, if (include_transport) "ON" else "OFF"))
cat(sprintf("[%s] Pasos: %d\n", now_str(), length(steps)))
cat(sprintf("[%s] Estimacion inicial: %.1f min\n\n", now_str(), estimate_total_minutes(scope_config)))

state <- load_state()
start_all <- Sys.time()
step_times <- numeric(length(steps))

for (i in seq_along(steps)) {
  step <- steps[[i]]
  cat(sprintf("[%s] (%d/%d) %s - inicio\n", now_str(), i, length(steps), step$label))
  start_step <- Sys.time()

  decision <- should_run_step(step, state)
  if (!decision$run) {
    if (isTRUE(decision$bootstrap)) {
      state[[step$path]] <- list(hash = decision$hash, updated_at = as.character(Sys.time()))
      save_state(state)
    }
    elapsed_step <- round(as.numeric(difftime(Sys.time(), start_step, units = "secs")), 1)
    step_times[i] <- elapsed_step
    cat(sprintf("[%s] (%d/%d) %s - SKIP (%s)\n\n", now_str(), i, length(steps), step$label, decision$reason))
    next
  }

  if (grepl("\\.sh$", step$path, ignore.case = TRUE)) {
    status <- system2("bash", c(step$path), stdout = "", stderr = "")
    if (!identical(status, 0L)) stop("Fallo ejecutando script shell: ", step$path)
  } else {
    source(step$path, local = new.env(parent = globalenv()))
  }

  state[[step$path]] <- list(hash = step_hash(step), updated_at = as.character(Sys.time()))
  save_state(state)

  elapsed_step <- round(as.numeric(difftime(Sys.time(), start_step, units = "secs")), 1)
  step_times[i] <- elapsed_step

  executed <- step_times[step_times > 0]
  avg_so_far <- if (length(executed) > 0) mean(executed) else 0
  eta_remaining <- avg_so_far * (length(steps) - i)

  cat(sprintf(
    "[%s] (%d/%d) %s - OK (%.1fs) | ETA restante aprox: %s\n\n",
    now_str(), i, length(steps), step$label, elapsed_step, fmt_seconds(eta_remaining)
  ))
}

elapsed_all <- round(as.numeric(difftime(Sys.time(), start_all, units = "secs")), 1)
elapsed_min <- elapsed_all / 60

cat(sprintf("[%s] Pipeline v2 completado en %.1fs (%.2f min)\n", now_str(), elapsed_all, elapsed_min))
cat(sprintf("[%s] Duracion total (hh:mm:ss): %s\n", now_str(), fmt_seconds(elapsed_all)))

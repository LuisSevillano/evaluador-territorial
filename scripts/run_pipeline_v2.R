source("scripts/00_config.R")

steps <- list(
  list(path = "scripts/01_municipios_base.R", label = "Base municipal"),
  list(path = "scripts/02_clima_real.R", label = "Clima real municipal"),
  list(path = "scripts/04_entorno_corine.R", label = "Entorno CORINE"),
  list(path = "scripts/03_isochrones.R", label = "Isochronas"),
  list(path = "scripts/03b_isochrones_difference.R", label = "Isochronas diferenciales"),
  list(path = "scripts/04c_download_rios.R", label = "Rios y cuencas (IGN WFS)"),
  list(path = "scripts/04d_buffers_rios.R", label = "Buffers rios 10/20km"),
  list(path = "scripts/04g_banio_score_simple.R", label = "Acceso fluvial recreativo (simple)"),
  list(path = "scripts/04_transporte_distance.R", label = "Transporte (OSM)"),
  list(path = "scripts/04b_transporte_renfe.R", label = "Transporte (Renfe)"),
  list(path = "scripts/04_quality_checks.R", label = "Control de calidad"),
  list(path = "scripts/05_export_frontend_v2.R", label = "Export frontend v2"),
  list(path = "scripts/06_metadata_indicators.R", label = "Metadatos"),
  list(path = "scripts/07_ccaa_boundaries.R", label = "CCAA (fuente provincial oficial)"),
  list(path = "scripts/08_provincias_boundaries.R", label = "Provincias (fuente oficial)")
)

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

cat("== Pipeline v2 iniciado ==\n")
cat(sprintf("[%s] Scope: %s (%s)\n", now_str(), scope_config$label, analysis_scope))
cat(sprintf("[%s] Pasos: %d\n", now_str(), length(steps)))
cat(sprintf("[%s] Estimacion inicial: %.1f min\n\n", now_str(), estimate_total_minutes(scope_config)))

start_all <- Sys.time()
step_times <- numeric(length(steps))

for (i in seq_along(steps)) {
  step <- steps[[i]]
  cat(sprintf("[%s] (%d/%d) %s - inicio\n", now_str(), i, length(steps), step$label))
  start_step <- Sys.time()

  source(step$path)

  elapsed_step <- round(as.numeric(difftime(Sys.time(), start_step, units = "secs")), 1)
  step_times[i] <- elapsed_step

  avg_so_far <- mean(step_times[seq_len(i)])
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

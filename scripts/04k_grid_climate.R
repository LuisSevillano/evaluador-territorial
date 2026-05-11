source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(terra)
  library(readr)
  library(tidyr)
  library(stringr)
})

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [grid-climate] ", msg)

sf_use_s2(FALSE)
terra::terraOptions(memfrac = 0.7)

has_exactextractr <- requireNamespace("exactextractr", quietly = TRUE)
if (!has_exactextractr) {
  stop("Falta el paquete 'exactextractr'.")
}

start_year <- 2014
end_year <- 2023
years <- start_year:end_year

terraclimate_dir <- file.path(project_root, "data", "raw", "climate", "terraclimate")

is_valid_nc <- function(path) {
  if (!file.exists(path) || file.size(path) <= 0) return(FALSE)
  ok <- tryCatch({
    r <- rast(path)
    nlyr(r) >= 12
  }, error = function(e) FALSE)
  ok
}

download_terraclimate <- function(var, year) {
  target <- file.path(terraclimate_dir, sprintf("TerraClimate_%s_%s.nc", var, year))
  if (is_valid_nc(target)) return(target)
  if (file.exists(target) && !is_valid_nc(target)) {
    message("Archivo corrupto detectado, se descarga de nuevo: ", basename(target))
    file.remove(target)
  }
  url <- sprintf(
    "https://climate.northwestknowledge.net/TERRACLIMATE-DATA/TerraClimate_%s_%s.nc",
    var,
    year
  )
  message("Descargando ", basename(target))
  tryCatch({
    download.file(url, target, mode = "wb", quiet = TRUE, method = "libcurl")
  }, error = function(e) {
    stop("No se pudo descargar ", url)
  })
  target
}

get_monthly_raster <- function(var, years_vec) {
  files <- vapply(years_vec, function(y) download_terraclimate(var, y), character(1))
  r <- tryCatch(
    suppressWarnings(rast(files)),
    error = function(e) stop("No se pudieron abrir los NetCDF para ", var)
  )
  r_ext <- ext(r)
  if (is.na(crs(r)) ||
      (r_ext$xmin == 0 && r_ext$ymin == 0 && ncol(r) == 8640 && nrow(r) == 4320)) {
    ext(r) <- ext(-180, 180, -90, 90)
    crs(r) <- "EPSG:4326"
  }
  names(r) <- unlist(lapply(years_vec, function(y) sprintf("%s_%s_%02d", var, y, 1:12)))
  r
}

monthly_climatology_raster <- function(rast_obj, years_vec, prefix) {
  month_index <- rep(1:12, times = length(years_vec))
  clim <- terra::tapp(rast_obj, index = month_index, fun = mean, na.rm = TRUE)
  names(clim) <- sprintf("%s_%02d", prefix, 1:12)
  clim
}

extract_monthly_values <- function(rast_obj, sf_obj, value_name) {
  vals <- exactextractr::exact_extract(rast_obj, sf_obj, "mean", progress = FALSE)
  vals_tbl <- as_tibble(vals)
  colnames(vals_tbl) <- sprintf("%s_%02d", value_name, seq_len(ncol(vals_tbl)))
  vals_tbl
}

log_step("Cargando celdas de rejilla")
grid_sf <- st_read(paths$output_grid_geojson, quiet = TRUE) |>
  st_transform(4326) |>
  select(cell_id, municipio_id, municipio_nombre, provincia)

if (nrow(grid_sf) == 0) {
  stop("No se encontraron celdas en el archivo de rejilla.")
}

log_step(paste0("Cargadas ", nrow(grid_sf), " celdas"))

log_step("Cargando TerraClimate (ppt, pet, tmin, tmax)")
ppt <- get_monthly_raster("ppt", years)
pet <- get_monthly_raster("pet", years)
tmin <- get_monthly_raster("tmin", years)
tmax <- get_monthly_raster("tmax", years)

log_step("Recortando rasters al ámbito de la rejilla")
ext <- st_bbox(grid_sf)
pad <- 0.15
ppt <- terra::crop(ppt, terra::ext(ext$xmin - pad, ext$xmax + pad, ext$ymin - pad, ext$ymax + pad), snap = "out")
pet <- terra::crop(pet, terra::ext(ext$xmin - pad, ext$xmax + pad, ext$ymin - pad, ext$ymax + pad), snap = "out")
tmin <- terra::crop(tmin, terra::ext(ext$xmin - pad, ext$xmax + pad, ext$ymin - pad, ext$ymax + pad), snap = "out")
tmax <- terra::crop(tmax, terra::ext(ext$xmin - pad, ext$xmax + pad, ext$ymin - pad, ext$ymax + pad), snap = "out")

log_step("Calculando climatologia mensual (1991-2020)")
ppt_scaled <- ifel(ppt < 0, NA, ppt * 0.1)
pet_scaled <- ifel(pet < 0, NA, pet * 0.1)
temp_mean_raw <- ((tmin * 0.01) - 99 + (tmax * 0.01) - 99) / 2

ppt_clim <- monthly_climatology_raster(ppt_scaled, years, "precip_mm")
pet_clim <- monthly_climatology_raster(pet_scaled, years, "pet_mm")
temp_clim <- monthly_climatology_raster(temp_mean_raw, years, "temp_mean_c")

log_step("Extrayendo valores mensuales por celda (puede tardar)")
start_extract <- Sys.time()

ppt_values <- extract_monthly_values(ppt_clim, grid_sf, "precip_mm")
pet_values <- extract_monthly_values(pet_clim, grid_sf, "pet_mm")
temp_values <- extract_monthly_values(temp_clim, grid_sf, "temp_mean_c")

log_step(sprintf("Extracción completada en %.1fs", as.numeric(difftime(Sys.time(), start_extract, units = "secs"))))

log_step("Procesando datos mensuales")
grid_climate <- bind_cols(
  st_drop_geometry(grid_sf) |> select(cell_id, municipio_id, municipio_nombre, provincia),
  temp_values
) |> bind_cols(ppt_values) |>
  bind_cols(pet_values) |>
  pivot_longer(
    cols = matches("^(temp_mean_c|precip_mm|pet_mm)_[0-9]{2}$"),
    names_to = "metric_month",
    values_to = "value"
  ) |>
  mutate(
    month = as.integer(str_extract(metric_month, "[0-9]{2}$")),
    variable = case_when(
      str_starts(metric_month, "temp_") ~ "temp_mean_c",
      str_starts(metric_month, "pet_") ~ "pet_mm",
      TRUE ~ "precip_mm"
    )
  ) |>
  pivot_wider(
    id_cols = c(cell_id, municipio_id, municipio_nombre, provincia, month),
    names_from = variable,
    values_from = value
  ) |>
  mutate(
    temp_mean_c = round(temp_mean_c, 1),
    precip_mm = round(precip_mm, 1),
    pet_mm = round(pet_mm, 1)
  ) |>
  arrange(cell_id, month)

clamp01 <- function(x) pmax(0, pmin(1, x))

score_from_breaks <- function(x, breaks, scores) {
  approx(breaks, scores, xout = x, rule = 2, ties = "ordered")$y |>
    clamp01()
}

calc_moisture_scores <- function(df) {
  annual_precip_score <- score_from_breaks(df$precip_annual_mm, c(250, 400, 600, 900, 1400), c(0.10, 0.35, 0.70, 0.95, 1.00))
  aridity_score <- score_from_breaks(df$aridity_index, c(0.20, 0.35, 0.50, 0.65, 0.90, 1.20), c(0.10, 0.25, 0.45, 0.70, 0.90, 1.00))
  regularity_score <- score_from_breaks(df$precip_seasonality_index, c(0.35, 0.65, 1.00, 1.40), c(1.00, 0.80, 0.55, 0.25))
  summer_aridity_score <- score_from_breaks(df$summer_aridity_index, c(0.05, 0.15, 0.30, 0.50, 0.80), c(0.10, 0.30, 0.55, 0.80, 1.00))
  summer_precip_score <- score_from_breaks(df$precip_summer_mm, c(20, 60, 100, 160, 240), c(0.10, 0.35, 0.60, 0.85, 1.00))
  dry_months_score <- clamp01(1 - (df$dry_months_count / 5))

  moisture_absolute_score <- clamp01(0.45 * annual_precip_score + 0.40 * aridity_score + 0.15 * regularity_score)
  summer_drought_score <- clamp01(0.50 * summer_aridity_score + 0.30 * summer_precip_score + 0.20 * dry_months_score)
  relative_base <- clamp01(0.60 * moisture_absolute_score + 0.40 * summer_drought_score)
  precip_relative_score <- rank(relative_base, ties.method = "average", na.last = "keep") / sum(is.finite(relative_base))
  precip_moisture_score <- clamp01(0.60 * moisture_absolute_score + 0.25 * summer_drought_score + 0.15 * precip_relative_score)

  water_drops_level <- dplyr::case_when(
    !is.finite(moisture_absolute_score) | !is.finite(summer_drought_score) ~ NA_integer_,
    moisture_absolute_score < 0.45 | summer_drought_score < 0.35 ~ 1L,
    moisture_absolute_score >= 0.72 & summer_drought_score >= 0.50 ~ 3L,
    TRUE ~ 2L
  )

  df |>
    mutate(
      moisture_absolute_score = round(moisture_absolute_score, 3),
      summer_drought_score = round(summer_drought_score, 3),
      precip_relative_score = round(precip_relative_score, 3),
      precip_moisture_score = round(precip_moisture_score, 3),
      water_drops_level = water_drops_level,
      water_drops_label = case_when(
        water_drops_level == 1L ~ "Seco",
        water_drops_level == 2L ~ "Equilibrado",
        water_drops_level == 3L ~ "Humedo",
        TRUE ~ NA_character_
      )
    )
}

log_step("Generando datos anuales por celda")
grid_climate_annual <- grid_climate |>
  group_by(cell_id, municipio_id, municipio_nombre, provincia) |>
  summarize(
    precip_annual_mm = round(sum(precip_mm, na.rm = TRUE), 0),
    precip_summer_mm = round(sum(precip_mm[month %in% c(6, 7, 8)], na.rm = TRUE), 0),
    precip_winter_mm = round(sum(precip_mm[month %in% c(12, 1, 2)], na.rm = TRUE), 0),
    pet_annual_mm = round(sum(pet_mm, na.rm = TRUE), 0),
    pet_summer_mm = round(sum(pet_mm[month %in% c(6, 7, 8)], na.rm = TRUE), 0),
    dry_months_count = sum(precip_mm < 2 * temp_mean_c, na.rm = TRUE),
    precip_seasonality_index = round(sd(precip_mm, na.rm = TRUE) / mean(precip_mm, na.rm = TRUE), 3),
    temp_winter_mean_c = round(mean(temp_mean_c[month %in% c(12, 1, 2)], na.rm = TRUE), 1),
    temp_summer_mean_c = round(mean(temp_mean_c[month %in% c(6, 7, 8)], na.rm = TRUE), 1),
    temp_jan_mean_c = round(mean(temp_mean_c[month == 1], na.rm = TRUE), 1),
    temp_jul_mean_c = round(mean(temp_mean_c[month == 7], na.rm = TRUE), 1),
    .groups = "drop"
  ) |>
  mutate(
    aridity_index = round(ifelse(pet_annual_mm > 0, precip_annual_mm / pet_annual_mm, NA_real_), 3),
    summer_aridity_index = round(ifelse(pet_summer_mm > 0, precip_summer_mm / pet_summer_mm, NA_real_), 3)
  ) |>
  calc_moisture_scores() |>
  select(-pet_annual_mm, -pet_summer_mm)

log_step("Resumen climate grid:")
log_step(paste0("  precip_annual_mm rango: ", min(grid_climate_annual$precip_annual_mm, na.rm = TRUE), " - ", max(grid_climate_annual$precip_annual_mm, na.rm = TRUE)))
log_step(paste0("  temp_invierno rango: ", min(grid_climate_annual$temp_winter_mean_c, na.rm = TRUE), " - ", max(grid_climate_annual$temp_winter_mean_c, na.rm = TRUE)))
log_step(paste0("  temp_verano rango: ", min(grid_climate_annual$temp_summer_mean_c, na.rm = TRUE), " - ", max(grid_climate_annual$temp_summer_mean_c, na.rm = TRUE)))

output_monthly_csv <- file.path(project_root, "output", "grid_climate_monthly.csv")
output_annual_csv <- file.path(project_root, "output", "grid_climate_annual.csv")

write_csv(grid_climate, output_monthly_csv)
write_csv(grid_climate_annual, output_annual_csv)

log_step(paste0("OK: Datos mensuales guardados en ", output_monthly_csv))
log_step(paste0("OK: Datos anuales guardados en ", output_annual_csv))

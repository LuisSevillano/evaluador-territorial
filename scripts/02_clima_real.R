source("scripts/00_config.R")

library(sf)
library(dplyr)
library(terra)
library(readr)
library(tidyr)
library(arrow)

terra::terraOptions(memfrac = 0.7)

has_exactextractr <- requireNamespace("exactextractr", quietly = TRUE)
if (!has_exactextractr) {
  stop(
    "Falta el paquete 'exactextractr'. Instala y reintenta:\n",
    "  R -q -e \"install.packages('exactextractr')\""
  )
}

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

start_year <- 2014
end_year <- 2023
years <- start_year:end_year

terraclimate_dir <- file.path(project_root, "data", "raw", "climate", "terraclimate")
dir.create(terraclimate_dir, recursive = TRUE, showWarnings = FALSE)

options(timeout = max(600, getOption("timeout")))

strict_nc_check <- identical(Sys.getenv("STRICT_NC_CHECK", "0"), "1")

is_valid_nc <- function(path) {
  if (!file.exists(path) || file.size(path) <= 0) return(FALSE)
  if (!strict_nc_check) return(TRUE)
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
    stop("No se pudo descargar ", url, ". Descargalo manualmente en ", terraclimate_dir)
  })

  if (!is_valid_nc(target)) {
    stop("Descarga incompleta o corrupta: ", target, ". Ejecuta scripts/download_terraclimate.sh")
  }

  target
}

get_monthly_raster <- function(var, years_vec) {
  files <- vapply(years_vec, function(y) download_terraclimate(var, y), character(1))
  r <- tryCatch(
    suppressWarnings(rast(files)),
    error = function(e) {
      stop(
        "No se pudieron abrir los NetCDF para variable ", var,
        ". Si ya los descargaste, no estan legibles por GDAL/terra en este entorno. ",
        "Prueba a re-descargar con scripts/download_terraclimate.sh o activa STRICT_NC_CHECK=1 para validar previo."
      )
    }
  )

  # Some terra/GDAL builds read TerraClimate NetCDF without georeference metadata.
  # In that case we restore the expected global grid georeference.
  r_ext <- ext(r)
  if (is.na(crs(r)) ||
      (r_ext$xmin == 0 && r_ext$ymin == 0 && ncol(r) == 8640 && nrow(r) == 4320)) {
    ext(r) <- ext(-180, 180, -90, 90)
    crs(r) <- "EPSG:4326"
  }

  names(r) <- unlist(lapply(years_vec, function(y) sprintf("%s_%s_%02d", var, y, 1:12)))
  r
}

crop_to_scope <- function(rast_obj, mun_sf, pad_deg = 0.15) {
  mun_vect <- terra::vect(mun_sf)
  e <- terra::ext(mun_vect)
  e_pad <- terra::ext(
    terra::xmin(e) - pad_deg,
    terra::xmax(e) + pad_deg,
    terra::ymin(e) - pad_deg,
    terra::ymax(e) + pad_deg
  )
  terra::crop(rast_obj, e_pad, snap = "out")
}

monthly_climatology_raster <- function(rast_obj, years_vec, prefix) {
  month_index <- rep(1:12, times = length(years_vec))
  clim <- terra::tapp(rast_obj, index = month_index, fun = mean, na.rm = TRUE)
  names(clim) <- sprintf("%s_%02d", prefix, 1:12)
  clim
}

extract_climatology <- function(rast_obj, mun_sf, value_name) {
  vals <- exactextractr::exact_extract(rast_obj, mun_sf, "mean", progress = FALSE)
  vals_tbl <- as_tibble(vals)
  colnames(vals_tbl) <- sprintf("%s_%02d", value_name, seq_len(ncol(vals_tbl)))

  vals_tbl |>
    mutate(
      id = mun_sf$codigo,
      nombre = mun_sf$nombre,
      provincia = mun_sf$provincia
    ) |>
    pivot_longer(
      cols = starts_with(value_name),
      names_to = "metric_month",
      values_to = value_name
    ) |>
    mutate(month = as.integer(gsub(".*_([0-9]{2})$", "\\1", metric_month))) |>
    select(id, nombre, provincia, month, !!value_name)
}

municipios <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326)

message("Cargando TerraClimate (ppt, pet, tmin, tmax)")
start_load <- Sys.time()

ppt <- get_monthly_raster("ppt", years)
pet <- get_monthly_raster("pet", years)
tmin <- get_monthly_raster("tmin", years)
tmax <- get_monthly_raster("tmax", years)

message(sprintf("TerraClimate cargado en %.1fs", as.numeric(difftime(Sys.time(), start_load, units = "secs"))))

message("Recortando rasters al ambito de municipios")
start_crop <- Sys.time()
ppt <- crop_to_scope(ppt, municipios)
pet <- crop_to_scope(pet, municipios)
tmin <- crop_to_scope(tmin, municipios)
tmax <- crop_to_scope(tmax, municipios)
message(sprintf("Rasters recortados en %.1fs", as.numeric(difftime(Sys.time(), start_crop, units = "secs"))))

message("Calculando climatologia mensual (12 capas por variable)")
start_clim <- Sys.time()

ppt_scaled <- ifel(ppt < 0, NA, ppt * 0.1)
pet_scaled <- ifel(pet < 0, NA, pet * 0.1)
temp_mean_raw <- ((tmin * 0.01) - 99 + (tmax * 0.01) - 99) / 2

ppt_clim <- monthly_climatology_raster(ppt_scaled, years, "precip_mm")
pet_clim <- monthly_climatology_raster(pet_scaled, years, "pet_mm")
temp_clim <- monthly_climatology_raster(temp_mean_raw, years, "temp_mean_c")

message(sprintf("Climatologia raster lista en %.1fs", as.numeric(difftime(Sys.time(), start_clim, units = "secs"))))

message("Extrayendo medias zonales con exactextractr")
start_extract <- Sys.time()

monthly_prec <- extract_climatology(ppt_clim, municipios, "precip_mm")
monthly_pet <- extract_climatology(pet_clim, municipios, "pet_mm")
monthly_temp <- extract_climatology(temp_clim, municipios, "temp_mean_c")

monthly_climatology <- monthly_temp |>
  left_join(monthly_prec, by = c("id", "nombre", "provincia", "month")) |>
  left_join(monthly_pet, by = c("id", "nombre", "provincia", "month")) |>
  mutate(
    temp_mean_c = round(temp_mean_c, 1),
    precip_mm = round(precip_mm, 1),
    pet_mm = round(pet_mm, 1)
  ) |>
  arrange(id, month)

message(sprintf("Extraccion completada en %.1fs", as.numeric(difftime(Sys.time(), start_extract, units = "secs"))))

if (all(is.na(monthly_climatology$temp_mean_c))) {
  stop("Error clima: todas las temperaturas mensuales son NA. Revisar lectura/extraccion raster.")
}

if (all(is.na(monthly_climatology$precip_mm))) {
  stop("Error clima: todas las precipitaciones mensuales son NA. Revisar lectura/extraccion raster.")
}

if (all(is.na(monthly_climatology$pet_mm))) {
  stop("Error clima: todas las evapotranspiraciones potenciales mensuales son NA. Revisar lectura/extraccion raster.")
}

clamp01 <- function(x) pmax(0, pmin(1, x))

score_from_breaks <- function(x, breaks, scores) {
  approx(breaks, scores, xout = x, rule = 2, ties = "ordered")$y |>
    clamp01()
}

calc_moisture_scores <- function(df) {
  annual_precip_score <- score_from_breaks(
    df$precip_annual_mm,
    c(250, 400, 600, 900, 1400),
    c(0.10, 0.35, 0.70, 0.95, 1.00)
  )
  aridity_score <- score_from_breaks(
    df$aridity_index,
    c(0.20, 0.35, 0.50, 0.65, 0.90, 1.20),
    c(0.10, 0.25, 0.45, 0.70, 0.90, 1.00)
  )
  regularity_score <- score_from_breaks(
    df$precip_seasonality_index,
    c(0.35, 0.65, 1.00, 1.40),
    c(1.00, 0.80, 0.55, 0.25)
  )
  summer_aridity_score <- score_from_breaks(
    df$summer_aridity_index,
    c(0.05, 0.15, 0.30, 0.50, 0.80),
    c(0.10, 0.30, 0.55, 0.80, 1.00)
  )
  summer_precip_score <- score_from_breaks(
    df$precip_summer_mm,
    c(20, 60, 100, 160, 240),
    c(0.10, 0.35, 0.60, 0.85, 1.00)
  )
  dry_months_score <- clamp01(1 - (df$dry_months_count / 5))

  moisture_absolute_score <- clamp01(
    0.45 * annual_precip_score +
      0.40 * aridity_score +
      0.15 * regularity_score
  )
  summer_drought_score <- clamp01(
    0.50 * summer_aridity_score +
      0.30 * summer_precip_score +
      0.20 * dry_months_score
  )

  relative_base <- clamp01(0.60 * moisture_absolute_score + 0.40 * summer_drought_score)
  precip_relative_score <- if (length(relative_base) <= 1 || all(is.na(relative_base))) {
    rep(0.5, length(relative_base))
  } else {
    rank(relative_base, ties.method = "average", na.last = "keep") / sum(is.finite(relative_base))
  }

  precip_moisture_score <- clamp01(
    0.60 * moisture_absolute_score +
      0.25 * summer_drought_score +
      0.15 * precip_relative_score
  )

  water_drops_level <- dplyr::case_when(
    !is.finite(moisture_absolute_score) | !is.finite(summer_drought_score) ~ NA_integer_,
    moisture_absolute_score < 0.45 | summer_drought_score < 0.35 ~ 1L,
    moisture_absolute_score >= 0.72 & summer_drought_score >= 0.50 ~ 3L,
    TRUE ~ 2L
  )
  water_drops_label <- dplyr::case_when(
    water_drops_level == 1L ~ "Seco",
    water_drops_level == 2L ~ "Equilibrado",
    water_drops_level == 3L ~ "Humedo",
    TRUE ~ NA_character_
  )

  df |>
    mutate(
      moisture_absolute_score = round(moisture_absolute_score, 3),
      summer_drought_score = round(summer_drought_score, 3),
      precip_relative_score = round(precip_relative_score, 3),
      precip_moisture_score = round(precip_moisture_score, 3),
      water_drops_level = water_drops_level,
      water_drops_label = water_drops_label
    )
}

message(
  "Resumen clima mensual | temp_mean_c rango: ",
  round(min(monthly_climatology$temp_mean_c, na.rm = TRUE), 1),
  " a ",
  round(max(monthly_climatology$temp_mean_c, na.rm = TRUE), 1),
  " | precip_mm rango: ",
  round(min(monthly_climatology$precip_mm, na.rm = TRUE), 1),
  " a ",
  round(max(monthly_climatology$precip_mm, na.rm = TRUE), 1)
)

clima_resumen <- monthly_climatology |>
  group_by(id) |>
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

municipios_clima <- municipios |>
  left_join(clima_resumen, by = c("codigo" = "id"))

write_csv(monthly_climatology, paths$output_climate_monthly_csv)
st_write(municipios_clima, paths$output_clima_geojson, delete_dsn = TRUE, quiet = TRUE)

feature_climate <- municipios_clima |>
  st_drop_geometry() |>
  transmute(
    codigo,
    precip_annual_mm,
    precip_summer_mm,
    precip_winter_mm,
    precip_seasonality_index,
    aridity_index,
    summer_aridity_index,
    dry_months_count,
    moisture_absolute_score,
    summer_drought_score,
    precip_relative_score,
    precip_moisture_score,
    water_drops_level,
    water_drops_label,
    temp_winter_mean_c,
    temp_summer_mean_c,
    temp_jan_mean_c,
    temp_jul_mean_c
  )
saveRDS(feature_climate, paths$output_feature_climate_rds)
try(write_parquet(feature_climate, paths$output_feature_climate_parquet), silent = TRUE)

message("OK: climatologia mensual guardada en ", paths$output_climate_monthly_csv)
message("OK: clima municipal real agregado por poligono guardado en ", paths$output_clima_geojson)

source("scripts/00_config.R")

library(sf)
library(dplyr)
library(jsonlite)
library(readr)
library(fs)

sf_use_s2(FALSE)

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe dataset post-quality. Ejecuta primero scripts/04_quality_checks.R")
}

if (!file.exists(paths$output_climate_monthly_csv)) {
  stop("No existe output/municipios_climate_monthly.csv")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)
mun_base <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_transform(4326)

coords <- mun |>
  st_transform(3857) |>
  st_geometry() |>
  st_point_on_surface() |>
  st_transform(4326) |>
  st_coordinates()

mun$lon <- coords[, 1]
mun$lat <- coords[, 2]

minmax_norm <- function(x, invert = FALSE) {
  rng <- range(x, na.rm = TRUE)
  if (!is.finite(rng[1]) || !is.finite(rng[2]) || rng[1] == rng[2]) {
    return(rep(0.5, length(x)))
  }
  out <- (x - rng[1]) / (rng[2] - rng[1])
  if (invert) out <- 1 - out
  out
}

mun$precip_norm <- round(minmax_norm(mun$precip_annual_mm, invert = FALSE), 4)
mun$temp_verano_norm <- round(minmax_norm(mun$temp_summer_mean_c, invert = TRUE), 4)
mun$temp_invierno_norm <- round(minmax_norm(mun$temp_winter_mean_c, invert = FALSE), 4)
mun$forest_norm <- round(minmax_norm(mun$forest_pct, invert = FALSE), 4)
mun$water_norm <- round(minmax_norm(mun$water_pct, invert = FALSE), 4)
mun$artificial_norm <- round(minmax_norm(mun$artificial_pct, invert = TRUE), 4)
mun$naturality_norm <- round(minmax_norm(mun$naturality_index, invert = FALSE), 4)
mun$diversity_norm <- round(minmax_norm(mun$landcover_diversity, invert = FALSE), 4)

travel_order <- c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00")
travel_score <- setNames(rev(seq_along(travel_order)), travel_order)
access_floor <- 0.2
access_raw <- (travel_score[mun$travel_bucket] - 1) / (length(travel_order) - 1)
mun$accesibilidad_norm <- round(access_floor + (1 - access_floor) * access_raw, 4)

mun$climate_block_score <- round(
  rowMeans(cbind(mun$precip_norm, mun$temp_verano_norm, mun$temp_invierno_norm), na.rm = TRUE),
  4
)
mun$access_block_score <- round(mun$accesibilidad_norm, 4)
mun$nature_block_score <- round(
  rowMeans(cbind(mun$forest_norm, mun$water_norm, mun$naturality_norm, mun$diversity_norm), na.rm = TRUE),
  4
)

w_climate <- 0.4
w_access <- 0.3
w_nature <- 0.3

mun$mixed_score <- round(
  w_climate * mun$climate_block_score +
    w_access * mun$access_block_score +
    w_nature * mun$nature_block_score,
  4
)

population <- if ("population" %in% names(mun)) mun$population else rep(NA_real_, nrow(mun))
population_men <- if ("population_men" %in% names(mun)) mun$population_men else rep(NA_real_, nrow(mun))
population_women <- if ("population_women" %in% names(mun)) mun$population_women else rep(NA_real_, nrow(mun))

mun_v2 <- mun |>
  transmute(
    id = codigo,
    codigo,
    nombre,
    provincia,
    lon,
    lat,
    population,
    population_men,
    population_women,
    precip_annual_mm,
    temp_winter_mean_c,
    temp_summer_mean_c,
    temp_jan_mean_c,
    temp_jul_mean_c,
    iso_01h30m,
    iso_02h00m,
    iso_02h30m,
    iso_03h30m,
    iso_04h00m,
    travel_bucket,
    precip_norm,
    temp_verano_norm,
    temp_invierno_norm,
    forest_pct,
    water_pct,
    artificial_pct,
    naturality_index,
    landcover_diversity,
    forest_norm,
    water_norm,
    artificial_norm,
    naturality_norm,
    diversity_norm,
    accesibilidad_norm,
    climate_block_score,
    access_block_score,
    nature_block_score,
    mixed_score
  )

mun_tab <- mun_v2 |>
  st_drop_geometry()

mun_tiles <- mun_base |>
  transmute(
    codigo,
    nombre_base = as.character(nombre),
    provincia_base = as.character(provincia),
    geometry
  ) |>
  left_join(mun_tab, by = "codigo") |>
  mutate(
    id = dplyr::coalesce(id, codigo),
    nombre = dplyr::coalesce(na_if(trimws(nombre), ""), nombre_base),
    provincia = dplyr::coalesce(na_if(trimws(provincia), ""), provincia_base)
  ) |>
  select(-nombre_base, -provincia_base)

write_csv(mun_tab, paths$output_v2_csv)
write_file(toJSON(mun_tab, auto_unbox = TRUE), paths$output_v2_json)
st_write(mun_tiles, paths$output_v2_geojson, delete_dsn = TRUE, quiet = TRUE)

monthly <- read_csv(paths$output_climate_monthly_csv, show_col_types = FALSE)
write_file(toJSON(monthly, auto_unbox = TRUE), paths$output_climate_monthly_json)

file_copy(paths$output_v2_json, paths$frontend_v2_json, overwrite = TRUE)
file_copy(paths$output_climate_monthly_json, paths$frontend_climate_monthly_json, overwrite = TRUE)

message("OK: export v2 tabular generado y copiado a frontend/static/data")

source("scripts/00_config.R")

library(sf)
library(dplyr)
library(jsonlite)
library(readr)
library(fs)

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe dataset post-quality. Ejecuta primero scripts/04_quality_checks.R")
}

if (!file.exists(paths$output_climate_monthly_csv)) {
  stop("No existe output/municipios_climate_monthly.csv")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)

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

travel_order <- c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00")
travel_score <- setNames(rev(seq_along(travel_order)), travel_order)
mun$accesibilidad_norm <- round((travel_score[mun$travel_bucket] - 1) / (length(travel_order) - 1), 4)
mun$mixed_score <- round(
  0.35 * mun$precip_norm +
    0.25 * mun$temp_verano_norm +
    0.20 * mun$temp_invierno_norm +
    0.20 * mun$accesibilidad_norm,
  4
)

mun_v2 <- mun |>
  transmute(
    id = codigo,
    codigo,
    nombre,
    provincia,
    lon,
    lat,
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
    accesibilidad_norm,
    mixed_score
  )

mun_tab <- mun_v2 |>
  st_drop_geometry()

write_csv(mun_tab, paths$output_v2_csv)
write_file(toJSON(mun_tab, auto_unbox = TRUE), paths$output_v2_json)
st_write(mun_v2, paths$output_v2_geojson, delete_dsn = TRUE, quiet = TRUE)

monthly <- read_csv(paths$output_climate_monthly_csv, show_col_types = FALSE)
write_file(toJSON(monthly, auto_unbox = TRUE), paths$output_climate_monthly_json)

file_copy(paths$output_v2_geojson, paths$frontend_v2_geojson, overwrite = TRUE)
file_copy(paths$output_v2_json, paths$frontend_v2_json, overwrite = TRUE)
file_copy(paths$output_climate_monthly_json, paths$frontend_climate_monthly_json, overwrite = TRUE)

message("OK: export v2 generado y copiado a frontend/static/data")

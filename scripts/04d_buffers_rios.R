source("scripts/00_config.R")

library(sf)
library(dplyr)
library(readr)

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

if (!file.exists(paths$output_rivers_geojson)) {
  stop("No existe rios_watercourse_scope.geojson. Ejecuta primero scripts/04c_download_rios.R")
}

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(3035)

riv <- st_read(paths$output_rivers_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(3035)

if (nrow(riv) == 0) {
  stop("La capa de rios no contiene tramos")
}

buf10 <- st_buffer(mun, 10000)
buf20 <- st_buffer(mun, 20000)

hits10 <- lengths(st_intersects(buf10, riv)) > 0
hits20 <- lengths(st_intersects(buf20, riv)) > 0

dist_km <- as.numeric(st_distance(st_centroid(mun), riv) |> apply(1, min, na.rm = TRUE)) / 1000

river_by_mun <- mun |>
  mutate(
    has_river_10km = hits10,
    has_river_20km = hits20,
    dist_river_km = round(dist_km, 2)
  ) |>
  st_transform(4326)

write_csv(
  river_by_mun |>
    st_drop_geometry() |>
    select(codigo, nombre, provincia, has_river_10km, has_river_20km, dist_river_km),
  paths$output_river_indicators_csv
)

st_write(river_by_mun, paths$output_river_indicators_geojson, delete_dsn = TRUE, quiet = TRUE)

message("OK: buffers de rios calculados en ", paths$output_river_indicators_geojson)

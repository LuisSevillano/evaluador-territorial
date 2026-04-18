source("scripts/00_config.R")

library(sf)
library(dplyr)

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

municipios <- st_read(paths$output_base_geojson, quiet = TRUE)

centroides <- municipios |>
  st_transform(3857) |>
  st_centroid() |>
  st_transform(4326)
coords <- st_coordinates(centroides)

municipios_clima <- municipios |>
  mutate(
    lon = coords[, 1],
    lat = coords[, 2],
    temp_invierno_c = round(pmax(-2, pmin(10, 9.5 - ((lat - 40) * 1.7) + ((lon + 4) * 0.35))), 1),
    precipitacion_mm = round(
      pmax(250, pmin(1200, 300 + ((lat - 40) * 180) + pmax(0, (-lon - 3)) * 70)),
      0
    )
  )

st_write(municipios_clima, paths$output_clima_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: clima simple guardado en ", paths$output_clima_geojson)

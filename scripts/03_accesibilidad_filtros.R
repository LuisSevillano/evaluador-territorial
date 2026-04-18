source("scripts/00_config.R")

library(sf)
library(dplyr)

sf_use_s2(FALSE)

if (!file.exists(paths$output_clima_geojson)) {
  stop("No existe municipios_clima.geojson. Ejecuta primero scripts/02_clima.R")
}

municipios <- st_read(paths$output_clima_geojson, quiet = TRUE)

centroides_3857 <- municipios |>
  st_transform(3857) |>
  st_centroid() |>
  st_geometry()
madrid_point_3857 <- st_transform(st_sfc(st_point(c(-3.7038, 40.4168)), crs = 4326), 3857)

distancias_m <- st_distance(centroides_3857, madrid_point_3857)

municipios_final <- municipios |>
  mutate(
    dist_madrid_km = round(as.numeric(distancias_m) / 1000, 1),
    filtro_distancia = dist_madrid_km < 200,
    filtro_lluvia = precipitacion_mm > 400,
    filtro_duro = filtro_distancia & filtro_lluvia
  )

st_write(municipios_final, paths$output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: municipios finales con accesibilidad/filtros en ", paths$output_final_geojson)

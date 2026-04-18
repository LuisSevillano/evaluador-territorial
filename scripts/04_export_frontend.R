source("scripts/00_config.R")

library(sf)
library(dplyr)
library(jsonlite)
library(readr)
library(fs)

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson. Ejecuta primero scripts/03_accesibilidad_filtros.R")
}

municipios <- st_read(paths$output_final_geojson, quiet = TRUE)

municipios_tabla <- municipios |>
  st_drop_geometry() |>
  transmute(
    id = codigo,
    nombre,
    provincia,
    lat = round(lat, 6),
    lon = round(lon, 6),
    temp_invierno_c,
    precipitacion_mm,
    dist_madrid_km,
    filtro_distancia,
    filtro_lluvia,
    filtro_duro
  )

write_csv(municipios_tabla, paths$output_final_csv)
write_file(toJSON(municipios_tabla, auto_unbox = TRUE), paths$output_final_json)
file_copy(paths$output_final_json, paths$frontend_json, overwrite = TRUE)
file_copy(paths$output_final_geojson, paths$frontend_geojson, overwrite = TRUE)

message("OK: export CSV/JSON en output y copia a frontend/static/data")

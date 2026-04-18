source("scripts/00_config.R")

library(sf)
library(dplyr)

if (!file.exists(paths$shapefile)) {
  stop("No se encontro el shapefile base de municipios: ", paths$shapefile)
}

provincias_cyl <- c(
  "05" = "Avila",
  "09" = "Burgos",
  "24" = "Leon",
  "34" = "Palencia",
  "37" = "Salamanca",
  "40" = "Segovia",
  "42" = "Soria",
  "47" = "Valladolid",
  "49" = "Zamora"
)

municipios_raw <- st_read(paths$shapefile, quiet = TRUE)

municipios_tag <- municipios_raw |>
  mutate(
    codigo = sprintf("%05s", as.character(cod_ine)),
    codprov = substr(codigo, 1, 2),
    nombre = as.character(NAMEUNIT),
    provincia = recode(codprov, !!!provincias_cyl, .default = "FueraCyL")
  )

municipios_base <- switch(
  scope_config$mode,
  "provincia" = municipios_tag |> filter(codprov == scope_config$codprov),
  "nut2" = municipios_tag |> filter(CODNUT2 == scope_config$codnut2),
  "all" = municipios_tag
)

municipios_base <- municipios_base |>
  mutate(
    provincia = ifelse(provincia == "FueraCyL", as.character(substr(codigo, 1, 2)), provincia)
  ) |>
  select(codigo, codprov, nombre, provincia, geometry) |>
  st_transform(4326)

st_write(municipios_base, paths$output_base_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: municipios base guardados en ", paths$output_base_geojson, " | filas: ", nrow(municipios_base))

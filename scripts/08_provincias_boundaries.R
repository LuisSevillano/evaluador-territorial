source("scripts/00_config.R")

library(sf)
library(dplyr)

sf_use_s2(FALSE)

if (!file.exists(paths$provinces_shapefile)) {
  stop("No se encontro el shapefile provincial oficial: ", paths$provinces_shapefile)
}

slugify <- function(x) {
  x_ascii <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x_ascii <- tolower(x_ascii)
  x_ascii <- gsub("[^a-z0-9]+", "_", x_ascii)
  x_ascii <- gsub("^_+|_+$", "", x_ascii)
  x_ascii
}

prov <- st_read(paths$provinces_shapefile, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326)

prov_scope <- switch(
  scope_config$mode,
  "provincia" = {
    target_name_slug <- slugify(unname(prov_labels[[scope_config$codprov]]))
    prov |> filter(slugify(as.character(NAMEUNIT)) == target_name_slug)
  },
  "nut2" = prov |> filter(CODNUT2 == scope_config$codnut2),
  "all" = prov
)

provincias <- prov_scope |>
  transmute(
    id_prov = slugify(as.character(NAMEUNIT)),
    nombre_prov = as.character(NAMEUNIT),
    codnut2 = as.character(CODNUT2),
    geometry
  )

st_write(provincias, paths$output_provincias_geojson, delete_dsn = TRUE, quiet = TRUE)
file.copy(paths$output_provincias_geojson, paths$frontend_provincias_geojson, overwrite = TRUE)

message("OK: limites provinciales (fuente oficial) exportados en ", paths$output_provincias_geojson)
message("OK: copia frontend en ", paths$frontend_provincias_geojson)

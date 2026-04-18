source("scripts/00_config.R")

library(sf)
library(dplyr)

sf_use_s2(FALSE)

if (!file.exists(paths$provinces_shapefile)) {
  stop("No se encontro el shapefile provincial oficial: ", paths$provinces_shapefile)
}

ccaa_names <- c(
  "ES11" = "Galicia",
  "ES12" = "Principado de Asturias",
  "ES13" = "Cantabria",
  "ES21" = "Pais Vasco",
  "ES22" = "Comunidad Foral de Navarra",
  "ES23" = "La Rioja",
  "ES24" = "Aragon",
  "ES30" = "Comunidad de Madrid",
  "ES41" = "Castilla y Leon",
  "ES42" = "Castilla-La Mancha",
  "ES43" = "Extremadura",
  "ES51" = "Cataluna",
  "ES52" = "Comunitat Valenciana",
  "ES53" = "Illes Balears",
  "ES61" = "Andalucia",
  "ES62" = "Region de Murcia",
  "ES63" = "Ciudad Autonoma de Ceuta",
  "ES64" = "Ciudad Autonoma de Melilla",
  "ES70" = "Canarias"
)

prov <- st_read(paths$provinces_shapefile, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326)

prov_scope <- switch(
  scope_config$mode,
  "provincia" = prov |> filter(CODNUT2 == "ES41"),
  "nut2" = prov |> filter(CODNUT2 == scope_config$codnut2),
  "all" = prov
)

ccaa <- prov_scope |>
  mutate(codnut2 = as.character(CODNUT2)) |>
  group_by(codnut2) |>
  summarize(geometry = st_union(geometry), .groups = "drop") |>
  mutate(
    id_ccaa = codnut2,
    nombre_ccaa = dplyr::recode(codnut2, !!!ccaa_names, .default = codnut2)
  ) |>
  select(id_ccaa, codnut2, nombre_ccaa, geometry)

st_write(ccaa, paths$output_ccaa_geojson, delete_dsn = TRUE, quiet = TRUE)
file.copy(paths$output_ccaa_geojson, paths$frontend_ccaa_geojson, overwrite = TRUE)

message("OK: CCAA (desde fuente provincial oficial) exportadas en ", paths$output_ccaa_geojson)
message("OK: Copia frontend en ", paths$frontend_ccaa_geojson)

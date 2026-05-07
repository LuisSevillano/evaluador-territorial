source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(stringr)
  library(fs)
})

sf_use_s2(FALSE)

input_gpkg <- path(project_root, "data", "raw", "hydrography", "idee_watercourselink_full.gpkg")
if (!file_exists(input_gpkg)) {
  stop("No existe idee_watercourselink_full.gpkg. Ejecuta scripts/04w_download_idee_watercourselink.R")
}

if (!file_exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson")
}

out_proxy <- path(paths$output_dir, "rios_banables_proxy.geojson")

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_transform(25830)

scope_union <- st_union(st_make_valid(mun))

riv <- st_read(input_gpkg, layer = "watercourselink", quiet = TRUE) |>
  st_make_valid() |>
  st_transform(25830)

if (nrow(riv) == 0) stop("Capa WatercourseLink vacia")

message("[proxy] Recortando a scope...")
riv <- suppressWarnings(st_intersection(riv, st_as_sf(st_sfc(scope_union, crs = st_crs(mun)))))
if (nrow(riv) == 0) stop("Sin rios tras recorte a scope")

name_col <- intersect(c("geographicalName", "name", "nombre", "localId"), names(riv))
name_col <- if (length(name_col) > 0) name_col[[1]] else NULL

riv <- riv |>
  mutate(
    river_name = if (!is.null(name_col)) as.character(.data[[name_col]]) else NA_character_,
    river_name_norm = {
      x <- river_name
      x[is.na(x)] <- ""
      x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
      str_squish(x)
    },
    length_m = as.numeric(st_length(geometry)),
    long_segment = length_m >= 3000,
    medium_segment = length_m >= 1500,
    likely_artificial = str_detect(river_name_norm, "canal|acequia|zanja|colector|desague|dren|cuneta"),
    bathable_proxy_class = case_when(
      likely_artificial ~ "descartar",
      long_segment ~ "alto",
      medium_segment ~ "medio",
      TRUE ~ "bajo"
    ),
    river_rank = bathable_proxy_class,
    source_layer = "idee_wfs_watercourselink",
    method_version = "bathable_proxy_v1"
  ) |>
  filter(bathable_proxy_class != "descartar")

st_write(riv, out_proxy, delete_dsn = TRUE, quiet = TRUE)

message("OK: proxy rios banables guardado en ", out_proxy)
message("Registros: ", nrow(riv))

source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(arrow)
})

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

if (!file.exists(paths$output_bathing_areas_unified_geojson)) {
  stop("No existe bathing_areas_unified.geojson. Ejecuta primero scripts/04y_bathing_sources_unified.R")
}

municipios <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(25830) |>
  select(codigo, geometry)

bathing <- st_read(paths$output_bathing_areas_unified_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(25830)

if ("is_primary_record" %in% names(bathing)) {
  bathing <- bathing |>
    filter(is_primary_record)
}

if (nrow(bathing) == 0) {
  stop("No hay registros de zonas de bano para calcular acceso")
}

mun_cent <- st_point_on_surface(municipios)
nearest_idx <- st_nearest_feature(mun_cent, bathing)
nearest_dist_km <- as.numeric(st_distance(mun_cent, bathing[nearest_idx, ], by_element = TRUE)) / 1000

bath_5 <- st_buffer(bathing, 5000)
bath_10 <- st_buffer(bathing, 10000)
bath_20 <- st_buffer(bathing, 20000)

inside_5 <- lengths(st_intersects(mun_cent, bath_5)) > 0
inside_10 <- lengths(st_intersects(mun_cent, bath_10)) > 0
inside_20 <- lengths(st_intersects(mun_cent, bath_20)) > 0

feature_tbl <- tibble(
  codigo = municipios$codigo,
  river_buffer_class = case_when(
    inside_5 ~ "<=5km",
    inside_10 ~ "5-10km",
    inside_20 ~ "10-20km",
    TRUE ~ ">20km"
  ),
  river_nearest_distance_km = round(nearest_dist_km, 2),
  river_access_score = case_when(
    inside_5 ~ 100,
    inside_10 ~ 80,
    inside_20 ~ 60,
    TRUE ~ 5
  ),
  river_rank = "zona_bano",
  river_access_class = case_when(
    river_access_score >= 85 ~ "alta",
    river_access_score >= 65 ~ "media",
    river_access_score >= 35 ~ "baja",
    TRUE ~ "muy_baja"
  ),
  river_method_version = "bathing_sources_v1"
)

saveRDS(feature_tbl, paths$output_feature_river_rds)
try(write_parquet(feature_tbl, paths$output_feature_river_parquet), silent = TRUE)

message("OK: acceso a zonas de bano generado en ", paths$output_feature_river_rds)

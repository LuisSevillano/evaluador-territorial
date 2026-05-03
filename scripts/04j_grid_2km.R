source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(arrow)
  library(fs)
})

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [grid] ", msg)

sf_use_s2(FALSE)

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson. Ejecuta primero el pipeline hasta ensamblado.")
}

bucket_to_rank <- function(bucket) {
  recode(
    bucket,
    "<=1h30" = 1L,
    "<=2h00" = 2L,
    "<=2h30" = 3L,
    "<=3h30" = 4L,
    "<=4h00" = 5L,
    ">4h00" = 6L,
    .default = NA_integer_
  )
}

rank_to_bucket <- function(rank) {
  recode(
    as.character(rank),
    "1" = "<=1h30",
    "2" = "<=2h00",
    "3" = "<=2h30",
    "4" = "<=3h30",
    "5" = "<=4h00",
    "6" = ">4h00",
    .default = NA_character_
  )
}

mode_int <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_integer_)
  tb <- table(x)
  as.integer(names(tb)[which.max(tb)])
}

log_step("Cargando municipios")
mun_sf <- st_read(paths$output_final_geojson, quiet = TRUE) |>
  st_transform(25830) |>
  select(
    codigo,
    nombre,
    provincia,
    precip_annual_mm,
    temp_winter_mean_c,
    temp_summer_mean_c,
    river_access_score,
    forest_nature_quality,
    travel_bucket
  )

score_from_river_distance <- function(distance_km) {
  case_when(
    is.na(distance_km) ~ NA_real_,
    distance_km <= 0.5 ~ 100,
    distance_km <= 1.0 ~ 85,
    distance_km <= 2.5 ~ 70,
    distance_km <= 5.0 ~ 55,
    distance_km <= 10.0 ~ 35,
    TRUE ~ 10
  )
}

log_step("Creando rejilla de 2km x 2km")
mun_union <- st_union(mun_sf)
ext <- st_bbox(mun_union)

grid_cells <- st_make_grid(
  mun_union,
  cellsize = 2000,
  crs = st_crs(mun_sf)
)

log_step(paste0("Generadas ", length(grid_cells), " celdas iniciales"))

log_step("Asignando celdas a municipio y variables base")
grid_sf <- st_sf(geometry = grid_cells) |>
  st_join(mun_sf, join = st_intersects, left = FALSE) |>
  mutate(
    area_km2 = as.numeric(st_area(geometry) / 1e6),
    grid_row = as.integer((ext$ymax - st_coordinates(st_centroid(geometry))[, 2]) / 2000),
    grid_col = as.integer((st_coordinates(st_centroid(geometry))[, 1] - ext$xmin) / 2000),
    cell_id = paste0(codigo, "_", grid_row, "_", grid_col),
    municipio_id = codigo,
    municipio_nombre = nombre,
    precip_annual = precip_annual_mm,
    temp_winter = temp_winter_mean_c,
    temp_summer = temp_summer_mean_c,
    natural_cover_pct = pmax(0, pmin(100, forest_nature_quality * 100))
  )

grid_centroids_utm <- st_centroid(grid_sf)

log_step("Calculando distancia a rios por celda")
if (file.exists(paths$output_rivers_geojson)) {
  rivers_utm <- st_read(paths$output_rivers_geojson, quiet = TRUE) |>
    st_transform(st_crs(grid_sf))
  if (nrow(rivers_utm) > 0) {
    nearest_idx <- st_nearest_feature(grid_centroids_utm, rivers_utm)
    nearest_dist <- st_distance(grid_centroids_utm, rivers_utm[nearest_idx, ], by_element = TRUE)
    river_distance_km <- as.numeric(nearest_dist) / 1000
    grid_sf <- grid_sf |>
      mutate(
        river_distance_km = river_distance_km,
        river_access_score = score_from_river_distance(river_distance_km)
      )
  } else {
    grid_sf <- grid_sf |>
      mutate(river_distance_km = NA_real_)
  }
} else {
  log_step("Aviso: no existe capa de rios; se conserva river_access_score municipal")
  grid_sf <- grid_sf |>
    mutate(river_distance_km = NA_real_)
}

log_step("Calculando cobertura natural por celda")
if (file.exists(paths$output_forest_geojson)) {
  forest_utm <- st_read(paths$output_forest_geojson, quiet = TRUE) |>
    st_transform(st_crs(grid_sf))
  if (nrow(forest_utm) > 0) {
    suppressWarnings({
      inter <- tryCatch(
        st_intersection(
          grid_sf |>
            select(cell_id, geometry),
          forest_utm |>
            st_make_valid() |>
            select(geometry)
        ),
        error = function(e) NULL
      )
    })

    if (!is.null(inter) && nrow(inter) > 0) {
      cover_tbl <- inter |>
        mutate(inter_area_m2 = as.numeric(st_area(geometry))) |>
        st_drop_geometry() |>
        group_by(cell_id) |>
        summarise(natural_area_m2 = sum(inter_area_m2, na.rm = TRUE), .groups = "drop")

      grid_sf <- grid_sf |>
        left_join(cover_tbl, by = "cell_id") |>
        mutate(
          cell_area_m2 = as.numeric(st_area(geometry)),
          natural_cover_pct = pmax(0, pmin(100, (coalesce(natural_area_m2, 0) / pmax(cell_area_m2, 1)) * 100))
        ) |>
        select(-natural_area_m2, -cell_area_m2)
    }
  }
}

log_step("Asignando bucket de isocrona por celda")
iso_files <- c(
  "<=1h30" = path(paths$output_dir, "iso_diff_01h30m.geojson"),
  "<=2h00" = path(paths$output_dir, "iso_diff_01h30m_02h00m.geojson"),
  "<=2h30" = path(paths$output_dir, "iso_diff_02h00m_02h30m.geojson"),
  "<=3h30" = path(paths$output_dir, "iso_diff_02h30m_03h30m.geojson"),
  "<=4h00" = path(paths$output_dir, "iso_diff_03h30m_04h00m.geojson")
)

grid_sf <- grid_sf |>
  mutate(isochrone_rank = 6L)

for (bucket in names(iso_files)) {
  fp <- iso_files[[bucket]]
  if (!file.exists(fp)) next
  iso_sf <- st_read(fp, quiet = TRUE) |>
    st_transform(st_crs(grid_sf))
  if (nrow(iso_sf) == 0) next
  inside <- lengths(st_within(grid_centroids_utm, iso_sf)) > 0
  rank_val <- bucket_to_rank(bucket)
  grid_sf$isochrone_rank[inside] <- pmin(grid_sf$isochrone_rank[inside], rank_val, na.rm = TRUE)
}

grid_sf <- grid_sf |>
  mutate(
    isochrone_bucket = rank_to_bucket(isochrone_rank)
  )

grid_sf <- grid_sf |>
  select(
    cell_id,
    municipio_id,
    municipio_nombre,
    provincia,
    area_km2,
    grid_row,
    grid_col,
    precip_annual,
    temp_winter,
    temp_summer,
    river_distance_km,
    river_access_score,
    natural_cover_pct,
    isochrone_bucket,
    isochrone_rank,
    geometry
  )

log_step("Agregando variables de celda a municipio")
grid_agg <- grid_sf |>
  st_drop_geometry() |>
  group_by(codigo = municipio_id) |>
  summarise(
    grid_cell_count = n(),
    grid_precip_annual_mean = mean(precip_annual, na.rm = TRUE),
    grid_precip_annual_median = median(precip_annual, na.rm = TRUE),
    grid_temp_winter_mean = mean(temp_winter, na.rm = TRUE),
    grid_temp_winter_median = median(temp_winter, na.rm = TRUE),
    grid_temp_summer_mean = mean(temp_summer, na.rm = TRUE),
    grid_temp_summer_median = median(temp_summer, na.rm = TRUE),
    grid_river_access_mean = mean(river_access_score, na.rm = TRUE),
    grid_river_access_p75 = as.numeric(quantile(river_access_score, probs = 0.75, na.rm = TRUE, type = 7)),
    grid_river_access_max = max(river_access_score, na.rm = TRUE),
    grid_pct_cells_river_access_high = mean(river_access_score >= 70, na.rm = TRUE) * 100,
    grid_nearest_good_river_distance = suppressWarnings(min(ifelse(river_access_score >= 70, river_distance_km, NA_real_), na.rm = TRUE)),
    grid_natural_cover_mean = mean(natural_cover_pct, na.rm = TRUE),
    grid_natural_cover_high_pct = mean(natural_cover_pct >= 60, na.rm = TRUE) * 100,
    grid_iso_best_rank = min(isochrone_rank, na.rm = TRUE),
    grid_iso_majority_rank = mode_int(isochrone_rank),
    grid_pct_area_inside_2h30 = mean(isochrone_rank <= 3, na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  mutate(
    grid_iso_best_bucket = rank_to_bucket(grid_iso_best_rank),
    grid_iso_majority_bucket = rank_to_bucket(grid_iso_majority_rank)
  ) |>
  select(-grid_iso_best_rank, -grid_iso_majority_rank)

grid_agg <- grid_agg |>
  mutate(across(where(is.double), ~ ifelse(is.finite(.x), .x, NA_real_)))

grid_agg <- grid_agg |>
  mutate(grid_nearest_good_river_distance = ifelse(is.infinite(grid_nearest_good_river_distance), NA_real_, grid_nearest_good_river_distance))

log_step("Reproyectando grid a EPSG:4326")
grid_sf <- st_transform(grid_sf, 4326) |>
  select(-isochrone_rank)

log_step("Guardando dataset de celdas")
st_write(grid_sf, paths$output_grid_geojson, delete_dsn = TRUE, quiet = TRUE)
invisible(file_copy(paths$output_grid_geojson, paths$frontend_grid_geojson, overwrite = TRUE))

log_step("Guardando agregados municipales de grid")
write_parquet(grid_agg, paths$output_feature_grid_agg_parquet)
saveRDS(grid_agg, paths$output_feature_grid_agg_rds)

log_step(paste0("Grid guardado en ", paths$output_grid_geojson))
log_step(paste0("Grid copiado a frontend en ", paths$frontend_grid_geojson))
log_step(paste0("Total celdas: ", nrow(grid_sf)))
log_step(paste0("Municipios con agregados: ", nrow(grid_agg)))

message("OK: Rejilla 2km y agregados municipales generados correctamente")

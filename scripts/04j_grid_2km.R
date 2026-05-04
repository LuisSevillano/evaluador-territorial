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

round_idx <- function(x) round(x, 3)

minmax_norm <- function(x, invert = FALSE) {
  x <- suppressWarnings(as.numeric(x))
  valid <- is.finite(x)
  out <- rep(NA_real_, length(x))
  if (!any(valid)) return(out)
  xv <- x[valid]
  xmin <- min(xv, na.rm = TRUE)
  xmax <- max(xv, na.rm = TRUE)
  if (!is.finite(xmin) || !is.finite(xmax) || xmax <= xmin) {
    out[valid] <- 0.5
  } else {
    out[valid] <- (xv - xmin) / (xmax - xmin)
  }
  if (invert) out <- 1 - out
  pmax(0, pmin(1, out))
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

if (!"mixed_score" %in% names(mun_sf) && file.exists(paths$output_v2_geojson)) {
  log_step("Uniendo mixed_score desde municipios_v2.geojson")
  mixed_tbl <- st_read(paths$output_v2_geojson, quiet = TRUE) |>
    st_drop_geometry() |>
    transmute(codigo = as.character(codigo), mixed_score = suppressWarnings(as.numeric(mixed_score)))

  mun_sf <- mun_sf |>
    mutate(codigo = as.character(codigo)) |>
    left_join(mixed_tbl, by = "codigo")
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
grid_base <- st_sf(cell_idx = seq_along(grid_cells), geometry = grid_cells)

suppressWarnings({
  cell_mun_inter <- tryCatch(
    st_intersection(
      grid_base,
      mun_sf |>
        select(
          codigo,
          nombre,
          provincia,
          precip_annual_mm,
          temp_winter_mean_c,
          temp_summer_mean_c,
          river_access_score,
          forest_nature_quality,
          travel_bucket,
          geometry
        ) |>
        st_make_valid()
    ),
    error = function(e) NULL
  )
})

if (is.null(cell_mun_inter) || nrow(cell_mun_inter) == 0) {
  stop("No se pudo asignar la rejilla a municipios por solape.")
}

grid_assign <- cell_mun_inter |>
  mutate(overlap_area = as.numeric(st_area(geometry))) |>
  st_drop_geometry() |>
  arrange(cell_idx, desc(overlap_area), codigo) |>
  group_by(cell_idx) |>
  slice(1) |>
  ungroup() |>
  select(-overlap_area)

grid_sf <- grid_base |>
  left_join(grid_assign, by = "cell_idx") |>
  filter(!is.na(codigo)) |>
  mutate(
    area_km2 = as.numeric(st_area(geometry) / 1e6),
    grid_row = as.integer((ext$ymax - st_coordinates(st_centroid(geometry))[, 2]) / 2000),
    grid_col = as.integer((st_coordinates(st_centroid(geometry))[, 1] - ext$xmin) / 2000),
    cell_id = paste0("cell_", cell_idx),
    municipio_id = codigo,
    municipio_nombre = nombre,
    precip_annual = precip_annual_mm,
    temp_winter = temp_winter_mean_c,
    temp_summer = temp_summer_mean_c,
    natural_cover_pct = pmax(0, pmin(100, forest_nature_quality * 100))
  )

grid_centroids_utm <- st_centroid(grid_sf)

log_step("Calculando acceso hidrico por buffers (rios + embalses)")
hydro_layers <- list()

if (file.exists(paths$output_rivers_geojson)) {
  hydro_layers[[length(hydro_layers) + 1]] <- st_read(paths$output_rivers_geojson, quiet = TRUE)
}

embalses_candidates <- c(
  path(paths$output_dir, "embalses_scope.geojson"),
  path(paths$output_dir, "embalses.geojson"),
  path(paths$rivers_cache_dir, "embalses_scope.geojson")
)

for (fp in embalses_candidates) {
  if (!file.exists(fp)) next
  hydro_layers[[length(hydro_layers) + 1]] <- st_read(fp, quiet = TRUE)
}

if (length(hydro_layers) > 0) {
  hydro_utm <- do.call(rbind, lapply(hydro_layers, function(x) st_transform(x, st_crs(grid_sf)))) |>
    st_make_valid()

  if (nrow(hydro_utm) > 0) {
    in10 <- lengths(st_is_within_distance(grid_centroids_utm, hydro_utm, dist = 10000)) > 0
    in20 <- lengths(st_is_within_distance(grid_centroids_utm, hydro_utm, dist = 20000)) > 0
    in30 <- lengths(st_is_within_distance(grid_centroids_utm, hydro_utm, dist = 30000)) > 0

    grid_sf <- grid_sf |>
      mutate(
        river_buffer_class = case_when(
          in10 ~ "<=10km",
          in20 ~ "10-20km",
          in30 ~ "20-30km",
          TRUE ~ ">30km"
        ),
        river_distance_km = case_when(
          river_buffer_class == "<=10km" ~ 5,
          river_buffer_class == "10-20km" ~ 15,
          river_buffer_class == "20-30km" ~ 25,
          TRUE ~ 35
        ),
        river_access_score = case_when(
          river_buffer_class == "<=10km" ~ 100,
          river_buffer_class == "10-20km" ~ 70,
          river_buffer_class == "20-30km" ~ 40,
          TRUE ~ 10
        )
      )
  }
}

if (!"river_access_score" %in% names(grid_sf)) {
  grid_sf <- grid_sf |>
    mutate(
      river_buffer_class = NA_character_,
      river_distance_km = NA_real_,
      river_access_score = NA_real_
    )
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

log_step("Calculando bloques y mixed_score por celda")
grid_sf <- grid_sf |>
  mutate(
    precip_norm = round_idx(minmax_norm(precip_annual, invert = FALSE)),
    temp_verano_norm = round_idx(minmax_norm(temp_summer, invert = TRUE)),
    temp_invierno_norm = round_idx(minmax_norm(temp_winter, invert = FALSE)),
    natural_cover_norm = round_idx(minmax_norm(natural_cover_pct, invert = FALSE)),
    river_access_norm = round_idx(minmax_norm(river_access_score, invert = FALSE))
  )

travel_order <- c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00")
travel_score <- setNames(rev(seq_along(travel_order)), travel_order)
access_floor <- 0.2
access_raw <- (travel_score[grid_sf$isochrone_bucket] - 1) / (length(travel_order) - 1)

grid_sf <- grid_sf |>
  mutate(
    accesibilidad_norm = round_idx(access_floor + (1 - access_floor) * access_raw),
    climate_block_score = round_idx(
      rowMeans(cbind(precip_norm, temp_verano_norm, temp_invierno_norm), na.rm = TRUE)
    ),
    access_block_score = round_idx(accesibilidad_norm),
    nature_block_score = round_idx(
      rowMeans(cbind(natural_cover_norm, river_access_norm), na.rm = TRUE)
    ),
    mixed_score = round_idx(
      0.4 * climate_block_score +
        0.3 * access_block_score +
        0.3 * nature_block_score
    )
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
    mixed_score,
    precip_annual,
    temp_winter,
    temp_summer,
    river_distance_km,
    river_buffer_class,
    river_access_score,
    natural_cover_pct,
    precip_norm,
    temp_verano_norm,
    temp_invierno_norm,
    natural_cover_norm,
    river_access_norm,
    accesibilidad_norm,
    climate_block_score,
    access_block_score,
    nature_block_score,
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
    grid_climate_block_median = median(climate_block_score, na.rm = TRUE),
    grid_access_block_median = median(access_block_score, na.rm = TRUE),
    grid_nature_block_median = median(nature_block_score, na.rm = TRUE),
    grid_mixed_score_median = median(mixed_score, na.rm = TRUE),
    grid_mixed_score_p75 = as.numeric(quantile(mixed_score, probs = 0.75, na.rm = TRUE, type = 7)),
    grid_pct_cells_mixed_top = mean(mixed_score >= 0.4283, na.rm = TRUE) * 100,
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

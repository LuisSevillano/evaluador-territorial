source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(arrow)
  library(fs)
})

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

if (!file.exists(paths$output_bathing_areas_unified_geojson)) {
  stop("No existe bathing_areas_unified.geojson. Ejecuta primero scripts/04y_bathing_sources_unified.R")
}

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [bathing-score] ", msg)

include_community <- identical(Sys.getenv("BATHING_INCLUDE_COMMUNITY", unset = "0"), "1")
method_version <- if (include_community) "hybrid_bathing_access_v3_plus_community" else "hybrid_bathing_access_v3"

score_distance <- function(distance_km, breaks, scores) {
  out <- rep(tail(scores, 1), length(distance_km))
  for (i in rev(seq_along(breaks))) {
    out[is.finite(distance_km) & distance_km <= breaks[[i]]] <- scores[[i]]
  }
  out
}

class_from_score <- function(score) {
  case_when(
    score >= 85 ~ "Muy alta",
    score >= 65 ~ "Alta",
    score >= 40 ~ "Media",
    score >= 20 ~ "Baja",
    TRUE ~ "Muy baja"
  )
}

empty_candidate_tbl <- function(codigo) {
  tibble(
    codigo = codigo,
    candidate_score = NA_real_,
    candidate_source_type = NA_character_,
    candidate_name = NA_character_,
    candidate_distance_km = NA_real_,
    candidate_confidence = NA_real_,
    candidate_count_10km = NA_integer_
  )
}

municipios <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(25830) |>
  select(codigo, codprov, nombre, provincia, geometry)

mun_pts <- st_point_on_surface(municipios)
codigo <- municipios$codigo

official_score <- function() {
  bathing <- st_read(paths$output_bathing_areas_unified_geojson, quiet = TRUE) |>
    st_make_valid()

  if ("is_primary_record" %in% names(bathing)) {
    bathing <- bathing |>
      filter(is_primary_record)
  }

  allowed_sources <- c("mapa", "chd", "nayade")
  if (include_community) allowed_sources <- c(allowed_sources, "community")

  if ("source" %in% names(bathing)) {
    bathing <- bathing |>
      filter(source %in% allowed_sources)
  }

  if ("has_geometry" %in% names(bathing)) {
    bathing <- bathing |>
      filter(is.na(has_geometry) | has_geometry)
  }

  bathing <- bathing |>
    filter(!st_is_empty(geometry)) |>
    st_transform(st_crs(municipios))

  if (nrow(bathing) == 0) {
    return(empty_candidate_tbl(codigo))
  }

  nearest_idx <- st_nearest_feature(mun_pts, bathing)
  nearest_dist_km <- as.numeric(st_distance(mun_pts, bathing[nearest_idx, ], by_element = TRUE)) / 1000
  candidate_count_10km <- lengths(st_is_within_distance(mun_pts, bathing, dist = 10000, sparse = TRUE))

  source_vals <- if ("source" %in% names(bathing)) as.character(bathing$source[nearest_idx]) else "official"
  source_confidence <- case_when(
    source_vals == "mapa" ~ 100,
    source_vals == "chd" ~ 95,
    source_vals == "nayade" ~ 90,
    source_vals == "community" ~ 55,
    TRUE ~ 85
  )

  raw_score <- score_distance(
    nearest_dist_km,
    breaks = c(5, 10, 20, 40),
    scores = c(100, 80, 60, 30, 5)
  )

  tibble(
    codigo = codigo,
    candidate_score = round(raw_score * source_confidence / 100, 1),
    candidate_source_type = ifelse(source_vals == "community", "community_bathing", "official_bathing"),
    candidate_name = if ("name" %in% names(bathing)) as.character(bathing$name[nearest_idx]) else NA_character_,
    candidate_distance_km = round(nearest_dist_km, 2),
    candidate_confidence = source_confidence,
    candidate_count_10km = candidate_count_10km
  )
}

proxy_from_summer_flow_candidates <- function() {
  if (!file.exists(paths$output_river_summer_candidates_rds)) {
    log_step("Sin candidatos de rios estivales; se omite capa proxy en este paso")
    return(empty_candidate_tbl(codigo))
  }

  candidates <- readRDS(paths$output_river_summer_candidates_rds) |>
    st_make_valid() |>
    st_transform(st_crs(municipios)) |>
    filter(!st_is_empty(geometry))

  if (nrow(candidates) == 0) {
    return(empty_candidate_tbl(codigo))
  }

  log_step("Creando grid 2km para proxy fluvial estival")
  mun_union <- st_union(municipios)
  grid <- st_sf(
    cell_idx = seq_along(st_make_grid(mun_union, cellsize = 2000, crs = st_crs(municipios))),
    geometry = st_make_grid(mun_union, cellsize = 2000, crs = st_crs(municipios))
  )

  suppressWarnings({
    grid_mun_inter <- st_intersection(
      grid,
      municipios |>
        select(codigo, geometry) |>
        st_make_valid()
    ) |>
      mutate(overlap_area = as.numeric(st_area(geometry))) |>
      st_drop_geometry() |>
      group_by(cell_idx) |>
      slice_max(overlap_area, n = 1, with_ties = FALSE) |>
      ungroup() |>
      select(cell_idx, codigo)
  })

  grid_assigned <- grid |>
    inner_join(grid_mun_inter, by = "cell_idx")

  score_by_class <- function(grid_pts, river_sf, cls) {
    cls_rivers <- river_sf |>
      filter(summer_flow_class == cls)
    if (nrow(cls_rivers) == 0) return(NULL)

    nearest_idx <- st_nearest_feature(grid_pts, cls_rivers)
    distance_km <- as.numeric(st_distance(grid_pts, cls_rivers[nearest_idx, ], by_element = TRUE)) / 1000

    if (cls == "fuerte") {
      score <- score_distance(distance_km, c(1, 3, 5, 10, 20), c(70, 62, 52, 38, 22, 0))
      confidence <- score_distance(distance_km, c(1, 3, 5, 10, 20), c(90, 88, 85, 80, 75, NA))
    } else if (cls == "medio") {
      score <- score_distance(distance_km, c(1, 3, 5, 10, 20), c(60, 52, 44, 30, 15, 0))
      confidence <- score_distance(distance_km, c(1, 3, 5, 10, 20), c(72, 70, 68, 65, 60, NA))
    } else {
      score <- score_distance(distance_km, c(1, 3, 5, 10), c(45, 38, 30, 18, 0))
      confidence <- score_distance(distance_km, c(1, 3, 5, 10), c(55, 52, 50, 45, NA))
    }

    tibble(
      cell_idx = grid_assigned$cell_idx,
      codigo = grid_assigned$codigo,
      summer_flow_class = cls,
      proxy_score = score,
      proxy_confidence = confidence,
      distance_km = distance_km
    ) |>
      filter(proxy_score > 0)
  }

  log_step("Asignando bandas de distancia a la grid por clase de rio estival")
  grid_pts <- st_point_on_surface(grid_assigned)
  cell_scores <- bind_rows(
    score_by_class(grid_pts, candidates, "fuerte"),
    score_by_class(grid_pts, candidates, "medio"),
    score_by_class(grid_pts, candidates, "debil")
  )

  if (nrow(cell_scores) == 0) {
    return(empty_candidate_tbl(codigo))
  }

  best_cell <- cell_scores |>
    group_by(cell_idx, codigo) |>
    arrange(desc(proxy_score), desc(proxy_confidence), distance_km, .by_group = TRUE) |>
    slice(1) |>
    ungroup()

  mun_proxy <- best_cell |>
    group_by(codigo) |>
    summarise(
      p75_score = as.numeric(quantile(proxy_score, probs = 0.75, na.rm = TRUE, type = 7)),
      max_score = max(proxy_score, na.rm = TRUE),
      median_confidence = median(proxy_confidence, na.rm = TRUE),
      best_distance_km = min(distance_km, na.rm = TRUE),
      covered_cells = n(),
      .groups = "drop"
    ) |>
    mutate(candidate_score = pmin(70, pmax(p75_score, 0.85 * max_score)))

  empty_candidate_tbl(codigo) |>
    select(codigo) |>
    left_join(mun_proxy, by = "codigo") |>
    transmute(
    codigo = codigo,
    candidate_score = round(candidate_score, 1),
    candidate_source_type = ifelse(is.finite(candidate_score), "river_summer_proxy", NA_character_),
    candidate_name = ifelse(is.finite(candidate_score), "Rio candidato con caudal estival probable", NA_character_),
    candidate_distance_km = round(best_distance_km, 2),
    candidate_confidence = round(median_confidence, 1),
    candidate_count_10km = as.integer(covered_cells)
    )
}

log_step("Calculando acceso a zonas oficiales/inventariadas")
official <- official_score()

log_step("Calculando proxy por rios con caudal estival probable")
proxy <- proxy_from_summer_flow_candidates()

combined <- bind_rows(
  official |> mutate(candidate_layer = "official"),
  proxy |> mutate(candidate_layer = "proxy")
) |>
  group_by(codigo) |>
  arrange(desc(coalesce(candidate_score, -Inf)), desc(coalesce(candidate_confidence, -Inf)), .by_group = TRUE) |>
  slice(1) |>
  ungroup()

feature_tbl <- municipios |>
  st_drop_geometry() |>
  select(codigo, codprov, nombre, provincia) |>
  left_join(combined, by = "codigo") |>
  mutate(
    river_access_score = round(coalesce(candidate_score, 0), 1),
    river_access_class = class_from_score(river_access_score),
    river_nearest_name = candidate_name,
    river_nearest_distance_km = candidate_distance_km,
    river_nearest_confidence = candidate_confidence,
    river_candidate_count_10km = candidate_count_10km,
    river_access_source_type = candidate_source_type,
    river_method_version = method_version
  ) |>
  select(
    codigo,
    river_access_score,
    river_access_class,
    river_nearest_name,
    river_nearest_distance_km,
    river_nearest_confidence,
    river_candidate_count_10km,
    river_access_source_type,
    river_method_version
  )

municipal_geo <- municipios |>
  left_join(feature_tbl, by = "codigo") |>
  st_transform(4326)

summary_tbl <- feature_tbl |>
  count(river_access_source_type, river_access_class, name = "municipios") |>
  arrange(river_access_source_type, desc(municipios))

out_geo <- path(paths$output_dir, "municipios_bathing_access.geojson")
out_csv <- path(paths$output_dir, "municipios_bathing_access.csv")
out_summary <- path(paths$output_dir, "bathing_access_summary.csv")

st_write(municipal_geo, out_geo, delete_dsn = TRUE, quiet = TRUE)
write_csv(st_drop_geometry(municipal_geo), out_csv)
write_csv(summary_tbl, out_summary)
saveRDS(feature_tbl, paths$output_feature_river_rds)
try(write_parquet(feature_tbl, paths$output_feature_river_parquet), silent = TRUE)

log_step("Escritura completada")
message("OK: score hibrido de zonas de bano en ", paths$output_feature_river_rds)
message("OK: resumen en ", out_summary)
print(summary_tbl)

source("scripts/00_config.R")

library(sf)
library(dplyr)
library(jsonlite)
library(readr)
library(fs)

sf_use_s2(FALSE)
use_bathing_sources <- identical(Sys.getenv("PIPELINE_USE_BATHING_SOURCES", unset = "0"), "1")

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe dataset post-quality. Ejecuta primero scripts/04_quality_checks.R")
}

if (!file.exists(paths$output_climate_monthly_csv)) {
  stop("No existe output/municipios_climate_monthly.csv")
}

if (!file.exists(paths$output_feature_grid_agg_rds)) {
  stop("No existe feature_grid_agg.rds. Ejecuta primero scripts/04j_grid_2km.R")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)
mun_base <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_transform(4326)

grid_agg <- readRDS(paths$output_feature_grid_agg_rds) |>
  select(any_of(c(
    "codigo",
    "grid_cell_count",
    "grid_precip_annual_median",
    "grid_temp_winter_median",
    "grid_temp_summer_median",
    "grid_river_access_median",
    "grid_natural_cover_median",
    "grid_iso_majority_bucket",
    "grid_climate_block_median",
    "grid_access_block_median",
    "grid_nature_block_median",
    "grid_mixed_score_median",
    "grid_mixed_score_p75",
    "grid_pct_cells_mixed_top",
    "grid_pct_cells_bathing_20km",
    "grid_river_method_version",
    "score_source"
  )))

mun <- mun |>
  left_join(grid_agg, by = "codigo")

if (file.exists(paths$output_provincias_geojson)) {
  provincias_bounds <- st_read(paths$output_provincias_geojson, quiet = TRUE) |>
    st_transform(4326)

  if ("nombre_prov" %in% names(provincias_bounds) && any(mun$provincia == "53", na.rm = TRUE)) {
    mun_53 <- mun |>
      mutate(.row_id = row_number()) |>
      filter(provincia == "53")

    if (nrow(mun_53) > 0) {
      mun_53_join <- st_join(
        mun_53,
        provincias_bounds |>
          transmute(provincia_boundary = as.character(nombre_prov)),
        left = TRUE,
        largest = TRUE,
        suffix = c("", "_boundary")
      )

      province_fix <- mun_53_join |>
        st_drop_geometry() |>
        transmute(.row_id, provincia_fix = provincia_boundary) |>
        filter(!is.na(provincia_fix) & provincia_fix != "")

      if (nrow(province_fix) > 0) {
        mun <- mun |>
          mutate(.row_id = row_number()) |>
          left_join(province_fix, by = ".row_id") |>
          mutate(provincia = if_else(provincia == "53" & !is.na(provincia_fix), provincia_fix, provincia)) |>
          select(-.row_id, -provincia_fix)
      }

      mun_53_remaining <- mun |>
        mutate(.row_id = row_number()) |>
        filter(provincia == "53")

      if (nrow(mun_53_remaining) > 0) {
        pts <- mun_53_remaining |>
          st_point_on_surface()
        nearest_idx <- st_nearest_feature(pts, provincias_bounds)
        nearest_prov <- as.character(provincias_bounds$nombre_prov[nearest_idx])

        nearest_fix <- tibble(.row_id = mun_53_remaining$.row_id, provincia_fix = nearest_prov)

        mun <- mun |>
          mutate(.row_id = row_number()) |>
          left_join(nearest_fix, by = ".row_id") |>
          mutate(provincia = if_else(provincia == "53" & !is.na(provincia_fix), provincia_fix, provincia)) |>
          select(-.row_id, -provincia_fix)
      }
    }
  }

  # Provincia geometrica estable para filtros (evita casos anómalos por prefijos de codigo)
  province_geo_join <- st_join(
    mun |>
      mutate(.row_id = row_number()),
    provincias_bounds |>
      transmute(
        provincia_id_geo = as.character(id_prov),
        provincia_nombre_geo = as.character(nombre_prov)
      ),
    left = TRUE,
    largest = TRUE
  )

  province_geo_tbl <- province_geo_join |>
    st_drop_geometry() |>
    select(.row_id, provincia_id_geo, provincia_nombre_geo)

  mun <- mun |>
    mutate(.row_id = row_number()) |>
    left_join(province_geo_tbl, by = ".row_id") |>
    mutate(
      provincia_id_geo = dplyr::coalesce(provincia_id_geo, as.character(provincia)),
      provincia_nombre_geo = dplyr::coalesce(provincia_nombre_geo, as.character(provincia))
    ) |>
    select(-.row_id)
}

river_access_csv_candidates <- c(
  path(paths$output_dir, "municipios_river_access.csv"),
  path(paths$output_dir, "burgos_river_access.csv")
)
river_access_csv <- river_access_csv_candidates[file.exists(river_access_csv_candidates)][1]

existing_river_cols <- c(
  "river_access_score", "river_access_class", "river_nearest_name",
  "river_nearest_distance_km", "river_nearest_confidence",
  "river_candidate_count_10km", "river_method_version"
)
has_river_already <- all(existing_river_cols %in% names(mun))

if (!is.na(river_access_csv)) {
  if (!has_river_already) {
    river_access <- read_csv(river_access_csv, show_col_types = FALSE) |>
      select(
        codigo,
        river_access_score,
        river_access_class,
        river_nearest_name,
        river_nearest_distance_km,
        river_nearest_confidence,
        river_candidate_count_10km,
        any_of("river_access_source_type"),
        river_method_version
      )
    mun <- mun |>
      left_join(river_access, by = "codigo")
  }
} else {
  if (!has_river_already) {
    mun$river_access_score <- NA_real_
    mun$river_access_class <- NA_character_
    mun$river_nearest_name <- NA_character_
    mun$river_nearest_distance_km <- NA_real_
    mun$river_nearest_confidence <- NA_real_
    mun$river_candidate_count_10km <- NA_integer_
    mun$river_access_source_type <- NA_character_
    mun$river_method_version <- NA_character_
  }
}

coords <- tryCatch(
  {
    mun |>
      st_make_valid() |>
      st_transform(3857) |>
      st_geometry() |>
      st_point_on_surface() |>
      st_transform(4326) |>
      st_coordinates()
  },
  error = function(e) matrix(numeric(0), ncol = 2)
)

if (nrow(coords) == nrow(mun)) {
  mun$lon <- coords[, 1]
  mun$lat <- coords[, 2]
} else {
  warning("No se pudieron obtener coordenadas para todas las geometrías. Se usa centroide como fallback.")
  coords_fb <- tryCatch(
    {
      mun |>
        st_make_valid() |>
        st_transform(4326) |>
        st_centroid(of_largest_polygon = TRUE) |>
        st_coordinates()
    },
    error = function(e) matrix(numeric(0), ncol = 2)
  )

  if (nrow(coords_fb) == nrow(mun)) {
    mun$lon <- coords_fb[, 1]
    mun$lat <- coords_fb[, 2]
  } else {
    mun$lon <- rep(NA_real_, nrow(mun))
    mun$lat <- rep(NA_real_, nrow(mun))
  }
}

minmax_norm <- function(x, invert = FALSE) {
  rng <- range(x, na.rm = TRUE)
  if (!is.finite(rng[1]) || !is.finite(rng[2]) || rng[1] == rng[2]) {
    return(rep(0.5, length(x)))
  }
  out <- (x - rng[1]) / (rng[2] - rng[1])
  if (invert) out <- 1 - out
  out
}

ensure_num_col <- function(df, col_name, default = NA_real_) {
  if (!col_name %in% names(df)) df[[col_name]] <- rep(default, nrow(df))
  df
}

ensure_chr_col <- function(df, col_name, default = NA_character_) {
  if (!col_name %in% names(df)) df[[col_name]] <- rep(default, nrow(df))
  df
}

round_idx <- function(x) round(x, 3)

for (col_name in c(
  "precip_annual_mm", "temp_summer_mean_c", "temp_winter_mean_c", "temp_jan_mean_c", "temp_jul_mean_c",
  "forest_pct", "forest_nature_quality", "water_pct", "artificial_pct",
  "naturality_index", "landcover_diversity", "river_access_score",
  "relieve_norm", "relieve_score_raw", "dist_estacion_tren_km",
  "dist_parada_bus_km", "transporte_norm", "dist_renfe_km",
  "renfe_salidas_dia", "servicio_renfe_norm", "dist_renfe_madrid_km",
  "renfe_madrid_active_days", "renfe_madrid_coverage_pct",
  "renfe_madrid_departures_total", "renfe_madrid_departures_avg_day",
  "renfe_madrid_departures_active_day", "renfe_madrid_departures_p25",
  "renfe_madrid_routes_count", "renfe_madrid_service_norm",
  "has_direct_madrid_service", "has_nearby_station", "nearest_station_distance_km",
  "transport_confidence"
)) {
  mun <- ensure_num_col(mun, col_name)
}

if (!"renfe_madrid_weekend_service" %in% names(mun)) mun$renfe_madrid_weekend_service <- rep(FALSE, nrow(mun))

for (col_name in c(
  "renfe_tipo_servicio", "renfe_madrid_connection_type",
  "renfe_madrid_stop_id", "renfe_madrid_stop_name",
  "renfe_madrid_stop_municipality", "renfe_madrid_stop_province",
  "travel_bucket", "transport_status"
)) {
  mun <- ensure_chr_col(mun, col_name)
}
mun <- ensure_chr_col(mun, "river_access_source_type")

for (col_name in c(
  "grid_precip_annual_median",
  "grid_temp_winter_median",
  "grid_temp_summer_median",
  "grid_river_access_median",
  "grid_natural_cover_median",
  "grid_climate_block_median",
  "grid_access_block_median",
  "grid_nature_block_median",
  "grid_mixed_score_median"
)) {
  mun <- ensure_num_col(mun, col_name)
}
mun <- ensure_chr_col(mun, "grid_iso_majority_bucket")
mun <- ensure_chr_col(mun, "grid_river_method_version")
mun <- ensure_chr_col(mun, "score_source")

for (col_name in c("provincia_id_geo", "provincia_nombre_geo")) {
  mun <- ensure_chr_col(mun, col_name, default = as.character(mun$provincia))
}

if (all(is.na(mun$forest_nature_quality)) && "forest_pct" %in% names(mun)) {
  mun$forest_nature_quality <- pmin(1, pmax(0, mun$forest_pct / 100))
}

mun$precip_norm <- round_idx(minmax_norm(mun$precip_annual_mm, invert = FALSE))
mun$temp_verano_norm <- round_idx(minmax_norm(mun$temp_summer_mean_c, invert = TRUE))
mun$temp_invierno_norm <- round_idx(minmax_norm(mun$temp_winter_mean_c, invert = FALSE))
mun$forest_norm <- round_idx(minmax_norm(mun$forest_pct, invert = FALSE))
mun$forest_nature_quality_norm <- round_idx(minmax_norm(mun$forest_nature_quality, invert = FALSE))
mun$water_norm <- round_idx(minmax_norm(mun$water_pct, invert = FALSE))
mun$artificial_norm <- round_idx(minmax_norm(mun$artificial_pct, invert = TRUE))
mun$naturality_norm <- round_idx(minmax_norm(mun$naturality_index, invert = FALSE))
mun$diversity_norm <- round_idx(minmax_norm(mun$landcover_diversity, invert = FALSE))
mun$river_access_norm <- round_idx(minmax_norm(mun$river_access_score, invert = FALSE))
mun$relieve_norm <- round_idx(minmax_norm(mun$relieve_norm, invert = FALSE))

travel_order <- c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00")
travel_score <- setNames(rev(seq_along(travel_order)), travel_order)
access_floor <- 0.2
access_raw <- (travel_score[mun$travel_bucket] - 1) / (length(travel_order) - 1)
mun$accesibilidad_norm <- round_idx(access_floor + (1 - access_floor) * access_raw)

mun$climate_block_score <- round_idx(
  rowMeans(cbind(mun$precip_norm, mun$temp_verano_norm, mun$temp_invierno_norm), na.rm = TRUE)
)
mun$access_block_score <- round_idx(mun$accesibilidad_norm)
nature_weights <- c(
  forest_nature_quality_norm = 0.52,
  water_norm = 0.20,
  diversity_norm = 0.10,
  river_access_norm = 0.06,
  relieve_norm = 0.12
)

nature_matrix <- cbind(
  forest_nature_quality_norm = mun$forest_nature_quality_norm,
  water_norm = mun$water_norm,
  diversity_norm = mun$diversity_norm,
  river_access_norm = mun$river_access_norm,
  relieve_norm = mun$relieve_norm
)

mun$nature_block_score <- round_idx(
  apply(nature_matrix, 1, function(row_vals) {
    valid <- is.finite(row_vals)
    if (!any(valid)) return(NA_real_)
    sum(row_vals[valid] * nature_weights[valid]) / sum(nature_weights[valid])
  })
)

w_climate <- 0.4
w_access <- 0.3
w_nature <- 0.3

mun$mixed_score <- round_idx(
  w_climate * mun$climate_block_score +
    w_access * mun$access_block_score +
    w_nature * mun$nature_block_score
)

mun <- mun |>
  mutate(
    precip_annual_mm = ifelse(is.finite(grid_precip_annual_median), grid_precip_annual_median, precip_annual_mm),
    temp_winter_mean_c = ifelse(is.finite(grid_temp_winter_median), grid_temp_winter_median, temp_winter_mean_c),
    temp_summer_mean_c = ifelse(is.finite(grid_temp_summer_median), grid_temp_summer_median, temp_summer_mean_c),
    river_access_score = ifelse(!use_bathing_sources & is.finite(grid_river_access_median), grid_river_access_median, river_access_score),
    forest_nature_quality = ifelse(is.finite(grid_natural_cover_median), pmin(1, pmax(0, grid_natural_cover_median / 100)), forest_nature_quality),
    travel_bucket = ifelse(!is.na(grid_iso_majority_bucket) & grid_iso_majority_bucket != "", grid_iso_majority_bucket, travel_bucket),
    climate_block_score = ifelse(is.finite(grid_climate_block_median), grid_climate_block_median, climate_block_score),
    access_block_score = ifelse(is.finite(grid_access_block_median), grid_access_block_median, access_block_score),
    nature_block_score = ifelse(is.finite(grid_nature_block_median), grid_nature_block_median, nature_block_score),
    mixed_score = ifelse(is.finite(grid_mixed_score_median), grid_mixed_score_median, mixed_score),
    river_method_version = ifelse(!is.na(grid_river_method_version) & grid_river_method_version != "", grid_river_method_version, river_method_version),
    score_source = ifelse(!is.na(score_source) & score_source != "", score_source, "municipal_fallback")
  )

population <- if ("population" %in% names(mun)) mun$population else rep(NA_real_, nrow(mun))
population_men <- if ("population_men" %in% names(mun)) mun$population_men else rep(NA_real_, nrow(mun))
population_women <- if ("population_women" %in% names(mun)) mun$population_women else rep(NA_real_, nrow(mun))

mun_v2 <- mun |>
  transmute(
    id = codigo,
    codigo,
    nombre,
    provincia,
    provincia_id_geo,
    provincia_nombre_geo,
    lon,
    lat,
    population,
    population_men,
    population_women,
    precip_annual_mm,
    temp_winter_mean_c,
    temp_summer_mean_c,
    temp_jan_mean_c,
    temp_jul_mean_c,
    iso_01h30m,
    iso_02h00m,
    iso_02h30m,
    iso_03h30m,
    iso_04h00m,
    travel_bucket,
    dist_estacion_tren_km,
    dist_parada_bus_km,
    transporte_norm,
    dist_renfe_km,
    renfe_salidas_dia,
    renfe_tipo_servicio,
    servicio_renfe_norm,
    dist_renfe_madrid_km,
    renfe_madrid_active_days,
    renfe_madrid_coverage_pct,
    renfe_madrid_departures_total,
    renfe_madrid_departures_avg_day,
    renfe_madrid_departures_active_day,
    renfe_madrid_departures_p25,
    renfe_madrid_weekend_service,
    renfe_madrid_routes_count,
    renfe_madrid_stop_id,
    renfe_madrid_stop_name,
    renfe_madrid_stop_municipality,
    renfe_madrid_stop_province,
    renfe_madrid_connection_type,
    renfe_madrid_service_norm,
    has_direct_madrid_service,
    transport_confidence,
    transport_status,
    precip_norm,
    temp_verano_norm,
    temp_invierno_norm,
    forest_pct,
    forest_nature_quality,
    water_pct,
    artificial_pct,
    naturality_index,
    landcover_diversity,
    river_access_score,
    river_access_class,
    river_nearest_name,
    river_nearest_distance_km,
    river_nearest_confidence,
    river_candidate_count_10km,
    river_access_source_type,
    river_method_version,
    grid_pct_cells_bathing_20km,
    forest_norm,
    forest_nature_quality_norm,
    water_norm,
    artificial_norm,
    naturality_norm,
    diversity_norm,
    river_access_norm,
    relieve_score_raw,
    relieve_norm,
    accesibilidad_norm,
    climate_block_score,
    access_block_score,
    nature_block_score,
    mixed_score,
    score_source
  )

mun_tab <- mun_v2 |>
  st_drop_geometry()

mun_tiles <- mun_base |>
  transmute(
    codigo,
    nombre_base = as.character(nombre),
    provincia_base = as.character(provincia),
    geometry
  ) |>
  left_join(mun_tab, by = "codigo") |>
  mutate(
    id = dplyr::coalesce(id, codigo),
    nombre = dplyr::coalesce(na_if(trimws(nombre), ""), nombre_base),
    provincia = dplyr::coalesce(na_if(trimws(provincia), ""), provincia_base)
  ) |>
  select(-nombre_base, -provincia_base)

write_csv(mun_tab, paths$output_v2_csv)
write_file(toJSON(mun_tab, auto_unbox = TRUE), paths$output_v2_json)
st_write(mun_tiles, paths$output_v2_geojson, delete_dsn = TRUE, quiet = TRUE)

monthly <- read_csv(paths$output_climate_monthly_csv, show_col_types = FALSE)
write_file(toJSON(monthly, auto_unbox = TRUE), paths$output_climate_monthly_json)

file_copy(paths$output_v2_json, paths$frontend_v2_json, overwrite = TRUE)
file_copy(paths$output_climate_monthly_json, paths$frontend_climate_monthly_json, overwrite = TRUE)

message("OK: export v2 tabular generado y copiado a frontend/static/data")

source("scripts/00_config.R")

library(sf)
library(dplyr)
library(arrow)

sf_use_s2(FALSE)
use_bathing_sources <- identical(Sys.getenv("PIPELINE_USE_BATHING_SOURCES", unset = "0"), "1")

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)

read_feature <- function(rds_path, parquet_path) {
  if (file.exists(rds_path)) {
    feat <- tryCatch(readRDS(rds_path), error = function(e) NULL)
    if (!is.null(feat)) return(as_tibble(feat))
  }
  if (file.exists(parquet_path)) {
    feat <- tryCatch(read_parquet(parquet_path) |> as_tibble(), error = function(e) NULL)
    if (!is.null(feat)) return(feat)
  }
  NULL
}

join_feature <- function(data_sf, rds_path, parquet_path, cols_expected) {
  feat <- read_feature(rds_path, parquet_path)
  if (is.null(feat)) {
    message("Aviso: feature no disponible/corrupta -> ", rds_path, " | ", parquet_path)
    return(data_sf)
  }
  if (!"codigo" %in% names(feat)) {
    message("Aviso: feature sin 'codigo' -> ", parquet_path)
    return(data_sf)
  }
  keep_cols <- intersect(c("codigo", cols_expected), names(feat))
  data_sf |>
    left_join(select(feat, all_of(keep_cols)), by = "codigo")
}

mun <- mun |>
  join_feature(paths$output_feature_climate_rds, paths$output_feature_climate_parquet, c("precip_annual_mm", "temp_winter_mean_c", "temp_summer_mean_c", "temp_jan_mean_c", "temp_jul_mean_c")) |>
  join_feature(paths$output_feature_isochrones_rds, paths$output_feature_isochrones_parquet, c("iso_01h30m", "iso_02h00m", "iso_02h30m", "iso_03h30m", "iso_04h00m", "travel_bucket")) |>
  join_feature(paths$output_feature_mfe_rds, paths$output_feature_mfe_parquet, c("forest_nature_quality", "water_pct")) |>
  join_feature(paths$output_feature_relief_rds, paths$output_feature_relief_parquet, c("elev_range_m", "slope_p90", "tri_mean", "relieve_score_raw", "relieve_norm")) |>
  join_feature(paths$output_feature_river_rds, paths$output_feature_river_parquet, c("river_access_score", "river_access_class", "river_nearest_name", "river_nearest_distance_km", "river_nearest_confidence", "river_candidate_count_10km", "river_access_source_type", "river_method_version"))

mun <- mun |>
  join_feature(paths$output_feature_transport_osm_rds, paths$output_feature_transport_osm_parquet, c("dist_estacion_tren_km", "dist_parada_bus_km", "transporte_norm")) |>
  join_feature(paths$output_feature_transport_renfe_rds, paths$output_feature_transport_renfe_parquet, c(
    "dist_renfe_km", "renfe_salidas_dia", "renfe_tipo_servicio", "servicio_renfe_norm",
    "dist_renfe_madrid_km", "renfe_madrid_active_days", "renfe_madrid_coverage_pct",
    "renfe_madrid_departures_total", "renfe_madrid_departures_avg_day",
    "renfe_madrid_departures_active_day", "renfe_madrid_departures_p25",
    "renfe_madrid_weekend_service", "renfe_madrid_routes_count",
    "renfe_madrid_stop_id", "renfe_madrid_stop_name",
    "renfe_madrid_stop_municipality", "renfe_madrid_stop_province",
    "renfe_madrid_connection_type", "renfe_madrid_service_norm",
    "has_direct_madrid_service", "has_nearby_station", "nearest_station_distance_km",
    "transport_confidence", "transport_status"
  ))

resolve_join_suffixes <- function(df) {
  nm <- names(df)
  x_cols <- nm[grepl("\\.x$", nm)]
  if (length(x_cols) == 0) return(df)

  for (x_name in x_cols) {
    base <- sub("\\.x$", "", x_name)
    y_name <- paste0(base, ".y")
    if (!y_name %in% names(df)) next

    x_val <- df[[x_name]]
    y_val <- df[[y_name]]

    if (is.character(x_val) || is.character(y_val)) {
      df[[base]] <- dplyr::coalesce(as.character(y_val), as.character(x_val))
    } else {
      df[[base]] <- dplyr::coalesce(y_val, x_val)
    }
  }

  drop_cols <- names(df)[grepl("\\.[xy]$", names(df))]
  if (length(drop_cols) > 0) {
    df <- df |>
      select(-any_of(drop_cols))
  }

  df
}

mun <- resolve_join_suffixes(mun)

st_write(mun, paths$output_final_geojson, delete_dsn = TRUE, quiet = TRUE)

message("OK: features ensambladas en ", paths$output_final_geojson)

#!/usr/bin/env Rscript
source("scripts/00_config.R")

library(fs)
library(jsonlite)
library(sf)
library(dplyr)
library(arrow)

output_final_geojson <- paths$output_final_geojson
intermediate_dir <- path(project_root, "data", "intermediate")
dir_create(intermediate_dir)

sf_use_s2(FALSE)

if (!file.exists(output_final_geojson)) {
  stop("No existe municipios_final.geojson")
}

mun <- sf::st_read(output_final_geojson, quiet = TRUE)

download_renfe_data <- function() {
  est_file <- path(intermediate_dir, "renfe_estaciones.csv")
  gtfs_file <- path(intermediate_dir, "renfe_gtfs.zip")
  gtfs_dir <- path(intermediate_dir, "renfe_gtfs")
  required_gtfs_files <- c("agency.txt", "calendar.txt", "routes.txt", "stops.txt", "stop_times.txt", "trips.txt")
  
  if (!file.exists(est_file)) {
    message("[renfe] Descargando estaciones...")
    est_url <- "https://ssl.renfe.com/ftransit/Fichero_estaciones/estaciones.csv"
    tryCatch({
      download.file(est_url, est_file, quiet = TRUE, method = "curl")
      message("[renfe] Estaciones guardadas: ", est_file)
    }, error = function(e) {
      message("[renfe] Error descargando estaciones: ", e$message)
    })
  }
  
  if (!file.exists(gtfs_file)) {
    message("[renfe] Descargando GTFS cercanias...")
    gtfs_url <- "https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip"
    tryCatch({
      download.file(gtfs_url, gtfs_file, quiet = TRUE, method = "curl")
      message("[renfe] GTFS guardado: ", gtfs_file)
    }, error = function(e) {
      message("[renfe] Error descargando GTFS: ", e$message)
    })
  }
  
  gtfs_file_exists <- function(filename) {
    length(list.files(gtfs_dir, pattern = paste0("^", filename, "$"), recursive = TRUE, full.names = TRUE)) > 0
  }

  gtfs_complete <- dir.exists(gtfs_dir) && all(vapply(required_gtfs_files, gtfs_file_exists, logical(1)))

  if (file.exists(gtfs_file) && !gtfs_complete) {
    if (dir.exists(gtfs_dir)) {
      message("[renfe] GTFS extraido incompleto; reextrayendo ZIP...")
      unlink(gtfs_dir, recursive = TRUE, force = TRUE)
    } else {
      message("[renfe] Extrayendo GTFS...")
    }
    dir_create(gtfs_dir)
    unzip(gtfs_file, exdir = gtfs_dir)
  }
  
  list(estaciones = est_file, gtfs_dir = gtfs_dir)
}

parse_gtfs_date <- function(x) {
  as.Date(as.character(x), format = "%Y%m%d")
}

expand_gtfs_service_dates <- function(gtfs_dir) {
  locate_gtfs_file <- function(filename) {
    candidates <- list.files(gtfs_dir, pattern = paste0("^", filename, "$"), recursive = TRUE, full.names = TRUE)
    if (length(candidates) == 0) return(path(gtfs_dir, filename))
    candidates[1]
  }

  calendar_file <- locate_gtfs_file("calendar.txt")
  calendar_dates_file <- locate_gtfs_file("calendar_dates.txt")

  service_dates <- data.frame(service_id = character(), service_date = as.Date(character()))

  if (file.exists(calendar_file)) {
    calendar <- read.csv(calendar_file, stringsAsFactors = FALSE)
    day_cols <- c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
    if (all(c("service_id", "start_date", "end_date", day_cols) %in% names(calendar))) {
      rows <- lapply(seq_len(nrow(calendar)), function(i) {
        start_date <- parse_gtfs_date(calendar$start_date[i])
        end_date <- parse_gtfs_date(calendar$end_date[i])
        if (is.na(start_date) || is.na(end_date) || end_date < start_date) return(NULL)
        dates <- seq.Date(start_date, end_date, by = "day")
        # POSIXlt wday: 0=sunday, 1=monday, ..., 6=saturday
        weekday_idx <- as.POSIXlt(dates)$wday
        active <- rep(FALSE, length(dates))
        active[weekday_idx == 1 & calendar$monday[i] == 1] <- TRUE
        active[weekday_idx == 2 & calendar$tuesday[i] == 1] <- TRUE
        active[weekday_idx == 3 & calendar$wednesday[i] == 1] <- TRUE
        active[weekday_idx == 4 & calendar$thursday[i] == 1] <- TRUE
        active[weekday_idx == 5 & calendar$friday[i] == 1] <- TRUE
        active[weekday_idx == 6 & calendar$saturday[i] == 1] <- TRUE
        active[weekday_idx == 0 & calendar$sunday[i] == 1] <- TRUE
        if (!any(active)) return(NULL)
        data.frame(service_id = calendar$service_id[i], service_date = dates[active])
      })
      service_dates <- bind_rows(rows)
    }
  }

  if (file.exists(calendar_dates_file)) {
    exceptions <- read.csv(calendar_dates_file, stringsAsFactors = FALSE)
    if (all(c("service_id", "date", "exception_type") %in% names(exceptions))) {
      exceptions <- exceptions |>
        mutate(service_date = parse_gtfs_date(date)) |>
        filter(!is.na(service_date))
      removed <- exceptions |> filter(exception_type == 2) |> select(service_id, service_date)
      added <- exceptions |> filter(exception_type == 1) |> select(service_id, service_date)
      if (nrow(removed) > 0 && nrow(service_dates) > 0) {
        service_dates <- anti_join(service_dates, removed, by = c("service_id", "service_date"))
      }
      if (nrow(added) > 0) {
        service_dates <- bind_rows(service_dates, added)
      }
    }
  }

  service_dates |>
    distinct(service_id, service_date) |>
    filter(!is.na(service_id), !is.na(service_date))
}

process_renfe <- function(data, mun_sf) {
  gtfs_dir <- data$gtfs_dir

  if (!dir.exists(gtfs_dir)) {
    message("[renfe] GTFS no disponible")
    return(NULL)
  }

  locate_gtfs_file <- function(filename) {
    candidates <- list.files(gtfs_dir, pattern = paste0("^", filename, "$"), recursive = TRUE, full.names = TRUE)
    if (length(candidates) == 0) return(path(gtfs_dir, filename))
    candidates[1]
  }

  stops_file <- locate_gtfs_file("stops.txt")
  trips_file <- locate_gtfs_file("trips.txt")
  stop_times_file <- locate_gtfs_file("stop_times.txt")

  if (!all(file.exists(c(stops_file, trips_file, stop_times_file)))) {
    message("[renfe] GTFS incompleto: faltan stops/trips/stop_times")
    return(NULL)
  }

  stops <- read.csv(stops_file, stringsAsFactors = FALSE)
  trips <- read.csv(trips_file, stringsAsFactors = FALSE)
  stop_times <- read.csv(stop_times_file, stringsAsFactors = FALSE)
  service_dates <- expand_gtfs_service_dates(gtfs_dir)

  if (nrow(service_dates) == 0) {
    message("[renfe] Sin calendario GTFS activo")
    return(NULL)
  }

  required_stops <- c("stop_id", "stop_name", "stop_lat", "stop_lon")
  if (!all(required_stops %in% names(stops)) || !all(c("trip_id", "service_id", "route_id") %in% names(trips)) ||
      !all(c("trip_id", "stop_id", "stop_sequence") %in% names(stop_times))) {
    message("[renfe] GTFS sin columnas obligatorias")
    return(NULL)
  }

  madrid_regex <- Sys.getenv(
    "RENFE_MADRID_STOP_REGEX",
    unset = "MADRID|ATOCHA|CHAMART[IÍ]N|PR[IÍ]NCIPE P[IÍ]O|RECOLETOS|NUEVOS MINISTERIOS|SOL"
  )

  madrid_stop_ids <- stops |>
    filter(grepl(madrid_regex, stop_name, ignore.case = TRUE)) |>
    pull(stop_id) |>
    unique()

  message("[renfe] Paradas destino Madrid detectadas: ", length(madrid_stop_ids))
  if (length(madrid_stop_ids) == 0) return(NULL)

  stop_times_base <- stop_times |>
    mutate(stop_sequence = as.integer(stop_sequence)) |>
    filter(!is.na(stop_sequence)) |>
    inner_join(trips |> select(trip_id, service_id, route_id), by = "trip_id")

  madrid_trip_seq <- stop_times_base |>
    filter(stop_id %in% madrid_stop_ids) |>
    group_by(trip_id) |>
    summarise(madrid_stop_sequence = min(stop_sequence, na.rm = TRUE), .groups = "drop")

  origin_candidates <- stop_times_base |>
    inner_join(madrid_trip_seq, by = "trip_id") |>
    filter(!stop_id %in% madrid_stop_ids, stop_sequence < madrid_stop_sequence) |>
    distinct(stop_id, trip_id, service_id, route_id)

  if (nrow(origin_candidates) == 0) {
    message("[renfe] No se han encontrado conexiones directas hacia Madrid")
    return(NULL)
  }

  total_days <- n_distinct(service_dates$service_date)
  trip_service_dates <- origin_candidates |>
    inner_join(service_dates, by = "service_id")

  daily_counts <- trip_service_dates |>
    group_by(stop_id, service_date) |>
    summarise(
      departures_day = n_distinct(trip_id),
      routes_day = n_distinct(route_id),
      .groups = "drop"
    )

  stop_metrics <- daily_counts |>
    mutate(is_weekend = as.POSIXlt(service_date)$wday %in% c(0, 6)) |>
    group_by(stop_id) |>
    summarise(
      renfe_madrid_active_days = n_distinct(service_date),
      renfe_madrid_coverage_pct = 100 * renfe_madrid_active_days / total_days,
      renfe_madrid_departures_total = sum(departures_day, na.rm = TRUE),
      renfe_madrid_departures_avg_day = renfe_madrid_departures_total / total_days,
      renfe_madrid_departures_active_day = mean(departures_day, na.rm = TRUE),
      renfe_madrid_departures_p25 = as.numeric(quantile(departures_day, probs = 0.25, na.rm = TRUE, type = 7)),
      renfe_madrid_weekend_service = any(is_weekend),
      renfe_madrid_routes_count = max(routes_day, na.rm = TRUE),
      .groups = "drop"
    )

  stops_connected <- stops |>
    mutate(
      lat = as.numeric(stop_lat),
      lon = as.numeric(stop_lon)
    ) |>
    inner_join(stop_metrics, by = "stop_id") |>
    filter(!is.na(lat), !is.na(lon), lat > 35, lat < 50, lon > -10, lon < 5) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)

  message("[renfe] Paradas con conexión directa a Madrid: ", nrow(stops_connected))
  list(stops = stops_connected, total_days = total_days)
}

calc_renfe_service <- function(mun_sf, renfe_data) {
  stops_df <- renfe_data$stops

  mun_centroids <- sf::st_centroid(sf::st_geometry(mun_sf))

  if (is.null(stops_df) || nrow(stops_df) == 0) {
    return(data.frame(
      dist_renfe_km = rep(NA_real_, nrow(mun_sf)),
      renfe_salidas_dia = rep(NA_real_, nrow(mun_sf)),
      renfe_tipo_servicio = rep("none", nrow(mun_sf)),
      servicio_renfe_norm = rep(NA_real_, nrow(mun_sf)),
      dist_renfe_madrid_km = rep(NA_real_, nrow(mun_sf)),
      renfe_madrid_active_days = rep(0, nrow(mun_sf)),
      renfe_madrid_coverage_pct = rep(0, nrow(mun_sf)),
      renfe_madrid_departures_total = rep(0, nrow(mun_sf)),
      renfe_madrid_departures_avg_day = rep(0, nrow(mun_sf)),
      renfe_madrid_departures_active_day = rep(0, nrow(mun_sf)),
      renfe_madrid_departures_p25 = rep(0, nrow(mun_sf)),
      renfe_madrid_weekend_service = rep(FALSE, nrow(mun_sf)),
      renfe_madrid_routes_count = rep(0, nrow(mun_sf)),
      renfe_madrid_connection_type = rep("none", nrow(mun_sf)),
      renfe_madrid_service_norm = rep(NA_real_, nrow(mun_sf))
    ))
  }

  message("[renfe] Calculando distancias a ", nrow(stops_df), " paradas conectadas con Madrid...")

  d <- sf::st_distance(mun_centroids, stops_df, by_element = FALSE)
  d_km <- d / 1000

  nearest_idx <- apply(d_km, 1, function(r) which.min(r)[1])
  dist_to_nearest <- sapply(1:nrow(d_km), function(i) d_km[i, nearest_idx[i]])

  result <- data.frame(
    dist_renfe_madrid_km = round(dist_to_nearest, 2),
    stringsAsFactors = FALSE
  )

  copy_cols <- c(
    "renfe_madrid_active_days",
    "renfe_madrid_coverage_pct",
    "renfe_madrid_departures_total",
    "renfe_madrid_departures_avg_day",
    "renfe_madrid_departures_active_day",
    "renfe_madrid_departures_p25",
    "renfe_madrid_weekend_service",
    "renfe_madrid_routes_count"
  )
  for (col_name in copy_cols) {
    result[[col_name]] <- stops_df[[col_name]][nearest_idx]
  }
  result$renfe_madrid_connection_type <- ifelse(result$renfe_madrid_active_days > 0, "direct", "none")

  floor_val <- 0.2

  q95_dist <- quantile(result$dist_renfe_madrid_km, 0.95, na.rm = TRUE)
  q95_avg_departures <- quantile(result$renfe_madrid_departures_avg_day, 0.95, na.rm = TRUE)

  norm_dist <- pmin(pmax(1 - (result$dist_renfe_madrid_km / q95_dist), 0), 1)
  norm_coverage <- pmin(pmax(result$renfe_madrid_coverage_pct / 100, 0), 1)
  norm_frequency <- pmin(pmax(result$renfe_madrid_departures_avg_day / max(q95_avg_departures, 1), 0), 1)
  norm_weekend <- ifelse(result$renfe_madrid_weekend_service, 1, 0)

  raw_score <- 0.4 * norm_coverage + 0.3 * norm_frequency + 0.2 * norm_dist + 0.1 * norm_weekend
  result$renfe_madrid_service_norm <- round(floor_val + (1 - floor_val) * raw_score, 3)
  result$renfe_madrid_service_norm <- pmin(pmax(result$renfe_madrid_service_norm, floor_val), 1)

  # Legacy aliases kept while frontend/docs migrate to Madrid-specific field names.
  result$dist_renfe_km <- result$dist_renfe_madrid_km
  result$renfe_salidas_dia <- round(result$renfe_madrid_departures_avg_day, 2)
  result$renfe_tipo_servicio <- result$renfe_madrid_connection_type
  result$servicio_renfe_norm <- result$renfe_madrid_service_norm

  result
}

message("[renfe] === Inicio proceso Renfe ===")

renfe_data <- download_renfe_data()

renfe_processed <- process_renfe(renfe_data, mun)

if (is.null(renfe_processed)) {
  message("[renfe] Sin datos de Renfe, creando campos vacíos")
  mun$dist_renfe_km <- NA_real_
  mun$renfe_salidas_dia <- NA_real_
  mun$renfe_tipo_servicio <- "none"
  mun$servicio_renfe_norm <- NA_real_
  mun$dist_renfe_madrid_km <- NA_real_
  mun$renfe_madrid_active_days <- 0
  mun$renfe_madrid_coverage_pct <- 0
  mun$renfe_madrid_departures_total <- 0
  mun$renfe_madrid_departures_avg_day <- 0
  mun$renfe_madrid_departures_active_day <- 0
  mun$renfe_madrid_departures_p25 <- 0
  mun$renfe_madrid_weekend_service <- FALSE
  mun$renfe_madrid_routes_count <- 0
  mun$renfe_madrid_connection_type <- "none"
  mun$renfe_madrid_service_norm <- NA_real_
} else {
  message("[renfe] Calculando servicio por municipio...")
  renfe_result <- calc_renfe_service(mun, renfe_processed)
  for (col_name in names(renfe_result)) {
    mun[[col_name]] <- renfe_result[[col_name]]
  }
}

message("[renfe] Distancia media a conexión Madrid: ", round(mean(mun$dist_renfe_madrid_km, na.rm = TRUE), 1), " km")
message("[renfe] Salidas medias/día a Madrid: ", round(mean(mun$renfe_madrid_departures_avg_day, na.rm = TRUE), 2))
message("[renfe] Score medio conexión Madrid: ", round(mean(mun$renfe_madrid_service_norm, na.rm = TRUE), 3))

feature_renfe <- mun |>
  st_drop_geometry() |>
  transmute(
    codigo,
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
    renfe_madrid_connection_type,
    renfe_madrid_service_norm
  )
saveRDS(feature_renfe, paths$output_feature_transport_renfe_rds)
try(write_parquet(feature_renfe, paths$output_feature_transport_renfe_parquet), silent = TRUE)

sf::st_write(mun, output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("[renfe] OK: servicio Renfe integrado")

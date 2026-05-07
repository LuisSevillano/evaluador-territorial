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
  gtfs_cercanias_file <- path(intermediate_dir, "renfe_cercanias.zip")
  gtfs_cercanias_dir <- path(intermediate_dir, "renfe_cercanias")
  gtfs_md_file <- path(intermediate_dir, "renfe_md.zip")
  gtfs_md_dir <- path(intermediate_dir, "renfe_md")
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
  
  if (!file.exists(gtfs_cercanias_file)) {
    message("[renfe] Descargando GTFS cercanias...")
    gtfs_url <- "https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip"
    tryCatch({
      download.file(gtfs_url, gtfs_cercanias_file, quiet = TRUE, method = "curl")
      message("[renfe] GTFS cercanias guardado: ", gtfs_cercanias_file)
    }, error = function(e) {
      message("[renfe] Error descargando GTFS cercanias: ", e$message)
    })
  }

  if (!file.exists(gtfs_md_file)) {
    message("[renfe] Descargando GTFS media/larga distancia...")
    gtfs_md_url <- "https://ssl.renfe.com/gtransit/Fichero_AV_LD/google_transit.zip"
    tryCatch({
      download.file(gtfs_md_url, gtfs_md_file, quiet = TRUE, method = "curl")
      message("[renfe] GTFS media/larga guardado: ", gtfs_md_file)
    }, error = function(e) {
      message("[renfe] Error descargando GTFS media/larga: ", e$message)
    })
  }
  
  gtfs_file_exists <- function(gtfs_dir, filename) {
    length(list.files(gtfs_dir, pattern = paste0("^", filename, "$"), recursive = TRUE, full.names = TRUE)) > 0
  }

  ensure_extracted <- function(zip_file, dir_path, label) {
    complete <- dir.exists(dir_path) && all(vapply(required_gtfs_files, function(f) gtfs_file_exists(dir_path, f), logical(1)))
    if (file.exists(zip_file) && !complete) {
      if (dir.exists(dir_path)) {
        message("[renfe] GTFS ", label, " incompleto; reextrayendo ZIP...")
        unlink(dir_path, recursive = TRUE, force = TRUE)
      } else {
        message("[renfe] Extrayendo GTFS ", label, "...")
      }
      dir_create(dir_path)
      unzip(zip_file, exdir = dir_path)
    }
  }

  ensure_extracted(gtfs_cercanias_file, gtfs_cercanias_dir, "cercanias")
  ensure_extracted(gtfs_md_file, gtfs_md_dir, "media/larga")
  
  list(
    estaciones = est_file,
    gtfs_dirs = list(cercanias = gtfs_cercanias_dir, md = gtfs_md_dir)
  )
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

process_single_gtfs <- function(gtfs_dir, label) {
  if (!dir.exists(gtfs_dir)) {
    message("[renfe] GTFS ", label, " no disponible")
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
    message("[renfe] GTFS ", label, " incompleto: faltan stops/trips/stop_times")
    return(NULL)
  }

  stops <- read.csv(stops_file, stringsAsFactors = FALSE)
  trips <- read.csv(trips_file, stringsAsFactors = FALSE)
  stop_times <- read.csv(stop_times_file, stringsAsFactors = FALSE)
  service_dates <- expand_gtfs_service_dates(gtfs_dir)

  if (nrow(service_dates) == 0) {
    message("[renfe] GTFS ", label, " sin calendario activo")
    return(NULL)
  }

  required_stops <- c("stop_id", "stop_name", "stop_lat", "stop_lon")
  if (!all(required_stops %in% names(stops)) || !all(c("trip_id", "service_id", "route_id") %in% names(trips)) ||
      !all(c("trip_id", "stop_id", "stop_sequence") %in% names(stop_times))) {
    message("[renfe] GTFS ", label, " sin columnas obligatorias")
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

  message("[renfe] [", label, "] Paradas destino Madrid detectadas: ", length(madrid_stop_ids))
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
    message("[renfe] [", label, "] No se han encontrado conexiones directas hacia Madrid")
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
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
    mutate(feed_type = label)

  message("[renfe] [", label, "] Paradas con conexión directa a Madrid: ", nrow(stops_connected))
  list(stops = stops_connected, total_days = total_days)
}

process_renfe <- function(data, mun_sf) {
  gtfs_dirs <- data$gtfs_dirs
  parts <- list()
  for (nm in names(gtfs_dirs)) {
    p <- process_single_gtfs(gtfs_dirs[[nm]], nm)
    if (!is.null(p)) parts[[nm]] <- p
  }
  if (length(parts) == 0) return(NULL)

  merged_stops <- bind_rows(lapply(parts, function(x) x$stops))
  merged_stops <- merged_stops |>
    mutate(.key = toupper(trimws(stop_name))) |>
    group_by(.key) |>
    summarise(
      stop_id = dplyr::first(stop_id),
      stop_name = dplyr::first(stop_name),
      renfe_madrid_active_days = max(renfe_madrid_active_days, na.rm = TRUE),
      renfe_madrid_coverage_pct = max(renfe_madrid_coverage_pct, na.rm = TRUE),
      renfe_madrid_departures_total = max(renfe_madrid_departures_total, na.rm = TRUE),
      renfe_madrid_departures_avg_day = max(renfe_madrid_departures_avg_day, na.rm = TRUE),
      renfe_madrid_departures_active_day = max(renfe_madrid_departures_active_day, na.rm = TRUE),
      renfe_madrid_departures_p25 = max(renfe_madrid_departures_p25, na.rm = TRUE),
      renfe_madrid_weekend_service = any(renfe_madrid_weekend_service),
      renfe_madrid_routes_count = max(renfe_madrid_routes_count, na.rm = TRUE),
      geometry = dplyr::first(geometry),
      .groups = "drop"
    ) |>
    st_as_sf(crs = 4326)

  message("[renfe] Paradas con conexión directa a Madrid (fusionadas): ", nrow(merged_stops))
  list(stops = merged_stops)
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
      renfe_madrid_stop_id = rep(NA_character_, nrow(mun_sf)),
      renfe_madrid_stop_name = rep(NA_character_, nrow(mun_sf)),
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
  result$renfe_madrid_stop_id <- stops_df$stop_id[nearest_idx]
  result$renfe_madrid_stop_name <- stops_df$stop_name[nearest_idx]
  result$renfe_madrid_stop_municipality <- stops_df$stop_municipality[nearest_idx]
  result$renfe_madrid_stop_province <- stops_df$stop_province[nearest_idx]

  intersects_list <- sf::st_intersects(sf::st_geometry(mun_sf), sf::st_geometry(stops_df))
  result$has_direct_madrid_service <- lengths(intersects_list) > 0
  result$nearest_station_distance_km <- result$dist_renfe_madrid_km
  result$has_nearby_station <- is.finite(result$nearest_station_distance_km) & result$nearest_station_distance_km <= 15

  result$transport_status <- dplyr::case_when(
    result$has_direct_madrid_service ~ "direct_madrid",
    result$has_nearby_station ~ "station_nearby",
    TRUE ~ "no_station"
  )

  result$transport_confidence <- dplyr::case_when(
    result$transport_status == "direct_madrid" ~ "high",
    result$transport_status == "station_nearby" ~ "medium",
    TRUE ~ "low"
  )

  result$renfe_madrid_connection_type <- ifelse(result$has_direct_madrid_service, "direct", "none")

  floor_val <- 0.2

  q95_avg_departures <- quantile(result$renfe_madrid_departures_avg_day, 0.95, na.rm = TRUE)

  norm_dist <- case_when(
    !is.finite(result$dist_renfe_madrid_km) ~ 0,
    result$dist_renfe_madrid_km <= 15 ~ 1,
    result$dist_renfe_madrid_km <= 40 ~ 0.7,
    result$dist_renfe_madrid_km <= 80 ~ 0.35,
    TRUE ~ 0.1
  )
  norm_coverage <- pmin(pmax(result$renfe_madrid_coverage_pct / 100, 0), 1)
  norm_frequency <- pmin(pmax(result$renfe_madrid_departures_avg_day / max(q95_avg_departures, 1), 0), 1)
  norm_weekend <- ifelse(result$renfe_madrid_weekend_service, 1, 0)

  raw_score <- 0.45 * norm_dist + 0.25 * norm_coverage + 0.2 * norm_frequency + 0.1 * norm_weekend
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
  mun$renfe_madrid_stop_id <- NA_character_
  mun$renfe_madrid_stop_name <- NA_character_
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
    renfe_madrid_stop_id,
    renfe_madrid_stop_name,
    renfe_madrid_stop_municipality,
    renfe_madrid_stop_province,
    renfe_madrid_connection_type,
    renfe_madrid_service_norm,
    has_direct_madrid_service,
    has_nearby_station,
    nearest_station_distance_km,
    transport_confidence,
    transport_status
  )
saveRDS(feature_renfe, paths$output_feature_transport_renfe_rds)
try(write_parquet(feature_renfe, paths$output_feature_transport_renfe_parquet), silent = TRUE)

sf::st_write(mun, output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("[renfe] OK: servicio Renfe integrado")

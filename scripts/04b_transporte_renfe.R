#!/usr/bin/env Rscript
library(fs)
library(jsonlite)
library(sf)
library(dplyr)

project_root <- path_abs(".")
output_final_geojson <- path(project_root, "output", "municipios_final.geojson")
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
  
  if (file.exists(gtfs_file) && !dir.exists(gtfs_dir)) {
    message("[renfe] Extrayendo GTFS...")
    unzip(gtfs_file, exdir = gtfs_dir)
  }
  
  list(estaciones = est_file, gtfs_dir = gtfs_dir)
}

process_renfe <- function(data, mun_sf) {
  est_file <- data$estaciones
  gtfs_dir <- data$gtfs_dir
  
  est_renfe <- tryCatch({
    read.csv(est_file, stringsAsFactors = FALSE, sep = ";", fileEncoding = "latin1")
  }, error = function(e) {
    message("[renfe] Error leyendo estaciones: ", e$message)
    return(NULL)
  })
  
  if (is.null(est_renfe)) {
    return(NULL)
  }
  
  names(est_renfe) <- toupper(names(est_renfe))
  
  if (!all(c("LATITUD", "LONGITUD") %in% names(est_renfe))) {
    message("[renfe] Columnas necesarias no encontradas: ", paste(names(est_renfe), collapse = ", "))
    return(NULL)
  }
  
  est_renfe <- est_renfe |>
    filter(!is.na(LATITUD), !is.na(LONGITUD), LATITUD != 0, LONGITUD != 0) |>
    mutate(
      lat = as.numeric(gsub(",", ".", LATITUD)),
      lon = as.numeric(gsub(",", ".", LONGITUD))
    ) |>
    filter(lat > 35, lat < 50, lon > -10, lon < 5) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
  
  message("[renfe] Estaciones Renfe válidas: ", nrow(est_renfe))
  
  stops_df <- NULL
  if (dir.exists(gtfs_dir)) {
    stops_file <- path(gtfs_dir, "stops.txt")
    trips_file <- path(gtfs_dir, "trips.txt")
    stop_times_file <- path(gtfs_dir, "stop_times.txt")
    
    if (file.exists(stops_file) && file.exists(trips_file) && file.exists(stop_times_file)) {
      message("[renfe] Procesando GTFS...")
      
      stops <- read.csv(stops_file, stringsAsFactors = FALSE)
      trips <- read.csv(trips_file, stringsAsFactors = FALSE)
      stop_times <- read.csv(stop_times_file, stringsAsFactors = FALSE)
      
      stop_trips <- stop_times |>
        inner_join(trips |> select(trip_id, route_id), by = "trip_id") |>
        group_by(stop_id) |>
        summarise(salidas_dia = n(), .groups = "drop")
      
      stops_with_service <- stops |>
        inner_join(stop_trips, by = "stop_id") |>
        mutate(
          lat = as.numeric(stop_lat),
          lon = as.numeric(stop_lon)
        ) |>
        filter(!is.na(lat), !is.na(lon)) |>
        sf::st_as_sf(coords = c("lon", "lat"), crs = 4326)
      
      stops_df <- stops_with_service
      message("[renfe] Paradas con servicio GTFS: ", nrow(stops_df))
    }
  }
  
  list(estaciones = est_renfe, stops = stops_df)
}

calc_renfe_service <- function(mun_sf, renfe_data) {
  est_renfe <- renfe_data$estaciones
  stops_df <- renfe_data$stops
  
  mun_centroids <- sf::st_centroid(sf::st_geometry(mun_sf))
  
  all_pts <- est_renfe
  stops_count <- 0
  
  if (!is.null(stops_df) && nrow(stops_df) > 0) {
    stops_count <- nrow(stops_df)
    est_renfe$source_type <- "estacion"
    stops_df$source_type <- "cercanias"
    all_pts <- rbind(
      stops_df |> select(source_type, geometry),
      est_renfe |> select(source_type, geometry)
    )
  }
  
  if (nrow(all_pts) == 0) {
    return(data.frame(
      dist_renfe_km = rep(NA_real_, nrow(mun_sf)),
      renfe_salidas_dia = rep(NA_real_, nrow(mun_sf)),
      renfe_tipo_servicio = rep("none", nrow(mun_sf)),
      servicio_renfe_norm = rep(NA_real_, nrow(mun_sf))
    ))
  }
  
  message("[renfe] Calculando distancias a ", nrow(all_pts), " puntos...")
  
  d <- sf::st_distance(mun_centroids, all_pts, by_element = FALSE)
  d_km <- d / 1000
  
  nearest_idx <- apply(d_km, 1, function(r) which.min(r)[1])
  dist_to_nearest <- sapply(1:nrow(d_km), function(i) d_km[i, nearest_idx[i]])
  
  result <- data.frame(
    dist_renfe_km = round(dist_to_nearest, 2),
    stringsAsFactors = FALSE
  )
  
  source_types <- all_pts$source_type
  result$renfe_tipo_servicio <- sapply(nearest_idx, function(idx) {
    ifelse(is.na(source_types[idx]), "none", source_types[idx])
  })
  
  if (stops_count > 0 && "salidas_dia" %in% names(stops_df)) {
    stops_with_idx <- stops_df |> mutate(stop_idx = 1:n())
    result$renfe_salidas_dia <- sapply(nearest_idx, function(idx) {
      if (idx <= stops_count) {
        stops_with_idx$salidas_dia[idx]
      } else {
        0
      }
    })
  } else {
    result$renfe_salidas_dia <- ifelse(result$renfe_tipo_servicio == "cercanias", 50, 0)
  }
  
  floor_val <- 0.2
  
  q95_dist <- quantile(result$dist_renfe_km, 0.95, na.rm = TRUE)
  q95_salidas <- quantile(result$renfe_salidas_dia, 0.95, na.rm = TRUE)
  
  tipo_score <- ifelse(result$renfe_tipo_servicio == "cercanias", 1.0,
                ifelse(result$renfe_tipo_servicio == "estacion", 0.5, 0.0))
  
  norm_dist <- pmin(pmax(1 - (result$dist_renfe_km / q95_dist), 0), 1)
  norm_salidas <- pmin(pmax(result$renfe_salidas_dia / max(q95_salidas, 1), 0), 1)
  
  raw_score <- 0.4 * norm_dist + 0.4 * norm_salidas + 0.2 * tipo_score
  
  result$servicio_renfe_norm <- round(floor_val + (1 - floor_val) * raw_score, 4)
  result$servicio_renfe_norm <- pmin(pmax(result$servicio_renfe_norm, floor_val), 1)
  
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
} else {
  message("[renfe] Calculando servicio por municipio...")
  renfe_result <- calc_renfe_service(mun, renfe_processed)
  
  mun$dist_renfe_km <- renfe_result$dist_renfe_km
  mun$renfe_salidas_dia <- renfe_result$renfe_salidas_dia
  mun$renfe_tipo_servicio <- renfe_result$renfe_tipo_servicio
  mun$servicio_renfe_norm <- renfe_result$servicio_renfe_norm
}

message("[renfe] Distancia media: ", round(mean(mun$dist_renfe_km, na.rm = TRUE), 1), " km")
message("[renfe] Score medio: ", round(mean(mun$servicio_renfe_norm, na.rm = TRUE), 3))

sf::st_write(mun, output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("[renfe] OK: servicio Renfe integrado")
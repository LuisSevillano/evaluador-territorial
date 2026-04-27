#!/usr/bin/env Rscript
library(fs)
library(jsonlite)
library(sf, lib.loc = .libPaths()[1])

project_root <- path_abs(".")
output_final_geojson <- path(project_root, "output", "municipios_final.geojson")

sf::sf_use_s2(FALSE)

if (!file.exists(output_final_geojson)) {
  stop("No existe municipios_final.geojson")
}

mun <- sf::st_read(output_final_geojson, quiet = TRUE)

download_osm <- function(query_base, cache_file, max_age_days = 30) {
  if (file.exists(cache_file)) {
    age_days <- as.numeric(difftime(Sys.time(), file.mtime(cache_file), units = "days"))
    if (age_days < max_age_days) {
      message("[transporte] Usando cache: ", cache_file)
      return(sf::st_read(cache_file, quiet = TRUE))
    }
  }

  message("[transporte] Descargando Overpass...")
  mun_proj <- sf::st_transform(sf::st_buffer(sf::st_make_valid(sf::st_geometry(mun)), 0), 4326)
  bb <- sf::st_bbox(mun_proj)
  bbox_str <- sprintf("%f,%f,%f,%f", bb[2], bb[1], bb[4], bb[3])
  message("[transporte] Bbox: ", bbox_str)
  query_full <- sub("BOUNDS", bbox_str, query_base, fixed = TRUE)
  message("[transporte] Query: ", substr(query_full, 1, 100))

  tmp <- tempfile(fileext = ".json")
  on.exit(if (file.exists(tmp)) file.remove(tmp), add = TRUE)
  
  query_encoded <- gsub("\\[", "%5B", gsub("\\]", "%5D", URLencode(query_full)))
  overpass_url <- paste0("https://overpass-api.de/api/interpreter?data=", query_encoded)
  message("[transporte] URL: ", substr(overpass_url, 1, 120))
  
  tryCatch({
    download.file(overpass_url, tmp, quiet = TRUE, method = "curl")
  }, error = function(e) {
    message("[transporte] download.file error: ", e$message)
  })
  
  if (!file.exists(tmp) || file.size(tmp) == 0) {
    message("[transporte] Fallo descarga")
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }

  raw <- tryCatch(readLines(tmp, warn = FALSE), error = function(e) NULL)
  message("[transporte] Raw lines: ", length(raw))
  if (is.null(raw) || length(raw) < 10) {
    message("[transporte] Raw vacío o muy corto")
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }

  raw_str <- paste(raw, collapse = "")
  message("[transporte] Primeros 200 chars: ", substr(raw_str, 1, 200))
  
  if (grepl("^<\\?xml", raw_str)) {
    message("[transporte] Respuesta es XML, buscando elementos...")
    lat_matches <- gregexpr('lat="([^"]+)"', raw_str, perl = TRUE)
    lon_matches <- gregexpr('lon="([^"]+)"', raw_str, perl = TRUE)
    
    lats <- as.numeric(regmatches(raw_str, lat_matches)[[1]])
    lons <- as.numeric(regmatches(raw_str, lon_matches)[[1]])
    
    message("[transporte] Encontrados: lat=", length(lats), " lon=", length(lons))
    
    if (length(lats) > 0 && length(lons) > 0 && length(lats) == length(lons)) {
      coords <- data.frame(lon = lons, lat = lats, stringsAsFactors = FALSE)
      sf_pts <- sf::st_as_sf(coords, coords = c("lon", "lat"), crs = 4326)
      dir_create(dirname(cache_file))
      sf::st_write(sf_pts, cache_file, delete_dsn = TRUE, quiet = TRUE)
      message("[transporte] Guardado (XML): ", cache_file, " (", nrow(sf_pts), " nodos)")
      return(sf_pts)
    }
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }

  parsed <- tryCatch(fromJSON(raw_str, simplifyDataFrame = FALSE), error = function(e) {
    message("[transporte] Error parseJSON: ", e$message)
    NULL
  })
  if (is.null(parsed) || is.null(parsed$elements) || length(parsed$elements) == 0) {
    message("[transporte] No elements en respuesta JSON")
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }
  message("[transporte] Elements: ", length(parsed$elements))
  
  els <- parsed$elements
  nodes <- lapply(els, function(el) {
    if (!identical(el$type, "node")) return(NULL)
    if (!is.numeric(el$lat) || !is.numeric(el$lon)) return(NULL)
    data.frame(lon = el$lon, lat = el$lat, stringsAsFactors = FALSE)
  })
  nodes <- do.call(rbind, nodes)
  if (is.null(nodes) || nrow(nodes) == 0) {
    return(sf::st_sf(geometry = sf::st_sfc(crs = 4326)))
  }

  sf_pts <- sf::st_as_sf(nodes, coords = c("lon", "lat"), crs = 4326)
  dir_create(dirname(cache_file))
  sf::st_write(sf_pts, cache_file, delete_dsn = TRUE, quiet = TRUE)
  message("[transporte] Guardado: ", cache_file, " (", nrow(sf_pts), " nodos)")
  sf_pts
}

query_train <- '[out:json][timeout:60];node[railway=station](BOUNDS);out body;'
query_bus <- '[out:json][timeout:60];node[highway=bus_stop][network~".*"](BOUNDS);out body;'

train_pts <- download_osm(query_train, path(project_root, "data", "intermediate", "osm_train_stations.geojson"))
bus_pts <- download_osm(query_bus, path(project_root, "data", "intermediate", "osm_bus_stops.geojson"))

calc_dist <- function(mun_sf, pts_sf) {
  if (!inherits(pts_sf, "sf") || nrow(pts_sf) == 0 || sf::st_is_empty(pts_sf)) {
    return(rep(NA_real_, nrow(mun_sf)))
  }
  suppressWarnings(suppressMessages(sf::st_crs(pts_sf) <- 4326))
  suppressWarnings(suppressMessages(sf::st_crs(mun_sf) <- 4326))
  centroids <- sf::st_centroid(sf::st_make_valid(sf::st_geometry(mun_sf)))
  d <- sf::st_distance(centroids, pts_sf, by_element = FALSE)
  apply(d, 1, function(r) if (all(is.na(r))) NA_real_ else min(r, na.rm = TRUE)) / 1000
}

message("[transporte] Calculando distancias...")
dist_train <- calc_dist(mun, train_pts)
dist_bus <- calc_dist(mun, bus_pts)

message("[transporte] Tren: ", round(mean(dist_train, na.rm = TRUE), 1), " km media")
message("[transporte] Bus: ", round(mean(dist_bus, na.rm = TRUE), 1), " km media")

floor_val <- 0.2
q95_train <- quantile(dist_train, 0.95, na.rm = TRUE)
q95_bus <- quantile(dist_bus, 0.95, na.rm = TRUE)

norm_train <- round(floor_val + (1 - floor_val) * (dist_train / q95_train), 4)
norm_bus <- round(floor_val + (1 - floor_val) * (dist_bus / q95_bus), 4)
norm_train <- pmin(pmax(norm_train, floor_val), 1)
norm_bus <- pmin(pmax(norm_bus, floor_val), 1)

mun$dist_estacion_tren_km <- round(dist_train, 2)
mun$dist_parada_bus_km <- round(dist_bus, 2)
mun$transporte_norm <- round(pmax(norm_train, norm_bus, na.rm = TRUE), 4)

sf::st_write(mun, output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: transporte integrado")
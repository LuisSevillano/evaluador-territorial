#!/usr/bin/env Rscript
source("scripts/00_config.R")

library(sf)
library(dplyr)
library(jsonlite)
library(arrow)
library(parallel)

sf_use_s2(FALSE)

otp_endpoint <- Sys.getenv("OTP_ENDPOINT", unset = "http://localhost:8080/otp/gtfs/v1")
otp_scope_province <- Sys.getenv("OTP_SCOPE_PROVINCE", unset = "09")
otp_target_label <- Sys.getenv("OTP_TARGET_LABEL", unset = "Madrid -> municipio")
otp_routes <- as.integer(Sys.getenv("OTP_N_ROUTES", unset = "5"))
otp_sleep <- as.numeric(Sys.getenv("OTP_QUERY_SLEEP_SECONDS", unset = "0"))
otp_search_window <- Sys.getenv("OTP_SEARCH_WINDOW", unset = "PT24H")
otp_nearest_stop_radius_m <- as.integer(Sys.getenv("OTP_NEAREST_STOP_RADIUS_M", unset = "15000"))
otp_nearest_stop_candidates <- as.integer(Sys.getenv("OTP_NEAREST_STOP_CANDIDATES", unset = "10"))
otp_only_municipios <- trimws(strsplit(Sys.getenv("OTP_ONLY_MUNICIPIOS", unset = ""), ",", fixed = TRUE)[[1]])
otp_only_municipios <- otp_only_municipios[nzchar(otp_only_municipios)]
otp_output_rds <- Sys.getenv("OTP_OUTPUT_RDS", unset = paths$output_feature_otp_transit_rds)
otp_output_parquet <- Sys.getenv("OTP_OUTPUT_PARQUET", unset = paths$output_feature_otp_transit_parquet)
otp_parallel_workers <- as.integer(Sys.getenv("OTP_PARALLEL_WORKERS", unset = "6"))

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson")
}

madrid_targets <- data.frame(
  label = c("Madrid Avenida de America", "Madrid Moncloa", "Madrid Estacion Sur", "Madrid Chamartin"),
  lat = c(40.4380, 40.4352, 40.3950, 40.4721),
  lon = c(-3.6768, -3.7191, -3.6781, -3.6824),
  stringsAsFactors = FALSE
)

query <- '#graphql
query PlanTransitRoute(
  $fromLat: CoordinateValue!,
  $fromLon: CoordinateValue!,
  $toLat: CoordinateValue!,
  $toLon: CoordinateValue!,
  $time: OffsetDateTime!,
  $searchWindow: Duration!,
  $nRoutes: Int!
) {
  planConnection(
    origin: { location: { coordinate: { latitude: $fromLat, longitude: $fromLon } } }
    destination: { location: { coordinate: { latitude: $toLat, longitude: $toLon } } }
    first: $nRoutes
    searchWindow: $searchWindow
    dateTime: { earliestDeparture: $time }
    modes: {
      direct: [WALK]
      transit: { transit: [{ mode: BUS }, { mode: RAIL }, { mode: TRAM }, { mode: SUBWAY }] }
    }
  ) {
    edges {
      node {
        start
        end
        legs {
          mode
          from { name lat lon }
          to { name lat lon }
          route { gtfsId longName shortName }
        }
      }
    }
  }
}'

stop_query <- '#graphql
query PlanTransitRouteFromStop(
  $fromLat: CoordinateValue!,
  $fromLon: CoordinateValue!,
  $destinationStopId: String!,
  $time: OffsetDateTime!,
  $searchWindow: Duration!,
  $nRoutes: Int!
) {
  planConnection(
    origin: { location: { coordinate: { latitude: $fromLat, longitude: $fromLon } } }
    destination: { location: { stopLocation: { stopLocationId: $destinationStopId } } }
    first: $nRoutes
    searchWindow: $searchWindow
    dateTime: { earliestDeparture: $time }
    modes: {
      direct: [WALK]
      transit: { transit: [{ mode: BUS }, { mode: RAIL }, { mode: TRAM }, { mode: SUBWAY }] }
    }
  ) {
    edges {
      node {
        start
        end
        legs {
          mode
          from { name lat lon }
          to { name lat lon }
          route { gtfsId longName shortName }
        }
      }
    }
  }
}'

nearest_stop_query <- '#graphql
query NearestStops(
  $lat: Float!,
  $lon: Float!,
  $radius: Int!,
  $maxResults: Int!
) {
  nearest(
    lat: $lat
    lon: $lon
    maxDistance: $radius
    maxResults: $maxResults
    filterByPlaceTypes: [STOP]
  ) {
    edges {
      node {
        distance
        place {
          ... on Stop { gtfsId name lat lon }
        }
      }
    }
  }
}'

named_stop_query <- '#graphql
query NamedStops($name: String!) {
  stops(name: $name) { gtfsId name lat lon }
}'

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

hhmm <- function(seconds) {
  if (!is.finite(seconds)) return(NA_character_)
  mins <- round(seconds / 60)
  sprintf("%02d:%02d", mins %/% 60, mins %% 60)
}

parse_otp_time <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"))
  normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", x)
  as.POSIXct(normalized, format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC")
}

post_graphql <- function(body) {
  body_file <- tempfile(fileext = ".json")
  response_file <- tempfile(fileext = ".json")
  on.exit(unlink(c(body_file, response_file), force = TRUE), add = TRUE)
  writeLines(toJSON(body, auto_unbox = TRUE, null = "null"), body_file, useBytes = TRUE)

  status <- system2(
    "curl",
    c("-sS", "--fail", "-X", "POST", "-H", shQuote("Content-Type: application/json"), "--data-binary", paste0("@", body_file), otp_endpoint, "-o", response_file),
    stdout = TRUE,
    stderr = TRUE
  )
  exit_code <- attr(status, "status")
  if (!is.null(exit_code) && exit_code != 0) {
    return(list(status = "error", error = paste(status, collapse = " ")))
  }
  if (!file.exists(response_file) || file.size(response_file) == 0) {
    return(list(status = "error", error = "empty_response"))
  }
  parsed <- tryCatch(fromJSON(response_file, simplifyVector = FALSE), error = function(e) list(errors = list(e$message)))
  if (!is.null(parsed$errors)) {
    return(list(status = "error", error = toJSON(parsed$errors, auto_unbox = TRUE)))
  }
  list(status = "ok", parsed = parsed)
}

parse_plan_response <- function(parsed) {
  edges <- parsed$data$planConnection$edges
  if (is.null(edges) || length(edges) == 0) {
    return(list(status = "no_route", error = NA_character_))
  }

  trips <- lapply(edges, function(edge) {
    node <- edge$node
    start <- parse_otp_time(node$start)
    end <- parse_otp_time(node$end)
    seconds <- as.numeric(difftime(end, start, units = "secs"))
    list(seconds = seconds, node = node)
  })
  valid <- vapply(trips, function(x) is.finite(x$seconds), logical(1))
  if (!any(valid)) {
    return(list(status = "error", error = "invalid_trip_times"))
  }
  best <- trips[[which.min(vapply(trips, function(x) ifelse(is.finite(x$seconds), x$seconds, Inf), numeric(1)))]]
  legs <- best$node$legs
  modes <- vapply(legs, function(leg) leg$mode %||% NA_character_, character(1))
  leg_labels <- vapply(legs, function(leg) {
    route <- leg$route
    route_label <- if (!is.null(route$shortName) && !is.na(route$shortName) && route$shortName != "") route$shortName else route$longName
    mode <- leg$mode %||% ""
    from <- leg$from$name %||% ""
    to <- leg$to$name %||% ""
    paste(na.omit(c(mode, route_label, paste0(from, " -> ", to))), collapse = " | ")
  }, character(1))

  list(
    status = "routed",
    seconds = best$seconds,
    minutes = round(best$seconds / 60, 1),
    hhmm = hhmm(best$seconds),
    modes = paste(unique(na.omit(modes)), collapse = ","),
    legs = paste(leg_labels, collapse = " || "),
    error = NA_character_
  )
}

nearest_stops <- function(from_lat, from_lon) {
  body <- list(
    query = nearest_stop_query,
    variables = list(
      lat = from_lat,
      lon = from_lon,
      radius = otp_nearest_stop_radius_m,
      maxResults = otp_nearest_stop_candidates
    )
  )
  response <- post_graphql(body)
  if (!identical(response$status, "ok")) return(list())
  edges <- response$parsed$data$nearest$edges
  if (is.null(edges) || length(edges) == 0) return(list())
  Filter(Negate(is.null), lapply(edges, function(edge) {
    place <- edge$node$place
    if (is.null(place$gtfsId)) return(NULL)
    list(
      id = place$gtfsId,
      name = place$name %||% place$gtfsId,
      lat = place$lat %||% NA_real_,
      lon = place$lon %||% NA_real_,
      distance = edge$node$distance %||% NA_real_
    )
  }))
}

named_stops <- function(origin_name) {
  body <- list(
    query = named_stop_query,
    variables = list(name = origin_name)
  )
  response <- post_graphql(body)
  if (!identical(response$status, "ok")) return(list())
  stops <- response$parsed$data$stops
  if (is.null(stops) || length(stops) == 0) return(list())
  Filter(Negate(is.null), lapply(stops, function(stop) {
    if (is.null(stop$gtfsId)) return(NULL)
    list(
      id = stop$gtfsId,
      name = stop$name %||% stop$gtfsId,
      lat = stop$lat %||% NA_real_,
      lon = stop$lon %||% NA_real_,
      distance = NA_real_
    )
  }))
}

post_otp_to_stop <- function(target, stop_id, query_datetime) {
  body <- list(
    query = stop_query,
    variables = list(
      fromLat = target$lat,
      fromLon = target$lon,
      destinationStopId = stop_id,
      time = query_datetime,
      searchWindow = otp_search_window,
      nRoutes = otp_routes
    )
  )
  response <- post_graphql(body)
  if (!identical(response$status, "ok")) return(response)
  result <- parse_plan_response(response$parsed)
  result$target <- target$label
  result$target_lat <- target$lat
  result$target_lon <- target$lon
  result
}

best_result <- function(results) {
  routed <- Filter(function(x) identical(x$status, "routed") && is.finite(x$seconds), results)
  if (length(routed) > 0) {
    return(routed[[which.min(vapply(routed, function(x) x$seconds, numeric(1)))]])
  }
  results[[1]]
}

find_stop_candidates <- function(from_lat, from_lon, origin_name) {
  named <- named_stops(origin_name)
  if (length(named) > 0) {
    return(head(named, 3))
  }
  nearest <- nearest_stops(from_lat, from_lon)
  seen <- character()
  candidates <- list()
  for (s in nearest) {
    if (s$id %in% seen) next
    seen <- c(seen, s$id)
    candidates[[length(candidates) + 1]] <- s
  }
  head(candidates, 3)
}

post_otp <- function(from_lat, from_lon, stop_candidates, query_datetime) {
  target_list <- split(madrid_targets, seq_len(nrow(madrid_targets)))
  primary_target <- target_list[[1]]

  for (stop in stop_candidates) {
    if (otp_sleep > 0) Sys.sleep(otp_sleep)
    result <- post_otp_to_stop(primary_target, stop$id, query_datetime = query_datetime)
    if (identical(result$status, "routed")) {
      has_distance <- !is.null(stop$distance) && is.finite(stop$distance)
      result$confidence <- if (has_distance) "pilot_nearest_stop" else "pilot"
      result$stop_name <- stop$name
      result$stop_id <- stop$id
      result$stop_distance_m <- stop$distance
      result$stop_lat <- stop$lat
      result$stop_lon <- stop$lon
      result$target <- primary_target$label
      result$target_lat <- primary_target$lat
      result$target_lon <- primary_target$lon
      for (t in target_list[-1]) {
        if (otp_sleep > 0) Sys.sleep(otp_sleep)
        r <- post_otp_to_stop(t, stop$id, query_datetime = query_datetime)
        if (identical(r$status, "routed")) {
          r$confidence <- result$confidence
          r$stop_name <- result$stop_name
          r$stop_id <- result$stop_id
          r$stop_distance_m <- result$stop_distance_m
          r$stop_lat <- result$stop_lat
          r$stop_lon <- result$stop_lon
          r$target <- t$label
          result <- best_result(list(result, r))
        }
      }
      stop_info <- sprintf("Parada: %s", result$stop_name %||% result$stop_id)
      if (is.finite(result$stop_distance_m %||% NA_real_)) {
        stop_info <- sprintf("%s (a %.0f m)", stop_info, result$stop_distance_m)
      }
      result$legs <- paste0(stop_info, " || ", result$legs)
      return(result)
    }
  }

  list(status = "no_route", error = "Ninguna parada GTFS conecta con Madrid")
}

post_otp_all_week <- function(from_lat, from_lon, origin_name) {
  week_start <- Sys.getenv("OTP_WEEK_START", unset = "2026-05-25")
  dates <- as.Date(week_start) + 0:6

  stop_candidates <- find_stop_candidates(from_lat, from_lon, origin_name)
  if (length(stop_candidates) == 0) {
    return(list(status = "no_route", error = "No se encontraron paradas GTFS cercanas a este municipio"))
  }

  for (i in seq_along(dates)) {
    dt <- paste0(format(dates[i], "%Y-%m-%d"), "T00:00:00+02:00")
    result <- post_otp(from_lat, from_lon, stop_candidates, query_datetime = dt)
    if (identical(result$status, "routed")) {
      result$query_day <- format(dates[i], "%Y-%m-%d")
      return(result)
    }
  }
  list(status = "no_route", error = "Sin ruta Madrid -> municipio ningún día de la semana")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)
centroids <- mun |>
  st_transform(3857) |>
  st_point_on_surface() |>
  st_transform(4326)
coords <- st_coordinates(centroids)

scope_prefixes <- trimws(strsplit(otp_scope_province, ",", fixed = TRUE)[[1]])
base <- mun |>
  st_drop_geometry() |>
  transmute(
    codigo,
    nombre,
    provincia,
    otp_madrid_query_scope = ifelse(substr(codigo, 1, 2) %in% scope_prefixes, "in_scope", "out_of_scope")
  )

base$otp_madrid_transit_seconds <- NA_real_
base$otp_madrid_transit_minutes <- NA_real_
base$otp_madrid_transit_hhmm <- NA_character_
base$otp_madrid_transit_legs <- NA_character_
base$otp_madrid_transit_modes <- NA_character_
base$otp_madrid_transit_status <- ifelse(base$otp_madrid_query_scope == "in_scope", "pending", "not_in_scope")
base$otp_madrid_transit_confidence <- ifelse(base$otp_madrid_query_scope == "in_scope", "pilot", "none")
base$otp_madrid_query_datetime <- NA_character_
base$otp_madrid_query_target <- ifelse(base$otp_madrid_query_scope == "in_scope", otp_target_label, NA_character_)
base$otp_madrid_stop_name <- NA_character_
base$otp_madrid_stop_distance_m <- NA_real_
base$otp_madrid_stop_lat <- NA_real_
base$otp_madrid_stop_lon <- NA_real_
base$otp_madrid_origin_lat <- NA_real_
base$otp_madrid_origin_lon <- NA_real_
base$otp_madrid_query_day <- NA_character_

idx <- which(base$otp_madrid_query_scope == "in_scope")
if (length(otp_only_municipios) > 0) {
  idx <- idx[base$codigo[idx] %in% otp_only_municipios | base$nombre[idx] %in% otp_only_municipios]
}
n_total <- length(idx)
if (n_total == 0) {
  message("[otp] No hay municipios en scope para provincia(s): ", otp_scope_province)
  saveRDS(base |> select(codigo, starts_with("otp_madrid")), otp_output_rds)
  try(write_parquet(base |> select(codigo, starts_with("otp_madrid")), otp_output_parquet), silent = TRUE)
  quit(save = "no", status = 0)
}

message(sprintf("[otp] Consultando %d municipios (scope: provincia %s, %d workers paralelos)", n_total, otp_scope_province, otp_parallel_workers))

results <- mclapply(seq_len(n_total), function(n) {
  i <- idx[[n]]
  result <- tryCatch(post_otp_all_week(coords[i, "Y"], coords[i, "X"], base$nombre[[i]]),
    error = function(e) list(status = "error", error = e$message))
  list(
    i = i,
    status = result$status %||% "error",
    seconds = if (identical(result$status, "routed")) result$seconds else NA_real_,
    minutes = if (identical(result$status, "routed")) result$minutes else NA_real_,
    hhmm = if (identical(result$status, "routed")) result$hhmm else NA_character_,
    legs = if (identical(result$status, "routed")) result$legs else result$error %||% NA_character_,
    modes = if (identical(result$status, "routed")) result$modes else NA_character_,
    confidence = if (identical(result$status, "routed")) result$confidence else base$otp_madrid_transit_confidence[[i]],
    target = if (identical(result$status, "routed")) result$target %||% otp_target_label else otp_target_label,
    target_lat = if (identical(result$status, "routed")) result$target_lat %||% NA_real_ else NA_real_,
    target_lon = if (identical(result$status, "routed")) result$target_lon %||% NA_real_ else NA_real_,
    query_day = if (identical(result$status, "routed")) result$query_day %||% NA_character_ else NA_character_,
    stop_name = if (identical(result$status, "routed")) result$stop_name %||% NA_character_ else NA_character_,
    stop_distance_m = if (identical(result$status, "routed")) result$stop_distance_m %||% NA_real_ else NA_real_,
    stop_lat = if (identical(result$status, "routed")) result$stop_lat %||% NA_real_ else NA_real_,
    stop_lon = if (identical(result$status, "routed")) result$stop_lon %||% NA_real_ else NA_real_
  )
}, mc.cores = otp_parallel_workers, mc.preschedule = TRUE)

for (r in results) {
  i <- r$i
  base$otp_madrid_transit_status[[i]] <- r$status
  if (identical(r$status, "routed")) {
    base$otp_madrid_transit_seconds[[i]] <- r$seconds
    base$otp_madrid_transit_minutes[[i]] <- r$minutes
    base$otp_madrid_transit_hhmm[[i]] <- r$hhmm
    base$otp_madrid_transit_legs[[i]] <- r$legs
    base$otp_madrid_transit_modes[[i]] <- r$modes
    base$otp_madrid_transit_confidence[[i]] <- r$confidence
    base$otp_madrid_query_target[[i]] <- r$target
    base$otp_madrid_query_day[[i]] <- r$query_day
    base$otp_madrid_stop_name[[i]] <- r$stop_name
    base$otp_madrid_stop_distance_m[[i]] <- r$stop_distance_m
    base$otp_madrid_stop_lat[[i]] <- r$stop_lat
    base$otp_madrid_stop_lon[[i]] <- r$stop_lon
    base$otp_madrid_origin_lat[[i]] <- r$target_lat
    base$otp_madrid_origin_lon[[i]] <- r$target_lon
  } else {
    base$otp_madrid_transit_legs[[i]] <- r$legs %||% NA_character_
  }
}

routed_count <- sum(base$otp_madrid_transit_status == "routed", na.rm = TRUE)
no_route_count <- sum(base$otp_madrid_transit_status == "no_route", na.rm = TRUE)
error_count <- sum(base$otp_madrid_transit_status == "error", na.rm = TRUE)
message(sprintf("[otp] Resultados: %d routed, %d no_route, %d error (de %d in_scope)", routed_count, no_route_count, error_count, n_total))

feature_otp <- base |>
  select(
    codigo,
    otp_madrid_transit_seconds,
    otp_madrid_transit_minutes,
    otp_madrid_transit_hhmm,
    otp_madrid_transit_legs,
    otp_madrid_transit_modes,
    otp_madrid_transit_status,
    otp_madrid_transit_confidence,
    otp_madrid_query_datetime,
    otp_madrid_query_target,
    otp_madrid_query_scope,
    otp_madrid_query_day,
    otp_madrid_stop_name,
    otp_madrid_stop_distance_m,
    otp_madrid_stop_lat,
    otp_madrid_stop_lon,
    otp_madrid_origin_lat,
    otp_madrid_origin_lon
  )

saveRDS(feature_otp, otp_output_rds)
try(write_parquet(feature_otp, otp_output_parquet), silent = TRUE)
message("[otp] Feature OTP guardada: ", otp_output_rds)

#!/usr/bin/env Rscript

source("scripts/00_config.R")

date_int <- as.integer(Sys.getenv("OTP_PLAYGROUND_DATE", unset = "20260527"))
date_iso <- Sys.getenv("OTP_PLAYGROUND_DATETIME", unset = "2026-05-27T07:00:00+02:00")
endpoint <- Sys.getenv("OTP_ENDPOINT", unset = "http://localhost:8081/otp/gtfs/v1")
alsa_zip <- file.path(project_root, "data", "raw", "otp", "graph", "nap_932_1133_alsa_autobuses.gtfs.zip")

read_gtfs <- function(file) {
  con <- unz(alsa_zip, file)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  read.csv(con, stringsAsFactors = FALSE, colClasses = "character")
}

active_services <- function(cal, cald, date_int) {
  active <- cal$service_id[
    as.integer(cal$start_date) <= date_int &
      as.integer(cal$end_date) >= date_int &
      as.integer(cal$wednesday) == 1
  ]
  adds <- cald$service_id[as.integer(cald$date) == date_int & as.integer(cald$exception_type) == 1]
  removes <- cald$service_id[as.integer(cald$date) == date_int & as.integer(cald$exception_type) == 2]
  setdiff(union(active, adds), removes)
}

direct_trips <- function(stops, trips, routes, stop_times, service_ids, from_pattern, to_pattern) {
  stop_name <- setNames(stops$stop_name, stops$stop_id)
  route_label <- setNames(trimws(paste(routes$route_short_name, routes$route_long_name)), routes$route_id)
  active_trips <- trips[trips$service_id %in% service_ids, , drop = FALSE]
  from_ids <- stops$stop_id[grepl(from_pattern, stops$stop_name, ignore.case = TRUE)]
  to_ids <- stops$stop_id[grepl(to_pattern, stops$stop_name, ignore.case = TRUE)]
  st <- stop_times[stop_times$trip_id %in% active_trips$trip_id, , drop = FALSE]
  a <- st[st$stop_id %in% from_ids, , drop = FALSE]
  b <- st[st$stop_id %in% to_ids, , drop = FALSE]
  rows <- list()
  for (tid in intersect(a$trip_id, b$trip_id)) {
    aa <- a[a$trip_id == tid, , drop = FALSE][1, ]
    bb <- b[b$trip_id == tid & as.integer(b$stop_sequence) > as.integer(aa$stop_sequence), , drop = FALSE]
    if (nrow(bb)) {
      trip <- active_trips[active_trips$trip_id == tid, , drop = FALSE][1, ]
      rows[[length(rows) + 1]] <- data.frame(
        trip_id = tid,
        service_id = trip$service_id,
        route = route_label[[trip$route_id]],
        dep = aa$departure_time,
        arr = bb$arrival_time[1],
        from = stop_name[[aa$stop_id]],
        to = stop_name[[bb$stop_id[1]]],
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  out[order(out$dep), ]
}

all_burgos_medina_trips <- function(stops, trips, routes, stop_times, cal, cald) {
  stop_name <- setNames(stops$stop_name, stops$stop_id)
  route_label <- setNames(trimws(paste(routes$route_short_name, routes$route_long_name)), routes$route_id)
  from_ids <- stops$stop_id[grepl("^Burgos$|Estación de Autobuses de Burgos", stops$stop_name, ignore.case = TRUE)]
  to_ids <- stops$stop_id[grepl("Medina De Pomar", stops$stop_name, ignore.case = TRUE)]
  a <- stop_times[stop_times$stop_id %in% from_ids, , drop = FALSE]
  b <- stop_times[stop_times$stop_id %in% to_ids, , drop = FALSE]
  rows <- list()
  for (tid in intersect(a$trip_id, b$trip_id)) {
    aa <- a[a$trip_id == tid, , drop = FALSE][1, ]
    bb <- b[b$trip_id == tid & as.integer(b$stop_sequence) > as.integer(aa$stop_sequence), , drop = FALSE]
    if (nrow(bb)) {
      trip <- trips[trips$trip_id == tid, , drop = FALSE][1, ]
      svc <- cal[cal$service_id == trip$service_id, , drop = FALSE]
      rows[[length(rows) + 1]] <- data.frame(
        trip_id = tid,
        service_id = trip$service_id,
        route = route_label[[trip$route_id]],
        dep = aa$departure_time,
        arr = bb$arrival_time[1],
        wednesday = if (nrow(svc)) svc$wednesday else NA_character_,
        start_date = if (nrow(svc)) svc$start_date else NA_character_,
        end_date = if (nrow(svc)) svc$end_date else NA_character_,
        active_on_date = trip$service_id %in% active_services(cal, cald, date_int),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  out[order(out$dep), ]
}

post_otp_medina <- function() {
  query <- '#graphql
query Plan($time: OffsetDateTime!) {
  planConnection(
    origin: { location: { coordinate: { latitude: 40.4380, longitude: -3.6768 } } }
    destination: { location: { stopLocation: { stopLocationId: "3:0000717100000001" } } }
    first: 10
    searchWindow: "PT12H"
    dateTime: { earliestDeparture: $time }
    modes: { direct: [WALK], transit: { transit: [{ mode: BUS }, { mode: RAIL }, { mode: TRAM }, { mode: SUBWAY }] } }
  ) {
    edges { node { start end legs { mode from { name } to { name } route { shortName longName } } } }
  }
}'
  body <- jsonlite::toJSON(list(query = query, variables = list(time = date_iso)), auto_unbox = TRUE)
  body_file <- tempfile(fileext = ".json")
  response_file <- tempfile(fileext = ".json")
  on.exit(unlink(c(body_file, response_file), force = TRUE), add = TRUE)
  writeLines(body, body_file, useBytes = TRUE)
  status <- system2("curl", c("-sS", "--fail", "-X", "POST", "-H", shQuote("Content-Type: application/json"), "--data-binary", paste0("@", body_file), endpoint, "-o", response_file), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status"))) return(list(error = paste(status, collapse = " ")))
  jsonlite::fromJSON(response_file, simplifyVector = FALSE)
}

stops <- read_gtfs("stops.txt")
trips <- read_gtfs("trips.txt")
routes <- read_gtfs("routes.txt")
stop_times <- read_gtfs("stop_times.txt")
cal <- read_gtfs("calendar.txt")
cald <- read_gtfs("calendar_dates.txt")
services <- active_services(cal, cald, date_int)

cat("\n=== OTP Madrid Avenida America -> Medina De Pomar ===\n")
otp <- post_otp_medina()
if (!is.null(otp$error)) {
  cat("OTP error:", otp$error, "\n")
} else {
  edges <- otp$data$planConnection$edges
  if (!length(edges)) {
    cat("OTP: no_route\n")
  } else {
    for (i in seq_along(edges)) {
      node <- edges[[i]]$node
      cat("\nItinerary", i, node$start, "->", node$end, "\n")
      for (leg in node$legs) {
        route <- leg$route
        route_label <- if (is.null(route)) "" else paste(route$shortName %||% "", route$longName %||% "")
        cat(" -", leg$mode, route_label, ":", leg$from$name, "->", leg$to$name, "\n")
      }
    }
  }
}

cat("\n=== GTFS activo Madrid -> Burgos ===\n")
print(direct_trips(stops, trips, routes, stop_times, services, "Madrid.*Av.America|Madrid Moncloa|Madrid Estacion Sur", "^Burgos$|Estación de Autobuses de Burgos"), row.names = FALSE)

cat("\n=== GTFS activo Burgos -> Medina De Pomar ===\n")
print(direct_trips(stops, trips, routes, stop_times, services, "^Burgos$|Estación de Autobuses de Burgos", "Medina De Pomar"), row.names = FALSE)

cat("\n=== Todos los Burgos -> Medina De Pomar en el feed ALSA ===\n")
print(all_burgos_medina_trips(stops, trips, routes, stop_times, cal, cald), row.names = FALSE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

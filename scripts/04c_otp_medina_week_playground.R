#!/usr/bin/env Rscript

source("scripts/00_config.R")

endpoint <- Sys.getenv("OTP_ENDPOINT", unset = "http://localhost:8081/otp/gtfs/v1")
dates <- as.Date(Sys.getenv("OTP_WEEK_START", unset = "2026-05-25")) + 0:6
times <- paste0(format(dates, "%Y-%m-%d"), "T07:00:00+02:00")

query <- '#graphql
query Plan($time: OffsetDateTime!) {
  planConnection(
    origin: { location: { coordinate: { latitude: 40.4380, longitude: -3.6768 } } }
    destination: { location: { stopLocation: { stopLocationId: "3:0000717100000001" } } }
    first: 20
    searchWindow: "PT16H"
    dateTime: { earliestDeparture: $time }
    modes: { direct: [WALK], transit: { transit: [{ mode: BUS }, { mode: RAIL }, { mode: TRAM }, { mode: SUBWAY }] } }
  ) {
    edges { node { start end legs { mode from { name } to { name } route { shortName longName } } } }
  }
}'

parse_otp_time <- function(x) {
  as.POSIXct(sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", x), format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC")
}

post <- function(time) {
  body_file <- tempfile(fileext = ".json")
  response_file <- tempfile(fileext = ".json")
  on.exit(unlink(c(body_file, response_file), force = TRUE), add = TRUE)
  writeLines(jsonlite::toJSON(list(query = query, variables = list(time = time)), auto_unbox = TRUE), body_file, useBytes = TRUE)
  status <- system2("curl", c("-sS", "--fail", "-X", "POST", "-H", shQuote("Content-Type: application/json"), "--data-binary", paste0("@", body_file), endpoint, "-o", response_file), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status"))) return(list(status = "curl_error", error = paste(status, collapse = " ")))
  parsed <- jsonlite::fromJSON(response_file, simplifyVector = FALSE)
  if (!is.null(parsed$errors)) return(list(status = "graphql_error", error = jsonlite::toJSON(parsed$errors, auto_unbox = TRUE)))
  edges <- parsed$data$planConnection$edges
  if (!length(edges)) return(list(status = "no_route"))
  trips <- lapply(edges, function(edge) {
    node <- edge$node
    seconds <- as.numeric(difftime(parse_otp_time(node$end), parse_otp_time(node$start), units = "secs"))
    list(seconds = seconds, node = node)
  })
  valid <- Filter(function(x) is.finite(x$seconds), trips)
  if (!length(valid)) return(list(status = "invalid"))
  best <- valid[[which.min(vapply(valid, function(x) x$seconds, numeric(1)))]]
  legs <- paste(vapply(best$node$legs, function(leg) {
    route <- leg$route
    route_label <- if (is.null(route)) "" else trimws(paste(route$shortName %||% "", route$longName %||% ""))
    paste(na.omit(c(leg$mode, route_label, paste0(leg$from$name, " -> ", leg$to$name))), collapse = " | ")
  }, character(1)), collapse = " || ")
  list(
    status = "routed",
    start = best$node$start,
    end = best$node$end,
    minutes = round(best$seconds / 60, 1),
    legs = legs
  )
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

rows <- lapply(seq_along(times), function(i) {
  result <- post(times[[i]])
  data.frame(
    date = as.character(dates[[i]]),
    weekday = weekdays(dates[[i]]),
    status = result$status,
    start = result$start %||% NA_character_,
    end = result$end %||% NA_character_,
    minutes = result$minutes %||% NA_real_,
    legs = result$legs %||% result$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, rows)
print(out[, c("date", "weekday", "status", "start", "end", "minutes")], row.names = FALSE)

routed <- out[out$status == "routed" & is.finite(out$minutes), , drop = FALSE]
if (nrow(routed)) {
  best <- routed[which.min(routed$minutes), , drop = FALSE]
  cat("\n=== Mejor ruta semanal ===\n")
  print(best[, c("date", "weekday", "start", "end", "minutes")], row.names = FALSE)
  cat(best$legs, "\n")
}

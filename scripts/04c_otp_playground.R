#!/usr/bin/env Rscript

source("scripts/00_config.R")

municipios <- Sys.getenv(
  "OTP_PLAYGROUND_MUNICIPIOS",
  unset = "Aranda de Duero,Burgos,Lerma,Medina de Pomar"
)

playground_rds <- file.path(paths$output_dir, "features", "feature_otp_transit_playground.rds")
playground_parquet <- file.path(paths$output_dir, "features", "feature_otp_transit_playground.parquet")

Sys.setenv(
  OTP_ONLY_MUNICIPIOS = municipios,
  OTP_OUTPUT_RDS = playground_rds,
  OTP_OUTPUT_PARQUET = playground_parquet,
  OTP_QUERY_SLEEP_SECONDS = Sys.getenv("OTP_QUERY_SLEEP_SECONDS", unset = "0")
)

source("scripts/04c_otp_transit_madrid.R", local = new.env(parent = globalenv()))

feature <- readRDS(playground_rds)
selected <- trimws(strsplit(municipios, ",", fixed = TRUE)[[1]])

mun <- sf::st_read(paths$output_final_geojson, quiet = TRUE)
labels <- sf::st_drop_geometry(mun)[, c("codigo", "nombre")]
out <- merge(labels, feature, by = "codigo")
out <- out[out$nombre %in% selected, c(
  "codigo",
  "nombre",
  "otp_madrid_transit_status",
  "otp_madrid_transit_confidence",
  "otp_madrid_transit_minutes",
  "otp_madrid_transit_hhmm",
  "otp_madrid_query_day",
  "otp_madrid_stop_name",
  "otp_madrid_stop_distance_m",
  "otp_madrid_query_target",
  "otp_madrid_transit_legs"
)]

print(out, row.names = FALSE)

source("scripts/00_config.R")

library(sf)
library(dplyr)
library(readr)

sf_use_s2(FALSE)

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe dataset post-isocronas. Ejecuta primero scripts/03_isochrones.R")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)

checks <- tibble(
  check_name = c(
    "rows_total",
    "invalid_geometry",
    "duplicated_codigo",
    "na_precip_annual_mm",
    "na_temp_winter_mean_c",
    "na_temp_summer_mean_c",
    "negative_precip",
    "absurd_temp_low",
    "absurd_temp_high",
    "invalid_travel_bucket"
  ),
  value = c(
    nrow(mun),
    sum(!st_is_valid(mun)),
    sum(duplicated(mun$codigo)),
    sum(is.na(mun$precip_annual_mm)),
    sum(is.na(mun$temp_winter_mean_c)),
    sum(is.na(mun$temp_summer_mean_c)),
    sum(mun$precip_annual_mm < 0, na.rm = TRUE),
    sum(mun$temp_winter_mean_c < -30, na.rm = TRUE),
    sum(mun$temp_summer_mean_c > 50, na.rm = TRUE),
    sum(!mun$travel_bucket %in% c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00"))
  )
)

write_csv(checks, paths$output_quality_report_csv)

message("OK: quality checks guardados en ", paths$output_quality_report_csv)
print(checks)

# --- Gate: los problemas de INTEGRIDAD detienen el pipeline (no solo se informan) ---
# Los recuentos de NA se informan como aviso pero no bloquean (puede faltar dato
# legítimamente); las violaciones de integridad nunca deberían ocurrir.
fatal_checks <- c(
  "invalid_geometry",
  "duplicated_codigo",
  "negative_precip",
  "absurd_temp_low",
  "absurd_temp_high",
  "invalid_travel_bucket"
)
rows_total <- checks$value[checks$check_name == "rows_total"]
violations <- dplyr::filter(checks, check_name %in% fatal_checks & value > 0)

na_warnings <- dplyr::filter(checks, grepl("^na_", check_name) & value > 0)
if (nrow(na_warnings) > 0) {
  message(
    "AVISO (no bloqueante) valores ausentes: ",
    paste(sprintf("%s=%d", na_warnings$check_name, na_warnings$value), collapse = ", ")
  )
}

if (rows_total == 0 || nrow(violations) > 0) {
  if (nrow(violations) > 0) print(violations)
  stop(
    "Control de calidad FALLIDO. ",
    if (rows_total == 0) "El dataset no tiene filas. " else "",
    if (nrow(violations) > 0)
      paste0(
        "Violaciones de integridad: ",
        paste(sprintf("%s=%d", violations$check_name, violations$value), collapse = ", ")
      )
    else ""
  )
}

message("OK: control de calidad superado (sin violaciones de integridad).")

source("scripts/00_config.R")

library(readr)
library(dplyr)
library(jsonlite)

municipios <- read_csv(paths$raw_csv, show_col_types = FALSE) |>
  mutate(
    clima_resumen = case_when(
      score_demo >= 80 ~ "Perfil climatico favorable en este ejemplo.",
      score_demo >= 75 ~ "Perfil climatico intermedio favorable.",
      TRUE ~ "Perfil climatico a revisar en siguientes iteraciones."
    ),
    accesibilidad_resumen = case_when(
      poblacion > 100000 ~ "Alta accesibilidad por servicios y red principal.",
      poblacion > 40000 ~ "Accesibilidad media con servicios urbanos.",
      TRUE ~ "Accesibilidad comarcal, requiere validacion de detalle."
    ),
    entorno_resumen = "Resumen preliminar con datos sinteticos de fase 0."
  ) |>
  transmute(
    id,
    nombre,
    provincia,
    poblacion,
    lat,
    lon,
    score_demo,
    clima_resumen,
    accesibilidad_resumen,
    entorno_resumen
  )

json_text <- toJSON(municipios, auto_unbox = TRUE, pretty = TRUE)
write_file(json_text, paths$output_json)
write_file(json_text, paths$frontend_json)

message("OK: dataset JSON generado en data/output/json y frontend/static/data")

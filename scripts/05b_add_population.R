# 05b_add_population.R — Añadir poblacion del INE al dataset
source("scripts/00_config.R")

library(sf)
library(dplyr)
library(mapSpain)

message("Descargando poblacion municipal del INE (2025)...")

pob <- pobmun25
names(pob)

pob_df <- pob |>
  mutate(
    ine_prov = sprintf("%02d", as.integer(cpro)),
    ine_mun = sprintf("%03d", as.integer(cmun)),
    codigo_ine = paste0(ine_prov, ine_mun)
  ) |>
  select(
    codigo_ine,
    population = pob25,
    population_men = men,
    population_women = women
  )

message(paste("Obtenidos", nrow(pob_df), "municipios con poblacion"))

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe dataset final. Ejecuta primero scripts/04_quality_checks.R")
}

mun <- st_read(paths$output_final_geojson, quiet = TRUE)

mun$codigo_ine <- mun$codigo

mun_pob <- mun |>
  left_join(pob_df, by = "codigo_ine") |>
  mutate(
    population = ifelse(is.na(population), NA_integer_, population),
    population_men = ifelse(is.na(population_men), NA_integer_, population_men),
    population_women = ifelse(is.na(population_women), NA_integer_, population_women)
  )

sin_pob <- mun_pob |> filter(is.na(population)) |> nrow()
message(paste("Municipios sin poblacion:", sin_pob))

st_write(mun_pob, paths$output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: Dataset actualizado con poblacion")
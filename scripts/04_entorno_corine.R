source("scripts/00_config.R")

library(sf)
library(dplyr)
library(fs)

if (!file.exists(paths$output_clima_geojson)) {
  stop("No existe municipios_clima.geojson. Ejecuta primero scripts/02_clima_real.R")
}

write_empty_geojson <- function(path_out) {
  empty <- st_sf(geometry = st_sfc(crs = 4326))
  st_write(empty, path_out, delete_dsn = TRUE, quiet = TRUE)
}

corine_env <- Sys.getenv("CORINE_GEOJSON", unset = "")
corine_path <- if (nzchar(corine_env)) corine_env else paths$corine_geojson

municipios <- st_read(paths$output_clima_geojson, quiet = TRUE)

if (!file.exists(corine_path)) {
  message("Aviso: CORINE no disponible en ", corine_path, ". Se crean indicadores neutrales.")

  municipios <- municipios |>
    mutate(
      forest_pct = NA_real_,
      artificial_pct = NA_real_,
      water_pct = NA_real_,
      naturality_index = NA_real_,
      landcover_diversity = NA_real_
    )

  st_write(municipios, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)

  write_empty_geojson(paths$output_forest_geojson)
  write_empty_geojson(paths$output_landuse_geojson)
  write_empty_geojson(paths$output_vegetation_geojson)

  file_copy(paths$output_entorno_geojson, paths$output_clima_geojson, overwrite = TRUE)
  file_copy(paths$output_forest_geojson, paths$frontend_forest_geojson, overwrite = TRUE)
  file_copy(paths$output_landuse_geojson, paths$frontend_landuse_geojson, overwrite = TRUE)
  file_copy(paths$output_vegetation_geojson, paths$frontend_vegetation_geojson, overwrite = TRUE)
  message("OK: entorno fallback generado sin CORINE")
} else {
  message("Cargando CORINE desde ", corine_path)
  corine <- st_read(corine_path, quiet = TRUE)

  code_col_candidates <- c("code_18", "CODE_18", "clc_code", "CLC_CODE", "code", "CODE")
  code_col <- code_col_candidates[code_col_candidates %in% names(corine)][1]
  if (is.na(code_col)) {
    stop("No se encuentra columna de clase CORINE en: ", paste(names(corine), collapse = ", "))
  }

  corine <- corine |>
    mutate(corine_code = suppressWarnings(as.integer(gsub("[^0-9]", "", as.character(.data[[code_col]]))))) |>
    filter(!is.na(corine_code))

  mun_aea <- municipios |>
    st_make_valid() |>
    st_transform(3035) |>
    mutate(mun_id = codigo)

  corine_aea <- corine |>
    st_make_valid() |>
    st_transform(3035)

  inter <- st_intersection(
    mun_aea |> select(mun_id),
    corine_aea |> select(corine_code)
  )

  if (nrow(inter) == 0) {
    stop("No hay interseccion entre municipios y CORINE. Revisa CRS o cobertura geografica")
  }

  inter <- inter |>
    mutate(area_m2 = as.numeric(st_area(geometry)))

  by_muni <- inter |>
    st_drop_geometry() |>
    group_by(mun_id) |>
    mutate(total_area = sum(area_m2, na.rm = TRUE), share = ifelse(total_area > 0, area_m2 / total_area, 0)) |>
    mutate(
      is_artificial = corine_code >= 100 & corine_code < 200,
      is_forest = corine_code >= 311 & corine_code <= 324,
      is_water = corine_code >= 500 & corine_code < 600,
      is_wetland = corine_code >= 400 & corine_code < 500
    )

  diversity <- by_muni |>
    group_by(mun_id, corine_code) |>
    summarise(code_share = sum(share, na.rm = TRUE), .groups = "drop_last") |>
    summarise(
      shannon = -sum(ifelse(code_share > 0, code_share * log(code_share), 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(landcover_diversity = pmin(100, pmax(0, 100 * shannon / log(44))))

  summary_tbl <- by_muni |>
    summarise(
      forest_pct = 100 * sum(share[is_forest], na.rm = TRUE),
      artificial_pct = 100 * sum(share[is_artificial], na.rm = TRUE),
      water_pct = 100 * sum(share[is_water], na.rm = TRUE),
      wetland_pct = 100 * sum(share[is_wetland], na.rm = TRUE),
      .by = mun_id
    ) |>
    left_join(diversity, by = "mun_id") |>
    mutate(
      naturality_index = pmin(
        100,
        pmax(0, forest_pct + 0.8 * water_pct + 0.6 * wetland_pct - 0.7 * artificial_pct)
      )
    )

  municipios <- municipios |>
    left_join(summary_tbl, by = c("codigo" = "mun_id"))

  st_write(municipios, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)
  file_copy(paths$output_entorno_geojson, paths$output_clima_geojson, overwrite = TRUE)

  forest_layer <- corine |>
    filter(corine_code >= 311, corine_code <= 324)
  landuse_layer <- corine |>
    filter(corine_code < 300)
  vegetation_layer <- corine |>
    filter(corine_code >= 300, corine_code < 500)

  st_write(forest_layer, paths$output_forest_geojson, delete_dsn = TRUE, quiet = TRUE)
  st_write(landuse_layer, paths$output_landuse_geojson, delete_dsn = TRUE, quiet = TRUE)
  st_write(vegetation_layer, paths$output_vegetation_geojson, delete_dsn = TRUE, quiet = TRUE)

  file_copy(paths$output_forest_geojson, paths$frontend_forest_geojson, overwrite = TRUE)
  file_copy(paths$output_landuse_geojson, paths$frontend_landuse_geojson, overwrite = TRUE)
  file_copy(paths$output_vegetation_geojson, paths$frontend_vegetation_geojson, overwrite = TRUE)

  message("OK: indicadores de entorno y capas CORINE exportados")
}

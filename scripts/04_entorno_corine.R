source("scripts/00_config.R")

library(sf)
library(dplyr)
library(fs)

sf_use_s2(FALSE)

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
  message("Aviso: CORINE no disponible en ", corine_path, ". Se intenta fallback con OSM Geofabrik.")

  osm_zip <- Sys.getenv("OSM_SHP_ZIP", unset = path(project_root, "data", "raw", "osm", "castilla-y-leon-latest-free.shp.zip"))
  osm_extract_dir <- path(project_root, "data", "raw", "osm", "castilla-y-leon-shp")

  if (!file.exists(osm_zip)) {
    message("No existe ZIP OSM en ", osm_zip, ". Generando indicadores neutrales.")
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
    message("OK: entorno fallback neutral generado")
  } else {
    dir_create(osm_extract_dir, recurse = TRUE)
    zip_listing <- utils::unzip(osm_zip, list = TRUE)$Name
    required <- c(
      "gis_osm_landuse_a_free_1",
      "gis_osm_natural_a_free_1",
      "gis_osm_water_a_free_1"
    )
    required_files <- unlist(lapply(required, function(base) {
      exts <- c(".shp", ".dbf", ".shx", ".prj", ".cpg")
      paste0(base, exts)
    }))
    files_to_extract <- zip_listing[zip_listing %in% required_files]
    if (length(files_to_extract) > 0) utils::unzip(osm_zip, files = files_to_extract, exdir = osm_extract_dir, overwrite = TRUE)

    landuse_path <- path(osm_extract_dir, "gis_osm_landuse_a_free_1.shp")
    natural_path <- path(osm_extract_dir, "gis_osm_natural_a_free_1.shp")
    water_path <- path(osm_extract_dir, "gis_osm_water_a_free_1.shp")

    if (!file.exists(landuse_path) || !file.exists(water_path)) {
      stop("Fallback OSM incompleto. No se encontraron shapefiles necesarios en ", osm_extract_dir)
    }

    landuse <- st_read(landuse_path, quiet = TRUE)
    natural <- if (file.exists(natural_path)) st_read(natural_path, quiet = TRUE) else st_sf(fclass = character(), geometry = st_sfc(crs = 4326))
    water <- st_read(water_path, quiet = TRUE)

    mun_aea <- municipios |>
      st_make_valid() |>
      st_transform(3035) |>
      mutate(mun_id = codigo, mun_area_m2 = as.numeric(st_area(geometry)))

    to_aea <- function(x) x |> st_make_valid() |> st_transform(3035)
    landuse_aea <- to_aea(landuse)
    natural_aea <- to_aea(natural)
    water_aea <- to_aea(water)

    forest_landuse <- landuse_aea |> filter(fclass %in% c("forest", "wood"))
    forest_natural <- natural_aea |> filter(fclass %in% c("wood", "scrub", "heath", "grassland"))
    forest_layer <- rbind(
      forest_landuse |> mutate(source_class = fclass),
      forest_natural |> mutate(source_class = fclass)
    )

    artificial_layer <- landuse_aea |> filter(fclass %in% c("residential", "industrial", "commercial", "retail", "construction", "military", "garages", "quarry", "landfill"))
    water_layer <- rbind(
      water_aea |> mutate(source_class = fclass),
      natural_aea |> filter(fclass %in% c("water", "wetland")) |> mutate(source_class = fclass)
    )

    cover_pct <- function(layer, col_name) {
      if (nrow(layer) == 0) return(tibble(mun_id = mun_aea$mun_id, !!col_name := 0))
      inter <- st_intersection(mun_aea |> select(mun_id, mun_area_m2), layer |> select(geometry))
      if (nrow(inter) == 0) return(tibble(mun_id = mun_aea$mun_id, !!col_name := 0))
      inter |>
        mutate(area_m2 = as.numeric(st_area(geometry))) |>
        st_drop_geometry() |>
        summarise(value = 100 * sum(area_m2, na.rm = TRUE) / first(mun_area_m2), .by = mun_id) |>
        transmute(mun_id, !!col_name := pmin(100, pmax(0, value)))
    }

    forest_pct_tbl <- cover_pct(forest_layer, "forest_pct")
    artificial_pct_tbl <- cover_pct(artificial_layer, "artificial_pct")
    water_pct_tbl <- cover_pct(water_layer, "water_pct")

    diversity_tbl <- {
      if (nrow(landuse_aea) == 0) {
        tibble(mun_id = mun_aea$mun_id, landcover_diversity = 0)
      } else {
        inter_lu <- st_intersection(mun_aea |> select(mun_id, mun_area_m2), landuse_aea |> select(fclass)) |>
          mutate(area_m2 = as.numeric(st_area(geometry))) |>
          st_drop_geometry()

        if (nrow(inter_lu) == 0) {
          tibble(mun_id = mun_aea$mun_id, landcover_diversity = 0)
        } else {
          inter_lu |>
            summarise(area_m2 = sum(area_m2, na.rm = TRUE), .by = c(mun_id, fclass, mun_area_m2)) |>
            mutate(share = pmax(0, pmin(1, area_m2 / mun_area_m2))) |>
            summarise(
              shannon = -sum(ifelse(share > 0, share * log(share), 0), na.rm = TRUE),
              .by = mun_id
            ) |>
            mutate(landcover_diversity = pmin(100, pmax(0, 100 * shannon / log(15)))) |>
            select(mun_id, landcover_diversity)
        }
      }
    }

    summary_tbl <- mun_aea |>
      st_drop_geometry() |>
      select(mun_id) |>
      left_join(forest_pct_tbl, by = "mun_id") |>
      left_join(artificial_pct_tbl, by = "mun_id") |>
      left_join(water_pct_tbl, by = "mun_id") |>
      left_join(diversity_tbl, by = "mun_id") |>
      mutate(
        forest_pct = coalesce(forest_pct, 0),
        artificial_pct = coalesce(artificial_pct, 0),
        water_pct = coalesce(water_pct, 0),
        landcover_diversity = coalesce(landcover_diversity, 0),
        naturality_index = pmin(100, pmax(0, forest_pct + 0.8 * water_pct - 0.7 * artificial_pct))
      )

    municipios <- municipios |>
      left_join(summary_tbl, by = c("codigo" = "mun_id"))

    st_write(municipios, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)
    file_copy(paths$output_entorno_geojson, paths$output_clima_geojson, overwrite = TRUE)

    landuse_layer <- landuse_aea
    vegetation_layer <- natural_aea |> filter(!fclass %in% c("water", "wetland"))

    st_write(st_transform(forest_layer, 4326), paths$output_forest_geojson, delete_dsn = TRUE, quiet = TRUE)
    st_write(st_transform(landuse_layer, 4326), paths$output_landuse_geojson, delete_dsn = TRUE, quiet = TRUE)
    st_write(st_transform(vegetation_layer, 4326), paths$output_vegetation_geojson, delete_dsn = TRUE, quiet = TRUE)

    file_copy(paths$output_forest_geojson, paths$frontend_forest_geojson, overwrite = TRUE)
    file_copy(paths$output_landuse_geojson, paths$frontend_landuse_geojson, overwrite = TRUE)
    file_copy(paths$output_vegetation_geojson, paths$frontend_vegetation_geojson, overwrite = TRUE)
    message("OK: entorno fallback OSM generado")
  }
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

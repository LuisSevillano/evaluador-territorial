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

municipios <- st_read(paths$output_clima_geojson, quiet = TRUE)
message("Entorno natural: fuente OSM Geofabrik")

osm_raw_dir <- path(project_root, "data", "raw", "osm")
osm_extract_root <- path(osm_raw_dir, "extract")
dir_create(osm_raw_dir, recurse = TRUE)
dir_create(osm_extract_root, recurse = TRUE)

default_osm_urls <- switch(
  analysis_scope,
  "norte" = c(
    "https://download.geofabrik.de/europe/spain/castilla-y-leon-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/la-rioja-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/pais-vasco-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/asturias-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/cantabria-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/galicia-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/castilla-la-mancha-latest-free.shp.zip",
    "https://download.geofabrik.de/europe/spain/madrid-latest-free.shp.zip"
  ),
  "cyl" = c("https://download.geofabrik.de/europe/spain/castilla-y-leon-latest-free.shp.zip"),
  "castilla_y_leon" = c("https://download.geofabrik.de/europe/spain/castilla-y-leon-latest-free.shp.zip"),
  "avila" = c("https://download.geofabrik.de/europe/spain/castilla-y-leon-latest-free.shp.zip"),
  "espana" = c("https://download.geofabrik.de/europe/spain-latest-free.shp.zip"),
  c("https://download.geofabrik.de/europe/spain/castilla-y-leon-latest-free.shp.zip")
)

urls_env <- trimws(Sys.getenv("OSM_SHP_URLS", unset = ""))
osm_urls <- if (nzchar(urls_env)) {
  unlist(strsplit(urls_env, ",", fixed = TRUE)) |> trimws()
} else {
  default_osm_urls
}
osm_urls <- unique(osm_urls[nzchar(osm_urls)])

download_if_missing <- function(url) {
  dest <- path(osm_raw_dir, path_file(url))
  if (file.exists(dest)) {
    message("[OSM] ZIP ya existe: ", dest)
    return(dest)
  }
  message("[OSM] Descargando: ", url)
  utils::download.file(url, destfile = dest, mode = "wb", quiet = FALSE)
  dest
}

extract_required_layers <- function(zip_path) {
  region_name <- gsub("-latest-free\\.shp\\.zip$", "", path_file(zip_path))
  region_dir <- path(osm_extract_root, region_name)
  dir_create(region_dir, recurse = TRUE)

  listing <- utils::unzip(zip_path, list = TRUE)$Name
  required <- c("gis_osm_landuse_a_free_1", "gis_osm_natural_a_free_1", "gis_osm_water_a_free_1")
  required_files <- unlist(lapply(required, function(base) paste0(base, c(".shp", ".dbf", ".shx", ".prj", ".cpg"))))

  has_required <- any(grepl("gis_osm_landuse_a_free_1\\.shp$", list.files(region_dir, recursive = TRUE)))
  if (!has_required) {
    files_to_extract <- listing[basename(listing) %in% required_files]
    if (length(files_to_extract) > 0) {
      utils::unzip(zip_path, files = files_to_extract, exdir = region_dir, overwrite = TRUE)
    }
  }

  pick_shp <- function(name) {
    candidates <- list.files(region_dir, pattern = paste0("^", name, "\\.shp$"), recursive = TRUE, full.names = TRUE)
    if (length(candidates) == 0) return(NA_character_)
    candidates[1]
  }

  list(
    landuse = pick_shp("gis_osm_landuse_a_free_1"),
    natural = pick_shp("gis_osm_natural_a_free_1"),
    water = pick_shp("gis_osm_water_a_free_1")
  )
}

read_optional_sf <- function(path_value) {
  if (!is.character(path_value) || is.na(path_value) || !file.exists(path_value)) return(NULL)
  st_read(path_value, quiet = TRUE)
}

combine_sf <- function(items) {
  valid_items <- items[!vapply(items, is.null, logical(1))]
  if (length(valid_items) == 0) return(NULL)
  if (length(valid_items) == 1) return(valid_items[[1]])
  do.call(rbind, valid_items)
}

zip_paths <- lapply(osm_urls, function(url) {
  tryCatch(download_if_missing(url), error = function(e) {
    message("[OSM] Error descargando ", url, ": ", e$message)
    NULL
  })
}) |> unlist(use.names = FALSE)

if (length(zip_paths) == 0) {
  stop("No se pudo descargar ningun ZIP OSM para calcular entorno")
}

extracted <- lapply(zip_paths, extract_required_layers)
landuse <- combine_sf(lapply(extracted, function(x) read_optional_sf(x$landuse)))
natural <- combine_sf(lapply(extracted, function(x) read_optional_sf(x$natural)))
water <- combine_sf(lapply(extracted, function(x) read_optional_sf(x$water)))

if (is.null(landuse) || is.null(water)) {
  stop("OSM incompleto: faltan capas landuse/water para entorno")
}
if (is.null(natural)) {
  natural <- st_sf(fclass = character(), geometry = st_sfc(crs = 4326))
}

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
forest_layer <- rbind(forest_landuse |> mutate(source_class = fclass), forest_natural |> mutate(source_class = fclass))

artificial_layer <- landuse_aea |> filter(fclass %in% c("residential", "industrial", "commercial", "retail", "construction", "military", "garages", "quarry", "landfill"))
water_layer <- rbind(water_aea |> mutate(source_class = fclass), natural_aea |> filter(fclass %in% c("water", "wetland")) |> mutate(source_class = fclass))

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
        summarise(shannon = -sum(ifelse(share > 0, share * log(share), 0), na.rm = TRUE), .by = mun_id) |>
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
    naturality_index = pmin(100, pmax(0, forest_pct + 0.8 * water_pct - 0.7 * artificial_pct)),
    forest_nature_quality = pmin(1, pmax(0, forest_pct / 100))
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

saveRDS(
  summary_tbl |>
    transmute(codigo = mun_id, forest_nature_quality, water_pct),
  paths$output_feature_mfe_rds
)
try(arrow::write_parquet(readRDS(paths$output_feature_mfe_rds), paths$output_feature_mfe_parquet), silent = TRUE)

message("OK: indicadores de entorno OSM generados")

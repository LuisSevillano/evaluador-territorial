source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(stringr)
  library(fs)
  library(arrow)
  library(jsonlite)
})

sf_use_s2(FALSE)

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [bathing] ", msg)

raw_root <- path(project_root, "data", "raw", "bathing_areas")
chd_dir <- path(raw_root, "chd")
mapa_dir <- path(raw_root, "mapa")
nayade_dir <- path(raw_root, "nayade")

dir_create(chd_dir, recurse = TRUE)
dir_create(mapa_dir, recurse = TRUE)
dir_create(nayade_dir, recurse = TRUE)

download_if_missing <- function(url, dest) {
  if (file_exists(dest) && file_info(dest)$size > 0) {
    log_step(paste0("Ya existe: ", path_rel(dest, start = project_root)))
    return(dest)
  }
  log_step(paste0("Descargando: ", url))
  tryCatch({
    utils::download.file(url, destfile = dest, mode = "wb", quiet = FALSE)
    dest
  }, error = function(e) {
    warning("No se pudo descargar ", url, ": ", e$message)
    dest
  })
}

chd_recreativas_url <- "https://mirame.chduero.es/geoserver/mirame/wfs?typeName=mirame:Zonas_Recreativas&service=wfs&version=1.1.0&request=GetFeature&outputFormat=shape-zip&srsName=EPSG:25830&format_options=CHARSET:UTF-8"
chd_influencia_url <- "https://mirame.chduero.es/geoserver/mirame/wfs?typeName=mirame:Zonas_Influencia_Zonas_Recreativas&service=wfs&version=1.1.0&request=GetFeature&outputFormat=shape-zip&srsName=EPSG:25830&format_options=CHARSET:UTF-8"
mapa_zip_url <- "https://www.mapama.gob.es/app/descargas/descargafichero.aspx?f=censoaguasbano_2025.zip"
nayade_url <- "https://nayadeciudadano.sanidad.gob.es/Splayas/ciudadano/ciudadanoZonaAction.do"

chd_recreativas_zip <- path(chd_dir, "zonas_recreativas.zip")
chd_influencia_zip <- path(chd_dir, "zonas_influencia_recreativas.zip")
mapa_zip_candidates <- c(
  path(raw_root, "censoaguasbano_2025.zip"),
  path(mapa_dir, "censoaguasbano_2025.zip")
)
mapa_zip <- mapa_zip_candidates[file_exists(mapa_zip_candidates)][1]
if (is.na(mapa_zip) || !nzchar(mapa_zip)) {
  mapa_zip <- path(mapa_dir, "censoaguasbano_2025.zip")
}
nayade_html <- path(nayade_dir, "ciudadanoZonaAction.html")
nayade_output_dir <- path(project_root, "output", "nayade")

download_if_missing(chd_recreativas_url, chd_recreativas_zip)
download_if_missing(chd_influencia_url, chd_influencia_zip)
if (!file_exists(mapa_zip) || file_info(mapa_zip)$size <= 0) {
  download_if_missing(mapa_zip_url, path(mapa_dir, "censoaguasbano_2025.zip"))
  mapa_zip <- path(mapa_dir, "censoaguasbano_2025.zip")
}
download_if_missing(nayade_url, nayade_html)

extract_zip <- function(zip_path, out_dir) {
  dir_create(out_dir, recurse = TRUE)
  if (!file_exists(zip_path) || file_info(zip_path)$size <= 0) return(out_dir)
  tryCatch({
    utils::unzip(zip_path, exdir = out_dir, overwrite = TRUE)
    out_dir
  }, error = function(e) {
    warning("No se pudo descomprimir ", zip_path, ": ", e$message)
    out_dir
  })
}

extract_zip(chd_recreativas_zip, path(chd_dir, "zonas_recreativas"))
extract_zip(chd_influencia_zip, path(chd_dir, "zonas_influencia_recreativas"))
extract_zip(mapa_zip, path(mapa_dir, "censoaguasbano_2025"))

to_wgs84_point <- function(x) {
  if (nrow(x) == 0) return(st_sfc(crs = 4326))
  x <- st_make_valid(x)
  if (is.na(st_crs(x))) st_crs(x) <- 4326
  x <- st_transform(x, 4326)
  gtype <- as.character(st_geometry_type(x, by_geometry = TRUE))
  pts <- x
  if (any(gtype %in% c("POLYGON", "MULTIPOLYGON"))) {
    pts <- st_point_on_surface(x)
  } else if (any(gtype %in% c("LINESTRING", "MULTILINESTRING"))) {
    pts <- st_line_sample(x, sample = 0.5)
    pts <- st_cast(pts, "POINT")
    pts <- st_set_crs(pts, 4326)
  }
  st_geometry(pts)
}

pick_col <- function(df, candidates) {
  hit <- intersect(candidates, names(df))
  if (length(hit) == 0) return(NULL)
  hit[[1]]
}

normalize_sf <- function(x, source, subsource, confidence = "official") {
  if (is.null(x) || nrow(x) == 0) return(NULL)
  nm <- names(x)
  nm_low <- tolower(nm)
  names(x) <- nm_low

  id_col <- pick_col(x, c("id", "fid", "gid", "codigo", "code", "id_zona", "idzona", "pk"))
  name_col <- pick_col(x, c("nombre", "name", "denominaci", "denominacion", "zona", "title", "nom"))
  ccaa_col <- pick_col(x, c("ccaa", "comunidad", "comunidad_autonoma", "autonomia"))
  prov_col <- pick_col(x, c("provincia", "province", "nom_prov", "prov"))
  mun_col <- pick_col(x, c("municipio", "municipality", "nom_mun", "muni", "term_mun"))

  pt_geom <- to_wgs84_point(x)
  xy <- suppressWarnings(st_coordinates(pt_geom))

  out <- x |>
    st_transform(4326) |>
    mutate(
      source = source,
      subsource = subsource,
      source_record_id = if (!is.null(id_col)) as.character(.data[[id_col]]) else as.character(row_number()),
      name = if (!is.null(name_col)) as.character(.data[[name_col]]) else NA_character_,
      admin_ccaa = if (!is.null(ccaa_col)) as.character(.data[[ccaa_col]]) else NA_character_,
      admin_provincia = if (!is.null(prov_col)) as.character(.data[[prov_col]]) else NA_character_,
      admin_municipio = if (!is.null(mun_col)) as.character(.data[[mun_col]]) else NA_character_,
      geom_type = as.character(st_geometry_type(geometry, by_geometry = TRUE)),
      lon = if (nrow(xy) == n()) as.numeric(xy[, 1]) else NA_real_,
      lat = if (nrow(xy) == n()) as.numeric(xy[, 2]) else NA_real_,
      has_geometry = !st_is_empty(geometry),
      is_centroid_fallback = geom_type != "POINT",
      confidence = confidence,
      downloaded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
    ) |>
    select(
      source,
      subsource,
      source_record_id,
      name,
      admin_ccaa,
      admin_provincia,
      admin_municipio,
      geom_type,
      lon,
      lat,
      has_geometry,
      is_centroid_fallback,
      confidence,
      downloaded_at_utc,
      geometry
    )

  out
}

read_spatial_any <- function(path_item) {
  tryCatch(st_read(path_item, quiet = TRUE), error = function(e) NULL)
}

collect_spatial_from_dir <- function(base_dir, source, subsource, confidence = "official") {
  if (!dir_exists(base_dir)) return(list())
  shp <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.shp$")
  kml <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.kml$")
  gpkg <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.gpkg$")
  geojson <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.(geojson|json)$")
  spatial_files <- unique(c(shp, kml, gpkg, geojson))
  out <- list()
  for (fp in spatial_files) {
    x <- read_spatial_any(fp)
    if (is.null(x) || nrow(x) == 0) next
    out[[length(out) + 1]] <- normalize_sf(x, source, paste0(subsource, ":", path_file(fp)), confidence = confidence)
  }
  out
}

extract_coords_from_table <- function(df) {
  nms <- names(df)
  nms_low <- tolower(nms)
  names(df) <- nms_low
  lon_col <- pick_col(df, c("lon", "lng", "long", "longitude", "x", "coordx"))
  lat_col <- pick_col(df, c("lat", "latitude", "y", "coordy"))
  if (is.null(lon_col) || is.null(lat_col)) return(NULL)
  lon <- suppressWarnings(as.numeric(str_replace_all(as.character(df[[lon_col]]), ",", ".")))
  lat <- suppressWarnings(as.numeric(str_replace_all(as.character(df[[lat_col]]), ",", ".")))
  ok <- is.finite(lon) & is.finite(lat)
  if (!any(ok)) return(NULL)

  id_col <- pick_col(df, c("id", "codigo", "code", "gid", "fid"))
  name_col <- pick_col(df, c("nombre", "name", "denominacion", "zona"))
  ccaa_col <- pick_col(df, c("ccaa", "comunidad", "comunidad_autonoma"))
  prov_col <- pick_col(df, c("provincia", "province"))
  mun_col <- pick_col(df, c("municipio", "municipality"))

  src_value <- if ("source" %in% names(df) && any(!is.na(df$source))) as.character(df$source[[which(!is.na(df$source))[1]]]) else "mapa"
  subsource_value <- if (identical(src_value, "nayade")) "nayade_tabular" else "censoaguasbano_2025_tabular"

  tibble::tibble(
    source = src_value,
    subsource = subsource_value,
    source_record_id = if (!is.null(id_col)) as.character(df[[id_col]]) else as.character(seq_len(nrow(df))),
    name = if (!is.null(name_col)) as.character(df[[name_col]]) else NA_character_,
    admin_ccaa = if (!is.null(ccaa_col)) as.character(df[[ccaa_col]]) else NA_character_,
    admin_provincia = if (!is.null(prov_col)) as.character(df[[prov_col]]) else NA_character_,
    admin_municipio = if (!is.null(mun_col)) as.character(df[[mun_col]]) else NA_character_,
    geom_type = "POINT",
    lon = lon,
    lat = lat,
    has_geometry = ok,
    is_centroid_fallback = FALSE,
    confidence = "official",
    downloaded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ) |>
    filter(is.finite(lon) & is.finite(lat)) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)
}

nayade_tabular_from_output <- function(base_dir) {
  if (!dir_exists(base_dir)) return(list())
  files <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.(csv|json)$")
  out <- list()
  for (fp in files) {
    if (grepl("\\.csv$", fp, ignore.case = TRUE)) {
      df <- tryCatch(read_csv(fp, show_col_types = FALSE), error = function(e) NULL)
    } else {
      parsed <- tryCatch(jsonlite::fromJSON(fp, simplifyDataFrame = TRUE), error = function(e) NULL)
      df <- if (is.data.frame(parsed)) parsed else NULL
    }
    if (is.null(df) || nrow(df) == 0) next
    names(df) <- tolower(names(df))
    if (!"source" %in% names(df)) df$source <- "nayade"
    sfobj <- extract_coords_from_table(df)
    if (!is.null(sfobj) && nrow(sfobj) > 0) out[[length(out) + 1]] <- sfobj
  }
  out
}

mapa_tabular_from_dir <- function(base_dir) {
  if (!dir_exists(base_dir)) return(list())
  csv_files <- dir_ls(base_dir, recurse = TRUE, type = "file", regexp = "\\.(csv|txt)$")
  out <- list()
  for (fp in csv_files) {
    df <- tryCatch(read_delim(fp, delim = ";", show_col_types = FALSE, locale = locale(encoding = "UTF-8")), error = function(e) NULL)
    if (is.null(df)) {
      df <- tryCatch(read_csv(fp, show_col_types = FALSE), error = function(e) NULL)
    }
    if (is.null(df) || nrow(df) == 0) next
    sfobj <- extract_coords_from_table(df)
    if (!is.null(sfobj) && nrow(sfobj) > 0) out[[length(out) + 1]] <- sfobj
  }
  out
}

log_step("Leyendo fuentes espaciales")
all_layers <- list()

all_layers <- c(all_layers, collect_spatial_from_dir(path(chd_dir, "zonas_recreativas"), "chd", "zonas_recreativas", confidence = "official"))
all_layers <- c(all_layers, collect_spatial_from_dir(path(chd_dir, "zonas_influencia_recreativas"), "chd", "zonas_influencia", confidence = "official"))
all_layers <- c(all_layers, collect_spatial_from_dir(path(mapa_dir, "censoaguasbano_2025"), "mapa", "censoaguasbano_2025", confidence = "official"))

local_kml <- path(raw_root, "Zonas de Baño Gratuitas.kml")
if (file_exists(local_kml)) {
  kml_sf <- read_spatial_any(local_kml)
  if (!is.null(kml_sf) && nrow(kml_sf) > 0) {
    all_layers[[length(all_layers) + 1]] <- normalize_sf(kml_sf, "community", "zonas_bano_gratuitas_kml", confidence = "community")
  }
}

all_layers <- c(all_layers, mapa_tabular_from_dir(path(mapa_dir, "censoaguasbano_2025")))
all_layers <- c(all_layers, nayade_tabular_from_output(nayade_output_dir))

if (length(all_layers) == 0) {
  stop("No se pudieron leer fuentes de zonas de bano con geometria/coordenadas.")
}

log_step("Unificando capas")
all_layers <- all_layers[!vapply(all_layers, is.null, logical(1))]
all_layers <- all_layers[vapply(all_layers, nrow, integer(1)) > 0]

unified <- do.call(rbind, all_layers) |>
  st_make_valid() |>
  mutate(
    name_norm = str_squish(str_to_lower(iconv(coalesce(name, ""), to = "ASCII//TRANSLIT"))),
    admin_mun_norm = str_squish(str_to_lower(iconv(coalesce(admin_municipio, ""), to = "ASCII//TRANSLIT"))),
    admin_prov_norm = str_squish(str_to_lower(iconv(coalesce(admin_provincia, ""), to = "ASCII//TRANSLIT")))
  )

priority <- c(mapa = 1L, chd = 2L, nayade = 3L, community = 4L)
unified <- unified |>
  mutate(source_priority = dplyr::coalesce(priority[source], 99L))

if (nrow(unified) > 1) {
  pts <- st_as_sf(unified, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  dm <- units::drop_units(st_distance(st_transform(pts, 25830)))
  n <- nrow(unified)
  duplicate_group_id <- seq_len(n)
  for (i in seq_len(n)) {
    near_idx <- which(dm[i, ] <= 300)
    near_idx <- near_idx[near_idx != i]
    if (length(near_idx) == 0) next
    same_name <- unified$name_norm[near_idx] == unified$name_norm[i] & nzchar(unified$name_norm[i])
    same_admin <- unified$admin_mun_norm[near_idx] == unified$admin_mun_norm[i] |
      unified$admin_prov_norm[near_idx] == unified$admin_prov_norm[i]
    merge_idx <- near_idx[same_name & same_admin]
    if (length(merge_idx) == 0) next
    grp <- min(c(i, merge_idx))
    duplicate_group_id[c(i, merge_idx)] <- pmin(duplicate_group_id[c(i, merge_idx)], grp)
  }
  unified$duplicate_group_id <- duplicate_group_id
} else {
  unified$duplicate_group_id <- 1L
}

mapa_idx <- which(unified$source == "mapa")
nayade_idx <- which(unified$source == "nayade")

if (length(mapa_idx) > 0 && length(nayade_idx) > 0) {
  pts_all <- st_as_sf(unified, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  pts_utm <- st_transform(pts_all, 25830)
  dmn <- units::drop_units(st_distance(pts_utm[nayade_idx, ], pts_utm[mapa_idx, ]))

  has_nayade_match <- rep(FALSE, nrow(unified))
  has_mapa_match <- rep(FALSE, nrow(unified))
  matched_sources <- rep("", nrow(unified))
  nayade_match_ids <- rep(NA_character_, nrow(unified))

  for (ri in seq_along(nayade_idx)) {
    ni <- nayade_idx[ri]
    drow <- dmn[ri, ]
    if (all(!is.finite(drow))) next
    best_j <- which.min(drow)
    if (!is.finite(drow[best_j]) || drow[best_j] > 300) next

    mi <- mapa_idx[best_j]
    has_nayade_match[mi] <- TRUE
    has_mapa_match[ni] <- TRUE
    matched_sources[mi] <- "mapa;nayade"
    matched_sources[ni] <- "mapa;nayade"

    existing <- nayade_match_ids[mi]
    this_id <- as.character(unified$source_record_id[ni])
    nayade_match_ids[mi] <- if (is.na(existing) || !nzchar(existing)) this_id else paste(existing, this_id, sep = ";")

    duplicate_group_id[ni] <- duplicate_group_id[mi]
  }

  unified$duplicate_group_id <- duplicate_group_id
  unified$has_nayade_match <- has_nayade_match
  unified$has_mapa_match <- has_mapa_match
  unified$matched_sources <- matched_sources
  unified$nayade_match_ids <- nayade_match_ids
} else {
  unified$has_nayade_match <- FALSE
  unified$has_mapa_match <- FALSE
  unified$matched_sources <- ""
  unified$nayade_match_ids <- NA_character_
}

unified <- unified |>
  arrange(duplicate_group_id, source_priority) |>
  group_by(duplicate_group_id) |>
  mutate(
    is_primary_record = row_number() == 1,
    source_primary = first(source)
  ) |>
  ungroup()

quality <- unified |>
  st_drop_geometry() |>
  group_by(source, subsource) |>
  summarise(
    rows = n(),
    primary_rows = sum(is_primary_record, na.rm = TRUE),
    with_coordinates = sum(is.finite(lon) & is.finite(lat), na.rm = TRUE),
    pct_with_coordinates = round(100 * with_coordinates / pmax(rows, 1), 2),
    .groups = "drop"
  )

feature_tbl <- unified |>
  st_drop_geometry() |>
  transmute(
    source,
    subsource,
    source_record_id,
    name,
    admin_ccaa,
    admin_provincia,
    admin_municipio,
    lon,
    lat,
    confidence,
    duplicate_group_id,
    is_primary_record
  )

log_step("Escribiendo salidas")
st_write(unified, paths$output_bathing_areas_unified_geojson, delete_dsn = TRUE, quiet = TRUE)
write_csv(st_drop_geometry(unified), paths$output_bathing_areas_unified_csv)
write_parquet(st_drop_geometry(unified), paths$output_bathing_areas_unified_parquet)
write_csv(quality, paths$output_bathing_areas_quality_csv)
saveRDS(feature_tbl, paths$output_feature_bathing_areas_rds)
try(write_parquet(feature_tbl, paths$output_feature_bathing_areas_parquet), silent = TRUE)

log_step(paste0("Registros unificados: ", nrow(unified)))
log_step(paste0("Registros principales: ", sum(unified$is_primary_record, na.rm = TRUE)))
message("OK: zonas de bano unificadas en ", paths$output_bathing_areas_unified_geojson)

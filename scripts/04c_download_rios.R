source("scripts/00_config.R")

library(sf)
library(dplyr)
library(fs)
library(readr)
library(tools)

sf_use_s2(FALSE)
options(timeout = max(600, getOption("timeout")))

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

invisible(dir_create(paths$rivers_raw_dir, recurse = TRUE))
invisible(dir_create(paths$rivers_cache_dir, recurse = TRUE))
invisible(dir_create(path_dir(paths$hydro_sources_csv), recurse = TRUE))

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326)

scope_poly <- mun |>
  st_union() |>
  st_as_sf() |>
  st_set_crs(4326)

scope_bbox <- scope_poly |>
  st_transform(3857) |>
  st_buffer(20000) |>
  st_transform(4326) |>
  st_bbox()
scope_poly_m <- st_transform(scope_poly, 3857)
bbox_geom <- st_as_sfc(scope_bbox)
bbox_wkt <- st_as_text(bbox_geom)

empty_lines <- function() {
  st_sf(geometry = st_sfc(crs = 4326))
}

safe_transform <- function(x, crs = 4326) {
  out <- tryCatch(st_transform(x, crs), error = function(e) x)
  if (is.na(st_crs(out))) st_set_crs(out, crs) else out
}

safe_make_valid <- function(x) {
  tryCatch(st_make_valid(x), error = function(e) x)
}

geometry_is_line <- function(sf_obj) {
  gt <- unique(as.character(st_geometry_type(sf_obj, by_geometry = TRUE)))
  any(gt %in% c("LINESTRING", "MULTILINESTRING", "CURVE", "MULTICURVE", "COMPOUNDCURVE"))
}

normalize_line_geometry <- function(sf_obj) {
  if (nrow(sf_obj) == 0) return(sf_obj)
  out <- sf_obj
  gtype <- unique(as.character(st_geometry_type(out, by_geometry = TRUE)))
  if (any(gtype %in% c("CURVE", "MULTICURVE", "COMPOUNDCURVE"))) {
    out <- tryCatch(st_cast(out, "MULTILINESTRING"), error = function(e) out)
  }
  out
}

read_wfs_filtered <- function(base_url, layer_name, wkt_filter) {
  dsn <- paste0("WFS:", base_url, "?service=WFS&version=2.0.0")
  out <- tryCatch(
    st_read(dsn, layer = layer_name, wkt_filter = wkt_filter, quiet = TRUE),
    error = function(e) NULL
  )
  if (is.null(out) || nrow(out) == 0) return(empty_lines())
  out |>
    safe_transform(4326) |>
    normalize_line_geometry() |>
    safe_make_valid()
}

read_wfs_full <- function(base_url, layer_name) {
  dsn <- paste0("WFS:", base_url, "?service=WFS&version=2.0.0")
  out <- tryCatch(
    st_read(dsn, layer = layer_name, quiet = TRUE),
    error = function(e) NULL
  )
  if (is.null(out) || nrow(out) == 0) return(empty_lines())
  out |>
    safe_transform(4326) |>
    normalize_line_geometry() |>
    safe_make_valid()
}

read_wfs_bbox_paged <- function(base_url, layer_name, bbox_vec, page_size = 2000, max_pages = 3) {
  parts <- vector("list", max_pages)
  n_parts <- 0L

  bbox_str <- sprintf(
    "%.6f,%.6f,%.6f,%.6f,EPSG:4326",
    bbox_vec[["xmin"]], bbox_vec[["ymin"]], bbox_vec[["xmax"]], bbox_vec[["ymax"]]
  )

  for (i in seq_len(max_pages)) {
    start_index <- (i - 1) * page_size
    req <- paste0(
      base_url,
      "?service=WFS&version=2.0.0&request=GetFeature",
      "&typeNames=", utils::URLencode(layer_name, reserved = TRUE),
      "&srsName=EPSG:4326",
      "&count=", page_size,
      "&startIndex=", start_index,
      "&bbox=", bbox_str
    )

    tmp <- tempfile(fileext = ".gml")
    on.exit(if (file.exists(tmp)) file.remove(tmp), add = TRUE)

    ok <- tryCatch({
      download.file(req, tmp, mode = "wb", quiet = TRUE, method = "libcurl")
      TRUE
    }, error = function(e) FALSE)
    if (!ok || !file.exists(tmp) || file.size(tmp) <= 0) break

    chunk <- tryCatch(st_read(tmp, quiet = TRUE), error = function(e) NULL)
    if (is.null(chunk) || nrow(chunk) == 0) break

    n_parts <- n_parts + 1L
    parts[[n_parts]] <- chunk
    if (nrow(chunk) < page_size) break
  }

  if (n_parts == 0) return(empty_lines())

  bind_rows(parts[seq_len(n_parts)]) |>
    safe_transform(4326) |>
    normalize_line_geometry() |>
    safe_make_valid()
}

normalize_river_fields <- function(sf_obj, source_id, demarcacion) {
  if (nrow(sf_obj) == 0) return(empty_lines())

  nms <- names(sf_obj)
  pick_col <- function(candidates) {
    hit <- candidates[candidates %in% nms]
    if (length(hit) == 0) return(NULL)
    hit[[1]]
  }

  id_col <- pick_col(c("id", "ID", "codigo", "CODIGO", "code", "CODE", "inspireId_localId", "localId"))
  name_col <- pick_col(c("name", "NAME", "nombre", "NOMBRE", "denominacion", "DENOMINACION", "toponym"))
  cat_col <- pick_col(c("categoria", "CATEGORIA", "category", "CATEGORY", "orden", "ORDEN", "tipo", "TIPO"))
  regime_col <- pick_col(c("regimen", "REGIMEN", "flowRegime", "FLOWREGIME", "permanencia", "PERMANENCIA"))

  out <- sf_obj |>
    mutate(
      river_id = if (!is.null(id_col)) as.character(.data[[id_col]]) else NA_character_,
      river_name = if (!is.null(name_col)) as.character(.data[[name_col]]) else NA_character_,
      categoria_phd = if (!is.null(cat_col)) as.character(.data[[cat_col]]) else NA_character_,
      flow_regime = if (!is.null(regime_col)) as.character(.data[[regime_col]]) else NA_character_,
      demarcacion = demarcacion,
      source = source_id
    ) |>
    select(river_id, river_name, categoria_phd, flow_regime, demarcacion, source, geometry)

  out
}

read_zip_lines <- function(zip_path, source_id, demarcacion) {
  extract_dir <- path(paths$rivers_cache_dir, source_id)
  invisible(dir_create(extract_dir, recurse = TRUE))

  unzip(zip_path, exdir = extract_dir, overwrite = TRUE)
  shp_files <- dir_ls(extract_dir, recurse = TRUE, glob = "*.shp", type = "file")
  if (length(shp_files) == 0) return(empty_lines())

  layers <- lapply(shp_files, function(shp) {
    obj <- tryCatch(st_read(shp, quiet = TRUE), error = function(e) NULL)
    if (is.null(obj) || nrow(obj) == 0) return(NULL)
    obj <- obj |>
      safe_make_valid() |>
      normalize_line_geometry() |>
      safe_transform(4326)
    if (!geometry_is_line(obj)) return(NULL)
    normalize_river_fields(obj, source_id, demarcacion)
  })

  layers <- layers[!vapply(layers, is.null, logical(1))]
  if (length(layers) == 0) return(empty_lines())
  bind_rows(layers)
}

download_zip_source <- function(url, source_id, force_download = FALSE) {
  zip_target <- path(paths$rivers_raw_dir, paste0(source_id, ".zip"))
  if (!file.exists(zip_target) || force_download) {
    download.file(url, zip_target, mode = "wb", quiet = TRUE, method = "libcurl")
  }
  zip_target
}

sources <- if (file.exists(paths$hydro_sources_csv)) {
  read_csv(paths$hydro_sources_csv, show_col_types = FALSE)
} else {
  tibble(
    source_id = "ign_wfs",
    demarcacion = "Ambito nacional",
    source_type = "wfs",
    url = "https://servicios.idee.es/wfs-inspire/hidrografia",
    layer_name = "hy-p:Watercourse",
    enabled = 1,
    priority = 90,
    notes = "Fallback nacional geometrico"
  )
}

sources <- sources |>
  mutate(
    enabled = as.integer(enabled),
    priority = as.numeric(priority)
  ) |>
  filter(enabled == 1) |>
  arrange(priority)

if (nrow(sources) == 0) {
  stop("No hay fuentes hidro habilitadas en config/hydro_sources.csv")
}

force_download <- identical(Sys.getenv("HYDRO_FORCE_DOWNLOAD", "0"), "1")
source_reports <- vector("list", nrow(sources))
rivers_chunks <- vector("list", nrow(sources))

for (i in seq_len(nrow(sources))) {
  src <- sources[i, ]
  source_id <- as.character(src$source_id)
  demarcacion <- as.character(src$demarcacion)
  source_type <- tolower(as.character(src$source_type))
  url <- as.character(src$url)
  layer_name <- as.character(src$layer_name)

  message("[hydro] Fuente ", source_id, " (", source_type, ")")

  chunk <- empty_lines()
  status <- "ok"
  detail <- ""
  n_raw <- 0L

  if (source_type == "wfs") {
    if (!nzchar(url) || !nzchar(layer_name)) {
      status <- "skip"
      detail <- "wfs sin url o layer_name"
    } else {
      chunk_raw <- read_wfs_bbox_paged(url, layer_name, scope_bbox)
      if (nrow(chunk_raw) == 0) {
        chunk_raw <- read_wfs_filtered(url, layer_name, bbox_wkt)
      }
      if (nrow(chunk_raw) == 0 && source_id == "chd_masas_rio") {
        chunk_raw <- read_wfs_full(url, layer_name)
      }
      n_raw <- nrow(chunk_raw)
      if (n_raw > 0) {
        chunk <- normalize_river_fields(chunk_raw, source_id, demarcacion)
      } else {
        status <- "empty"
        detail <- "wfs sin features en ambito"
      }
    }
  } else if (source_type == "zip") {
    if (!nzchar(url)) {
      status <- "skip"
      detail <- "zip sin url"
    } else {
      chunk <- tryCatch({
        zip_path <- download_zip_source(url, source_id, force_download = force_download)
        lines <- read_zip_lines(zip_path, source_id, demarcacion)
        n_raw <<- nrow(lines)
        lines
      }, error = function(e) {
        status <<- "error"
        detail <<- conditionMessage(e)
        empty_lines()
      })

      if (status == "ok" && nrow(chunk) == 0) {
        status <- "empty"
        detail <- "zip leido pero sin lineas"
      }
    }
  } else {
    status <- "skip"
    detail <- "source_type no soportado"
  }

  if (nrow(chunk) > 0) {
    chunk <- chunk |>
      st_transform(3857) |>
      st_filter(scope_poly_m, .predicate = st_intersects) |>
      st_intersection(scope_poly_m) |>
      st_transform(4326)
  }

  rivers_chunks[[i]] <- chunk
  source_reports[[i]] <- tibble(
    source_id = source_id,
    demarcacion = demarcacion,
    source_type = source_type,
    status = status,
    detail = detail,
    raw_features = n_raw,
    scope_features = nrow(chunk),
    run_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
}

report_tbl <- bind_rows(source_reports)

rivers_scope <- bind_rows(rivers_chunks) |>
  st_make_valid() |>
  st_transform(4326)

if (nrow(rivers_scope) == 0) {
  stop("No se obtuvieron rios en el scope. Revisa config/hydro_sources.csv")
}

rivers_scope <- rivers_scope |>
  mutate(geom_wkt = as.character(st_as_text(geometry))) |>
  distinct(source, river_id, geom_wkt, .keep_all = TRUE) |>
  select(-geom_wkt)

hydro_wfs <- Sys.getenv("HYDRO_WFS_URL", unset = "https://servicios.idee.es/wfs-inspire/hidrografia")
basin_layer <- Sys.getenv("HYDRO_BASIN_LAYER", unset = "hy-p:RiverBasin")
fetch_basins <- identical(Sys.getenv("HYDRO_FETCH_BASINS", "1"), "1")

if (fetch_basins) {
  basins_raw <- read_wfs_filtered(hydro_wfs, basin_layer, bbox_wkt)
  if (nrow(basins_raw) > 0) {
    basins_scope <- basins_raw |>
      st_transform(3857) |>
      st_filter(scope_poly_m, .predicate = st_intersects) |>
      st_intersection(scope_poly_m) |>
      st_transform(4326)
    st_write(basins_scope, paths$output_river_basins_geojson, delete_dsn = TRUE, quiet = TRUE)
    message("OK: cuencas descargadas y recortadas en ", paths$output_river_basins_geojson)
  } else {
    message("Aviso: no se pudieron descargar cuencas con la capa ", basin_layer)
  }
}

write_csv(report_tbl, paths$output_hydro_sources_report_csv)
st_write(rivers_scope, paths$output_rivers_geojson, delete_dsn = TRUE, quiet = TRUE)

message("OK: rios descargados y recortados en ", paths$output_rivers_geojson, " | tramos: ", nrow(rivers_scope))
message("OK: reporte de fuentes hidro en ", paths$output_hydro_sources_report_csv)

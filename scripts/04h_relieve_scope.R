source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(fs)
  library(arrow)
})

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [relieve] ", msg)

write_parquet_safe <- function(df, target_path) {
  tmp_path <- paste0(target_path, ".tmp")
  if (file.exists(tmp_path)) file_delete(tmp_path)

  write_parquet(df, tmp_path)

  ok <- tryCatch({
    tb <- read_parquet(tmp_path)
    nrow(tb) >= 0
  }, error = function(e) FALSE)

  if (!ok) {
    if (file.exists(tmp_path)) file_delete(tmp_path)
    stop("No se pudo validar parquet temporal: ", tmp_path)
  }

  file_move(tmp_path, target_path)
}

write_feature_safe <- function(df, rds_path, parquet_path = NULL) {
  saveRDS(df, rds_path)
  if (!is.null(parquet_path)) {
    try(write_parquet(df, parquet_path), silent = TRUE)
  }
}

sf_use_s2(FALSE)

if (!file.exists(paths$output_entorno_geojson)) {
  stop("No existe municipios_entorno.geojson. Ejecuta antes el paso de entorno.")
}

log_step("Cargando municipios de entorno")
mun <- st_read(paths$output_entorno_geojson, quiet = TRUE)
resume_mode <- identical(Sys.getenv("RELIEF_RESUME", unset = "1"), "1")
prov_only <- trimws(Sys.getenv("RELIEF_PROV_ONLY", unset = ""))

dem_env <- Sys.getenv("RELIEF_DEM", unset = "")
dem_default <- path(paths$relieve_raw_dir, paste0(analysis_scope, "_dem.tif"))
dem_path <- if (nzchar(dem_env)) dem_env else dem_default

download_dem_opentopo <- function(target_path) {
  api_key <- Sys.getenv("OPENTOPO_API_KEY", unset = "")
  dem_type <- Sys.getenv("OPENTOPO_DEM_TYPE", unset = "COP30")

  if (!nzchar(api_key)) {
    warning("Falta OPENTOPO_API_KEY en entorno/.env. No se puede descargar DEM automaticamente.")
    stop("Define OPENTOPO_API_KEY en .env o exporta RELIEF_DEM con una ruta local.")
  }

  bbox_source <- if (file.exists(paths$output_base_geojson)) paths$output_base_geojson else paths$output_entorno_geojson
  if (!file.exists(bbox_source)) return(FALSE)

  mun_bbox <- st_read(bbox_source, quiet = TRUE) |>
    st_transform(4326) |>
    st_bbox()

  west <- as.numeric(mun_bbox[["xmin"]])
  south <- as.numeric(mun_bbox[["ymin"]])
  east <- as.numeric(mun_bbox[["xmax"]])
  north <- as.numeric(mun_bbox[["ymax"]])

  dir_create(path_dir(target_path), recurse = TRUE)

  url <- paste0(
    "https://portal.opentopography.org/API/globaldem?",
    "demtype=", dem_type,
    "&south=", sprintf("%.6f", south),
    "&north=", sprintf("%.6f", north),
    "&west=", sprintf("%.6f", west),
    "&east=", sprintf("%.6f", east),
    "&outputFormat=GTiff",
    "&API_Key=", api_key
  )

  log_step(paste0("Descargando DEM OpenTopography (", dem_type, ") para bbox scope"))
  old_timeout <- getOption("timeout")
  options(timeout = max(600, old_timeout))
  on.exit(options(timeout = old_timeout), add = TRUE)

  ok <- tryCatch({
    download.file(url, target_path, mode = "wb", quiet = TRUE, method = "libcurl")
    file.exists(target_path) && file.size(target_path) > 0
  }, error = function(e) FALSE)

  if (ok) {
    ok <- tryCatch({
      r <- rast(target_path)
      nlyr(r) >= 1 && !is.null(crs(r)) && crs(r) != ""
    }, error = function(e) FALSE)
  }

  if (!ok && file.exists(target_path)) {
    file_delete(target_path)
  }

  if (ok) {
    log_step(paste0("OK: DEM descargado en ", target_path))
    TRUE
  } else {
    log_step("Aviso: no se pudo descargar DEM desde OpenTopography")
    FALSE
  }
}

validate_dem_readable <- function(dem_file) {
  tryCatch({
    r <- rast(dem_file)
    if (nlyr(r) < 1) return(FALSE)
    # Force block reads to detect partially downloaded/corrupt TIFFs.
    g <- terra::global(r, fun = "mean", na.rm = TRUE)
    is.matrix(g) || is.data.frame(g)
  }, error = function(e) FALSE)
}

  if (!file.exists(dem_path)) {
  if (dir_exists(paths$relieve_raw_dir)) {
    dem_candidates <- dir_ls(paths$relieve_raw_dir, recurse = TRUE, regexp = "\\.tif$", type = "file")
  } else {
    dem_candidates <- character(0)
  }
  if (length(dem_candidates) > 0) {
    dem_path <- dem_candidates[1]
    log_step(paste0("Aviso: RELIEF_DEM no definido. Usando DEM encontrado: ", dem_path))
  } else {
    downloaded <- download_dem_opentopo(dem_default)
    if (downloaded) dem_path <- dem_default
  }
}

if (file.exists(dem_path)) {
  dem_ok <- validate_dem_readable(dem_path)
  if (!dem_ok) {
    warning("DEM existente corrupto o ilegible. Se elimina para evitar errores de raster.")
    file_delete(dem_path)
  }
}

if (!file.exists(dem_path) && !nzchar(dem_env)) {
  downloaded <- download_dem_opentopo(dem_default)
  if (downloaded && validate_dem_readable(dem_default)) {
    dem_path <- dem_default
  } else if (file.exists(dem_default) && !validate_dem_readable(dem_default)) {
    warning("DEM descargado no es legible. Se elimina archivo corrupto.")
    file_delete(dem_default)
  }
}

if (!file.exists(dem_path)) {
  log_step("Aviso: no se encontro DEM Copernicus. Se aplica fallback neutral de relieve")
  mun$elev_range_m <- NA_real_
  mun$slope_p90 <- NA_real_
  mun$tri_mean <- NA_real_
  mun$relieve_score_raw <- 0.5
  mun$relieve_norm <- 0.5
  feature_relief <- mun |>
    st_drop_geometry() |>
    transmute(
      codigo,
      elev_range_m = as.numeric(NA),
      slope_p90 = as.numeric(NA),
      tri_mean = as.numeric(NA),
      relieve_score_raw = 0.5,
      relieve_norm = 0.5
    )
  write_feature_safe(feature_relief, paths$output_feature_relief_rds, paths$output_feature_relief_parquet)
  st_write(mun, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)
  log_step(paste0("OK: fallback relieve aplicado en ", paths$output_entorno_geojson))
  quit(save = "no", status = 0)
}

log_step(paste0("Abriendo DEM: ", dem_path))
dem <- rast(dem_path)
if (is.null(crs(dem)) || crs(dem) == "") {
  stop("El DEM no tiene CRS definido: ", dem_path)
}

mun_aea <- mun |>
  st_make_valid() |>
  st_transform(crs(dem))

if (!"codigo" %in% names(mun_aea)) stop("No existe columna 'codigo' en municipios")

if (length(scope_config$codprov) == 1 && nzchar(scope_config$codprov) && "codigo" %in% names(mun_aea)) {
  mun_aea <- mun_aea |>
    mutate(codprov = substr(codigo, 1, 2)) |>
    filter(codprov == scope_config$codprov) |>
    select(-codprov)
}

if (nrow(mun_aea) == 0) stop("No hay municipios para calcular relieve en el scope activo")

mun_aea <- mun_aea |>
  mutate(codprov = substr(codigo, 1, 2))

if (nzchar(prov_only)) {
  mun_aea <- mun_aea |>
    filter(codprov == prov_only)
  log_step(paste0("Filtro RELIEF_PROV_ONLY activo: ", prov_only))
}

if (nrow(mun_aea) == 0) stop("No hay municipios para las provincias solicitadas")

prov_codes <- sort(unique(mun_aea$codprov))
log_step(paste0("Procesando relieve por provincias: ", paste(prov_codes, collapse = ", ")))

feature_relief_dir <- path(paths$output_features_dir, "relief_by_prov")
dir_create(feature_relief_dir, recurse = TRUE)

extract_q <- function(r, vect_poly, prob, col_name) {
  out <- terra::extract(
    r,
    vect_poly,
    fun = function(x, ...) {
      x <- x[is.finite(x)]
      if (length(x) == 0) return(NA_real_)
      as.numeric(quantile(x, probs = prob, na.rm = TRUE, type = 7))
    },
    na.rm = TRUE
  )
  names(out)[2] <- col_name
  as_tibble(out)
}

log_step("Extrayendo cuantiles municipales (P05, P95, P90)")
relief_parts <- list()

for (p in prov_codes) {
  prov_file <- path(feature_relief_dir, paste0("relieve_prov_", p, ".rds"))
  if (resume_mode && file.exists(prov_file)) {
    cached_part <- tryCatch(readRDS(prov_file), error = function(e) NULL)

    if (!is.null(cached_part) && nrow(cached_part) > 0 && all(c("codigo", "elev_range_m", "slope_p90", "tri_mean") %in% names(cached_part))) {
      log_step(paste0("Provincia ", p, " SKIP (cache local)"))
      relief_parts[[p]] <- cached_part
      next
    }

    warning(paste0("Cache parquet corrupta o incompleta para provincia ", p, ". Se recalcula."))
    file_delete(prov_file)
  }

  log_step(paste0("Provincia ", p, ": preparando geometria"))
  prov_sf <- mun_aea |>
    filter(codprov == p)
  prov_vect <- vect(prov_sf)

  log_step(paste0("Provincia ", p, ": recortando y enmascarando DEM"))
  dem_crop <- crop(dem, prov_vect)
  dem_mask <- mask(dem_crop, prov_vect)

  if (nrow(prov_sf) > 250) {
    log_step(paste0("Provincia ", p, ": agregando DEM (factor 2)"))
    dem_mask <- aggregate(dem_mask, fact = 2, fun = mean, na.rm = TRUE)
  }

  log_step(paste0("Provincia ", p, ": calculando pendiente y TRI"))
  slope <- terrain(dem_mask, v = "slope", unit = "degrees", neighbors = 8)
  tri <- terrain(dem_mask, v = "TRI", neighbors = 8)

  log_step(paste0("Provincia ", p, ": extrayendo cuantiles"))
  elev_p05_tbl <- extract_q(dem_mask, prov_vect, 0.05, "elev_p05")
  elev_p95_tbl <- extract_q(dem_mask, prov_vect, 0.95, "elev_p95")
  slope_q <- extract_q(slope, prov_vect, 0.90, "slope_p90")

  log_step(paste0("Provincia ", p, ": extrayendo TRI medio"))
  tri_mean <- terra::extract(tri, prov_vect, fun = mean, na.rm = TRUE)
  names(tri_mean)[2] <- "tri_mean"

  part <- elev_p05_tbl |>
    left_join(elev_p95_tbl, by = "ID") |>
    left_join(as_tibble(slope_q), by = "ID") |>
    left_join(as_tibble(tri_mean), by = "ID") |>
    mutate(
      elev_range_m = pmax(0, elev_p95 - elev_p05),
      codigo = prov_sf$codigo
    ) |>
    select(codigo, elev_range_m, slope_p90, tri_mean)

  saveRDS(part, prov_file)
  relief_parts[[p]] <- part
  log_step(paste0("Provincia ", p, ": OK"))
}

relief_tbl <- bind_rows(relief_parts)

robust_norm <- function(x) {
  x <- as.numeric(x)
  if (all(!is.finite(x))) return(rep(0.5, length(x)))
  lo <- suppressWarnings(quantile(x, 0.02, na.rm = TRUE, type = 7))
  hi <- suppressWarnings(quantile(x, 0.98, na.rm = TRUE, type = 7))
  if (!is.finite(lo) || !is.finite(hi) || lo >= hi) return(rep(0.5, length(x)))
  clipped <- pmin(pmax(x, lo), hi)
  out <- (clipped - lo) / (hi - lo)
  out[!is.finite(out)] <- 0.5
  out
}

relief_tbl <- relief_tbl |>
  mutate(
    elev_range_norm = robust_norm(elev_range_m),
    tri_norm = robust_norm(tri_mean),
    slope_p90_norm = robust_norm(slope_p90),
    relieve_score_raw = 0.4 * elev_range_norm + 0.4 * tri_norm + 0.2 * slope_p90_norm,
    relieve_norm = robust_norm(relieve_score_raw)
  )

log_step("Uniendo relieve al dataset municipal")
mun <- mun |>
  left_join(
    relief_tbl |>
      select(codigo, elev_range_m, slope_p90, tri_mean, relieve_score_raw, relieve_norm),
    by = "codigo"
  ) |>
  mutate(
    relieve_score_raw = coalesce(relieve_score_raw, 0.5),
    relieve_norm = coalesce(relieve_norm, 0.5)
  )

feature_relief <- mun |>
  st_drop_geometry() |>
  transmute(
    codigo,
    elev_range_m = round(as.numeric(elev_range_m), 3),
    slope_p90 = round(as.numeric(slope_p90), 3),
    tri_mean = round(as.numeric(tri_mean), 3),
    relieve_score_raw = round(as.numeric(relieve_score_raw), 3),
    relieve_norm = round(as.numeric(relieve_norm), 3)
  )
write_feature_safe(feature_relief, paths$output_feature_relief_rds, paths$output_feature_relief_parquet)

st_write(mun, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)

log_step(paste0("OK: relieve Copernicus calculado y unido en ", paths$output_entorno_geojson))

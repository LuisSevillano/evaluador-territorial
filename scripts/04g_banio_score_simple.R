source("scripts/00_config.R")

library(sf)
library(dplyr)
library(readr)
library(fs)
library(stringr)
library(arrow)

sf_use_s2(FALSE)

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] ", msg)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

codprov_target <- trimws(Sys.getenv("BANIO_CODPROV", unset = ""))
demarc_codes_env <- trimws(Sys.getenv("BANIO_DEMARC_CODES", unset = ""))
hydro_dir_env <- trimws(Sys.getenv("BANIO_HYDRO_DIR", unset = ""))
hydro_candidates <- c(
  if (nzchar(hydro_dir_env)) path_abs(hydro_dir_env) else character(0),
  path(project_root, "data", "raw", "hydrography"),
  paths$rivers_raw_dir,
  path_expand("~/Downloads")
)
hydro_candidates <- unique(hydro_candidates)
hydro_data_dir <- hydro_candidates[file.exists(hydro_candidates)][1]
if (is.na(hydro_data_dir) || !nzchar(hydro_data_dir)) {
  stop("No se encontro directorio de hidrografia. Define BANIO_HYDRO_DIR o coloca datos en data/raw/hydrography")
}
log_step(paste0("Directorio hidrografia: ", hydro_data_dir))
method_version <- "v3_candidate_confidence"
cache_dir <- path(paths$rivers_cache_dir, "banio_access")
dir_create(cache_dir, recurse = TRUE)

use_cache <- identical(Sys.getenv("BANIO_USE_CACHE", unset = "1"), "1")
refresh_stage <- trimws(Sys.getenv("BANIO_REFRESH_STAGE", unset = ""))
write_diag_full <- identical(Sys.getenv("BANIO_WRITE_DIAG", unset = "1"), "1")

cache_key <- if (nzchar(codprov_target)) paste0("prov_", codprov_target) else paste0("scope_", analysis_scope)
cache_bbox <- path(cache_dir, paste0(cache_key, "_rivers_bbox.rds"))
cache_diag <- path(cache_dir, paste0(cache_key, "_rivers_diag.rds"))
cache_candidates <- path(cache_dir, paste0(cache_key, "_rivers_candidates.rds"))

if (refresh_stage %in% c("all", "bbox") && file.exists(cache_bbox)) file_delete(cache_bbox)
if (refresh_stage %in% c("all", "diag") && file.exists(cache_diag)) file_delete(cache_diag)
if (refresh_stage %in% c("all", "candidates") && file.exists(cache_candidates)) file_delete(cache_candidates)

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid()
log_step("Municipios base cargados")

if (nzchar(codprov_target)) {
  mun <- mun |>
    filter(codprov == codprov_target)
}

if (nrow(mun) == 0) {
  stop("No hay municipios para el filtro actual (BANIO_CODPROV)")
}
log_step(paste0("Municipios en scope: ", nrow(mun)))

normalize_name <- function(x) {
  y <- as.character(x)
  y[is.na(y)] <- ""
  y <- tolower(y)
  y <- iconv(y, to = "ASCII//TRANSLIT")
  y[is.na(y)] <- ""
  y <- gsub("[^a-z0-9 ]+", " ", y)
  y <- gsub("\\s+", " ", y)
  trimws(y)
}

clean_code <- function(x) {
  y <- as.character(x)
  y[y %in% c("-998", "-999", "-997", "-DE", "-NA", "-SD", "")] <- NA_character_
  y
}

to_bool <- function(x) {
  if (is.logical(x)) return(replace(x, is.na(x), FALSE))
  y <- tolower(trimws(as.character(x)))
  y %in% c("1", "t", "true", "si", "s", "yes", "y")
}

to_int <- function(x) {
  y <- clean_code(x)
  suppressWarnings(as.integer(y))
}

to_numeric_comma <- function(x) {
  y <- clean_code(x)
  y <- gsub(",", ".", y, fixed = TRUE)
  suppressWarnings(as.numeric(y))
}

default_whitelist <- c(
  "duero", "ebro", "arlanza", "gandara", "gandara", "pisuerga", "esla", "tormes",
  "tietar", "tietar", "alberche", "cea", "carrion", "carrion", "arandilla", "duraton",
  "duraton", "riaza", "agueda", "agueda"
)

if (file.exists(paths$river_whitelist_txt)) {
  wl <- read_lines(paths$river_whitelist_txt, progress = FALSE)
  wl <- wl[!str_detect(trimws(wl), "^#")]
  wl <- normalize_name(wl)
  wl <- wl[nzchar(wl)]
  river_whitelist <- unique(wl)
} else {
  river_whitelist <- unique(normalize_name(default_whitelist))
}

tramocurso_shps <- dir_ls(
  hydro_data_dir,
  recurse = TRUE,
  regexp = "DH_V0_ES[0-9]{3}.*/hi_tramocurso_l_ES[0-9]{3}\\.shp$",
  type = "file"
)

if (length(tramocurso_shps) == 0) {
  stop("No se han encontrado SHP hi_tramocurso_l_ESxxx en ", hydro_data_dir)
}

demarc_codes <- character(0)

if (nzchar(demarc_codes_env)) {
  demarc_codes <- unique(trimws(unlist(strsplit(demarc_codes_env, ",", fixed = TRUE))))
  demarc_codes <- demarc_codes[nzchar(demarc_codes)]
} else {
  demarc_shps <- dir_ls(
    hydro_data_dir,
    recurse = TRUE,
    regexp = "DH_V0_ES[0-9]{3}.*/re_demarcacion_s_ES[0-9]{3}\\.shp$",
    type = "file"
  )
  if (length(demarc_shps) > 0) {
    mun_bbox <- st_as_sfc(st_bbox(st_transform(mun, 4326)))
    hit_codes <- c()
    for (ds in demarc_shps) {
      code <- sub(".*(ES[0-9]{3}).*", "\\1", ds)
      g <- tryCatch(st_read(ds, quiet = TRUE), error = function(e) NULL)
      if (is.null(g)) next
      g <- tryCatch(st_transform(g, 4326), error = function(e) g)
      if (any(st_intersects(g, mun_bbox, sparse = FALSE))) {
        hit_codes <- c(hit_codes, code)
      }
    }
    demarc_codes <- unique(hit_codes)
  }
}

if (length(demarc_codes) > 0) {
  pattern <- paste0("(", paste(demarc_codes, collapse = "|"), ")")
  tramocurso_shps <- tramocurso_shps[grepl(pattern, tramocurso_shps)]
}

if (length(tramocurso_shps) == 0) {
  stop("Tras filtrar BANIO_DEMARC_CODES no quedan SHP de entrada")
}

read_hydro <- function(shp_tramocurso) {
  demarc <- sub(".*(ES[0-9]{3}).*", "\\1", shp_tramocurso)
  shp_redtramo <- sub("hi_tramocurso_l_", "hi_redtramo_l_", shp_tramocurso)

  if (demarc == "ES091" && file.exists(shp_redtramo)) {
    out <- tryCatch(
      st_read(shp_redtramo, quiet = TRUE) |>
        mutate(source_layer = "redtramo"),
      error = function(e) NULL
    )
    if (!is.null(out)) return(out)
  }

  out_main <- tryCatch(
    st_read(shp_tramocurso, quiet = TRUE) |>
      mutate(source_layer = "tramocurso"),
    error = function(e) NULL
  )
  if (!is.null(out_main)) return(out_main)

  if (file.exists(shp_redtramo)) {
    out_fallback <- tryCatch(
      st_read(shp_redtramo, quiet = TRUE) |>
        mutate(source_layer = "redtramo"),
      error = function(e) NULL
    )
    if (!is.null(out_fallback)) return(out_fallback)
  }

  NULL
}

hydro_list <- lapply(tramocurso_shps, read_hydro)
log_step(paste0("Capas hidro leidas: ", length(hydro_list), " (incluyendo NULLs)"))
hydro_list <- hydro_list[!vapply(hydro_list, is.null, logical(1))]
if (length(hydro_list) == 0) {
  stop("No se pudo leer ninguna capa de hidrografia")
}
log_step(paste0("Capas hidro validas: ", length(hydro_list)))

rivers_raw <- bind_rows(hydro_list)
log_step(paste0("Tramos hidro iniciales: ", nrow(rivers_raw)))
names(rivers_raw) <- tolower(names(rivers_raw))

keep_cols <- intersect(
  c(
    "source_layer", "id_demarc", "id_curso", "nombre", "tipo_curso", "tipo_tramo", "tipo_red",
    "ficticio", "marea", "longitud", "ancho_max", "ancho_min", "persist", "codmasa", "dma",
    "orden", "geometry"
  ),
  names(rivers_raw)
)

rivers <- rivers_raw |>
  select(any_of(keep_cols))

if (!"codmasa" %in% names(rivers)) rivers$codmasa <- NA_character_
if (!"persist" %in% names(rivers)) rivers$persist <- NA_character_
if (!"ancho_min" %in% names(rivers)) rivers$ancho_min <- NA_character_
if (!"ancho_max" %in% names(rivers)) rivers$ancho_max <- NA_character_
if (!"dma" %in% names(rivers)) rivers$dma <- NA_character_
if (!"orden" %in% names(rivers)) rivers$orden <- NA_character_

rivers <- rivers |>
  mutate(
    source_layer = as.character(source_layer),
    id_demarc = clean_code(id_demarc),
    id_curso = clean_code(id_curso),
    nombre = clean_code(nombre),
    name_norm = normalize_name(nombre),
    tipo_curso = clean_code(tipo_curso),
    tipo_tramo = clean_code(tipo_tramo),
    tipo_red = clean_code(tipo_red),
    ficticio_bool = to_bool(ficticio),
    marea_num = to_int(marea),
    marea_bool = to_bool(marea),
    longitud_num = to_numeric_comma(longitud),
    ancho_max_num = to_numeric_comma(ancho_max),
    ancho_min_num = to_numeric_comma(ancho_min),
    persist_txt = normalize_name(persist),
    codmasa_txt = clean_code(codmasa),
    dma_num = to_int(dma),
    orden_num = to_int(orden)
  ) |>
  mutate(
    tipo_curso = ifelse(source_layer == "redtramo" & is.na(tipo_curso), "1001", tipo_curso),
    tipo_tramo = ifelse(source_layer == "redtramo" & is.na(tipo_tramo), "4002", tipo_tramo),
    marea_bool = ifelse(source_layer == "redtramo" & is.na(marea_bool), FALSE, marea_bool)
  )

mun_bbox <- st_bbox(st_transform(mun, 4326))
bbox_expand <- st_as_sfc(st_bbox(c(
  xmin = mun_bbox[["xmin"]] - 0.3,
  ymin = mun_bbox[["ymin"]] - 0.3,
  xmax = mun_bbox[["xmax"]] + 0.3,
  ymax = mun_bbox[["ymax"]] + 0.3
), crs = 4326))

if (use_cache && file.exists(cache_bbox)) {
  rivers <- readRDS(cache_bbox)
  log_step(paste0("Cache bbox cargada: ", nrow(rivers), " tramos"))
} else {
  rivers <- rivers |>
    st_transform(4326) |>
    st_filter(bbox_expand, .predicate = st_intersects)
  if (use_cache) saveRDS(rivers, cache_bbox)
  log_step(paste0("Tramos tras recorte por bbox: ", nrow(rivers)))
}

name_has_rio <- str_detect(
  rivers$name_norm,
  "(^|[[:space:][:punct:]])(r[[:space:][:punct:]]*io|ibai|ibaia|riu|river)([[:space:][:punct:]]|$)"
)

name_in_whitelist <- vapply(rivers$name_norm, function(nm) {
  if (!nzchar(nm)) return(FALSE)
  any(vapply(river_whitelist, function(w) {
    str_detect(nm, paste0("(^|[[:space:][:punct:]])", w, "([[:space:][:punct:]]|$)"))
  }, logical(1)))
}, logical(1))
width_strong <- coalesce(rivers$ancho_max_num >= 8, FALSE) | coalesce(rivers$ancho_min_num >= 4, FALSE)
has_codmasa <- !is.na(rivers$codmasa_txt) & rivers$codmasa_txt != ""
dma_flag <- !is.na(rivers$dma_num) & rivers$dma_num == 1L

positive_river_signal <- name_has_rio | name_in_whitelist | width_strong | has_codmasa | dma_flag

artificial_like <- str_detect(
  rivers$name_norm,
  "(^|[[:space:][:punct:]])(canal|acequia|azequia|cacera|caz|cauce artificial|zanja|dren|drenaje|desague|colector|emisario|tuberia|cuneta|aliviadero|sifon)([[:space:][:punct:]]|$)"
)

ephemeral_like_name <- str_detect(
  rivers$name_norm,
  "(^|[[:space:][:punct:]])(barranco|rambla|torrente|torrent|vaguada|canada|arroyo|regato|regata|reguera)([[:space:][:punct:]]|$)"
)

ephemeral_like_persist <- rivers$persist_txt %in% c(
  "tmp", "temporal", "temporario", "intermitente", "int", "estacional", "efimero", "efimera", "efimero"
)

ephemeral_like <- ephemeral_like_name | ephemeral_like_persist
tidal_like <- (coalesce(rivers$marea_num == 1L, FALSE) | rivers$marea_bool)

if (use_cache && file.exists(cache_diag)) {
  rivers_diag <- readRDS(cache_diag)
  log_step(paste0("Cache diagnostico cargada: ", nrow(rivers_diag), " tramos"))
} else {
  rivers_diag <- rivers |>
  mutate(
    name_has_rio = name_has_rio,
    name_in_whitelist = name_in_whitelist,
    width_strong = width_strong,
    has_codmasa = has_codmasa,
    dma_flag = dma_flag,
    tidal_like = tidal_like,
    artificial_like = artificial_like,
    ephemeral_like = ephemeral_like,
    positive_river_signal = positive_river_signal
  ) |>
  st_transform(3035) |>
  mutate(
    length_m = as.numeric(st_length(geometry)),
    order_valid = !is.na(orden_num),
    river_candidate = positive_river_signal & !artificial_like & !ephemeral_like & !tidal_like & (length_m > 100),
    river_confidence_raw = 30 +
      ifelse(name_has_rio, 20, 0) +
      ifelse(name_in_whitelist, 25, 0) +
      ifelse(width_strong, 20, 0) +
      ifelse(has_codmasa | dma_flag, 15, 0) +
      ifelse(order_valid, 5, 0) -
      ifelse(artificial_like, 40, 0) -
      ifelse(ephemeral_like, 25, 0) -
      ifelse(tidal_like, 100, 0),
    river_confidence = pmax(0, pmin(100, river_confidence_raw)),
    river_exclusion_reason = case_when(
      river_candidate ~ "candidate",
      !positive_river_signal ~ "no_positive_signal",
      artificial_like ~ "artificial_like",
      ephemeral_like ~ "ephemeral_like",
      tidal_like ~ "tidal_like",
      length_m <= 100 ~ "short_segment",
      TRUE ~ "other"
    )
  ) |>
  st_transform(4326)
  if (use_cache) saveRDS(rivers_diag, cache_diag)
  log_step("Diagnostico de tramos calculado")
}

if (!any(rivers_diag$river_candidate)) {
  stop("No hay tramos candidatos con la regla conservadora")
}
log_step(paste0("Tramos candidatos: ", sum(rivers_diag$river_candidate, na.rm = TRUE)))

if (use_cache && file.exists(cache_candidates)) {
  rivers_candidates <- readRDS(cache_candidates)
  log_step(paste0("Cache candidatos cargada: ", nrow(rivers_candidates), " tramos"))
} else {
  rivers_candidates <- rivers_diag |>
    filter(river_candidate)
  if (use_cache) saveRDS(rivers_candidates, cache_candidates)
}

mun_m <- st_transform(mun, 3035)
river_m <- st_transform(rivers_candidates, 3035)

nearest_idx <- st_nearest_feature(mun_m, river_m)
nearest_dist_km <- as.numeric(st_distance(st_geometry(mun_m), st_geometry(river_m[nearest_idx, ]), by_element = TRUE)) / 1000

# Priorizacion: si hay varios tramos a distancia minima (incl. distancia 0),
# elegir el de mayor confianza; en empate, priorizar whitelist.
eps_m <- 0.1
log_step("Calculando matriz de distancias municipio-tramo (puede tardar)...")
# Optimizacion: evitar matriz completa municipio x tramo.
# 1) nearest rapido por indice espacial
# 2) desempate local solo entre tramos que intersectan un buffer muy pequeno
log_step("Calculando nearest inicial con indice espacial...")
nearest_initial <- st_nearest_feature(mun_m, river_m)
best_idx <- nearest_initial

for (i in seq_len(nrow(mun_m))) {
  if (i %% 50 == 0 || i == nrow(mun_m)) {
    log_step(paste0("Priorizacion nearest: ", i, "/", nrow(mun_m)))
  }

  muni_geom <- st_geometry(mun_m[i, ])
  nearest_geom <- st_geometry(river_m[nearest_initial[i], ])
  dmin <- as.numeric(st_distance(muni_geom, nearest_geom, by_element = TRUE))

  local_buffer <- st_buffer(muni_geom, dmin + eps_m)
  cand <- st_intersects(local_buffer, river_m, sparse = TRUE)[[1]]

  if (length(cand) <= 1) {
    best_idx[i] <- nearest_initial[i]
  } else {
    sub <- river_m[cand, ] |>
      st_drop_geometry() |>
      mutate(idx = cand)
    sub <- sub |>
      arrange(desc(river_confidence), desc(name_in_whitelist), name_norm)
    best_idx[i] <- sub$idx[[1]]
  }
}

nearest_idx <- best_idx
nearest_dist_km <- as.numeric(st_distance(st_geometry(mun_m), st_geometry(river_m[nearest_idx, ]), by_element = TRUE)) / 1000
log_step("Priorizacion nearest completada")

distance_score <- case_when(
  nearest_dist_km <= 1 ~ 100,
  nearest_dist_km <= 3 ~ 85,
  nearest_dist_km <= 5 ~ 70,
  nearest_dist_km <= 10 ~ 45,
  nearest_dist_km <= 20 ~ 20,
  TRUE ~ 0
)

log_step("Calculando river_candidate_count_10km (modo optimizado por buffers)...")
candidate_count_10km <- integer(nrow(mun_m))
mun_pts_m <- st_point_on_surface(mun_m)
for (i in seq_len(nrow(mun_m))) {
  if (i %% 100 == 0 || i == nrow(mun_m)) {
    log_step(paste0("Conteo candidatos 10km: ", i, "/", nrow(mun_m)))
  }
  candidate_count_10km[i] <- tryCatch({
    b10 <- st_buffer(st_geometry(mun_m[i, ]), 10000)
    length(st_intersects(b10, river_m, sparse = TRUE, prepared = FALSE)[[1]])
  }, error = function(e) {
    # Fallback robusto (evita caidas GEOS en algunos buffers complejos):
    # conteo por distancia desde punto representativo municipal.
    length(st_is_within_distance(st_geometry(mun_pts_m[i, ]), river_m, dist = 10000, sparse = TRUE)[[1]])
  })
}
log_step("Conteo river_candidate_count_10km completado")

municipal <- mun_m |>
  st_drop_geometry() |>
  select(codigo, codprov, nombre, provincia) |>
  mutate(
    river_nearest_name = river_m$nombre[nearest_idx],
    river_nearest_distance_km = round(nearest_dist_km, 2),
    river_nearest_confidence = round(river_m$river_confidence[nearest_idx], 1),
    river_candidate_count_10km = candidate_count_10km,
    river_access_score = round(distance_score * river_nearest_confidence / 100, 1),
    river_access_class = case_when(
      river_access_score >= 80 ~ "Muy alta",
      river_access_score >= 60 ~ "Alta",
      river_access_score >= 40 ~ "Media",
      river_access_score >= 20 ~ "Baja",
      TRUE ~ "Muy baja"
    ),
    river_method_version = method_version
  )

municipal_geo <- mun_m |>
  left_join(municipal, by = c("codigo", "codprov", "nombre", "provincia")) |>
  st_transform(4326)

summary_tbl <- tibble(
  metric = c(
    "initial_total",
    "discarded_artificial_like",
    "discarded_ephemeral_like",
    "discarded_tidal_like",
    "final_candidates"
  ),
  value = c(
    nrow(rivers_diag),
    sum(!rivers_diag$river_candidate & rivers_diag$artificial_like, na.rm = TRUE),
    sum(!rivers_diag$river_candidate & rivers_diag$ephemeral_like, na.rm = TRUE),
    sum(!rivers_diag$river_candidate & rivers_diag$tidal_like, na.rm = TRUE),
    sum(rivers_diag$river_candidate, na.rm = TRUE)
  )
)

sample_candidates <- rivers_diag |>
  filter(river_candidate) |>
  st_drop_geometry() |>
  select(id_demarc, id_curso, nombre, river_confidence, river_exclusion_reason) |>
  slice_head(n = 20)

sample_discarded <- rivers_diag |>
  filter(!river_candidate) |>
  st_drop_geometry() |>
  select(id_demarc, id_curso, nombre, river_confidence, river_exclusion_reason) |>
  slice_head(n = 20)

if (nzchar(codprov_target)) {
  prov_name <- municipal$provincia[[1]]
  prov_slug <- iconv(prov_name, to = "ASCII//TRANSLIT")
  prov_slug <- tolower(prov_slug)
  prov_slug <- gsub("[^a-z0-9]+", "_", prov_slug)
  prov_slug <- gsub("^_+|_+$", "", prov_slug)
  out_geo <- path(paths$output_dir, paste0(prov_slug, "_river_access.geojson"))
  out_csv <- path(paths$output_dir, paste0(prov_slug, "_river_access.csv"))
  out_diag <- path(paths$output_dir, paste0(prov_slug, "_river_segments_diagnostic.csv"))
  out_summary <- path(paths$output_dir, paste0(prov_slug, "_river_filter_summary.csv"))
  out_cand <- path(paths$output_dir, paste0(prov_slug, "_river_candidates_sample.csv"))
  out_disc <- path(paths$output_dir, paste0(prov_slug, "_river_discarded_sample.csv"))
} else {
  out_geo <- path(paths$output_dir, "municipios_river_access.geojson")
  out_csv <- path(paths$output_dir, "municipios_river_access.csv")
  out_diag <- path(paths$output_dir, "river_segments_diagnostic.csv")
  out_summary <- path(paths$output_dir, "river_filter_summary.csv")
  out_cand <- path(paths$output_dir, "river_candidates_sample.csv")
  out_disc <- path(paths$output_dir, "river_discarded_sample.csv")
}

st_write(municipal_geo, out_geo, delete_dsn = TRUE, quiet = TRUE)
write_csv(st_drop_geometry(municipal_geo), out_csv)
feature_river <- municipal_geo |>
  st_drop_geometry() |>
  transmute(
    codigo,
    river_access_score = round(as.numeric(river_access_score), 3),
    river_access_class,
    river_nearest_name,
    river_nearest_distance_km = round(as.numeric(river_nearest_distance_km), 3),
    river_nearest_confidence = round(as.numeric(river_nearest_confidence), 3),
    river_candidate_count_10km,
    river_method_version
  )
saveRDS(feature_river, paths$output_feature_river_rds)
try(write_parquet(feature_river, paths$output_feature_river_parquet), silent = TRUE)
log_step("Escritura municipal completada")
if (write_diag_full) {
  write_csv(
    rivers_diag |>
      st_drop_geometry() |>
      select(
        source_layer, id_demarc, id_curso, nombre, name_norm, tipo_curso, tipo_tramo, tipo_red,
        name_has_rio, name_in_whitelist, width_strong, has_codmasa, dma_flag,
        tidal_like, artificial_like, ephemeral_like, positive_river_signal,
        length_m, river_candidate, river_confidence, river_exclusion_reason
      ),
    out_diag
  )
  log_step("Escritura diagnostico tramos completada")
} else {
  log_step("Diagnostico full desactivado (BANIO_WRITE_DIAG=0)")
}
write_csv(summary_tbl, out_summary)
write_csv(sample_candidates, out_cand)
write_csv(sample_discarded, out_disc)

message("OK: river access municipal en ", out_geo)
message("OK: diagnostico de tramos en ", out_diag)
message("OK: resumen de filtro en ", out_summary)
print(summary_tbl)
log_step("Script completado")

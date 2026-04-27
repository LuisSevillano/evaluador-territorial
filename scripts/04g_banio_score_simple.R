source("scripts/00_config.R")

library(sf)
library(dplyr)
library(readr)
library(fs)

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

codprov_target <- trimws(Sys.getenv("BANIO_CODPROV", unset = ""))
demarc_codes_env <- trimws(Sys.getenv("BANIO_DEMARC_CODES", unset = ""))
downloads_dir <- path_expand("~/Downloads")

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid()

if (nzchar(codprov_target)) {
  mun <- mun |>
    filter(codprov == codprov_target)
}

if (nrow(mun) == 0) {
  stop("No hay municipios para el filtro actual (BANIO_CODPROV)")
}

tramocurso_shps <- dir_ls(
  downloads_dir,
  recurse = TRUE,
  regexp = "DH_V0_ES[0-9]{3}.*/hi_tramocurso_l_ES[0-9]{3}\\.shp$",
  type = "file"
)

if (length(tramocurso_shps) == 0) {
  stop("No se han encontrado SHP hi_tramocurso_l_ESxxx en ~/Downloads")
}

demarc_codes <- character(0)

if (nzchar(demarc_codes_env)) {
  demarc_codes <- unique(trimws(unlist(strsplit(demarc_codes_env, ",", fixed = TRUE))))
  demarc_codes <- demarc_codes[nzchar(demarc_codes)]
} else {
  demarc_shps <- dir_ls(
    downloads_dir,
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
hydro_list <- hydro_list[!vapply(hydro_list, is.null, logical(1))]

if (length(hydro_list) == 0) {
  stop("No se pudo leer ninguna capa de hidrografia")
}

rivers_raw <- bind_rows(hydro_list)
names(rivers_raw) <- tolower(names(rivers_raw))

keep_cols <- intersect(
  c("source_layer", "id_demarc", "nombre", "tipo_curso", "tipo_tramo", "tipo_red", "ficticio", "marea", "longitud", "ancho_max", "geometry"),
  names(rivers_raw)
)

rivers <- rivers_raw |>
  select(any_of(keep_cols)) |>
  mutate(
    source_layer = as.character(source_layer),
    id_demarc = clean_code(id_demarc),
    nombre = clean_code(nombre),
    tipo_curso = clean_code(tipo_curso),
    tipo_tramo = clean_code(tipo_tramo),
    tipo_red = clean_code(tipo_red),
    ancho_max_num = to_numeric_comma(ancho_max),
    ficticio_bool = to_bool(ficticio),
    marea_num = to_int(marea),
    marea_bool = to_bool(marea),
    longitud_num = to_numeric_comma(longitud)
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

rivers <- rivers |>
  st_transform(4326) |>
  st_filter(bbox_expand, .predicate = st_intersects)

is_natural <- function(tipo) {
  tipo %in% c("RIO", "1001")
}

is_banio_name <- function(nombre) {
  !is.na(nombre) & grepl("r[ií]o|ibai|ibaia", nombre, ignore.case = TRUE)
}

is_excluded_name <- function(nombre) {
  !is.na(nombre) & grepl("arroyo|regato|barranco|canal|acequia|zanja|tuber", nombre, ignore.case = TRUE)
}

is_main_network <- function(tipo_tramo, tipo_red, source_layer, longitud_num) {
  ifelse(
    source_layer == "redtramo",
    coalesce(longitud_num >= 500, FALSE),
    ifelse(
      !is.na(tipo_tramo),
      tipo_tramo == "4001",
      tipo_red == "110"
    )
  )
}

rivers_banio <- rivers |>
  mutate(
    name_ok = is_banio_name(nombre) & !is_excluded_name(nombre),
    major_banio = case_when(
      source_layer == "redtramo" ~ coalesce(longitud_num >= 5000, FALSE) & name_ok,
      TRUE ~ coalesce(ancho_max_num >= 20, FALSE) & name_ok & is_main_network(tipo_tramo, tipo_red, source_layer, longitud_num)
    )
  ) |>
  filter(
    is_natural(tipo_curso),
    !ficticio_bool,
    !(coalesce(marea_num == 1L, FALSE) | marea_bool),
    major_banio
  )

if (nrow(rivers_banio) == 0) {
  stop("No hay tramos elegibles para score simple de banio")
}

mun_m <- st_transform(mun, 3035)
rivers_m <- st_transform(rivers_banio, 3035)

nearest_idx <- st_nearest_feature(mun_m, rivers_m)
dist_km <- as.numeric(st_distance(st_geometry(mun_m), st_geometry(rivers_m[nearest_idx, ]), by_element = TRUE)) / 1000

has_inside <- lengths(st_intersects(mun_m, rivers_m)) > 0

has10 <- dist_km <= 10
has20 <- dist_km <= 20

score_dist <- case_when(
  has_inside ~ 100,
  dist_km <= 1 ~ 70,
  dist_km <= 3 ~ 55,
  dist_km <= 5 ~ 40,
  dist_km <= 10 ~ 20,
  dist_km <= 20 ~ 10,
  TRUE ~ 0
)

banio_res <- mun_m |>
  st_drop_geometry() |>
  select(codigo, codprov, nombre, provincia) |>
  mutate(
    banio_has_rio_principal_10km = has10,
    banio_has_rio_principal_20km = has20,
    banio_has_rio_principal_en_municipio = has_inside,
    banio_dist_rio_principal_km = round(dist_km, 2),
    banio_score_simple_0_100 = round(score_dist, 1),
    banio_class_simple = case_when(
      banio_has_rio_principal_en_municipio ~ "alta",
      banio_dist_rio_principal_km <= 5 ~ "media",
      TRUE ~ "baja"
    ),
    banio_nearest_river_name = rivers_m$nombre[nearest_idx],
    banio_nearest_demarc = rivers_m$id_demarc[nearest_idx],
    banio_rule_version = "v1_distance_principal"
  )

banio_geo <- mun_m |>
  left_join(banio_res, by = c("codigo", "codprov", "nombre", "provincia")) |>
  st_transform(4326)

if (nzchar(codprov_target)) {
  prov_name <- banio_res$provincia[[1]]
  prov_slug <- iconv(prov_name, to = "ASCII//TRANSLIT")
  prov_slug <- tolower(prov_slug)
  prov_slug <- gsub("[^a-z0-9]+", "_", prov_slug)
  prov_slug <- gsub("^_+|_+$", "", prov_slug)
  out_geo <- path(paths$output_dir, paste0(prov_slug, "_banio_simple.geojson"))
  out_csv <- path(paths$output_dir, paste0(prov_slug, "_banio_simple.csv"))
} else {
  out_geo <- path(paths$output_dir, "municipios_banio_simple.geojson")
  out_csv <- path(paths$output_dir, "municipios_banio_simple.csv")
}

st_write(banio_geo, out_geo, delete_dsn = TRUE, quiet = TRUE)
write_csv(st_drop_geometry(banio_geo), out_csv)

message("OK: score simple de banio guardado en ", out_geo)
message("OK: tabla simple de banio en ", out_csv)

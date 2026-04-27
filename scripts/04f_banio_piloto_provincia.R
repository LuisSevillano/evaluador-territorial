source("scripts/00_config.R")

library(sf)
library(dplyr)
library(readr)
library(fs)

sf_use_s2(FALSE)

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

has_climate <- file.exists(paths$output_clima_geojson)

codprov_target <- trimws(Sys.getenv("BANIO_CODPROV", unset = "09"))
downloads_dir <- path_expand("~/Downloads")

river_shps <- dir_ls(downloads_dir, recurse = TRUE, regexp = "DH_V0_ES[0-9]{3}.*/hi_tramocurso_l_ES[0-9]{3}\\.shp$", type = "file")
if (length(river_shps) == 0) {
  stop("No se han encontrado SHP hi_tramocurso_l_ESxxx en ~/Downloads")
}

mun <- st_read(paths$output_base_geojson, quiet = TRUE) |>
  st_make_valid() |>
  filter(codprov == codprov_target)

clima <- NULL
if (has_climate) {
  clima <- st_read(paths$output_clima_geojson, quiet = TRUE) |>
    st_drop_geometry() |>
    select(codigo, precip_annual_mm)
}

if (nrow(mun) == 0) {
  stop("No hay municipios para codprov=", codprov_target, " en municipios_base.geojson")
}

prov_name <- mun$provincia[[1]]
prov_slug <- iconv(prov_name, to = "ASCII//TRANSLIT")
prov_slug <- tolower(prov_slug)
prov_slug <- gsub("[^a-z0-9]+", "_", prov_slug)
prov_slug <- gsub("^_+|_+$", "", prov_slug)

clean_code <- function(x) {
  y <- as.character(x)
  y[y %in% c("-998", "-999", "-997", "-DE", "-NA", "-SD", "")] <- NA_character_
  y
}

to_numeric_comma <- function(x) {
  y <- clean_code(x)
  y <- gsub(",", ".", y, fixed = TRUE)
  suppressWarnings(as.numeric(y))
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

read_river_layer <- function(p) {
  demarc <- sub(".*(ES[0-9]{3}).*", "\\1", p)
  fallback_p <- sub("hi_tramocurso_l_", "hi_redtramo_l_", p)

  if (demarc == "ES091" && file.exists(fallback_p)) {
    fallback <- tryCatch(
      st_read(fallback_p, quiet = TRUE) |>
        st_make_valid() |>
        mutate(source_layer = "redtramo"),
      error = function(e) NULL
    )
    if (!is.null(fallback)) return(fallback)
  }

  main <- tryCatch(
    st_read(p, quiet = TRUE) |>
      st_make_valid() |>
      mutate(source_layer = "tramocurso"),
    error = function(e) NULL
  )
  if (!is.null(main)) return(main)

  if (!file.exists(fallback_p)) return(NULL)

  fallback <- tryCatch(
    st_read(fallback_p, quiet = TRUE) |>
      st_make_valid() |>
      mutate(source_layer = "redtramo"),
    error = function(e) NULL
  )
  if (is.null(fallback)) return(NULL)

  fallback
}

river_list <- lapply(river_shps, read_river_layer)
river_list <- river_list[!vapply(river_list, is.null, logical(1))]
if (length(river_list) == 0) {
  stop("No se pudo leer ninguna capa de rios en ~/Downloads")
}

river_raw <- bind_rows(river_list)

names(river_raw) <- tolower(names(river_raw))

keep_cols <- intersect(
  c(
    "source_layer",
    "id_demarc", "id_curso", "nombre", "tipo_curso", "tipo_red", "tipo_tramo", "ficticio", "persist",
    "condicion", "situacion", "orden", "orden_esq", "orden_amb", "ancho_max", "ancho_min",
    "marea", "longitud", "inspireid_"
  ),
  names(river_raw)
)

river <- river_raw |>
  select(any_of(keep_cols), geometry) |>
  mutate(
    id_demarc = clean_code(id_demarc),
    id_curso = clean_code(id_curso),
    nombre = clean_code(nombre),
    source_layer = ifelse(is.na(source_layer), "tramocurso", as.character(source_layer)),
    tipo_curso = clean_code(tipo_curso),
    tipo_red = clean_code(tipo_red),
    tipo_tramo = clean_code(tipo_tramo),
    persist = clean_code(persist),
    condicion = clean_code(condicion),
    situacion = clean_code(situacion),
    orden = clean_code(orden),
    orden_esq = clean_code(orden_esq),
    orden_amb = clean_code(orden_amb),
    ancho_max = to_numeric_comma(ancho_max),
    ancho_min = to_numeric_comma(ancho_min),
    longitud_attr = suppressWarnings(as.numeric(clean_code(longitud))),
    marea_num = to_int(marea),
    marea_bool = to_bool(marea),
    ficticio_bool = to_bool(ficticio)
  ) |>
  mutate(
    tipo_curso = ifelse(source_layer == "redtramo" & is.na(tipo_curso), "1001", tipo_curso),
    tipo_tramo = ifelse(source_layer == "redtramo" & is.na(tipo_tramo), "4002", tipo_tramo),
    marea_bool = ifelse(source_layer == "redtramo" & is.na(marea_bool), FALSE, marea_bool)
  )

mun_bbox <- st_bbox(st_transform(st_as_sfc(st_bbox(mun)), 4326))
river <- river |>
  st_transform(4326) |>
  st_filter(st_as_sfc(mun_bbox), .predicate = st_intersects)

is_natural <- function(tipo) {
  tipo %in% c("RIO", "1001")
}

is_persist_target <- function(persist) {
  persist %in% c("PER", "TMP", "INT", "18001", "18002")
}

is_persist_target_or_unknown_ebro <- function(persist, id_demarc, source_layer) {
  is_persist_target(persist) | (source_layer == "redtramo" & id_demarc == "ES091" & is.na(persist))
}

is_red_target <- function(tipo_red, tipo_tramo) {
  ifelse(!is.na(tipo_red), tipo_red %in% c("110", "010"), tipo_tramo %in% c("4001", "4002"))
}

river_filtered <- river |>
  filter(
    is_natural(tipo_curso),
    is_persist_target_or_unknown_ebro(persist, id_demarc, source_layer),
    is_red_target(tipo_red, tipo_tramo),
    !ficticio_bool,
    !(coalesce(marea_num == 1L, FALSE) | marea_bool)
  )

if (nrow(river_filtered) == 0) {
  stop("El filtrado inicial dejo 0 tramos para provincia ", prov_name)
}

score_persist <- c(PER = 35, TMP = 8, INT = 0, EFI = 0, "18001" = 35, "18002" = 8)
score_tipo <- c(RIO = 15, CAR = 4, CAN = 2, ACE = 1, ZAN = 0, TUB = 0, "1001" = 15, "1002" = 2, "1003" = 4, "1004" = 0)
score_red <- c("110" = 20, "010" = 6, "001" = 0, "000" = 0)
score_red_tramo <- c("4001" = 20, "4002" = 6, "4003" = 0, "4004" = 0)
score_situ <- c(NAL = 12, ENC = 8, CNX = 6, CXC = 4, CDO = 2, COR = 1, COB = 0, OCU = 0, ABA = 1, "2001" = 12, "2002" = 4, "2003" = 0)

river_scored <- river_filtered |>
  mutate(
    s_persist = coalesce(unname(score_persist[persist]), 0),
    s_tipo = coalesce(unname(score_tipo[tipo_curso]), 0),
    s_red = ifelse(!is.na(tipo_red), coalesce(unname(score_red[tipo_red]), 0), coalesce(unname(score_red_tramo[tipo_tramo]), 0)),
    s_situ = coalesce(unname(score_situ[situacion]), 0),
    ancho_ref = pmax(ancho_max, ancho_min, na.rm = TRUE),
    ancho_ref = ifelse(is.infinite(ancho_ref), NA_real_, ancho_ref),
    s_size = ifelse(is.na(ancho_ref), 0, pmin(8, 8 * ancho_ref / 12)),
    score_tramo = pmax(0, pmin(100, s_persist + s_tipo + s_red + s_situ + s_size))
  )

mun_m <- st_transform(mun, 3035)
river_m <- st_transform(river_scored, 3035)

mun_buf10 <- st_buffer(mun_m, 10000)
mun_buf20 <- st_buffer(mun_m, 20000)

hit10 <- lengths(st_intersects(mun_buf10, river_m)) > 0
hit20 <- lengths(st_intersects(mun_buf20, river_m)) > 0
dist_km <- as.numeric(st_distance(st_centroid(mun_m), river_m) |> apply(1, min, na.rm = TRUE)) / 1000

int10_seg <- st_intersection(
  mun_buf10 |> select(codigo),
  river_m |> select(score_tramo, persist, id_curso)
) |>
  mutate(seg_len = as.numeric(st_length(geometry))) |>
  st_drop_geometry()

int10_course <- int10_seg |>
  group_by(codigo, id_curso) |>
  summarise(
    course_len = sum(seg_len, na.rm = TRUE),
    course_score = weighted.mean(score_tramo, seg_len, na.rm = TRUE),
    .groups = "drop"
  )

int10_main <- int10_course |>
  group_by(codigo) |>
  summarise(
    main_course_len_10km = max(course_len, na.rm = TRUE),
    main_course_score_10km = max(course_score, na.rm = TRUE),
    .groups = "drop"
  )

int10 <- int10_seg |>
  group_by(codigo) |>
  summarise(
    len_river_10km = sum(seg_len, na.rm = TRUE),
    len_per_10km = sum(ifelse(persist %in% c("PER", "18001"), seg_len, 0), na.rm = TRUE),
    share_per_10km = ifelse(len_river_10km > 0, len_per_10km / len_river_10km, NA_real_),
    bath_score_10km = weighted.mean(score_tramo, seg_len, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(int10_main, by = "codigo")

needs20 <- mun_m |>
  st_drop_geometry() |>
  mutate(has10 = hit10, has20 = hit20) |>
  filter(!has10 & has20) |>
  select(codigo)

int20 <- tibble(codigo = character(), bath_score_20km = numeric())
if (nrow(needs20) > 0) {
  int20 <- st_intersection(
    mun_buf20 |> semi_join(needs20, by = "codigo") |> select(codigo),
    river_m |> select(score_tramo)
  ) |>
    mutate(seg_len = as.numeric(st_length(geometry))) |>
    st_drop_geometry() |>
    group_by(codigo) |>
    summarise(
      bath_score_20km = weighted.mean(score_tramo, seg_len, na.rm = TRUE),
      .groups = "drop"
    )
}

pilot <- mun_m |>
  st_drop_geometry() |>
  select(codigo, codprov, nombre, provincia) |>
  mutate(
    has_river_10km = hit10,
    has_river_20km = hit20,
    dist_river_km = round(dist_km, 2)
  )

if (!is.null(clima)) {
  pilot <- left_join(pilot, clima, by = "codigo")
}

pilot <- pilot |>
  left_join(int10, by = "codigo") |>
  left_join(int20, by = "codigo") |>
  mutate(
    has_river_10km = ifelse(!is.na(len_river_10km), len_river_10km >= 5000, has_river_10km),
    bath_score_raw_10km = 0.65 * bath_score_10km + 0.35 * main_course_score_10km,
    bath_score_raw = case_when(
      !is.na(bath_score_raw_10km) ~ bath_score_raw_10km,
      !is.na(bath_score_20km) ~ pmax(0, bath_score_20km - 10),
      TRUE ~ NA_real_
    ),
    per_penalty = case_when(
      is.na(bath_score_raw) ~ NA_real_,
      is.na(share_per_10km) ~ 6,
      share_per_10km < 0.05 ~ 8,
      share_per_10km < 0.15 ~ 4,
      TRUE ~ 0
    ),
    dist_penalty = case_when(
      is.na(bath_score_raw) ~ NA_real_,
      TRUE ~ pmin(10, dist_river_km * 0.5)
    ),
    climate_penalty = case_when(
      is.na(bath_score_raw) ~ NA_real_,
      is.na(precip_annual_mm) ~ 0,
      precip_annual_mm < 300 ~ 15,
      precip_annual_mm < 400 ~ 8,
      precip_annual_mm < 500 ~ 3,
      TRUE ~ 0
    ),
    bath_score = pmax(0, bath_score_raw - per_penalty - dist_penalty - climate_penalty),
    bath_score = round(bath_score, 1),
    bath_class = case_when(
      is.na(bath_score) ~ NA_character_,
      bath_score >= 70 ~ "alto",
      bath_score >= 40 ~ "medio",
      TRUE ~ "bajo"
    )
  )

pilot_geo <- mun_m |>
  left_join(pilot, by = c("codigo", "codprov", "nombre", "provincia")) |>
  st_transform(4326)

out_geo <- path(paths$output_dir, paste0(prov_slug, "_rios_pilot.geojson"))
out_csv <- path(paths$output_dir, paste0(prov_slug, "_rios_pilot.csv"))
out_seg <- path(paths$output_dir, paste0(prov_slug, "_rios_tramos_filtrados.geojson"))

st_write(river_scored |> st_transform(4326), out_seg, delete_dsn = TRUE, quiet = TRUE)
st_write(pilot_geo, out_geo, delete_dsn = TRUE, quiet = TRUE)
write_csv(st_drop_geometry(pilot_geo), out_csv)

message("OK: piloto provincia guardado en ", out_geo)
message("OK: tabla piloto en ", out_csv)
message("OK: tramos filtrados en ", out_seg)

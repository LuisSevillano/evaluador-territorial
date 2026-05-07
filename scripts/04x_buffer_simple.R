source("scripts/00_config.R")

library(sf)
library(dplyr)
library(stringr)

sf_use_s2(FALSE)

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] ", msg)

clean_code <- function(x) {
  y <- as.character(x)
  y[y %in% c("-998", "-999", "-997", "-DE", "-NA", "-SD", "")] <- NA_character_
  y
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

log_step("Cargando SHP Duero...")

shp_duero <- "data/raw/hydrography/DH_V0_ES020_Duero/hi_tramocurso_l_ES020.shp"
riv <- st_read(shp_duero, quiet = TRUE)
names(riv) <- tolower(names(riv))

if (!"ficticio" %in% names(riv)) riv$ficticio <- NA_character_
if (!"canaliza" %in% names(riv)) riv$canaliza <- NA_character_

riv <- riv |>
  mutate(
    nombre = clean_code(nombre),
    name_norm = normalize_name(nombre),
    tipo_curso = clean_code(tipo_curso),
    origen = clean_code(origen),
    persist_num = to_int(persist),
    ancho_max_num = to_numeric_comma(ancho_max),
    is_ficticio = tolower(trimws(as.character(ficticio))) == "t",
    is_canalizado = tolower(trimws(as.character(canaliza))) == "t",
    es_natural_origen = origen == "8001",
    es_artificial_origen = origen == "8002",
    es_natural_tipo = tipo_curso == "1001"
  )

artificial_like <- str_detect(
  riv$name_norm,
  "(^|[[:space:][:punct:]])(canal|acequia|azequia|cacera|caz|cauce artificial|zanja|dren|drenaje|desague|colector|emisario|tuberia|cuneta|aliviadero|sifon)([[:space:][:punct:]]|$)"
)

riv <- riv |>
  mutate(
    is_artificial = artificial_like | es_artificial_origen,
    is_temporal = persist_num %in% c(18002L, 18003L),
    is_permanent = persist_num == 18001L,
    clase_banio = case_when(
      es_natural_tipo & es_natural_origen & is_permanent & !is_canalizado & !is_ficticio & !is.na(ancho_max_num) & ancho_max_num >= 20 ~ "rio_grande_permanente",
      es_natural_tipo & es_natural_origen & is_permanent & !is_canalizado & !is_ficticio ~ "rio_permanente_revision",
      es_natural_tipo & es_natural_origen & is_temporal & !is_canalizado & !is_ficticio ~ "rio_temporal_baja_confianza",
      is_artificial | is_canalizado | is_ficticio | is_temporal ~ "descartar",
      TRUE ~ "descartar"
    )
  )

log_step("Resumen:")
print(riv |> st_drop_geometry() |> count(clase_banio, name = "n"))

log_step("Procesando cada clase...")

for (clase in c("rio_grande_permanente", "rio_permanente_revision", "rio_temporal_baja_confianza")) {
  
  riv_cl <- riv |> 
    filter(clase_banio == clase) |>
    st_transform(3857)
  
  if (nrow(riv_cl) == 0) next
  
  buffer_m <- switch(clase,
    rio_grande_permanente = 10000,
    rio_permanente_revision = 5000,
    rio_temporal_baja_confianza = 2000
  )
  
  log_step(paste0("Clase: ", clase, " (", nrow(riv_cl), " segmentos)"))
  log_step("  Buffer individual (cada segmento)...")
  
  buf <- st_buffer(riv_cl, buffer_m)
  
  log_step("  Combinando geometries (st_union)...")
  buf_union <- st_union(buf)
  
  log_step("  Convertir a POLYGON...")
  buf_sf <- st_sf(geometry = buf_union) |>
    st_transform(4326) |>
    st_zm(drop = TRUE) |>
    mutate(
      clase = clase,
      buffer_m = buffer_m,
      area_km2 = round(as.numeric(st_area(buf_union)) / 1e6, 2)
    )
  
  log_step(paste0("  Área: ", buf_sf$area_km2, " km²"))
  
  fname <- paste0("output/rios_duero_buffer_", gsub("_", "_", clase), ".shp")
  st_write(buf_sf, fname, delete_dsn = TRUE, quiet = FALSE)
  log_step(paste0("  Guardado: ", fname))
}

message("\n=== SHP GENERADOS ===")
message("- output/rios_duero_buffer_rio_grande_permanente.shp")
message("- output/rios_duero_buffer_rio_permanente_revision.shp")
message("- output/rios_duero_buffer_rio_temporal_baja_confianza.shp")
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

log_step(paste0("Total tramos: ", nrow(riv)))

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
summary <- riv |> st_drop_geometry() |> group_by(clase_banio) |> summarise(n = n(), .groups = "drop")
print(summary)

rios_sel <- riv |> filter(clase_banio != "descartar")
log_step(paste0("Seleccionados: ", nrow(rios_sel)))

log_step("Convertir a 2D...")
rios_sel <- st_zm(rios_sel, drop = TRUE)

log_step("Exportando ríos clasificados a SHP...")
st_write(rios_sel, "output/rios_duero_clasificados.shp", delete_dsn = TRUE, quiet = TRUE)
log_step("Guardado: output/rios_duero_clasificados.shp")

log_step("Generando buffers a SHP...")
buffer_m <- c(
  rio_grande_permanente = 10000,
  rio_permanente_revision = 5000,
  rio_temporal_baja_confianza = 2000
)

for (cl in names(buffer_m)) {
  riv_cl <-rios_sel |> filter(clase_banio == cl)
  if (nrow(riv_cl) == 0) next
  
  log_step(paste0("Buffer ", cl, " (", buffer_m[[cl]], "m)..."))
  
  buf <- st_buffer(st_transform(riv_cl, 3857), buffer_m[[cl]]) |>
    st_transform(4326) |>
    st_zm(drop = TRUE)
  
  st_write(buf, "output/rios_duero_buffers.shp", delete_dsn = TRUE, quiet = TRUE)
  log_step(paste0("Guardado: output/rios_duero_buffers.shp"))
  
  break
}

message("\n=== ARCHIVOS SHP ===")
message("- output/rios_duero_clasificados.shp: Ríos clasificados")
message("- output/rios_duero_buffers.shp: Buffers")
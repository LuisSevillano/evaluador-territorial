source("scripts/00_config.R")

library(sf)
library(dplyr)
library(ggplot2)
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

normalize_line_geometry <- function(sf_obj) {
  if (nrow(sf_obj) == 0) return(sf_obj)
  out <- sf_obj
  gtype <- unique(as.character(st_geometry_type(out, by_geometry = TRUE)))
  if (any(gtype %in% c("CURVE", "MULTICURVE", "COMPOUNDCURVE"))) {
    out <- tryCatch(st_cast(out, "MULTILINESTRING"), error = function(e) out)
  }
  out
}

log_step("Cargando solo Duero para ejemplo rápido...")

shp_duero <- "data/raw/hydrography/DH_V0_ES020_Duero/hi_tramocurso_l_ES020.shp"
if (!file.exists(shp_duero)) {
  stop("No encontrado: ", shp_duero)
}

log_step("Leyendo SHP Duero...")
riv <- st_read(shp_duero, quiet = TRUE)
names(riv) <- tolower(names(riv))

log_step(paste0("Total tramos Duero: ", nrow(riv)))

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

log_step("Resumen clasificación Duero:")
summary <- riv |> st_drop_geometry() |> group_by(clase_banio) |> summarise(n = n(), .groups = "drop")
print(summary)

log_step("Filtrando seleccionados...")
rios_sel <- riv |> filter(clase_banio != "descartar")
log_step(paste0("Ríos seleccionados: ", nrow(rios_sel)))

log_step("Plot de ríos Duero clasificados...")
p <- ggplot() +
  geom_sf(data = riv |> filter(clase_banio == "descartar"), aes(color = clase_banio), alpha = 0.15, linewidth = 0.2) +
  geom_sf(data = rios_sel |> filter(clase_banio == "rio_temporal_baja_confianza"), aes(color = clase_banio), alpha = 0.5, linewidth = 0.3) +
  geom_sf(data = rios_sel |> filter(clase_banio == "rio_permanente_revision"), aes(color = clase_banio), alpha = 0.7, linewidth = 0.5) +
  geom_sf(data = rios_sel |> filter(clase_banio == "rio_grande_permanente"), aes(color = clase_banio), alpha = 0.9, linewidth = 0.8) +
  scale_color_manual(
    values = c("descartar" = "gray80", "rio_temporal_baja_confianza" = "orange1", "rio_permanente_revision" = "green3", "rio_grande_permanente" = "blue2"),
    name = "Clase"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(
    title = "Ríos Duero - Clasificación para baño",
    caption = "Fuente: IGN/CNIG"
  )

ggsave("output/rios_duero_plot.png", p, width = 10, height = 8, dpi = 150)
log_step("Plot guardado: output/rios_duero_plot.png")

log_step("Exportando ríos Duero clasificados...")
st_write(rios_sel, "output/rios_duero_clasificados.geojson", delete_dsn = TRUE, quiet = TRUE)
log_step("Guardado: output/rios_duero_clasificados.geojson")

log_step("Generando buffers...")
buffer_m <- c(
  rio_grande_permanente = 10000,
  rio_permanente_revision = 5000,
  rio_temporal_baja_confianza = 2000
)

buffers_list <- list()
for (cl in names(buffer_m)) {
  riv_cl <-rios_sel |> filter(clase_banio == cl)
  if (nrow(riv_cl) == 0) next
  
  log_step(paste0("Buffer ", cl, " (", buffer_m[[cl]], "m)...", nrow(riv_cl), " tramos"))
  buf <- st_buffer(st_transform(riv_cl, 3857), buffer_m[[cl]]) |>
    st_transform(4326) |>
    mutate(buffer_m = buffer_m[[cl]], clase = cl)
  buffers_list[[length(buffers_list) + 1]] <- buf
}

if (length(buffers_list) > 0) {
  buffers_all <- do.call(rbind, buffers_list)
  st_write(buffers_all, "output/rios_duero_buffers.geojson", delete_dsn = TRUE, quiet = TRUE)
  log_step("Buffers guardados: output/rios_duero_buffers.geojson")
  
  log_step("Plot con buffers...")
  p_buf <- ggplot() +
    geom_sf(data = buffers_all, aes(fill = clase), alpha = 0.2) +
    geom_sf(data =rios_sel, aes(color = clase_banio), alpha = 0.8, linewidth = 0.4) +
    scale_fill_manual(values = c("rio_grande_permanente" = "blue", "rio_permanente_revision" = "green", "rio_temporal_baja_confianza" = "orange"), name = "Buffer") +
    scale_color_manual(values = c("rio_grande_permanente" = "blue4", "rio_permanente_revision" = "green4", "rio_temporal_baja_confianza" = "orange3"), name = "Río") +
    theme_minimal() +
    theme(legend.position = "bottom") +
    labs(
      title = "Ríos Duero + Buffers para baño",
      subtitle = "Buffers: 10km (grande), 5km (permanente), 2km (temporal)",
      caption = "Fuente: IGN/CNIG"
    )
  
  ggsave("output/rios_duero_buffers_plot.png", p_buf, width = 12, height = 8, dpi = 150)
  log_step("Plot: output/rios_duero_buffers_plot.png")
}

message("\n=== ARCHIVOS GENERADOS (Duero) ===")
message("- output/rios_duero_clasificados.geojson")
message("- output/rios_duero_buffers.geojson")
message("- output/rios_duero_plot.png")
message("- output/rios_duero_buffers_plot.png")
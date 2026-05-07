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

log_step("Buscando SHP de hidrografía...")

tramocurso_shps <- dir_ls(
  path(project_root, "data", "raw", "hydrography"),
  recurse = TRUE,
  regexp = "DH_V0_ES[0-9]{3}.*/hi_tramocurso_l_ES[0-9]{3}\\.shp$",
  type = "file"
)

log_step(paste0("Encontrados: ", length(tramocurso_shps), " SHP"))

read_hydro <- function(shp_path) {
  out <- tryCatch(
    st_read(shp_path, quiet = TRUE) |>
      mutate(source_layer = "tramocurso"),
    error = function(e) NULL
  )
  if (is.null(out)) return(NULL)
  names(out) <- tolower(names(out))
  
  if (!"ficticio" %in% names(out)) out$ficticio <- NA_character_
  if (!"canaliza" %in% names(out)) out$canaliza <- NA_character_
  
  out <- out |>
    mutate(
      id_curso = clean_code(id_curso),
      nombre = clean_code(nombre),
      name_norm = normalize_name(nombre),
      tipo_curso = clean_code(tipo_curso),
      origen = clean_code(origen),
      persist_num = to_int(persist),
      orden_num = to_int(orden),
      ancho_max_num = to_numeric_comma(ancho_max),
      is_ficticio = tolower(trimws(as.character(ficticio))) == "t",
      is_canalizado = tolower(trimws(as.character(canaliza))) == "t",
      es_natural_origen = origen == "8001",
      es_artificial_origen = origen == "8002",
      es_natural_tipo = tipo_curso == "1001"
    )
  normalize_line_geometry(out)
}

ris_clasificados <- list()
for (shp_file in tramocurso_shps) {
  riv <- read_hydro(shp_file)
  if (is.null(riv) || nrow(riv) == 0) next
  
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
  
  ris_clasificados[[length(ris_clasificados) + 1]] <- riv
  log_step(paste0(basename(shp_file), ": ", nrow(riv), " tramos"))
}

rios_all <- do.call(rbind, ris_clasificados)
log_step(paste0("Total tramos: ", nrow(rios_all)))

rios_selected <-rios_all |> filter(clase_banio != "descartar")
log_step(paste0("Tramos seleccionados para bathe: ", nrow(rios_selected)))

log_step("Géneroso plot...")
p <- ggplot() +
  geom_sf(data =rios_all |> filter(clase_banio == "descartar"), aes(color = clase_banio), alpha = 0.2, linewidth = 0.2) +
  geom_sf(data =rios_selected |> filter(clase_banio == "rio_temporal_baja_confianza"), aes(color = clase_banio), alpha = 0.5, linewidth = 0.3) +
  geom_sf(data =rios_selected |> filter(clase_banio == "rio_permanente_revision"), aes(color = clase_banio), alpha = 0.7, linewidth = 0.5) +
  geom_sf(data =rios_selected |> filter(clase_banio == "rio_grande_permanente"), aes(color = clase_banio), alpha = 0.9, linewidth = 0.8) +
  scale_color_manual(
    values = c(
      "descartar" = "gray70",
      "rio_temporal_baja_confianza" = "orange1",
      "rio_permanente_revision" = "green3",
      "rio_grande_permanente" = "blue2"
    ),
    labels = c(
      "descartar" = "Descartar",
      "rio_temporal_baja_confianza" = "Temporal/Baja confianza",
      "rio_permanente_revision" = "Permanente (revisión)",
      "rio_grande_permanente" = "Grande/Permanente"
    ),
    name = "Clase"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(
    title = "Ríos clasificados para acceso a baño",
    subtitle = paste0("Scope: ", analysis_scope),
    caption = " IGN/CNIG hidrografía"
  )

ggsave("output/rios_clasificados_plot.png", p, width = 12, height = 10, dpi = 150)
log_step("Plot guardado: output/rios_clasificados_plot.png")

log_step("Exportando ríos clasificados...")
st_write(rios_selected, "output/rios_clasificados_banio.geojson", delete_dsn = TRUE, quiet = TRUE)
log_step("Guardado: output/rios_clasificados_banio.geojson")

log_step("Generando buffers...")
buffer_m <- c(
  rio_grande_permanente = 10000,
  rio_permanente_revision = 5000,
  rio_temporal_baja_confianza = 2000
)

buffers <- list()
for (cl in names(buffer_m)) {
  riv_cl <-rios_selected |> filter(clase_banio == cl)
  if (nrow(riv_cl) == 0) next
  
  buf <- st_buffer(st_transform(riv_cl, 3857), buffer_m[[cl]]) |>
    st_transform(4326) |>
    mutate(buffer_m = buffer_m[[cl]])
  buffers[[length(buffers) + 1]] <- buf
  log_step(paste0(cl, ": ", nrow(buf), " polígonos buffer (", buffer_m[[cl]], "m)"))
}

if (length(buffers) > 0) {
  buffers_all <- do.call(rbind, buffers)
  st_write(buffers_all, "output/rios_buffers_banio.geojson", delete_dsn = TRUE, quiet = TRUE)
  log_step("Buffers guardados: output/rios_buffers_banio.geojson")
  
  log_step("Plot con buffers...")
  p_buf <- ggplot() +
    geom_sf(data = buffers_all, aes(fill = clase_banio), alpha = 0.15) +
    geom_sf(data =rios_selected, aes(color = clase_banio), alpha = 0.7, linewidth = 0.3) +
    scale_fill_manual(
      values = c(
        "rio_grande_permanente" = "blue2",
        "rio_permanente_revision" = "green3",
        "rio_temporal_baja_confianza" = "orange1"
      ),
      name = "Buffer"
    ) +
    scale_color_manual(
      values = c(
        "rio_grande_permanente" = "blue4",
        "rio_permanente_revision" = "green4",
        "rio_temporal_baja_confianza" = "orange3"
      ),
      name = "Río"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom") +
    labs(
      title = "Ríos y buffers para acceso a baño",
      subtitle = paste0("Buffers: 10km (grande), 5km (permanente), 2km (temporal)"),
      caption = "Fuente: IGN/CNIG"
    )
  
  ggsave("output/rios_buffers_plot.png", p_buf, width = 14, height = 10, dpi = 150)
  log_step("Plot con buffers: output/rios_buffers_plot.png")
}

log_step("Resumo de clasificación:")
summary <- summarise(group_by(st_drop_geometry(rios_all), clase_banio), n = n(), .groups = "drop")
print(summary)

message("\n=== ARCHIVOS GENERADOS ===")
message("- output/rios_clasificados_banio.geojson: Ríos clasificados")
message("- output/rios_buffers_banio.geojson: Buffers de bathe")
message("- output/rios_clasificados_plot.png: Plot de ríos")
message("- output/rios_buffers_plot.png: Plot con buffers")
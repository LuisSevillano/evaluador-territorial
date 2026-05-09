source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(fs)
})

sf_use_s2(FALSE)

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [summer-rivers] ", msg)

cache_candidates <- path(paths$rivers_cache_dir, "banio_access", paste0("scope_", analysis_scope, "_rivers_candidates.rds"))

if (!file.exists(cache_candidates)) {
  stop(
    "No existe cache de candidatos fluviales: ", cache_candidates,
    ". Ejecuta primero scripts/04g_banio_score_simple.R o scripts/run_bathing_hybrid_update.sh"
  )
}

if (!file.exists(paths$output_base_geojson)) {
  stop("No existe municipios_base.geojson. Ejecuta primero scripts/01_municipios_base.R")
}

log_step("Cargando candidatos fluviales cacheados")
rivers <- readRDS(cache_candidates) |>
  st_make_valid() |>
  st_transform(25830) |>
  filter(!st_is_empty(geometry))

if (nrow(rivers) == 0) {
  stop("La cache de candidatos fluviales esta vacia")
}

if (!"id_demarc" %in% names(rivers)) rivers$id_demarc <- NA_character_
if (!"id_curso" %in% names(rivers)) rivers$id_curso <- NA_character_
if (!"name_norm" %in% names(rivers)) rivers$name_norm <- NA_character_
if (!"nombre" %in% names(rivers)) rivers$nombre <- NA_character_
if (!"persist_txt" %in% names(rivers)) rivers$persist_txt <- NA_character_
if (!"orden_num" %in% names(rivers)) rivers$orden_num <- NA_integer_
if (!"ancho_max_num" %in% names(rivers)) rivers$ancho_max_num <- NA_real_
if (!"ancho_min_num" %in% names(rivers)) rivers$ancho_min_num <- NA_real_
if (!"has_codmasa" %in% names(rivers)) rivers$has_codmasa <- FALSE
if (!"dma_flag" %in% names(rivers)) rivers$dma_flag <- FALSE
if (!"name_has_rio" %in% names(rivers)) rivers$name_has_rio <- FALSE
if (!"name_in_whitelist" %in% names(rivers)) rivers$name_in_whitelist <- FALSE
if (!"artificial_like" %in% names(rivers)) rivers$artificial_like <- FALSE
if (!"ephemeral_like" %in% names(rivers)) rivers$ephemeral_like <- FALSE
if (!"tidal_like" %in% names(rivers)) rivers$tidal_like <- FALSE
if (!"river_confidence" %in% names(rivers)) rivers$river_confidence <- 50

rivers <- rivers |>
  mutate(
    course_key = if_else(
      !is.na(id_demarc) & !is.na(id_curso),
      paste(id_demarc, id_curso, sep = "_"),
      if_else(!is.na(name_norm) & name_norm != "", name_norm, paste0("row_", row_number()))
    ),
    segment_length_m = as.numeric(st_length(geometry))
  )

course_lengths <- rivers |>
  st_drop_geometry() |>
  group_by(course_key) |>
  summarise(course_length_m = sum(segment_length_m, na.rm = TRUE), .groups = "drop")

log_step("Calculando confianza de caudal estival probable")
candidates <- rivers |>
  left_join(course_lengths, by = "course_key") |>
  mutate(
    permanent_signal = persist_txt %in% c("18001", "per", "permanente", "permanent"),
    unknown_persist = is.na(persist_txt) | persist_txt == "",
    waterbody_signal = coalesce(has_codmasa, FALSE) | coalesce(dma_flag, FALSE),
    order_signal = case_when(
      !is.na(orden_num) & orden_num >= 4 ~ 20,
      !is.na(orden_num) & orden_num >= 3 ~ 15,
      !is.na(orden_num) & orden_num >= 2 ~ 5,
      TRUE ~ 0
    ),
    width_signal = case_when(
      !is.na(ancho_max_num) & ancho_max_num >= 12 ~ 12,
      !is.na(ancho_max_num) & ancho_max_num >= 8 ~ 10,
      !is.na(ancho_min_num) & ancho_min_num >= 4 ~ 8,
      TRUE ~ 0
    ),
    course_length_signal = case_when(
      course_length_m >= 50000 ~ 15,
      course_length_m >= 20000 ~ 10,
      course_length_m >= 10000 ~ 5,
      TRUE ~ 0
    ),
    summer_flow_confidence_raw = 10 +
      ifelse(permanent_signal, 30, 0) +
      ifelse(waterbody_signal, 20, 0) +
      order_signal +
      width_signal +
      course_length_signal +
      ifelse(coalesce(name_has_rio, FALSE), 5, 0) +
      ifelse(coalesce(name_in_whitelist, FALSE), 8, 0) +
      pmin(8, pmax(0, coalesce(as.numeric(river_confidence), 0) - 60) / 5) -
      ifelse(unknown_persist, 15, 0) -
      ifelse(coalesce(ephemeral_like, FALSE), 50, 0) -
      ifelse(coalesce(artificial_like, FALSE), 70, 0) -
      ifelse(coalesce(tidal_like, FALSE), 100, 0),
    summer_flow_confidence = pmax(0, pmin(100, summer_flow_confidence_raw)),
    summer_flow_class = case_when(
      summer_flow_confidence >= 85 ~ "fuerte",
      summer_flow_confidence >= 65 ~ "medio",
      summer_flow_confidence >= 50 ~ "debil",
      TRUE ~ "descartar"
    ),
    exclusion_reason = case_when(
      summer_flow_class != "descartar" ~ "candidate",
      coalesce(tidal_like, FALSE) ~ "tidal",
      coalesce(artificial_like, FALSE) ~ "artificial_like",
      coalesce(ephemeral_like, FALSE) ~ "ephemeral_like",
      summer_flow_confidence < 40 ~ "low_summer_flow_confidence",
      TRUE ~ "other"
    )
  ) |>
  filter(summer_flow_class != "descartar")

if (nrow(candidates) == 0) {
  stop("No quedan candidatos de caudal estival tras aplicar el filtro")
}

summary_tbl <- candidates |>
  st_drop_geometry() |>
  count(summer_flow_class, name = "segments") |>
  left_join(
    candidates |>
      st_drop_geometry() |>
      group_by(summer_flow_class) |>
      summarise(
        median_confidence = round(median(summer_flow_confidence, na.rm = TRUE), 1),
        p75_confidence = round(as.numeric(quantile(summer_flow_confidence, 0.75, na.rm = TRUE)), 1),
        .groups = "drop"
      ),
    by = "summer_flow_class"
  ) |>
  arrange(desc(median_confidence))

log_step("Escribiendo artefactos")
st_write(candidates |> st_transform(4326), paths$output_river_summer_candidates_geojson, delete_dsn = TRUE, quiet = TRUE)
saveRDS(candidates, paths$output_river_summer_candidates_rds)
write_csv(summary_tbl, paths$output_river_summer_summary_csv)

message("OK: candidatos estivales en ", paths$output_river_summer_candidates_geojson)
print(summary_tbl)

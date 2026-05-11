source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(fs)
  library(stringr)
})

sf_use_s2(FALSE)

if (!file.exists(paths$output_clima_geojson)) {
  stop("No existe municipios_clima.geojson. Ejecuta primero scripts/02_clima_real.R")
}

mfe_root <- path(project_root, "data", "raw", "mfe")
if (!dir_exists(mfe_root)) {
  stop("No existe data/raw/mfe")
}

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [mfe] ", msg)

normalize_text <- function(x) {
  y <- as.character(x)
  y[is.na(y)] <- ""
  y <- tolower(y)
  y <- iconv(y, to = "ASCII//TRANSLIT")
  y[is.na(y)] <- ""
  str_squish(y)
}

pick_first <- function(df, candidates) {
  hit <- intersect(candidates, names(df))
  if (length(hit) == 0) return(NULL)
  hit[[1]]
}

prov_mfe_map <- list(
  "05" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Ávila"),
  "09" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Burgos"),
  "24" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "León"),
  "34" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Palencia"),
  "37" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Salamanca"),
  "39" = list(dir = "mfe_cantabria", file = "MFE_13.shp", nut3 = "Cantabria"),
  "40" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Segovia"),
  "42" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Soria"),
  "47" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Valladolid"),
  "48" = list(dir = "mfe_pais_vasco", file = "MFE_21.shp", nut3 = "Bizkaia"),
  "49" = list(dir = "mfe_castillayleon", file = "MFE_41.shp", nut3 = "Zamora"),
  "01" = list(dir = "mfe_pais_vasco", file = "MFE_21.shp", nut3 = "Araba/Álava"),
  "20" = list(dir = "mfe_pais_vasco", file = "MFE_21.shp", nut3 = "Gipuzkoa"),
  "26" = list(dir = "mfe_larioja", file = "MFE_23.shp", nut3 = "La Rioja"),
  "28" = list(dir = "mfe_madrid", file = "MFE_30.shp", nut3 = "Madrid"),
  "33" = list(dir = "mfe_principadodeasturias", file = "MFE_12.shp", nut3 = "Asturias"),
  "27" = list(dir = "mfe_galicia", file = "MFE_11.shp", nut3 = "Lugo"),
  "32" = list(dir = "mfe_galicia", file = "MFE_11.shp", nut3 = "Ourense"),
  "19" = list(dir = "MFE_42", file = "mFE_42.shp", nut3 = "Guadalajara")
)

build_targets <- function(scope_cfg) {
  codprov <- scope_cfg[["codprov"]]
  if (!is.null(codprov)) {
    cfg <- prov_mfe_map[[codprov]]
    if (is.null(cfg)) stop("Sin mapping MFE para codprov ", codprov)
    return(list(list(codprov = codprov, cfg = cfg)))
  }

  cods <- unique(c(
    c("05", "09", "24", "34", "37", "39", "40", "42", "47", "48", "49", "01", "20", "26", "33"),
    scope_cfg[["codprov_include"]]
  ))
  missing_map <- setdiff(cods, names(prov_mfe_map))
  if (length(missing_map) > 0) {
    stop("Sin mapping MFE para codprov: ", paste(missing_map, collapse = ", "))
  }
  lapply(cods, function(cp) list(codprov = cp, cfg = prov_mfe_map[[cp]]))
}

log_step("Cargando municipios base de entorno")
municipios <- st_read(paths$output_clima_geojson, quiet = TRUE)
mun_aea <- municipios |>
  st_make_valid() |>
  st_transform(3035) |>
  mutate(mun_id = .data$codigo)

targets <- build_targets(scope_config)
if (length(targets) == 0) stop("No hay objetivos MFE para scope actual")
log_step(paste0("Objetivos MFE: ", length(targets), " provincias"))

inter_parts <- list()

for (idx in seq_along(targets)) {
  t <- targets[[idx]]
  fp <- path(mfe_root, t$cfg$dir, t$cfg$file)
  if (!file_exists(fp)) {
    log_step(paste0("Skip (faltante): ", fp))
    next
  }

  layer_name <- gsub("\\.shp$", "", t$cfg$file)
  where_sql <- paste0("PRO_F = ", as.integer(t$codprov))
  sql <- paste0("SELECT * FROM ", layer_name, " WHERE ", where_sql)
  log_step(paste0("[", idx, "/", length(targets), "] ", basename(fp), " | ", where_sql))

  mfe <- tryCatch(st_read(fp, query = sql, quiet = TRUE), error = function(e) NULL)
  if (is.null(mfe) || nrow(mfe) == 0) {
    log_step("  sin registros tras filtro")
    next
  }

  # Normaliza columnas de especies sin crear nombres duplicados
  if (!"O1" %in% names(mfe)) {
    src <- intersect(c("n_sp1", "sp1_"), names(mfe))
    if (length(src) > 0) mfe$O1 <- suppressWarnings(as.numeric(mfe[[src[[1]]]]))
  }
  if (!"O2" %in% names(mfe)) {
    src <- intersect(c("n_sp2", "sp2_"), names(mfe))
    if (length(src) > 0) mfe$O2 <- suppressWarnings(as.numeric(mfe[[src[[1]]]]))
  }
  if (!"O3" %in% names(mfe)) {
    src <- intersect(c("n_sp3", "sp3_"), names(mfe))
    if (length(src) > 0) mfe$O3 <- suppressWarnings(as.numeric(mfe[[src[[1]]]]))
  }

  uso_col <- pick_first(mfe, c("UsoMFE", "USOMFE", "usoMFE", "uso"))
  fccarb_col <- pick_first(mfe, c("FCCARB", "fccarb"))
  if (is.null(uso_col)) {
    log_step("  skip: sin columna UsoMFE")
    next
  }

  mfe <- mfe |>
    st_make_valid() |>
    st_transform(3035) |>
    mutate(
      uso_mfe = as.character(.data[[uso_col]]),
      uso_mfe_norm = normalize_text(.data[[uso_col]]),
      fccarb_raw = if (!is.null(fccarb_col)) suppressWarnings(as.numeric(.data[[fccarb_col]])) else NA_real_,
      fccarb_pct = pmax(0, pmin(100, coalesce(fccarb_raw, 0))),
      fccarb_norm = fccarb_pct / 100,
      o1 = coalesce(suppressWarnings(as.numeric(if ("O1" %in% names(mfe)) .data[["O1"]] else NA_real_)), 0),
      o2 = coalesce(suppressWarnings(as.numeric(if ("O2" %in% names(mfe)) .data[["O2"]] else NA_real_)), 0),
      o3 = coalesce(suppressWarnings(as.numeric(if ("O3" %in% names(mfe)) .data[["O3"]] else NA_real_)), 0),
      species_weights_sum = o1 + o2 + o3,
      p1 = ifelse(species_weights_sum > 0, o1 / species_weights_sum, 0),
      p2 = ifelse(species_weights_sum > 0, o2 / species_weights_sum, 0),
      p3 = ifelse(species_weights_sum > 0, o3 / species_weights_sum, 0),
      species_div_poly = {
        h <- -(ifelse(p1 > 0, p1 * log(p1), 0) + ifelse(p2 > 0, p2 * log(p2), 0) + ifelse(p3 > 0, p3 * log(p3), 0))
        pmin(1, pmax(0, h / log(3)))
      },
      is_forest = str_detect(uso_mfe_norm, "arbolado"),
      is_water = str_detect(uso_mfe_norm, "agua"),
      is_artificial = str_detect(uso_mfe_norm, "artificial"),
      is_crop = str_detect(uso_mfe_norm, "cultivo"),
      is_ralo = str_detect(uso_mfe_norm, "ralo"),
      is_disperso = str_detect(uso_mfe_norm, "disperso")
    ) |>
    select(uso_mfe_norm, fccarb_norm, species_div_poly, is_forest, is_water, is_artificial, is_crop, is_ralo, is_disperso)

  inter <- suppressWarnings(st_intersection(mun_aea |> select(mun_id), mfe))
  if (nrow(inter) == 0) {
    rm(mfe, inter)
    gc(verbose = FALSE)
    next
  }
  inter_parts[[length(inter_parts) + 1]] <- inter
  rm(mfe, inter)
  gc(verbose = FALSE)
}

if (length(inter_parts) == 0) {
  stop("No hay interseccion entre municipios y MFE")
}

log_step("Combinando intersecciones por provincia")
inter_all <- do.call(rbind, inter_parts)
rm(inter_parts)
gc(verbose = FALSE)

inter_tbl <- inter_all |>
  mutate(area_m2 = as.numeric(st_area(geometry))) |>
  st_drop_geometry() |>
  group_by(mun_id) |>
  mutate(total_area = sum(area_m2, na.rm = TRUE), share = ifelse(total_area > 0, area_m2 / total_area, 0)) |>
  ungroup()

diversity_tbl <- inter_tbl |>
  group_by(mun_id, uso_mfe_norm) |>
  summarise(code_share = sum(share, na.rm = TRUE), .groups = "drop_last") |>
  summarise(shannon = -sum(ifelse(code_share > 0, code_share * log(code_share), 0), na.rm = TRUE), .groups = "drop") |>
  mutate(landcover_diversity = pmin(100, pmax(0, 100 * shannon / log(7)))) |>
  select(mun_id, landcover_diversity)

summary_tbl <- inter_tbl |>
  summarise(
    forest_pct = 100 * sum(share[is_forest], na.rm = TRUE),
    water_pct = 100 * sum(share[is_water], na.rm = TRUE),
    artificial_pct = 100 * sum(share[is_artificial], na.rm = TRUE),
    crop_pct = 100 * sum(share[is_crop], na.rm = TRUE),
    tree_cover_score = 100 * sum(share * fccarb_norm, na.rm = TRUE),
    structure_score = 100 * sum(share * ifelse(is_forest & is_ralo, 0.6, ifelse(is_forest & is_disperso, 0.4, ifelse(is_forest, 1, 0))), na.rm = TRUE),
    species_div_score = 100 * sum(share * species_div_poly, na.rm = TRUE),
    .by = mun_id
  ) |>
  left_join(diversity_tbl, by = "mun_id") |>
  mutate(
    landcover_diversity = coalesce(landcover_diversity, 0),
    forest_nature_quality = pmin(1, pmax(0,
      0.45 * (tree_cover_score / 100) +
      0.25 * (structure_score / 100) +
      0.20 * (species_div_score / 100) +
      0.10 * (landcover_diversity / 100)
    )),
    naturality_index = pmin(100, pmax(0,
      0.55 * (forest_nature_quality * 100) +
      0.20 * water_pct +
      0.15 * landcover_diversity -
      0.20 * artificial_pct -
      0.10 * crop_pct
    ))
  ) |>
  select(mun_id, forest_pct, water_pct, artificial_pct, landcover_diversity, naturality_index, forest_nature_quality)

municipios <- municipios |>
  left_join(summary_tbl, by = c("codigo" = "mun_id"))

log_step("Escribiendo salidas de entorno")
st_write(municipios, paths$output_entorno_geojson, delete_dsn = TRUE, quiet = TRUE)

feature_tbl <- summary_tbl |>
  transmute(codigo = mun_id, forest_nature_quality, water_pct)
saveRDS(feature_tbl, paths$output_feature_mfe_rds)
try(arrow::write_parquet(feature_tbl, paths$output_feature_mfe_parquet), silent = TRUE)

log_step("OK: indicadores de entorno MFE generados")

source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(arrow)
  library(fs)
  library(stringr)
})

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [grid] ", msg)

sf_use_s2(FALSE)
use_bathing_sources <- identical(Sys.getenv("PIPELINE_USE_BATHING_SOURCES", unset = "0"), "1")
grid_fast_mode <- identical(Sys.getenv("PIPELINE_GRID_FAST", unset = "1"), "1")

if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson. Ejecuta primero el pipeline hasta ensamblado.")
}

bucket_to_rank <- function(bucket) {
  recode(
    bucket,
    "<=1h30" = 1L,
    "<=2h00" = 2L,
    "<=2h30" = 3L,
    "<=3h30" = 4L,
    "<=4h00" = 5L,
    ">4h00" = 6L,
    .default = NA_integer_
  )
}

rank_to_bucket <- function(rank) {
  recode(
    as.character(rank),
    "1" = "<=1h30",
    "2" = "<=2h00",
    "3" = "<=2h30",
    "4" = "<=3h30",
    "5" = "<=4h00",
    "6" = ">4h00",
    .default = NA_character_
  )
}

mode_int <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_integer_)
  tb <- table(x)
  as.integer(names(tb)[which.max(tb)])
}

round_idx <- function(x) round(x, 3)

minmax_norm <- function(x, invert = FALSE) {
  x <- suppressWarnings(as.numeric(x))
  valid <- is.finite(x)
  out <- rep(NA_real_, length(x))
  if (!any(valid)) return(out)
  xv <- x[valid]
  xmin <- min(xv, na.rm = TRUE)
  xmax <- max(xv, na.rm = TRUE)
  if (!is.finite(xmin) || !is.finite(xmax) || xmax <= xmin) {
    out[valid] <- 0.5
  } else {
    out[valid] <- (xv - xmin) / (xmax - xmin)
  }
  if (invert) out <- 1 - out
  pmax(0, pmin(1, out))
}

log_step("Cargando municipios")
mun_sf <- st_read(paths$output_final_geojson, quiet = TRUE)

if (!"river_access_score" %in% names(mun_sf)) {
  mun_sf$river_access_score <- NA_real_
}
if (!"river_method_version" %in% names(mun_sf)) {
  mun_sf$river_method_version <- NA_character_
}
if (!"forest_nature_quality" %in% names(mun_sf)) {
  mun_sf$forest_nature_quality <- NA_real_
}
if (!"travel_bucket" %in% names(mun_sf)) {
  mun_sf$travel_bucket <- NA_character_
}

mun_sf <- mun_sf |>
  st_transform(25830) |>
  select(
    codigo,
    nombre,
    provincia,
    precip_annual_mm,
    temp_winter_mean_c,
    temp_summer_mean_c,
    river_access_score,
    river_method_version,
    forest_nature_quality,
    travel_bucket
  )

log_step("Creando rejilla de 2km x 2km")
mun_union <- st_union(mun_sf)
ext <- st_bbox(mun_union)

grid_cells <- st_make_grid(
  mun_union,
  cellsize = 2000,
  crs = st_crs(mun_sf)
)

log_step(paste0("Generadas ", length(grid_cells), " celdas iniciales"))

log_step("Asignando celdas a municipio y variables base")
grid_base <- st_sf(cell_idx = seq_along(grid_cells), geometry = grid_cells)

log_step("Usando st_intersection para asignar celdas basandose en solape real de area")
suppressWarnings({
  cell_mun_inter <- tryCatch(
    st_intersection(
      grid_base,
      mun_sf |>
        select(
          codigo,
          nombre,
          provincia,
          precip_annual_mm,
          temp_winter_mean_c,
          temp_summer_mean_c,
          river_access_score,
          river_method_version,
          forest_nature_quality,
          travel_bucket,
          geometry
        ) |>
        st_make_valid()
    ),
    error = function(e) NULL
  )
})

if (is.null(cell_mun_inter) || nrow(cell_mun_inter) == 0) {
  stop("No se pudo asignar la rejilla a municipios por solape.")
}

grid_assign <- cell_mun_inter |>
  mutate(overlap_area = as.numeric(st_area(geometry))) |>
  st_drop_geometry() |>
  arrange(cell_idx, desc(overlap_area), codigo) |>
  group_by(cell_idx) |>
  slice(1) |>
  ungroup() |>
  select(-overlap_area)

grid_sf <- grid_base |>
  left_join(grid_assign, by = "cell_idx") |>
  filter(!is.na(codigo)) |>
  mutate(
    area_km2 = as.numeric(st_area(geometry) / 1e6),
    grid_row = as.integer((ext$ymax - st_coordinates(st_centroid(geometry))[, 2]) / 2000),
    grid_col = as.integer((st_coordinates(st_centroid(geometry))[, 1] - ext$xmin) / 2000),
    cell_id = paste0("cell_", cell_idx),
    municipio_id = codigo,
    municipio_nombre = nombre,
    precip_annual = precip_annual_mm,
    temp_winter = temp_winter_mean_c,
    temp_summer = temp_summer_mean_c,
    natural_cover_pct = pmax(0, pmin(100, forest_nature_quality * 100))
  )

if (file.exists(paths$output_ccaa_geojson) && file.exists(paths$output_provincias_geojson)) {
  log_step("Reasignando CCAA y provincia de celdas por join espacial")

  ccaa_sf <- st_read(paths$output_ccaa_geojson, quiet = TRUE) |>
    st_make_valid() |>
    st_transform(st_crs(grid_sf)) |>
    select(codnut2, nombre_ccaa, geometry)

  prov_sf <- st_read(paths$output_provincias_geojson, quiet = TRUE) |>
    st_make_valid() |>
    st_transform(st_crs(grid_sf)) |>
    select(codnut2, nombre_prov, geometry)

  grid_centroids <- st_centroid(grid_sf)

  ccaa_join <- suppressWarnings(st_join(grid_centroids, ccaa_sf, left = TRUE))
  ccaa_missing <- which(is.na(ccaa_join$codnut2) | ccaa_join$codnut2 == "")
  if (length(ccaa_missing) > 0) {
    nearest_ccaa_idx <- st_nearest_feature(grid_centroids[ccaa_missing, ], ccaa_sf)
    ccaa_join$codnut2[ccaa_missing] <- ccaa_sf$codnut2[nearest_ccaa_idx]
    ccaa_join$nombre_ccaa[ccaa_missing] <- ccaa_sf$nombre_ccaa[nearest_ccaa_idx]
  }

  prov_join <- suppressWarnings(st_join(grid_centroids, prov_sf, left = TRUE))
  prov_name <- as.character(prov_join$nombre_prov)
  prov_codnut2 <- as.character(prov_join$codnut2)
  target_codnut2 <- as.character(ccaa_join$codnut2)

  invalid_idx <- which(is.na(prov_name) | prov_name == "" | is.na(prov_codnut2) | prov_codnut2 != target_codnut2)

  if (length(invalid_idx) > 0) {
    for (i in invalid_idx) {
      cand <- prov_sf |> filter(codnut2 == target_codnut2[i])
      if (nrow(cand) == 0) cand <- prov_sf
      nearest_idx <- st_nearest_feature(grid_centroids[i, ], cand)
      prov_name[i] <- cand$nombre_prov[nearest_idx]
      prov_codnut2[i] <- cand$codnut2[nearest_idx]
    }
  }

  grid_sf <- grid_sf |>
    mutate(
      ccaa = ifelse(!is.na(ccaa_join$nombre_ccaa) & ccaa_join$nombre_ccaa != "", as.character(ccaa_join$nombre_ccaa), NA_character_),
      codnut2 = ifelse(!is.na(target_codnut2) & target_codnut2 != "", target_codnut2, NA_character_),
      provincia = ifelse(!is.na(prov_name) & prov_name != "", prov_name, provincia)
    )
}

grid_centroids_utm <- st_centroid(grid_sf)

log_step("Calculando acceso hidrico por candidatos de baño (rios IGN con persistencia + embalses)")

if (use_bathing_sources && file.exists(paths$output_bathing_areas_unified_geojson)) {
  log_step("Usando zonas de bano unificadas (PIPELINE_USE_BATHING_SOURCES=1)")
  bathing_sf <- st_read(paths$output_bathing_areas_unified_geojson, quiet = TRUE) |>
    st_make_valid() |>
    st_transform(st_crs(grid_sf))

  bathing_primary <- bathing_sf
  if ("is_primary_record" %in% names(bathing_primary)) {
    bathing_primary <- bathing_primary |>
      filter(is_primary_record)
  }

  if (nrow(bathing_primary) > 0) {
    nearest_idx <- st_nearest_feature(grid_centroids_utm, bathing_primary)
    nearest_dist <- as.numeric(st_distance(grid_centroids_utm, bathing_primary[nearest_idx, ], by_element = TRUE)) / 1000

    inside_20km <- nearest_dist <= 20
    inside_10km <- nearest_dist <= 10
    inside_5km <- nearest_dist <= 5

    river_buffer_class <- case_when(
      inside_5km ~ "<=5km",
      inside_10km ~ "5-10km",
      inside_20km ~ "10-20km",
      TRUE ~ ">20km"
    )

    grid_sf <- grid_sf |>
      mutate(
        river_buffer_class = river_buffer_class,
        river_distance_km = round(nearest_dist, 2),
        river_rank = "zona_bano",
        river_access_score = case_when(
          inside_5km ~ 100,
          inside_10km ~ 80,
          inside_20km ~ 60,
          TRUE ~ 5
        )
      )
  }
} else {

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

hydro_layers <- list()

tramocurso_shps <- dir_ls(
  path(project_root, "data", "raw", "hydrography"),
  recurse = TRUE,
  regexp = "DH_V0_ES[0-9]{3}.*/hi_tramocurso_l_ES[0-9]{3}\\.shp$",
  type = "file"
)

if (length(tramocurso_shps) > 0) {
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
    if (!"delineatio" %in% names(out)) out$delineatio <- NA_character_

    out <- out |>
      mutate(
        source_layer = as.character(source_layer),
        id_curso = clean_code(id_curso),
        nombre = clean_code(nombre),
        name_norm = normalize_name(nombre),
        tipo_curso = clean_code(tipo_curso),
        origen = clean_code(origen),
        persist_num = to_int(persist),
        orden_num = to_int(orden),
        ancho_max_num = to_numeric_comma(ancho_max),
        ancho_min_num = to_numeric_comma(ancho_min),
        longitud_num = to_numeric_comma(longitud),
        is_ficticio = tolower(trimws(as.character(ficticio))) == "t",
        is_canalizado = tolower(trimws(as.character(canaliza))) == "t",
        es_natural_origen = origen == "8001",
        es_artificial_origen = origen == "8002",
        es_natural_tipo = tipo_curso == "1001"
      )
    normalize_line_geometry(out)
  }

  for (shp_file in tramocurso_shps) {
    riv <- read_hydro(shp_file)
    if (is.null(riv) || nrow(riv) == 0) next

    artificial_like <- str_detect(
      riv$name_norm,
      "(^|[[:space:][:punct:]])(canal|acequia|azequia|cacera|caz|cauce artificial|zanja|dren|drenaje|desague|colector|emisario|tuberia|cuneta|aliviadero|sifon)([[:space:][:punct:]]|$)"
    )

    riv <- riv |>
      mutate(
        is_artificial = artificial_like | riv$es_artificial_origen,
        is_temporal = persist_num %in% c(18002L, 18003L),
        is_permanent = persist_num == 18001L,
        clase_banio = case_when(
          es_natural_tipo & es_natural_origen & is_permanent & !is_canalizado & !is_ficticio & !is.na(ancho_max_num) & ancho_max_num >= 20 ~ "rio_grande_permanente",
          es_natural_tipo & es_natural_origen & is_permanent & !is_canalizado & !is_ficticio ~ "rio_permanente_revision",
          es_natural_tipo & es_natural_origen & is_temporal & !is_canalizado & !is_ficticio ~ "rio_temporal_baja_confianza",
          is_artificial | is_canalizado | is_ficticio | is_temporal ~ "descartar",
          TRUE ~ "descartar"
        ),
        river_rank = case_when(
          clase_banio == "rio_grande_permanente" ~ "alto",
          clase_banio == "rio_permanente_revision" ~ "medio",
          clase_banio == "rio_temporal_baja_confianza" ~ "bajo",
          TRUE ~ "ninguno"
        )
      )

    riv_filtered <- riv |>
      filter(river_rank != "ninguno")
    if (nrow(riv_filtered) > 0) {
      count_by_class <- summarise(group_by(st_drop_geometry(riv_filtered), clase_banio), n = n(), .groups = "drop")
      class_str <- paste(paste0(count_by_class$clase_banio, "=", count_by_class$n), collapse = ", ")
      hydro_layers[[length(hydro_layers) + 1]] <- riv_filtered
      log_step(paste0("  ", basename(shp_file), ": ", nrow(riv_filtered), " km (clases: ", class_str, ")"))
    }
  }
}

if (length(hydro_layers) == 0 && file.exists(paths$output_rivers_geojson)) {
  log_step("  SHP IGN no encontrados, usando fallback RiosWatercourseScope")
  rivers_raw <- st_read(paths$output_rivers_geojson, quiet = TRUE) |>
    st_transform(st_crs(grid_sf)) |>
    st_make_valid()

  if (nrow(rivers_raw) > 0) {
    if (!"orden_num" %in% names(rivers_raw)) {
      rivers_raw$orden_num <- as.integer(NA)
    }
    if (!"ancho_max_num" %in% names(rivers_raw)) {
      rivers_raw$ancho_max_num <- as.numeric(NA)
    }
    if (!"longitud_num" %in% names(rivers_raw)) {
      rivers_raw$longitud_num <- as.numeric(NA)
    }

    rivers_raw <- rivers_raw |>
      mutate(
        river_rank = case_when(
          !is.na(orden_num) & orden_num <= 1 ~ "alto",
          !is.na(orden_num) & orden_num <= 3 ~ "medio",
          !is.na(ancho_max_num) & ancho_max_num >= 8 ~ "alto",
          !is.na(ancho_max_num) & ancho_max_num >= 4 ~ "medio",
          !is.na(longitud_num) & longitud_num >= 5000 ~ "medio",
          TRUE ~ "bajo"
        )
      )

    hydro_layers[[length(hydro_layers) + 1]] <- rivers_raw
  }
}

embalses_candidates <- c(
  path(paths$output_dir, "embalses_scope.geojson"),
  path(paths$output_dir, "embalses.geojson"),
  path(paths$rivers_cache_dir, "embalses_scope.geojson")
)

for (fp in embalses_candidates) {
  if (!file.exists(fp)) next
  hydro_layers[[length(hydro_layers) + 1]] <- st_read(fp, quiet = TRUE)
}

if (length(hydro_layers) > 0) {
  hydro_utm <- do.call(rbind, lapply(hydro_layers, function(x) st_transform(x, st_crs(grid_sf)))) |>
    st_make_valid()

  if (nrow(hydro_utm) > 0) {
    log_step("Calculando distancia a candidatos de baño por relevancia...")

    nearest_idx <- st_nearest_feature(grid_centroids_utm, hydro_utm)
    nearest_dist <- as.numeric(st_distance(grid_centroids_utm, hydro_utm[nearest_idx, ], by_element = TRUE)) / 1000

    rank_vals <- hydro_utm$river_rank[nearest_idx]
    rank_vals[is.na(rank_vals)] <- "bajo"

    river_buffer_class = case_when(
      nearest_dist <= 10 ~ "<=10km",
      nearest_dist <= 20 ~ "10-20km",
      nearest_dist <= 30 ~ "20-30km",
      TRUE ~ ">30km"
    )

    rank_bonus = case_when(
      rank_vals == "alto" ~ 20,
      rank_vals == "medio" ~ 10,
      TRUE ~ 0
    )

    grid_sf <- grid_sf |>
      mutate(
        river_buffer_class = river_buffer_class,
        river_distance_km = round(nearest_dist, 2),
        river_rank = rank_vals,
        river_access_score_base = case_when(
          river_buffer_class == "<=10km" ~ 80,
          river_buffer_class == "10-20km" ~ 60,
          river_buffer_class == "20-30km" ~ 30,
          TRUE ~ 0
        ),
        river_access_score = pmin(100, river_access_score_base + rank_bonus)
      )
  }
}
}

if (!"river_access_score" %in% names(grid_sf)) {
  grid_sf <- grid_sf |>
    mutate(
      river_buffer_class = NA_character_,
      river_distance_km = NA_real_,
      river_access_score = NA_real_
    )
}


log_step("Calculando cobertura natural por celda")
if (!grid_fast_mode && file.exists(paths$output_forest_geojson)) {
  forest_utm <- st_read(paths$output_forest_geojson, quiet = TRUE) |>
    st_transform(st_crs(grid_sf))
  if (nrow(forest_utm) > 0) {
    suppressWarnings({
      inter <- tryCatch(
        st_intersection(
          grid_sf |>
            select(cell_id, geometry),
          forest_utm |>
            st_make_valid() |>
            select(geometry)
        ),
        error = function(e) NULL
      )
    })

    if (!is.null(inter) && nrow(inter) > 0) {
      cover_tbl <- inter |>
        mutate(inter_area_m2 = as.numeric(st_area(geometry))) |>
        st_drop_geometry() |>
        group_by(cell_id) |>
        summarise(natural_area_m2 = sum(inter_area_m2, na.rm = TRUE), .groups = "drop")

      grid_sf <- grid_sf |>
        left_join(cover_tbl, by = "cell_id") |>
        mutate(
          cell_area_m2 = as.numeric(st_area(geometry)),
          natural_cover_pct = pmax(0, pmin(100, (coalesce(natural_area_m2, 0) / pmax(cell_area_m2, 1)) * 100))
        ) |>
        select(-natural_area_m2, -cell_area_m2)
    }
  }
}
if (grid_fast_mode) {
  log_step("Modo rapido grid: usando proxy municipal para cobertura natural")
  grid_sf <- grid_sf |>
    mutate(natural_cover_pct = pmax(0, pmin(100, coalesce(forest_nature_quality, 0) * 100)))
}

log_step("Asignando bucket de isocrona por celda")
iso_files <- c(
  "<=1h30" = path(paths$output_dir, "iso_diff_01h30m.geojson"),
  "<=2h00" = path(paths$output_dir, "iso_diff_01h30m_02h00m.geojson"),
  "<=2h30" = path(paths$output_dir, "iso_diff_02h00m_02h30m.geojson"),
  "<=3h30" = path(paths$output_dir, "iso_diff_02h30m_03h30m.geojson"),
  "<=4h00" = path(paths$output_dir, "iso_diff_03h30m_04h00m.geojson")
)

grid_sf <- grid_sf |>
  mutate(isochrone_rank = 6L)

for (bucket in names(iso_files)) {
  fp <- iso_files[[bucket]]
  if (!file.exists(fp)) next
  iso_sf <- st_read(fp, quiet = TRUE) |>
    st_transform(st_crs(grid_sf))
  if (nrow(iso_sf) == 0) next
  inside <- lengths(st_within(grid_centroids_utm, iso_sf)) > 0
  rank_val <- bucket_to_rank(bucket)
  grid_sf$isochrone_rank[inside] <- pmin(grid_sf$isochrone_rank[inside], rank_val, na.rm = TRUE)
}

grid_sf <- grid_sf |>
  mutate(
    isochrone_bucket = rank_to_bucket(isochrone_rank)
  )

log_step("Calculando bloques y mixed_score por celda")
grid_sf <- grid_sf |>
  mutate(
    precip_norm = round_idx(minmax_norm(precip_annual, invert = FALSE)),
    temp_verano_norm = round_idx(minmax_norm(temp_summer, invert = TRUE)),
    temp_invierno_norm = round_idx(minmax_norm(temp_winter, invert = FALSE)),
    natural_cover_norm = round_idx(minmax_norm(natural_cover_pct, invert = FALSE)),
    river_access_norm = round_idx(minmax_norm(river_access_score, invert = FALSE))
  )

travel_order <- c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00", ">4h00")
travel_score <- setNames(rev(seq_along(travel_order)), travel_order)
access_floor <- 0.2
access_raw <- (travel_score[grid_sf$isochrone_bucket] - 1) / (length(travel_order) - 1)

grid_sf <- grid_sf |>
  mutate(
    accesibilidad_norm = round_idx(access_floor + (1 - access_floor) * access_raw),
    climate_block_score = round_idx(
      rowMeans(cbind(precip_norm, temp_verano_norm, temp_invierno_norm), na.rm = TRUE)
    ),
    access_block_score = round_idx(accesibilidad_norm),
    nature_block_score = round_idx(
      rowMeans(cbind(natural_cover_norm, river_access_norm), na.rm = TRUE)
    ),
    mixed_score = round_idx(
      0.4 * climate_block_score +
        0.3 * access_block_score +
        0.3 * nature_block_score
    )
  )

grid_sf <- grid_sf |>
  select(
    cell_id,
    municipio_id,
    municipio_nombre,
    provincia,
    area_km2,
    grid_row,
    grid_col,
    mixed_score,
    precip_annual,
    temp_winter,
    temp_summer,
    river_distance_km,
    river_buffer_class,
    river_rank,
    river_access_score,
    river_method_version,
    natural_cover_pct,
    precip_norm,
    temp_verano_norm,
    temp_invierno_norm,
    natural_cover_norm,
    river_access_norm,
    accesibilidad_norm,
    climate_block_score,
    access_block_score,
    nature_block_score,
    isochrone_bucket,
    isochrone_rank,
    geometry
  )

log_step("Agregando variables de celda a municipio")
grid_agg <- grid_sf |>
  st_drop_geometry() |>
  group_by(codigo = municipio_id) |>
  summarise(
    grid_cell_count = n(),
    grid_precip_annual_mean = mean(precip_annual, na.rm = TRUE),
    grid_precip_annual_median = median(precip_annual, na.rm = TRUE),
    grid_temp_winter_mean = mean(temp_winter, na.rm = TRUE),
    grid_temp_winter_median = median(temp_winter, na.rm = TRUE),
    grid_temp_summer_mean = mean(temp_summer, na.rm = TRUE),
    grid_temp_summer_median = median(temp_summer, na.rm = TRUE),
    grid_river_access_mean = mean(river_access_score, na.rm = TRUE),
    grid_river_access_median = median(river_access_score, na.rm = TRUE),
    grid_river_access_p75 = as.numeric(quantile(river_access_score, probs = 0.75, na.rm = TRUE, type = 7)),
    grid_river_access_max = max(river_access_score, na.rm = TRUE),
    grid_pct_cells_river_access_high = mean(river_access_score >= 70, na.rm = TRUE) * 100,
    grid_pct_cells_bathing_20km = mean(river_buffer_class != ">20km", na.rm = TRUE) * 100,
    grid_nearest_good_river_distance = suppressWarnings(min(ifelse(river_access_score >= 70, river_distance_km, NA_real_), na.rm = TRUE)),
    grid_natural_cover_mean = mean(natural_cover_pct, na.rm = TRUE),
    grid_natural_cover_median = median(natural_cover_pct, na.rm = TRUE),
    grid_natural_cover_high_pct = mean(natural_cover_pct >= 60, na.rm = TRUE) * 100,
    grid_climate_block_median = median(climate_block_score, na.rm = TRUE),
    grid_access_block_median = median(access_block_score, na.rm = TRUE),
    grid_nature_block_median = median(nature_block_score, na.rm = TRUE),
    grid_mixed_score_median = median(mixed_score, na.rm = TRUE),
    grid_mixed_score_p75 = as.numeric(quantile(mixed_score, probs = 0.75, na.rm = TRUE, type = 7)),
    grid_pct_cells_mixed_top = mean(mixed_score >= 0.4283, na.rm = TRUE) * 100,
    grid_river_method_version = dplyr::first(river_method_version[!is.na(river_method_version) & river_method_version != ""], default = NA_character_),
    grid_iso_best_rank = min(isochrone_rank, na.rm = TRUE),
    grid_iso_majority_rank = mode_int(isochrone_rank),
    grid_pct_area_inside_2h30 = mean(isochrone_rank <= 3, na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  mutate(
    grid_iso_best_bucket = rank_to_bucket(grid_iso_best_rank),
    grid_iso_majority_bucket = rank_to_bucket(grid_iso_majority_rank),
    score_source = "cell_agg"
  ) |>
  select(-grid_iso_best_rank, -grid_iso_majority_rank)

grid_agg <- grid_agg |>
  mutate(across(where(is.double), ~ ifelse(is.finite(.x), .x, NA_real_)))

grid_agg <- grid_agg |>
  mutate(grid_nearest_good_river_distance = ifelse(is.infinite(grid_nearest_good_river_distance), NA_real_, grid_nearest_good_river_distance))

log_step("Reproyectando grid a EPSG:4326")
grid_sf <- st_transform(grid_sf, 4326) |>
  select(-isochrone_rank)

log_step("Guardando dataset de celdas")
st_write(grid_sf, paths$output_grid_geojson, delete_dsn = TRUE, quiet = TRUE)
invisible(file_copy(paths$output_grid_geojson, paths$frontend_grid_geojson, overwrite = TRUE))

log_step("Guardando agregados municipales de grid")
write_parquet(grid_agg, paths$output_feature_grid_agg_parquet)
saveRDS(grid_agg, paths$output_feature_grid_agg_rds)

log_step(paste0("Grid guardado en ", paths$output_grid_geojson))
log_step(paste0("Grid copiado a frontend en ", paths$frontend_grid_geojson))
log_step(paste0("Total celdas: ", nrow(grid_sf)))
log_step(paste0("Municipios con agregados: ", nrow(grid_agg)))

message("OK: Rejilla 2km y agregados municipales generados correctamente")

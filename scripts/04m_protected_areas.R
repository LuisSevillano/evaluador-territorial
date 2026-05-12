source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(arrow)
  library(fs)
  library(jsonlite)
})

sf_use_s2(FALSE)

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [protected-areas] ", msg)

if (!file.exists(paths$output_grid_geojson)) {
  stop("No existe municipios_grid_2km.geojson. Ejecuta primero scripts/04j_grid_2km.R")
}
if (!file.exists(paths$protected_areas_shp_zip)) {
  stop("No existe la capa ENP: ", paths$protected_areas_shp_zip)
}

protected_areas_to_json <- function(df) {
  if (is.null(df) || nrow(df) == 0) return("[]")
  rows <- df |>
    transmute(
      designation = as.character(odesignate),
      name = as.character(site_name)
    ) |>
    filter(!is.na(designation), designation != "", !is.na(name), name != "") |>
    distinct(designation, name)
  if (nrow(rows) == 0) return("[]")
  payload <- lapply(seq_len(nrow(rows)), function(i) {
    list(designation = rows$designation[[i]], name = rows$name[[i]])
  })
  as.character(toJSON(payload, auto_unbox = TRUE))
}

clean_chr <- function(x) {
  out <- trimws(as.character(x))
  out[out %in% c("", "NA", "-998", "-999", "-997")] <- NA_character_
  out
}

log_step("Cargando rejilla 2km")
grid_sf <- st_read(paths$output_grid_geojson, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(25830)

if (!"cell_id" %in% names(grid_sf) || !"municipio_id" %in% names(grid_sf)) {
  stop("La rejilla no contiene cell_id/municipio_id")
}

zip_path <- paste0("/vsizip/", paths$protected_areas_shp_zip, "/Enp2025_shp/Enp2025_p.shp")
log_step("Cargando ENP peninsular/balear desde zip")
enp <- st_read(zip_path, quiet = TRUE) |>
  st_make_valid() |>
  st_transform(st_crs(grid_sf))

names(enp) <- tolower(names(enp))
for (col_name in c("site_code_", "site_name", "odesignate")) {
  if (!col_name %in% names(enp)) stop("La capa ENP no contiene el campo ", col_name)
}

enp <- enp |>
  mutate(
    site_code_ = clean_chr(site_code_),
    site_name = clean_chr(site_name),
    odesignate = clean_chr(odesignate),
    protected_key = ifelse(
      !is.na(site_code_),
      site_code_,
      paste(coalesce(odesignate, ""), coalesce(site_name, ""), sep = "::")
    )
  ) |>
  filter(!is.na(site_name), site_name != "", !is.na(odesignate), odesignate != "") |>
  select(protected_key, site_code_, site_name, odesignate, geometry)

log_step("Recortando ENP al alcance de la rejilla")
enp_scope <- suppressWarnings(st_filter(enp, st_union(grid_sf), .predicate = st_intersects))

if (nrow(enp_scope) == 0) {
  log_step("No hay ENP dentro del alcance")
  empty_grid <- grid_sf |>
    st_drop_geometry() |>
    transmute(cell_id, municipio_id, protected_areas = "[]")
  empty_mun <- empty_grid |>
    distinct(codigo = municipio_id) |>
    mutate(protected_areas = "[]", protected_areas_source = "MITECO ENP 2025")
  saveRDS(empty_grid, paths$output_feature_protected_areas_grid_rds)
  write_parquet(empty_grid, paths$output_feature_protected_areas_grid_parquet)
  saveRDS(empty_mun, paths$output_feature_protected_areas_municipal_rds)
  write_parquet(empty_mun, paths$output_feature_protected_areas_municipal_parquet)
  quit(save = "no", status = 0)
}

log_step("Intersectando rejilla con ENP")
suppressWarnings({
  inter <- st_intersection(
    grid_sf |>
      select(cell_id, municipio_id, geometry),
    enp_scope |>
      select(protected_key, site_code_, site_name, odesignate, geometry)
  )
})

if (nrow(inter) == 0) {
  inter_tbl <- tibble(
    cell_id = character(),
    municipio_id = character(),
    protected_key = character(),
    site_name = character(),
    odesignate = character(),
    overlap_area_m2 = numeric()
  )
} else {
  inter_tbl <- inter |>
    mutate(overlap_area_m2 = as.numeric(st_area(geometry))) |>
    st_drop_geometry() |>
    group_by(cell_id, municipio_id, protected_key, site_name, odesignate) |>
    summarise(overlap_area_m2 = sum(overlap_area_m2, na.rm = TRUE), .groups = "drop")
}

log_step("Construyendo listas por celda")
grid_lists <- inter_tbl |>
  arrange(cell_id, desc(overlap_area_m2), odesignate, site_name) |>
  group_by(cell_id, municipio_id) |>
  group_modify(~ tibble(protected_areas = protected_areas_to_json(.x))) |>
  ungroup()

grid_feature <- grid_sf |>
  st_drop_geometry() |>
  transmute(cell_id, municipio_id) |>
  left_join(grid_lists, by = c("cell_id", "municipio_id")) |>
  mutate(protected_areas = coalesce(protected_areas, "[]"))

log_step("Construyendo listas por municipio desde celdas")
municipal_lists <- inter_tbl |>
  group_by(codigo = municipio_id, protected_key, site_name, odesignate) |>
  summarise(overlap_area_m2 = sum(overlap_area_m2, na.rm = TRUE), .groups = "drop") |>
  arrange(codigo, desc(overlap_area_m2), odesignate, site_name) |>
  group_by(codigo) |>
  group_modify(~ tibble(protected_areas = protected_areas_to_json(.x))) |>
  ungroup()

municipal_feature <- grid_sf |>
  st_drop_geometry() |>
  distinct(codigo = municipio_id) |>
  left_join(municipal_lists, by = "codigo") |>
  mutate(
    protected_areas = coalesce(protected_areas, "[]"),
    protected_areas_source = "MITECO ENP 2025"
  )

log_step("Actualizando GeoJSON de rejilla con listas ENP")
grid_out <- grid_sf |>
  left_join(select(grid_feature, cell_id, protected_areas), by = "cell_id") |>
  mutate(protected_areas = coalesce(protected_areas, "[]")) |>
  st_transform(4326)

st_write(grid_out, paths$output_grid_geojson, delete_dsn = TRUE, quiet = TRUE)
invisible(file_copy(paths$output_grid_geojson, paths$frontend_grid_geojson, overwrite = TRUE))

saveRDS(grid_feature, paths$output_feature_protected_areas_grid_rds)
write_parquet(grid_feature, paths$output_feature_protected_areas_grid_parquet)
saveRDS(municipal_feature, paths$output_feature_protected_areas_municipal_rds)
write_parquet(municipal_feature, paths$output_feature_protected_areas_municipal_parquet)

log_step(paste0("Celdas con ENP: ", sum(grid_feature$protected_areas != "[]", na.rm = TRUE)))
log_step(paste0("Municipios con ENP: ", sum(municipal_feature$protected_areas != "[]", na.rm = TRUE)))
message("OK: espacios naturales protegidos integrados como informacion contextual")

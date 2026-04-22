source("scripts/00_config.R")

library(sf)

sf_use_s2(FALSE)

iso_steps <- list(
  list(key = "01h30m", file = file.path(paths$isochrones_dir, "distance_01h30m_filled.json")),
  list(key = "02h00m", file = file.path(paths$isochrones_dir, "distance_02h00m_filled.json")),
  list(key = "02h30m", file = file.path(paths$isochrones_dir, "distance_02h30m_filled.json")),
  list(key = "03h30m", file = file.path(paths$isochrones_dir, "distance_03h30m_filled.json")),
  list(key = "04h00m", file = file.path(paths$isochrones_dir, "distance_04h00m_filled.json"))
)

missing_iso <- vapply(iso_steps, function(x) !file.exists(x$file), logical(1))
if (any(missing_iso)) {
  stop("Faltan isocronas para diferencias: ", paste(vapply(iso_steps[missing_iso], `[[`, character(1), "key"), collapse = ", "))
}

load_union_polygon <- function(path_file) {
  sf_obj <- st_read(path_file, quiet = TRUE) |>
    st_make_valid() |>
    st_transform(4326)
  poly <- st_collection_extract(sf_obj, "POLYGON")
  if (nrow(poly) == 0) stop("Sin poligonos validos en ", path_file)
  st_as_sf(data.frame(id = 1), geometry = st_union(st_geometry(poly)), crs = 4326)
}

ensure_polygon <- function(sf_obj) {
  geom <- st_make_valid(st_geometry(sf_obj))
  geom <- st_collection_extract(geom, "POLYGON")
  if (length(geom) == 0) return(NULL)
  st_as_sf(data.frame(id = seq_along(geom)), geometry = geom, crs = 4326)
}

union_shapes <- lapply(iso_steps, function(step) load_union_polygon(step$file))

write_geojson <- function(sf_obj, target_file) {
  st_write(sf_obj, target_file, delete_dsn = TRUE, quiet = TRUE)
  file.copy(target_file, file.path(paths$frontend_isochrones_dir, basename(target_file)), overwrite = TRUE)
}

for (i in seq_along(union_shapes)) {
  current <- union_shapes[[i]]
  if (i == 1) {
    out <- ensure_polygon(current)
    if (!is.null(out)) {
      out_path <- file.path(paths$output_dir, paste0("iso_diff_", iso_steps[[i]]$key, ".geojson"))
      write_geojson(out, out_path)
    }
    next
  }

  previous <- union_shapes[[i - 1]]
  diff_geom <- st_difference(st_geometry(current), st_geometry(previous))
  diff_sf <- ensure_polygon(st_as_sf(data.frame(id = 1), geometry = diff_geom, crs = 4326))
  if (!is.null(diff_sf)) {
    out_path <- file.path(paths$output_dir, paste0("iso_diff_", iso_steps[[i - 1]]$key, "_", iso_steps[[i]]$key, ".geojson"))
    write_geojson(diff_sf, out_path)
  }
}

message("OK: isocronas diferenciales generadas en output y frontend/static/data/isochrones")

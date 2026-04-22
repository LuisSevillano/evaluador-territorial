source("scripts/00_config.R")

library(sf)
library(dplyr)

sf_use_s2(FALSE)

if (!file.exists(paths$output_clima_geojson)) {
  stop("No existe municipios_clima.geojson. Ejecuta primero scripts/02_clima_real.R")
}

iso_files <- c(
  iso_01h30m = file.path(paths$isochrones_dir, "distance_01h30m_filled.json"),
  iso_02h00m = file.path(paths$isochrones_dir, "distance_02h00m_filled.json"),
  iso_02h30m = file.path(paths$isochrones_dir, "distance_02h30m_filled.json"),
  iso_03h30m = file.path(paths$isochrones_dir, "distance_03h30m_filled.json"),
  iso_04h00m = file.path(paths$isochrones_dir, "distance_04h00m_filled.json")
)

missing_iso <- names(iso_files)[!file.exists(iso_files)]
if (length(missing_iso) > 0) {
  stop("Faltan isocronas: ", paste(missing_iso, collapse = ", "))
}

municipios <- st_read(paths$output_clima_geojson, quiet = TRUE)
centroides <- municipios |>
  st_transform(3857) |>
  st_centroid() |>
  st_transform(4326)

centroides_3857 <- st_transform(centroides, 3857)

iso_start <- Sys.time()

for (iso_name in names(iso_files)) {
  step_start <- Sys.time()
  iso_sf <- st_read(iso_files[[iso_name]], quiet = TRUE) |>
    st_make_valid() |>
    st_transform(3857)

  iso_geom <- st_collection_extract(iso_sf, "POLYGON")
  if (nrow(iso_geom) == 0) {
    municipios[[iso_name]] <- FALSE
    message("Aviso: sin poligonos validos en ", basename(iso_files[[iso_name]]), ". Se marca FALSE.")
  } else {
    municipios[[iso_name]] <- lengths(st_intersects(centroides_3857, iso_geom, sparse = TRUE)) > 0
  }

  elapsed <- as.numeric(difftime(Sys.time(), step_start, units = "secs"))
  message(sprintf("[iso] %s OK (%.1fs)", iso_name, elapsed))
}

message(sprintf("[iso] Total isocronas: %.1fs", as.numeric(difftime(Sys.time(), iso_start, units = "secs"))))

municipios <- municipios |>
  mutate(
    travel_bucket = case_when(
      iso_01h30m ~ "<=1h30",
      iso_02h00m ~ "<=2h00",
      iso_02h30m ~ "<=2h30",
      iso_03h30m ~ "<=3h30",
      iso_04h00m ~ "<=4h00",
      TRUE ~ ">4h00"
    )
  )

st_write(municipios, paths$output_final_geojson, delete_dsn = TRUE, quiet = TRUE)
message("OK: isocronas integradas y travel_bucket generado en ", paths$output_final_geojson)

for (iso_name in names(iso_files)) {
  target_path <- file.path(paths$frontend_isochrones_dir, basename(iso_files[[iso_name]]))
  file.copy(iso_files[[iso_name]], target_path, overwrite = TRUE)
}
message("OK: isocronas copiadas a frontend/static/data/isochrones")

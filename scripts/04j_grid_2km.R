source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(terra)
  library(fs)
})

ts_now <- function() format(Sys.time(), "%H:%M:%S")
log_step <- function(msg) message("[", ts_now(), "] [grid] ", msg)

# Verificar que existe el GeoJSON municipal
if (!file.exists(paths$output_final_geojson)) {
  stop("No existe municipios_final.geojson. Ejecuta primero el pipeline hasta ensamblado.")
}

log_step("Cargando municipios")
mun_sf <- st_read(paths$output_final_geojson, quiet = TRUE) |>
  st_transform(25830)  # ETRS89 / UTM zone 30N (ajustar según scope)

# Crear grid de 2km x 2km
log_step("Creando rejilla de 2km x 2km")
mun_union <- st_union(mun_sf)

# Obtener extensión
ext <- st_bbox(mun_union)

# Crear grid regular
grid_cells <- st_make_grid(
  mun_union,
  cellsize = 2000,  # 2km en metros
  crs = st_crs(mun_sf)
)

log_step(paste0("Generadas ", length(grid_cells), " celdas iniciales"))

# Intersectar con municipios
log_step("Intersectando grid con municipios")
grid_sf <- st_sf(geometry = grid_cells) |>
  st_join(mun_sf |> select(codigo, nombre, provincia), join = st_intersects) |>
  filter(!is.na(codigo)) |>
  mutate(
    area_km2 = as.numeric(st_area(geometry) / 1e6)
  )

# Generar cell_id
grid_sf <- grid_sf |>
  mutate(
    grid_row = as.integer((ext$ymax - st_bbox(geometry)$ymax) / 2000),
    grid_col = as.integer((st_bbox(geometry)$xmin - ext$xmin) / 2000),
    cell_id = paste0(codigo, "_", grid_row, "_", grid_col)
  )

# Reproyectar a 4326 para GeoJSON
grid_sf <- grid_sf |>
  st_transform(4326)

# Guardar
grid_output <- path(paths$output_dir, "municipios_grid_2km.geojson")
st_write(grid_sf, grid_output, delete_dsn = TRUE, quiet = TRUE)

log_step(paste0("Guardado en ", grid_output))
log_step(paste0("Total celdas: ", nrow(grid_sf)))

# Estadísticas básicas
log_step("Resumen de áreas (km2):")
print(summary(grid_sf$area_km2))

message("OK: Rejilla 2km generada correctamente")

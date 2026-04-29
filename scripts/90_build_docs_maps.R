source("scripts/00_config.R")

library(sf)
library(ggplot2)

sf_use_s2(FALSE)

assets_dir <- file.path(project_root, "docs-site", "public", "assets")
dir.create(assets_dir, recursive = TRUE, showWarnings = FALSE)

source_note <- "Fuente: Elaboracion propia con TerraClimate, OSM Geofabrik, TravelTime API y SIGLIM"

theme_docs_map <- function(dark = FALSE) {
  text_col <- if (dark) "#e5e7eb" else "#111827"
  theme_void() +
    theme(
      plot.background = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA),
      legend.position = "top",
      legend.justification = "left",
      legend.direction = "horizontal",
      legend.background = element_rect(fill = "transparent", color = NA),
      legend.key = element_rect(fill = "transparent", color = NA),
      legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
      legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
      legend.title = element_text(face = "bold", color = text_col, size = 10),
      legend.text = element_text(color = text_col, size = 9),
      plot.title = element_text(face = "bold", color = text_col, size = 12, hjust = 0),
      plot.caption = element_text(color = text_col, size = 8, hjust = 1),
      text = element_text(color = text_col),
      plot.margin = margin(t = 6, r = 0, b = 8, l = 0)
    )
}

simplify_geo <- function(x, tol) {
  st_simplify(x, dTolerance = tol, preserveTopology = TRUE)
}

bbox_with_margin <- function(x, margin_x = 0.35, margin_y = 0.30) {
  bb <- st_bbox(x)
  c(
    xmin = as.numeric(bb["xmin"]) - margin_x,
    xmax = as.numeric(bb["xmax"]) + margin_x,
    ymin = as.numeric(bb["ymin"]) - margin_y,
    ymax = as.numeric(bb["ymax"]) + margin_y
  )
}

ccaa <- st_read(
  "/Users/portatil/Documents/gis/SIGLIM_Publico_INSPIRE/SHP_ETRS89/recintos_autonomicas_inspire_peninbal_etrs89/recintos_autonomicas_inspire_peninbal_etrs89.shp",
  quiet = TRUE
) |> st_transform(4326)

prov <- st_read(
  "/Users/portatil/Documents/gis/SIGLIM_Publico_INSPIRE/SHP_ETRS89/recintos_provinciales_inspire_peninbal_etrs89/recintos_provinciales_inspire_peninbal_etrs89.shp",
  quiet = TRUE
) |> st_transform(4326)

mun <- st_read(paths$output_v2_geojson, quiet = TRUE) |> st_transform(4326)
mun_bbox <- bbox_with_margin(mun)

ccaa <- simplify_geo(ccaa, 0.01)
prov <- simplify_geo(prov, 0.006)

iso1 <- st_read(file.path(paths$frontend_isochrones_dir, "iso_diff_01h30m.geojson"), quiet = TRUE) |> st_transform(4326) |> simplify_geo(0.002)
iso2 <- st_read(file.path(paths$frontend_isochrones_dir, "iso_diff_01h30m_02h00m.geojson"), quiet = TRUE) |> st_transform(4326) |> simplify_geo(0.002)
iso3 <- st_read(file.path(paths$frontend_isochrones_dir, "iso_diff_02h00m_02h30m.geojson"), quiet = TRUE) |> st_transform(4326) |> simplify_geo(0.002)
iso4 <- st_read(file.path(paths$frontend_isochrones_dir, "iso_diff_02h30m_03h30m.geojson"), quiet = TRUE) |> st_transform(4326) |> simplify_geo(0.002)
iso5 <- st_read(file.path(paths$frontend_isochrones_dir, "iso_diff_03h30m_04h00m.geojson"), quiet = TRUE) |> st_transform(4326) |> simplify_geo(0.002)

iso1$bucket <- "<=1h30"
iso2$bucket <- "<=2h00"
iso3$bucket <- "<=2h30"
iso4$bucket <- "<=3h30"
iso5$bucket <- "<=4h00"

iso <- rbind(iso1[, "bucket"], iso2[, "bucket"], iso3[, "bucket"], iso4[, "bucket"], iso5[, "bucket"])
iso$bucket <- factor(iso$bucket, levels = c("<=1h30", "<=2h00", "<=2h30", "<=3h30", "<=4h00"))

make_maps <- function(dark = FALSE) {
  mode <- if (dark) "dark" else "light"
  boundary_minor <- if (dark) "#6b7280" else "#9ca3af"
  boundary_major <- if (dark) "#e5e7eb" else "#111827"
  bg_peninsula <- if (dark) "#111827" else "#f8fafc"

  class_cols <- if (dark) {
    c("Muy baja" = "#f87171", "Baja" = "#fb923c", "Media" = "#fbbf24", "Alta" = "#86efac", "Muy alta" = "#22c55e")
  } else {
    c("Muy baja" = "#8c1d18", "Baja" = "#d94841", "Media" = "#f59f00", "Alta" = "#66c24a", "Muy alta" = "#15803d")
  }

  mun$score_band <- cut(mun$mixed_score, breaks = c(-Inf, 0.319, 0.354, 0.3885, 0.4283, Inf), labels = names(class_cols), right = FALSE)
  p_mixed <- ggplot() +
    geom_sf(data = mun, aes(fill = score_band), color = NA) +
    scale_fill_manual(values = class_cols, drop = FALSE, name = "Score") +
    geom_sf(data = prov, fill = NA, color = boundary_minor, linewidth = 0.10) +
    geom_sf(data = ccaa, fill = NA, color = boundary_major, linewidth = 0.28) +
    coord_sf(
      xlim = c(mun_bbox["xmin"], mun_bbox["xmax"]),
      ylim = c(mun_bbox["ymin"], mun_bbox["ymax"]),
      expand = FALSE
    ) +
    theme_docs_map(dark) +
    labs(title = "Mapa del score mixto por fases", caption = source_note)

  ggsave(file.path(assets_dir, sprintf("map_mixed_score.%s.png", mode)), p_mixed, width = 9, height = 6.4, dpi = 170, bg = "transparent")

  p_iso <- ggplot() +
    geom_sf(data = ccaa, fill = bg_peninsula, color = NA) +
    geom_sf(data = prov, fill = NA, color = if (dark) "#374151" else "#cbd5e1", linewidth = 0.08) +
    geom_sf(data = iso, aes(fill = bucket), color = NA, alpha = 0.80) +
    scale_fill_manual(
      values = c("<=1h30" = "#0f4c5c", "<=2h00" = "#4d7c0f", "<=2h30" = "#d97706", "<=3h30" = "#7b1f1f", "<=4h00" = "#5f5f5f"),
      name = "Accesibilidad",
      drop = FALSE
    ) +
    geom_sf(data = prov, fill = NA, color = boundary_minor, linewidth = 0.10) +
    geom_sf(data = ccaa, fill = NA, color = boundary_major, linewidth = 0.30) +
    # Isochrones keep full peninsular extent by design.
    coord_sf(xlim = c(-10.2, 4.5), ylim = c(35.5, 44.5), expand = FALSE) +
    theme_docs_map(dark) +
    labs(title = "Isocronas diferenciales", caption = source_note)

  ggsave(file.path(assets_dir, sprintf("map_isochrones_diff.%s.png", mode)), p_iso, width = 9, height = 6.4, dpi = 170, bg = "transparent")
}

make_maps(FALSE)
make_maps(TRUE)

message("OK: mapas docs regenerados (light/dark)")

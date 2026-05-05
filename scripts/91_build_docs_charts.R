source("scripts/00_config.R")

library(ggplot2)
library(treemapify)
library(dplyr)

assets_dir <- file.path(project_root, "docs-site", "public", "assets")
dir.create(assets_dir, recursive = TRUE, showWarnings = FALSE)

d <- read.csv(paths$output_v2_csv)
p <- read.csv(file.path(project_root, "output", "municipios_river_access.csv"))

source_note <- "Fuente: Elaboracion propia con datos del pipeline territorial"

save_treemap <- function(df, index, vSize, vColor, title, filename, palette = "RdYlGn") {
  png(file.path(assets_dir, filename), width = 800, height = 600, bg = "transparent")
  treemap(df, index = index, vSize = vSize, vColor = vColor,
          title = title, palette = palette, fontsize.title = 14,
          fontcolor.labels = "white", fontface.labels = 1)
  dev.off()
}

theme_docs_chart <- function() {
  theme_minimal(base_size = 12) +
    theme(
      legend.position = "bottom",
      legend.justification = "left",
      legend.direction = "horizontal",
      legend.title = element_text(face = "bold", hjust = 0),
      legend.margin = margin(t = 5, r = 0, b = 0, l = 0),
      legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
      plot.title = element_text(face = "bold", hjust = 0, size = 14),
      plot.caption = element_text(hjust = 0, size = 9, color = "gray40"),
      plot.margin = margin(t = 6, r = 0, b = 6, l = 0),
      axis.title = element_text(size = 11),
      axis.text = element_text(size = 10)
    )
}

g1 <- ggplot(d, aes(mixed_score, fill = "Serie")) +
  geom_histogram(bins = 30, color = "white") +
  scale_fill_manual(values = c("Serie" = "#2f855a"), guide = "none") +
  labs(title = "Distribucion de mixed_score", x = "mixed_score", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "mixed_score_distribution.png"), g1, width = 8, height = 4, dpi = 150, bg = "transparent")

g2 <- ggplot(d, aes(climate_block_score, fill = "Serie")) +
  geom_histogram(bins = 30, color = "white") +
  scale_fill_manual(values = c("Serie" = "#2b6cb0"), guide = "none") +
  labs(title = "Distribucion bloque clima", x = "climate_block_score", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "climate_block_distribution.png"), g2, width = 8, height = 4, dpi = 150, bg = "transparent")

g3 <- ggplot(d, aes(access_block_score, fill = "Serie")) +
  geom_histogram(bins = 30, color = "white") +
  scale_fill_manual(values = c("Serie" = "#805ad5"), guide = "none") +
  labs(title = "Distribucion bloque accesibilidad", x = "access_block_score", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "access_block_distribution.png"), g3, width = 8, height = 4, dpi = 150, bg = "transparent")

g4 <- ggplot(d, aes(nature_block_score, fill = "Serie")) +
  geom_histogram(bins = 30, color = "white") +
  scale_fill_manual(values = c("Serie" = "#2f855a"), guide = "none") +
  labs(title = "Distribucion bloque naturaleza", x = "nature_block_score", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "nature_block_distribution.png"), g4, width = 8, height = 4, dpi = 150, bg = "transparent")

g5 <- ggplot(p, aes(river_access_class, fill = "Serie")) +
  geom_bar() +
  scale_fill_manual(values = c("Serie" = "#0f766e"), guide = "none") +
  labs(title = "Clases de acceso fluvial", x = "Clase", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "river_class_counts.png"), g5, width = 8, height = 4, dpi = 150, bg = "transparent")

message("OK: graficos existentes regenerados")

global_weights <- data.frame(
  bloque = c("Clima (40%)", "Accesibilidad (30%)", "Naturaleza (30%)"),
  peso = c(0.40, 0.30, 0.30),
  color = c("#2b6cb0", "#805ad5", "#2f855a")
)

gg_treemap <- function(df, title_text, is_dark = FALSE) {
  label_col <- names(df)[1]
  df$label <- df[[label_col]]
  df$value <- df$peso
  
  title_color <- if(is_dark) "white" else "black"
  caption_color <- if(is_dark) "gray60" else "gray40"
  
  ggplot(df, aes(area = value, fill = color, label = label)) +
    geom_treemap(color = "white", size = 2, na.rm = TRUE) +
    geom_treemap_text(color = "white", place = "centre", grow = FALSE, 
                      reflow = TRUE, padding.x = grid::unit(3, "mm"),
                      padding.y = grid::unit(3, "mm"), size = 12) +
    labs(title = title_text, caption = "Fuente: Elaboracion propia con datos del pipeline territorial") +
    theme_void() +
    theme(
      plot.title = element_text(hjust = 0, face = "bold", size = 18, 
                                 color = title_color, margin = margin(b = 10)),
      plot.caption = element_text(hjust = 0, size = 10, 
                                 color = caption_color, margin = margin(t = 10)),
      plot.margin = margin(t = 15, r = 15, b = 15, l = 15),
      legend.position = "none"
    ) +
    scale_fill_identity()
}

global_weights <- data.frame(
  bloque = c("Clima (40%)", "Accesibilidad (30%)", "Naturaleza (30%)"),
  peso = c(0.40, 0.30, 0.30),
  color = c("#2b6cb0", "#805ad5", "#2f855a")
)

g1 <- gg_treemap(global_weights, "Ponderacion global del score mixto", FALSE)
ggsave(file.path(assets_dir, "score_weights_global_treemap.light.png"), g1, width = 8, height = 7, dpi = 150, bg = "transparent")

g1d <- gg_treemap(global_weights, "Ponderacion global del score mixto", TRUE)
ggsave(file.path(assets_dir, "score_weights_global_treemap.dark.png"), g1d, width = 8, height = 7, dpi = 150, bg = "#1a1a1a")

nature_weights <- data.frame(
  componente = c("Forestal (30%)", "Naturalidad (25%)", "Agua (20%)", "Diversidad (15%)", "Acceso fluvial (10%)"),
  peso = c(0.30, 0.25, 0.20, 0.15, 0.10),
  color = c("#22543d", "#276749", "#2f855a", "#38a169", "#48bb78")
)

g2 <- gg_treemap(nature_weights, "Ponderacion interna del bloque naturaleza", FALSE)
ggsave(file.path(assets_dir, "score_weights_nature_treemap.light.png"), g2, width = 8, height = 7, dpi = 150, bg = "transparent")

g2d <- gg_treemap(nature_weights, "Ponderacion interna del bloque naturaleza", TRUE)
ggsave(file.path(assets_dir, "score_weights_nature_treemap.dark.png"), g2d, width = 8, height = 7, dpi = 150, bg = "#1a1a1a")

nature_contrib <- d |> summarise(
  Forestal = mean(forest_norm, na.rm = TRUE),
  Naturalidad = mean(naturality_norm, na.rm = TRUE),
  Agua = mean(water_norm, na.rm = TRUE),
  Diversidad = mean(diversity_norm, na.rm = TRUE),
  "Acceso fluvial" = mean(river_access_norm, na.rm = TRUE)
) |> tidyr::pivot_longer(everything(), names_to = "Componente", values_to = "Media")

g_nature <- ggplot(nature_contrib, aes(x = reorder(Componente, -Media), y = Media, fill = Componente)) +
  geom_bar(stat = "identity") +
  scale_fill_brewer(palette = "Greens") +
  labs(title = "Contribucion media de componentes de naturaleza", x = "Componente", y = "Media", caption = source_note) +
  theme_docs_chart() +
  theme(legend.position = "none")
ggsave(file.path(assets_dir, "nature_component_mean_contribution.light.png"), g_nature, width = 8, height = 4, dpi = 150, bg = "transparent")

g_nature_dark <- ggplot(nature_contrib, aes(x = reorder(Componente, -Media), y = Media, fill = Componente)) +
  geom_bar(stat = "identity") +
  scale_fill_brewer(palette = "Greens") +
  labs(title = "Contribucion media de componentes de naturaleza", x = "Componente", y = "Media", caption = source_note) +
  theme_docs_chart() +
  theme(legend.position = "none", 
        plot.background = element_rect(fill = "#1a1a1a", color = NA), 
        text = element_text(color = "#ffffff"),
        axis.text = element_text(color = "#ffffff"),
        axis.title = element_text(color = "#ffffff"),
        plot.title = element_text(color = "#ffffff", hjust = 0),
        plot.caption = element_text(color = "#a0a0a0", hjust = 0))
ggsave(file.path(assets_dir, "nature_component_mean_contribution.dark.png"), g_nature_dark, width = 8, height = 4, dpi = 150, bg = "#1a1a1a")

top10 <- d |> arrange(-mixed_score) |> head(10) |> 
  select(nombre, climate_block_score, access_block_score, nature_block_score, mixed_score) |>
  tidyr::pivot_longer(c(climate_block_score, access_block_score, nature_block_score), names_to = "Bloque", values_to = "Score")
top10$Bloque <- gsub("_block_score", "", top10$Bloque)

g_tornado <- ggplot(top10, aes(x = reorder(nombre, -mixed_score), y = Score, fill = Bloque)) +
  geom_bar(stat = "identity", position = "stack") +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "Descomposicion score mixto: Top 10 municipios", x = "Municipio", y = "Score", caption = source_note) +
  theme_docs_chart() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(assets_dir, "score_rank_tornado_top10.light.png"), g_tornado, width = 10, height = 5, dpi = 150, bg = "transparent")

g_tornado_dark <- ggplot(top10, aes(x = reorder(nombre, -mixed_score), y = Score, fill = Bloque)) +
  geom_bar(stat = "identity", position = "stack") +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "Descomposicion score mixto: Top 10 municipios", x = "Municipio", y = "Score", caption = source_note) +
  theme_docs_chart() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, color = "#ffffff"), 
        axis.text.y = element_text(color = "#ffffff"),
        axis.title = element_text(color = "#ffffff"),
        plot.title = element_text(color = "#ffffff", hjust = 0),
        plot.caption = element_text(color = "#a0a0a0", hjust = 0),
        legend.text = element_text(color = "#ffffff"),
        legend.title = element_text(color = "#ffffff"),
        plot.background = element_rect(fill = "#1a1a1a", color = NA), 
        text = element_text(color = "#ffffff"))
ggsave(file.path(assets_dir, "score_rank_tornado_top10.dark.png"), g_tornado_dark, width = 10, height = 5, dpi = 150, bg = "#1a1a1a")

g_climate <- ggplot(d, aes(x = precip_annual_mm, y = temp_summer_mean_c, color = climate_block_score)) +
  geom_point(alpha = 0.6) +
  scale_color_viridis_c(name = "Score clima") +
  labs(title = "Precipitacion anual vs temperatura verano", x = "Precipitacion (mm)", y = "Temp. verano (°C)", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "climate_scatter_precip_vs_summer.light.png"), g_climate, width = 8, height = 5, dpi = 150, bg = "transparent")

g_climate_dark <- ggplot(d, aes(x = precip_annual_mm, y = temp_summer_mean_c, color = climate_block_score)) +
  geom_point(alpha = 0.6) +
  scale_color_viridis_c(name = "Score clima") +
  labs(title = "Precipitacion anual vs temperatura verano", x = "Precipitacion (mm)", y = "Temp. verano (°C)", caption = source_note) +
  theme_docs_chart() +
  theme(plot.background = element_rect(fill = "#1a1a1a", color = NA), 
        text = element_text(color = "#ffffff"),
        axis.text = element_text(color = "#ffffff"),
        axis.title = element_text(color = "#ffffff"),
        plot.title = element_text(color = "#ffffff", hjust = 0),
        plot.caption = element_text(color = "#a0a0a0", hjust = 0),
        legend.text = element_text(color = "#ffffff"),
        legend.title = element_text(color = "#ffffff"))
ggsave(file.path(assets_dir, "climate_scatter_precip_vs_summer.dark.png"), g_climate_dark, width = 8, height = 5, dpi = 150, bg = "#1a1a1a")

g_access <- ggplot(d, aes(travel_bucket, fill = "Serie")) +
  geom_bar() +
  scale_fill_manual(values = c("Serie" = "#805ad5"), guide = "none") +
  labs(title = "Distribucion buckets de accesibilidad", x = "Bucket", y = "Municipios", caption = source_note) +
  theme_docs_chart()
ggsave(file.path(assets_dir, "access_bucket_counts.light.png"), g_access, width = 8, height = 4, dpi = 150, bg = "transparent")

g_access_dark <- ggplot(d, aes(travel_bucket, fill = "Serie")) +
  geom_bar() +
  scale_fill_manual(values = c("Serie" = "#805ad5"), guide = "none") +
  labs(title = "Distribucion buckets de accesibilidad", x = "Bucket", y = "Municipios", caption = source_note) +
  theme_docs_chart() +
  theme(plot.background = element_rect(fill = "#1a1a1a", color = NA), 
        text = element_text(color = "#ffffff"),
        axis.text = element_text(color = "#ffffff"),
        axis.title = element_text(color = "#ffffff"),
        plot.title = element_text(color = "#ffffff", hjust = 0),
        plot.caption = element_text(color = "#a0a0a0", hjust = 0))
ggsave(file.path(assets_dir, "access_bucket_counts.dark.png"), g_access_dark, width = 8, height = 4, dpi = 150, bg = "#1a1a1a")

message("OK: graficos de score y componentes regenerados")

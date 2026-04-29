source("scripts/00_config.R")

library(ggplot2)

assets_dir <- file.path(project_root, "docs-site", "public", "assets")
dir.create(assets_dir, recursive = TRUE, showWarnings = FALSE)

d <- read.csv(paths$output_v2_csv)
p <- read.csv(file.path(project_root, "output", "municipios_river_access.csv"))

source_note <- "Fuente: Elaboracion propia con datos del pipeline territorial"

theme_docs_chart <- function() {
  theme_minimal() +
    theme(
      legend.position = "top",
      legend.justification = "left",
      legend.direction = "horizontal",
      legend.title = element_text(face = "bold"),
      legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
      legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
      plot.title = element_text(face = "bold", hjust = 0),
      plot.caption = element_text(hjust = 1, size = 8),
      plot.margin = margin(t = 6, r = 0, b = 8, l = 0)
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

message("OK: graficos docs regenerados con fuente")

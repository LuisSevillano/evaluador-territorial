#!/usr/bin/env Rscript
# Reproducibilidad ligera: registra las versiones del entorno de R con el que se
# genera el dataset. NO es un renv completo (no crea renv/ ni .Rprofile ni fija
# versiones), pero deja trazabilidad de versiones sin alterar el arranque de R.
#
# Uso:  Rscript scripts/99_r_environment.R
# Salida: docs-site/pipeline/entorno-r.md  (se publica en la doc VitePress)

pkgs <- c(
  "sf", "terra", "exactextractr", "dplyr", "tidyr", "readr",
  "stringr", "jsonlite", "arrow", "fs"
)

pkg_version <- function(p) {
  if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "NO INSTALADO"
}

geo <- tryCatch(sf::sf_extSoftVersion(), error = function(e) character(0))

lines <- c(
  "# Entorno de R",
  "",
  "> Versiones del entorno con el que se genera el dataset. Regenera esta página con",
  "> `Rscript scripts/99_r_environment.R`. No sustituye a un `renv` completo, pero deja",
  "> trazabilidad de versiones (clave para reproducir áreas y geometrías con `sf`/`terra`/GDAL/GEOS).",
  "",
  paste0("- **R**: ", R.version.string),
  paste0("- **Plataforma**: ", R.version$platform),
  "",
  "## Bibliotecas geoespaciales del sistema",
  ""
)
if (length(geo) > 0) {
  for (n in names(geo)) lines <- c(lines, paste0("- **", n, "**: ", geo[[n]]))
} else {
  lines <- c(lines, "- (no disponible)")
}

lines <- c(lines, "", "## Paquetes de R del pipeline", "")
for (p in pkgs) lines <- c(lines, paste0("- **", p, "**: ", pkg_version(p)))

out <- "docs-site/pipeline/entorno-r.md"
writeLines(lines, out)
cat("Escrito", out, "\n")

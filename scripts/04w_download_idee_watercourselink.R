source("scripts/00_config.R")

suppressPackageStartupMessages({
  library(xml2)
  library(httr2)
  library(sf)
  library(fs)
})

sf_use_s2(FALSE)

base_url <- "https://servicios.idee.es/wfs-inspire/hidrografia"
type_name <- "hy-n:WatercourseLink"
page_size <- as.integer(Sys.getenv("IDEE_PAGE_SIZE", unset = "10000"))
target_gpkg <- path(project_root, "data", "raw", "hydrography", "idee_watercourselink_full.gpkg")
tmp_dir <- path(project_root, "output", "tmp", "idee_wfs_pages")

dir_create(path_dir(target_gpkg), recurse = TRUE)
dir_create(tmp_dir, recurse = TRUE)

build_url <- function(start_index = NULL, hits = FALSE) {
  req <- request(base_url) |>
    req_url_query(
      service = "WFS",
      version = "2.0.0",
      request = "GetFeature",
      typeNames = type_name,
      srsName = "EPSG:25830",
      outputFormat = "text/xml; subtype=\"gml/3.2.1\""
    )
  if (hits) req <- req |> req_url_query(resultType = "hits")
  if (!is.null(start_index)) req <- req |> req_url_query(count = page_size, startIndex = start_index)
  req
}

message("[idee] Consultando total de features...")
hits_txt <- build_url(hits = TRUE) |> req_perform() |> resp_body_string()
hits_xml <- read_xml(hits_txt)
matched <- xml_attr(xml_find_first(hits_xml, "//*[@numberMatched]"), "numberMatched")
total <- suppressWarnings(as.integer(matched))
if (!is.finite(total) || is.na(total)) stop("No se pudo obtener numberMatched del WFS")

message("[idee] Total features: ", total)
starts <- seq.int(0L, max(0L, total - 1L), by = page_size)

page_files <- character(length(starts))
for (i in seq_along(starts)) {
  st <- starts[[i]]
  page_path <- path(tmp_dir, sprintf("watercourselink_%07d.gml", st))
  page_files[[i]] <- page_path
  if (file_exists(page_path) && file_info(page_path)$size > 0) {
    message("[idee] Reutilizando pagina ", i, "/", length(starts), " (startIndex=", st, ")")
    next
  }
  message("[idee] Descargando pagina ", i, "/", length(starts), " (startIndex=", st, ")")
  ok <- FALSE
  for (attempt in 1:5) {
    resp <- tryCatch(
      build_url(start_index = st) |> req_perform(),
      error = function(e) {
        message("[idee] intento ", attempt, " fallido: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(resp)) {
      writeBin(resp_body_raw(resp), page_path)
      ok <- TRUE
      break
    }
    Sys.sleep(min(30, 2^attempt))
  }
  if (!ok) {
    stop("No se pudo descargar pagina startIndex=", st, " tras 5 intentos")
  }
}

message("[idee] Uniendo paginas en GeoPackage...")
if (file_exists(target_gpkg)) file_delete(target_gpkg)

for (i in seq_along(page_files)) {
  fp <- page_files[[i]]
  x <- tryCatch(st_read(fp, quiet = TRUE), error = function(e) NULL)
  if (is.null(x) || nrow(x) == 0) next
  st_write(x, target_gpkg, layer = "watercourselink", append = i > 1, quiet = TRUE)
  rm(x)
  gc(verbose = FALSE)
}

message("OK: capa completa guardada en ", target_gpkg)

options(stringsAsFactors = FALSE)

library(fs)

project_root <- path_abs(".")
analysis_scope <- tolower(trimws(Sys.getenv("ANALYSIS_SCOPE", unset = "norte")))

prov_labels <- c(
  "05" = "Avila", "09" = "Burgos", "24" = "Leon", "34" = "Palencia", "37" = "Salamanca",
  "39" = "Cantabria", "40" = "Segovia", "42" = "Soria", "47" = "Valladolid", "48" = "Bizkaia",
  "49" = "Zamora", "01" = "Araba/Alava", "20" = "Gipuzkoa", "26" = "La Rioja", "28" = "Madrid"
)

scope_config <- switch(analysis_scope,
  "avila" = list(mode = "provincia", codprov = "05", label = "Avila", n_provinces = 1),
  "norte" = list(
    mode = "custom_scope",
    codnut2 = c("ES41", "ES23", "ES21", "ES13", "ES12"),
    codprov_include = c("27", "32", "19", "28"),
    prov_names_include = c("Lugo", "Ourense", "Guadalajara", "Madrid"),
    label = "Castilla y Leon + La Rioja + Pais Vasco + Cantabria + Asturias + Lugo + Ourense + Guadalajara + Madrid",
    n_provinces = 20
  ),
  "cyl" = list(mode = "nut2", codnut2 = "ES41", label = "Castilla y Leon", n_provinces = 9),
  "castilla_y_leon" = list(mode = "nut2", codnut2 = "ES41", label = "Castilla y Leon", n_provinces = 9),
  "espana" = list(mode = "all", label = "Espana", n_provinces = 52),
  stop("ANALYSIS_SCOPE no valido. Usa: avila | norte | cyl | espana")
)

paths <- list(
  shapefile = path(
    "/Users/portatil/Documents/gis/SIGLIM_Publico_INSPIRE/SHP_ETRS89/recintos_municipales_inspire_peninbal_etrs89",
    "recintos_municipales_inspire_peninbal_etrs89.shp"
  ),
  provinces_shapefile = path(
    "/Users/portatil/Documents/gis/SIGLIM_Publico_INSPIRE/SHP_ETRS89/recintos_provinciales_inspire_peninbal_etrs89",
    "recintos_provinciales_inspire_peninbal_etrs89.shp"
  ),
  output_dir = path(project_root, "output"),
  output_base_geojson = path(project_root, "output", "municipios_base.geojson"),
  output_clima_geojson = path(project_root, "output", "municipios_clima.geojson"),
  output_entorno_geojson = path(project_root, "output", "municipios_entorno.geojson"),
  output_final_geojson = path(project_root, "output", "municipios_final.geojson"),
  output_final_csv = path(project_root, "output", "municipios_final.csv"),
  output_final_json = path(project_root, "output", "municipios_final.json"),
  frontend_geojson = path(project_root, "frontend", "static", "data", "municipios_final.geojson"),
  frontend_json = path(project_root, "frontend", "static", "data", "municipios_final.json"),
  isochrones_dir = path("/Users/portatil/Documents/epic-life/isochrones"),
  output_v2_geojson = path(project_root, "output", "municipios_v2.geojson"),
  output_v2_csv = path(project_root, "output", "municipios_v2.csv"),
  output_v2_json = path(project_root, "output", "municipios_v2.json"),
  output_climate_monthly_csv = path(project_root, "output", "municipios_climate_monthly.csv"),
  output_climate_monthly_json = path(project_root, "output", "municipios_climate_monthly.json"),
  output_quality_report_csv = path(project_root, "output", "data_quality_report.csv"),
  output_ccaa_geojson = path(project_root, "output", "ccaa_boundaries.geojson"),
  output_provincias_geojson = path(project_root, "output", "provincias_boundaries.geojson"),
  output_dataset_metadata_json = path(project_root, "output", "dataset_metadata_v3.json"),
  output_features_dir = path(project_root, "output", "features"),
  output_feature_mfe_parquet = path(project_root, "output", "features", "feature_mfe_nature.parquet"),
  output_feature_relief_parquet = path(project_root, "output", "features", "feature_relief.parquet"),
  output_feature_climate_parquet = path(project_root, "output", "features", "feature_climate.parquet"),
  output_feature_isochrones_parquet = path(project_root, "output", "features", "feature_isochrones.parquet"),
  output_feature_river_parquet = path(project_root, "output", "features", "feature_river_access.parquet"),
  output_feature_transport_osm_parquet = path(project_root, "output", "features", "feature_transport_osm.parquet"),
  output_feature_transport_renfe_parquet = path(project_root, "output", "features", "feature_transport_renfe.parquet"),
  output_feature_grid_agg_parquet = path(project_root, "output", "features", "feature_grid_agg.parquet"),
  output_feature_mfe_rds = path(project_root, "output", "features", "feature_mfe_nature.rds"),
  output_feature_relief_rds = path(project_root, "output", "features", "feature_relief.rds"),
  output_feature_climate_rds = path(project_root, "output", "features", "feature_climate.rds"),
  output_feature_isochrones_rds = path(project_root, "output", "features", "feature_isochrones.rds"),
  output_feature_river_rds = path(project_root, "output", "features", "feature_river_access.rds"),
  output_feature_transport_osm_rds = path(project_root, "output", "features", "feature_transport_osm.rds"),
  output_feature_transport_renfe_rds = path(project_root, "output", "features", "feature_transport_renfe.rds"),
  output_feature_grid_agg_rds = path(project_root, "output", "features", "feature_grid_agg.rds"),
  relieve_raw_dir = path(project_root, "data", "raw", "relieve", "copdem"),
  relieve_processed_dir = path(project_root, "data", "processed", "relieve"),
  output_rivers_geojson = path(project_root, "output", "rios_watercourse_scope.geojson"),
  output_river_basins_geojson = path(project_root, "output", "cuencas_scope.geojson"),
  output_hydro_sources_report_csv = path(project_root, "output", "hydro_sources_report.csv"),
  output_bathing_areas_unified_geojson = path(project_root, "output", "bathing_areas_unified.geojson"),
  output_bathing_areas_unified_csv = path(project_root, "output", "bathing_areas_unified.csv"),
  output_bathing_areas_unified_parquet = path(project_root, "output", "bathing_areas_unified.parquet"),
  output_bathing_areas_quality_csv = path(project_root, "output", "bathing_areas_quality.csv"),
  output_feature_bathing_areas_rds = path(project_root, "output", "features", "feature_bathing_areas.rds"),
  output_feature_bathing_areas_parquet = path(project_root, "output", "features", "feature_bathing_areas.parquet"),
  output_river_summer_candidates_geojson = path(project_root, "output", "river_summer_flow_candidates.geojson"),
  output_river_summer_candidates_rds = path(project_root, "output", "river_summer_flow_candidates.rds"),
  output_river_summer_buffers_geojson = path(project_root, "output", "river_summer_flow_buffers.geojson"),
  output_river_summer_buffers_rds = path(project_root, "output", "river_summer_flow_buffers.rds"),
  output_river_summer_summary_csv = path(project_root, "output", "river_summer_flow_summary.csv"),
  output_river_indicators_geojson = path(project_root, "output", "municipios_rios.geojson"),
  output_river_indicators_csv = path(project_root, "output", "municipios_rios.csv"),
  output_cantabria_river_pilot_geojson = path(project_root, "output", "cantabria_rios_pilot.geojson"),
  output_cantabria_river_pilot_csv = path(project_root, "output", "cantabria_rios_pilot.csv"),
  output_cantabria_river_segments_geojson = path(project_root, "output", "cantabria_rios_tramos_filtrados.geojson"),
  output_forest_geojson = path(project_root, "output", "masa_forestal.geojson"),
  output_landuse_geojson = path(project_root, "output", "usos_suelo.geojson"),
  output_vegetation_geojson = path(project_root, "output", "cobertura_vegetal.geojson"),
  rivers_raw_dir = path(project_root, "data", "raw", "hydro"),
  rivers_cache_dir = path(project_root, "data", "intermediate", "hydro"),
  hydro_sources_csv = path(project_root, "config", "hydro_sources.csv"),
  river_whitelist_txt = path(project_root, "config", "river_name_whitelist.txt"),
  docs_indicators = path(project_root, "docs", "indicators.md"),
  frontend_v2_geojson = path(project_root, "frontend", "static", "data", "municipios_v2.geojson"),
  frontend_v2_json = path(project_root, "frontend", "static", "data", "municipios_v2.json"),
  frontend_climate_monthly_json = path(project_root, "frontend", "static", "data", "municipios_climate_monthly.json"),
  frontend_dataset_metadata_json = path(project_root, "frontend", "static", "data", "dataset_metadata_v3.json"),
  frontend_forest_geojson = path(project_root, "frontend", "static", "data", "masa_forestal.geojson"),
  frontend_landuse_geojson = path(project_root, "frontend", "static", "data", "usos_suelo.geojson"),
  frontend_vegetation_geojson = path(project_root, "frontend", "static", "data", "cobertura_vegetal.geojson"),
  frontend_ccaa_geojson = path(project_root, "frontend", "static", "data", "ccaa_boundaries.geojson"),
  frontend_provincias_geojson = path(project_root, "frontend", "static", "data", "provincias_boundaries.geojson"),
  frontend_isochrones_dir = path(project_root, "frontend", "static", "data", "isochrones"),
  frontend_isochrones_pmtiles = path(project_root, "frontend", "static", "tiles", "isochrones.pmtiles"),
  output_grid_geojson = path(project_root, "output", "municipios_grid_2km.geojson"),
  frontend_grid_geojson = path(project_root, "frontend", "static", "data", "municipios_grid_2km.geojson"),
  frontend_grid_pmtiles = path(project_root, "frontend", "static", "tiles", "grid")
)

invisible(dir_create(paths$output_dir, recurse = TRUE))
invisible(dir_create(paths$output_features_dir, recurse = TRUE))
invisible(dir_create(paths$relieve_processed_dir, recurse = TRUE))
invisible(dir_create(path_dir(paths$frontend_json), recurse = TRUE))
invisible(dir_create(paths$frontend_isochrones_dir, recurse = TRUE))

message("Scope activo: ", scope_config$label, " (ANALYSIS_SCOPE=", analysis_scope, ")")

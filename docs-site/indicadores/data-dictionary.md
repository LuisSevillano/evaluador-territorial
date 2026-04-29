# Diccionario completo de datos (`municipios_v2`)

Esta tabla documenta las columnas exportadas en `output/municipios_v2.csv` y `frontend/static/data/municipios_v2.json`.
Sirve para auditar definiciones y orígenes antes de interpretar resultados.

| Campo | Tipo | Unidad/rango | Descripción | Origen |
|---|---|---|---|---|
| `id` | string | código INE | Identificador principal para frontend. | `05_export_frontend_v2.R` |
| `código` | string | INE | Codigo municipal. | base municipal |
| `nombre` | string | texto | Nombre municipal. | base municipal |
| `provincia` | string | texto | Provincia del municipio. | base municipal |
| `lon` | number | grados | Longitud de punto representativo municipal. | derivado geometría |
| `lat` | number | grados | Latitud de punto representativo municipal. | derivado geometría |
| `population` | number | hab | Poblacion total. | `05b_add_population.R` |
| `population_men` | number | hab | Poblacion masculina. | `05b_add_population.R` |
| `population_women` | number | hab | Poblacion femenina. | `05b_add_population.R` |
| `precip_annual_mm` | number | mm/anual | Precipitacion anual agregada. | `02_clima_real.R` |
| `temp_winter_mean_c` | number | C | Temperatura media invernal (DJF). | `02_clima_real.R` |
| `temp_summer_mean_c` | number | C | Temperatura media estival (JJA). | `02_clima_real.R` |
| `temp_jan_mean_c` | number | C | Media de enero. | `02_clima_real.R` |
| `temp_jul_mean_c` | number | C | Media de julio. | `02_clima_real.R` |
| `iso_01h30m` | boolean | 0/1 | Dentro de isocrona 1h30. | `03_isochrones.R` |
| `iso_02h00m` | boolean | 0/1 | Dentro de isocrona 2h00. | `03_isochrones.R` |
| `iso_02h30m` | boolean | 0/1 | Dentro de isocrona 2h30. | `03_isochrones.R` |
| `iso_03h30m` | boolean | 0/1 | Dentro de isocrona 3h30. | `03_isochrones.R` |
| `iso_04h00m` | boolean | 0/1 | Dentro de isocrona 4h00. | `03_isochrones.R` |
| `travel_bucket` | string | buckets | Categoría principal de accesibilidad. | `03_isochrones.R` |
| `dist_estacion_tren_km` | number | km | Distancia a estacion ferroviaria. | `04_transporte_distance.R` |
| `dist_parada_bus_km` | number | km | Distancia a nodo de bus. | `04_transporte_distance.R` |
| `transporte_norm` | number | [0,1] | Accesibilidad de transporte general normalizada. | `04_transporte_distance.R` |
| `dist_renfe_km` | number | km | Distancia a nodo Renfe. | `04b_transporte_renfe.R` |
| `renfe_salidas_dia` | number | servicios/día | Frecuencia de servicios Renfe. | `04b_transporte_renfe.R` |
| `renfe_tipo_servicio` | string | categoría | Tipo de servicio ferroviario. | `04b_transporte_renfe.R` |
| `servicio_renfe_norm` | number | [0,1] | Normalizacion de servicio Renfe. | `04b_transporte_renfe.R` |
| `precip_norm` | number | [0,1] | Precipitacion normalizada. | `05_export_frontend_v2.R` |
| `temp_verano_norm` | number | [0,1] | Temperatura estival invertida y normalizada. | `05_export_frontend_v2.R` |
| `temp_invierno_norm` | number | [0,1] | Temperatura invernal normalizada. | `05_export_frontend_v2.R` |
| `forest_pct` | number | % | Cobertura forestal municipal. | `04_entorno_corine.R` |
| `water_pct` | number | % | Cobertura de agua municipal. | `04_entorno_corine.R` |
| `artificial_pct` | number | % | Cobertura artificial municipal. | `04_entorno_corine.R` |
| `naturality_index` | number | 0-100 | Indice de naturalidad. | `04_entorno_corine.R` |
| `landcover_diversity` | number | 0-100 | Diversidad de coberturas. | `04_entorno_corine.R` |
| `river_access_score` | number | 0-100 | Acceso fluvial recreativo potencial. | `04g_banio_score_simple.R` |
| `river_access_class` | string | 5 clases | Clase cualitativa de acceso fluvial. | `04g_banio_score_simple.R` |
| `river_nearest_name` | string | texto | Nombre del tramo candidato más cercano. | `04g_banio_score_simple.R` |
| `river_nearest_distance_km` | number | km | Distancia al tramo candidato más cercano. | `04g_banio_score_simple.R` |
| `river_nearest_confidence` | number | 0-100 | Confianza del tramo nearest. | `04g_banio_score_simple.R` |
| `river_candidate_count_10km` | integer | conteo | Numero de tramos candidatos en 10 km. | `04g_banio_score_simple.R` |
| `river_method_version` | string | versión | Versión del metodo fluvial. | `04g_banio_score_simple.R` |
| `forest_norm` | number | [0,1] | Forestal normalizado. | `05_export_frontend_v2.R` |
| `water_norm` | number | [0,1] | Agua normalizada. | `05_export_frontend_v2.R` |
| `artificial_norm` | number | [0,1] | Artificial invertido normalizado. | `05_export_frontend_v2.R` |
| `naturality_norm` | number | [0,1] | Naturalidad normalizada. | `05_export_frontend_v2.R` |
| `diversity_norm` | number | [0,1] | Diversidad normalizada. | `05_export_frontend_v2.R` |
| `river_access_norm` | number | [0,1] | Acceso fluvial normalizado. | `05_export_frontend_v2.R` |
| `accesibilidad_norm` | number | [0,1] | Bucket de accesibilidad normalizado. | `05_export_frontend_v2.R` |
| `climate_block_score` | number | [0,1] | Media del bloque clima. | `05_export_frontend_v2.R` |
| `access_block_score` | number | [0,1] | Score del bloque accesibilidad. | `05_export_frontend_v2.R` |
| `nature_block_score` | number | [0,1] | Score ponderado de naturaleza. | `05_export_frontend_v2.R` |
| `mixed_score` | number | [0,1] | Score final comparativo del Atlas. | `05_export_frontend_v2.R` |

## Notas de interpretación

- `mixed_score` es comparativo multicriterio; no es causal ni prescriptivo.
- `river_access_score` mide acceso potencial recreativo, no calidad de agua.
- El valor final depende del alcance territorial activo (`ANALYSIS_SCOPE`).
- Si un resultado parece raro, conviene revisar primero el desglose por bloques y la fuente de cada indicador.

# Diccionario completo de datos (`municipios_v2`)

Esta tabla documenta las columnas exportadas en `output/municipios_v2.csv` y `frontend/static/data/municipios_v2.json`.
Sirve para auditar definiciones y orígenes antes de interpretar resultados.

Si solo quieres entender el Atlas, no hace falta leer esta página completa. Es una referencia para resolver dudas concretas: qué significa un campo, en qué unidad está y de dónde sale.

## Cómo usar este diccionario

Los campos se pueden leer por bloques:

- **Identificación**: nombre, código, provincia y posición del municipio.
- **Clima**: lluvia y temperaturas.
- **Accesibilidad**: tramos de tiempo, transporte general y tren.
- **Naturaleza**: bosque, agua, artificialización, relieve y ríos.
- **Scores**: puntuaciones normalizadas y score mixto.

Los nombres con guion bajo son nombres internos del dataset. En la interfaz suelen aparecer con etiquetas más legibles.

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
| `precip_summer_mm` | number | mm/JJA | Precipitacion acumulada de junio, julio y agosto. | `02_clima_real.R` |
| `precip_winter_mm` | number | mm/DJF | Precipitacion acumulada de diciembre, enero y febrero. | `02_clima_real.R` |
| `precip_seasonality_index` | number | índice | Coeficiente de variacion mensual de la precipitacion. | `02_clima_real.R` |
| `aridity_index` | number | P/PET | Relacion anual entre precipitacion y evapotranspiracion potencial. | `02_clima_real.R` |
| `summer_aridity_index` | number | P/PET JJA | Relacion estival entre precipitacion y evapotranspiracion potencial. | `02_clima_real.R` |
| `dry_months_count` | integer | meses | Meses secos segun `precip_mm < 2 * temp_mean_c`. | `02_clima_real.R` |
| `moisture_absolute_score` | number | [0,1] | Humedad climatica absoluta por umbrales fijos TerraClimate 1991-2020. | `02_clima_real.R` |
| `summer_drought_score` | number | [0,1] | Score de lluvia util y sequia estival. | `02_clima_real.R` |
| `precip_relative_score` | number | [0,1] | Ventaja relativa dentro del alcance activo. | `02_clima_real.R` |
| `precip_moisture_score` | number | [0,1] | Score hibrido: 60% absoluto, 25% estival, 15% relativo. | `02_clima_real.R` |
| `water_drops_level` | integer | 1-3 | Nivel visual estable de gotas derivado de humedad absoluta y sequia estival. | `02_clima_real.R` |
| `water_drops_label` | string | clase | Etiqueta `Seco`, `Equilibrado` o `Humedo`. | `02_clima_real.R` |
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
| `dist_renfe_km` | number | km | Alias legacy de distancia a conexión Renfe directa con Madrid. | `04b_transporte_renfe.R` |
| `renfe_salidas_dia` | number | servicios/día | Alias legacy de salidas medias diarias hacia Madrid. | `04b_transporte_renfe.R` |
| `renfe_tipo_servicio` | string | categoría | Alias legacy de tipo de conexión Renfe con Madrid. | `04b_transporte_renfe.R` |
| `servicio_renfe_norm` | number | [0,1] | Alias legacy de conectividad Renfe con Madrid. | `04b_transporte_renfe.R` |
| `dist_renfe_madrid_km` | number | km | Distancia a parada Renfe con conexión directa hacia Madrid. | `04b_transporte_renfe.R` |
| `renfe_madrid_active_days` | number | días | Días del calendario GTFS con al menos una salida directa hacia Madrid. | `04b_transporte_renfe.R` |
| `renfe_madrid_coverage_pct` | number | % | Porcentaje del calendario GTFS con servicio directo hacia Madrid. | `04b_transporte_renfe.R` |
| `renfe_madrid_departures_avg_day` | number | servicios/día | Salidas medias diarias hacia Madrid sobre todo el calendario GTFS. | `04b_transporte_renfe.R` |
| `renfe_madrid_weekend_service` | boolean | 0/1 | Existencia de servicio directo sábado o domingo. | `04b_transporte_renfe.R` |
| `renfe_madrid_stop_id` | string | id GTFS | Identificador de la estación Renfe de referencia. | `04b_transporte_renfe.R` |
| `renfe_madrid_stop_name` | string | texto | Nombre de la estación Renfe de referencia. | `04b_transporte_renfe.R` |
| `renfe_madrid_stop_municipality` | string | texto | Municipio de la estación Renfe de referencia. | `04b_transporte_renfe.R` |
| `renfe_madrid_stop_province` | string | texto | Provincia de la estación Renfe de referencia. | `04b_transporte_renfe.R` |
| `renfe_madrid_connection_type` | string | categoría | Tipo de conexión detectada con Madrid. | `04b_transporte_renfe.R` |
| `renfe_madrid_service_norm` | number | [0,1] | Conectividad Renfe directa con Madrid normalizada. | `04b_transporte_renfe.R` |
| `has_direct_madrid_service` | boolean | 0/1 | Indica si el municipio contiene conexión directa con Madrid. | `04b_transporte_renfe.R` |
| `has_nearby_station` | boolean | 0/1 | Indica si hay estación conectada con Madrid a 15 km o menos. | `04b_transporte_renfe.R` |
| `nearest_station_distance_km` | number | km | Distancia a la estación conectada con Madrid más cercana. | `04b_transporte_renfe.R` |
| `transport_confidence` | string | categoría | Nivel de confianza simplificado para el estado de transporte. | `04b_transporte_renfe.R` |
| `transport_status` | string | categoría | Estado visible de tren: directo, cercano o lejano. | `04b_transporte_renfe.R` |
| `precip_norm` | number | [0,1] | Precipitacion normalizada legacy/comparativa dentro del alcance activo. | `05_export_frontend_v2.R` |
| `temp_verano_norm` | number | [0,1] | Temperatura estival invertida y normalizada. | `05_export_frontend_v2.R` |
| `temp_invierno_norm` | number | [0,1] | Temperatura invernal normalizada. | `05_export_frontend_v2.R` |
| `forest_pct` | number | % | Cobertura forestal municipal del Mapa Forestal de España. | `04_entorno_mfe.R` |
| `water_pct` | number | % | Láminas/superficie de agua municipal del Mapa Forestal de España; dato secundario, no lectura principal de acceso al agua. | `04_entorno_mfe.R` |
| `artificial_pct` | number | % | Cobertura artificial municipal del Mapa Forestal de España. | `04_entorno_mfe.R` |
| `naturality_index` | number | 0-100 | Indice de naturalidad derivado de MFE. | `04_entorno_mfe.R` |
| `landcover_diversity` | number | 0-100 | Diversidad de coberturas MFE. | `04_entorno_mfe.R` |
| `river_access_score` | number | 0-100 | Acceso recreativo a zonas de baño o cursos fluviales candidatos. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_access_class` | string | 5 clases | Clase cualitativa de acceso recreativo. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_nearest_name` | string | texto | Nombre de la zona o tramo candidato más cercano. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_nearest_distance_km` | number | km | Distancia a la zona o tramo candidato seleccionado. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_nearest_confidence` | number | 0-100 | Confianza de la fuente seleccionada. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_candidate_count_10km` | integer | conteo | Numero de candidatos en 10 km para la fuente seleccionada. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
| `river_access_source_type` | string | categoría | Fuente que determina el score: `official_bathing`, `river_summer_proxy` o `community_bathing` si se activa. | `04z_bathing_access_score.R` |
| `river_method_version` | string | versión | Versión del metodo de acceso recreativo. | `04z_bathing_access_score.R` / `04g_banio_score_simple.R` legacy |
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
- `river_access_score` mide acceso recreativo potencial. Si `river_access_source_type = official_bathing`, se apoya en zonas oficiales/inventariadas; si vale `river_summer_proxy`, es un proxy capado de curso fluvial con caudal estival probable y no certifica baño ni calidad sanitaria.
- `water_pct` mide superficie de agua cartografiada, no presencia de arroyos, caudal, accesibilidad ni calidad sanitaria. En la interfaz se interpreta como detalle secundario junto a distancia y clase de acceso fluvial.
- En la rejilla de 2 km, `river_access_norm` se usa como bonus contextual dentro del bloque naturaleza, capado y ponderado por cobertura natural para evitar que las bandas de distancia dominen visualmente el `mixed_score`.
- El valor final depende del alcance territorial activo (`ANALYSIS_SCOPE`).
- Si un resultado parece raro, conviene revisar primero el desglose por bloques y la fuente de cada indicador.

## Campos legacy

Algunos campos se mantienen por compatibilidad con versiones anteriores del frontend o de los análisis. Por ejemplo, `dist_renfe_km`, `renfe_salidas_dia`, `renfe_tipo_servicio` y `servicio_renfe_norm` son alias de campos más específicos de Renfe a Madrid.

Cuando haya duda, conviene priorizar los campos con prefijo `renfe_madrid_` y los campos de estado `transport_status`, `has_direct_madrid_service` y `has_nearby_station`.

# Indicadores v2 - Observatorio Territorial El Buen Vivir

## Clima
- `precip_annual_mm`: precipitacion anual (mm) agregada a municipio desde mediana de celdas 2x2 km.
- `precip_summer_mm`: precipitacion acumulada de junio, julio y agosto (mm).
- `precip_winter_mm`: precipitacion acumulada de diciembre, enero y febrero (mm).
- `aridity_index`: relacion P/PET anual sobre normal TerraClimate 1991-2020.
- `summer_aridity_index`: relacion P/PET de junio-agosto.
- `dry_months_count`: numero de meses secos segun criterio precip_mm < 2 * temp_media_c.
- `precip_seasonality_index`: coeficiente de variacion mensual de la precipitacion.
- `moisture_absolute_score`: score absoluto de humedad climatica por umbrales fijos.
- `summer_drought_score`: score de sequia estival y lluvia util de verano.
- `precip_relative_score`: ventaja relativa interna dentro del alcance activo.
- `precip_moisture_score`: score hibrido de pluviometria = 60% humedad absoluta + 25% sequia estival + 15% ventaja relativa.
- `water_drops_level` y `water_drops_label`: lectura visual estable derivada de humedad absoluta y sequia estival, no de filtros.
- `temp_winter_mean_c`: temperatura media invierno (C) agregada a municipio desde mediana de celdas.
- `temp_summer_mean_c`: temperatura media verano (C) agregada a municipio desde mediana de celdas.
- `temp_jan_mean_c`: temperatura media enero (C).
- `temp_jul_mean_c`: temperatura media julio (C).

## Accesibilidad
- `iso_01h30m`, `iso_02h00m`, `iso_02h30m`, `iso_03h30m`, `iso_04h00m`: pertenencia booleana por centroide municipal dentro de isocrona precalculada.
- `travel_bucket`: bucket de accesibilidad derivado por celdas y agregado a municipio por mayoria.
- `accesibilidad_norm`: normalizacion por buckets con suelo metodologico de 0.20 para evitar que territorios lejanos colapsen a cero.

## Limitaciones
- La unidad de calculo es celda 2x2 km; el municipio resume distribuciones internas y no microclima de parcela.
- Isocronas fijas precalculadas: no representan variacion horaria o de trafico en tiempo real.

## Entorno natural
- `forest_pct`: porcentaje municipal de coberturas forestales y matorral (OSM `landuse` + `natural`).
- `water_pct`: porcentaje municipal de coberturas de agua (OSM `water` + `natural=water/wetland`).
- `artificial_pct`: porcentaje municipal de coberturas artificiales (OSM `landuse`).
- `naturality_index`: indice simple de naturalidad (0-100).
- `landcover_diversity`: diversidad de coberturas (Shannon normalizado 0-100).
- `protected_areas`: lista contextual opt-in de espacios naturales protegidos presentes en celdas 2x2 km del municipio. Usa `ODESIGNATE` y `SITE_NAME` de MITECO ENP 2025 y no participa en el scoring.
- `protected_areas_source`: fuente textual de la lista anterior cuando se genera con `PIPELINE_INCLUDE_PROTECTED_AREAS=1`.

## Scoring compuesto
- `climate_block_score`: bloque clima (media de precip_moisture_score, temp_verano_norm, temp_invierno_norm).
- `access_block_score`: bloque accesibilidad (accesibilidad_norm).
- `nature_block_score`: bloque naturaleza (media de forest_norm, water_norm, naturality_norm, diversity_norm).
- `mixed_score`: score mixto final = 0.4 * clima + 0.3 * accesibilidad + 0.3 * naturaleza.

## Trazabilidad del dataset
- `dataset_version`: v3.0.0
- `generated_at_utc`: 2026-05-12 08:03:47 UTC
- `analysis_scope`: Castilla y Leon + La Rioja + Pais Vasco + Cantabria + Asturias + Lugo + Ourense + Guadalajara + Madrid

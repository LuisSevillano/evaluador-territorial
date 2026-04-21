# Indicadores v3 - Observatorio Territorial El Buen Vivir

## Identificacion
- `population`: poblacion total (2025). Fuente: INE (Padrón continuo) via mapSpain.
- `population_men`: poblacion masculina (2025).
- `population_women`: poblacion femenina (2025).

## Clima
- `precip_annual_mm`: precipitacion anual (mm). Fuente: TerraClimate mensual. Periodo: 2014-2023. Metodo: suma de climatologia mensual agregada por poligono municipal.
- `temp_winter_mean_c`: temperatura media invierno (C). Fuente: TerraClimate (`tmin`, `tmax`). Metodo: media de dic-ene-feb sobre climatologia mensual municipal.
- `temp_summer_mean_c`: temperatura media verano (C). Metodo: media de jun-jul-ago sobre climatologia mensual municipal.
- `temp_jan_mean_c`: temperatura media enero (C).
- `temp_jul_mean_c`: temperatura media julio (C).

## Accesibilidad
- `iso_01h30m`, `iso_02h00m`, `iso_02h30m`, `iso_03h30m`, `iso_04h00m`: pertenencia booleana por centroide municipal dentro de isocrona precalculada.
- `travel_bucket`: bucket de accesibilidad derivado por prioridad de isocrona minima que contiene el centroide.

## Limitaciones
- Clima agregado a escala municipal desde raster (no microclima de parcela).
- Isocronas fijas precalculadas: no representan variacion horaria o de trafico en tiempo real.

## Entorno natural
- `forest_pct`: porcentaje municipal de coberturas forestales y matorral arbolado (CORINE 311-324).
- `water_pct`: porcentaje municipal de coberturas de agua (CORINE 5xx).
- `artificial_pct`: porcentaje municipal de coberturas artificiales (CORINE 1xx).
- `naturality_index`: indice simple de naturalidad (0-100).
- `landcover_diversity`: diversidad de coberturas (Shannon normalizado 0-100).

## Scoring compuesto
- `climate_block_score`: bloque clima (media de precip_norm, temp_verano_norm, temp_invierno_norm).
- `access_block_score`: bloque accesibilidad (accesibilidad_norm).
- `nature_block_score`: bloque naturaleza (media de forest_norm, water_norm, naturality_norm, diversity_norm).
- `mixed_score`: score mixto final = 0.4 * clima + 0.3 * accesibilidad + 0.3 * naturaleza.

## Trazabilidad del dataset
- `dataset_version`: v3.0.0
- `generated_at_utc`: 2026-04-18 07:17:30 UTC
- `analysis_scope`: Castilla y Leon

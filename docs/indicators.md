# Indicadores v2 - Observatorio Territorial El Buen Vivir

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

## Trazabilidad del dataset
- `dataset_version`: v3.0.0
- `generated_at_utc`: 2026-04-17 21:26:12 UTC
- `analysis_scope`: Castilla y Leon

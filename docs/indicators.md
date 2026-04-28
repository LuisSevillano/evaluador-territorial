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
- `accesibilidad_norm`: normalizacion por buckets con suelo metodologico de 0.20 para evitar que territorios lejanos colapsen a cero.

## Limitaciones
- Clima agregado a escala municipal desde raster (no microclima de parcela).
- Isocronas fijas precalculadas: no representan variacion horaria o de trafico en tiempo real.

## Entorno natural
- `forest_pct`: porcentaje municipal de coberturas forestales y matorral arbolado (CORINE 311-324).
- `water_pct`: porcentaje municipal de coberturas de agua (CORINE 5xx).
- `artificial_pct`: porcentaje municipal de coberturas artificiales (CORINE 1xx).
- `naturality_index`: indice simple de naturalidad (0-100).
- `landcover_diversity`: diversidad de coberturas (Shannon normalizado 0-100).
- `river_access_score`: score simple (0-100) de accesibilidad a cursos fluviales relevantes con potencial recreativo.
- `river_access_class`: clase cualitativa del acceso fluvial (`Muy alta`, `Alta`, `Media`, `Baja`, `Muy baja`).
- `river_nearest_name`: nombre del tramo candidato mas cercano.
- `river_nearest_distance_km`: distancia minima (km) al tramo candidato mas cercano.
- `river_nearest_confidence`: confianza (0-100) de que el tramo mas cercano representa un curso fluvial relevante.
- `river_candidate_count_10km`: numero de tramos candidatos en un radio de 10 km.
- `river_method_version`: version metodologica del filtro/score fluvial aplicado.

## Nota metodologica acceso fluvial
- Esta variable NO mide calidad sanitaria del agua.
- Esta variable NO identifica oficialmente zonas de bano.
- Esta variable aproxima acceso municipal a cursos fluviales relevantes con potencial recreativo.
- Se construye combinando distancia al tramo candidato y confianza del tramo (diagnostico por senales positivas y exclusiones).
- Se evita depender de un unico campo fragil (`ficticio`, `orden`, `persistencia`) como regla dura unica.

## Scoring compuesto
- `climate_block_score`: bloque clima (media de precip_norm, temp_verano_norm, temp_invierno_norm).
- `access_block_score`: bloque accesibilidad (accesibilidad_norm).
- `nature_block_score`: bloque naturaleza (media de forest_norm, water_norm, naturality_norm, diversity_norm).
- `mixed_score`: score mixto final = 0.4 * clima + 0.3 * accesibilidad + 0.3 * naturaleza.

## Trazabilidad del dataset
- `dataset_version`: v3.0.0
- `generated_at_utc`: 2026-04-27 17:22:56 UTC
- `analysis_scope`: Castilla y Leon + La Rioja + Pais Vasco + Cantabria + Asturias + Lugo + Ourense + Guadalajara

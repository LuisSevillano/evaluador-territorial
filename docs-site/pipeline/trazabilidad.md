# Trazabilidad

Esta página muestra cómo seguir una métrica final hasta su script y su fuente.

Sirve para auditar resultados y discutir cambios metodológicos con base técnica.

En una lectura no técnica, trazabilidad significa poder responder: "¿de dónde sale este número?". Si un resultado sorprende, esta página ayuda a encontrar qué proceso lo produjo.

## Cómo usar esta página

1. Busca la métrica que aparece en la app o en el dataset.
2. Revisa el script principal que la calcula.
3. Comprueba la fuente usada.
4. Contrasta la salida final donde debería aparecer.

No hace falta memorizar los nombres de scripts. La tabla sirve como mapa de referencia.

## Mapa métrica -> script -> salida

| Métrica final | Script principal | Fuente | Salida |
|---|---|---|---|
| `precip_annual_mm` | `scripts/02_clima_real.R` | TerraClimate | `municipios_v2.*` |
| `precip_moisture_score`, `moisture_absolute_score`, `summer_drought_score` | `scripts/02_clima_real.R` | TerraClimate 1991-2020 (`ppt`, `pet`, `tmin`, `tmax`) | `municipios_v2.*` |
| `water_drops_level`, `water_drops_label` | `scripts/02_clima_real.R` | Scores absolutos de humedad y sequía estival | `municipios_v2.*` |
| `grid climate monthly` | `scripts/04_extract_monthly_climate_grid.R` | TerraClimate | `frontend/static/data/grid-climate/*.json` |
| `travel_bucket` | `scripts/03_*` | Isochronas precomputadas | `municipios_v2.*` |
| `forest_pct`, `water_pct` | `scripts/04_entorno_mfe.R` | Mapa Forestal de España | `municipios_v2.*` |
| `river_access_score` | `scripts/04z_bathing_access_score.R` + `scripts/04g_build_summer_flow_river_candidates.R` | MAPA/SINAC, CHD, NÁYADE y proxy CNIG/IGR de caudal estival probable | `municipios_bathing_access.*`, `river_summer_flow_candidates.*`, `feature_river_access.*` |
| `transport_status` | `scripts/04b_transporte_renfe.R` | GTFS Renfe | `municipios_v2.*` |
| `mixed_score` | `scripts/05_export_frontend_v2.R` | Derivada de bloques | `municipios_v2.*` |

## Reglas de versionado

- Cada ejecución registra fecha UTC y alcance de análisis.
- Cambios metodológicos actualizan `river_method_version` o versión de dataset.
- Modificaciones de umbrales se documentan en notas de release.
- Los artefactos de rejilla conservan asignación espacial de provincia y CCAA para filtrar por límites administrativos.

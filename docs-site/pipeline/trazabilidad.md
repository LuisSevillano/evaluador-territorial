# Trazabilidad

Esta página muestra cómo seguir una métrica final hasta su script y su fuente.

Sirve para auditar resultados y discutir cambios metodológicos con base técnica.

## Mapa métrica -> script -> salida

| Métrica final | Script principal | Fuente | Salida |
|---|---|---|---|
| `precip_annual_mm` | `scripts/02_clima_real.R` | TerraClimate | `municipios_v2.*` |
| `travel_bucket` | `scripts/03_*` | Isochronas precomputadas | `municipios_v2.*` |
| `forest_pct`, `water_pct` | `scripts/04_*` | CORINE u OSM (según ejecución) | `municipios_v2.*` |
| `river_access_score` | `scripts/04g_banio_score_simple.R` | Red hidro CNIG/IGR | `municipios_river_access.*` |
| `mixed_score` | `scripts/05_export_frontend_v2.R` | Derivada de bloques | `municipios_v2.*` |

## Reglas de versionado

- Cada ejecución registra fecha UTC y alcance de análisis.
- Cambios metodológicos actualizan `river_method_version` o versión de dataset.
- Modificaciones de umbrales se documentan en notas de release.

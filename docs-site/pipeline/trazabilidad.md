# Trazabilidad

## Mapa métrica -> script -> salida

| Métrica final | Script principal | Fuente | Salida |
|---|---|---|---|
| `precip_annual_mm` | `scripts/02_clima_real.R` | TerraClimate | `municipios_v2.*` |
| `travel_bucket` | `scripts/03_*` | Isochronas precomputadas | `municipios_v2.*` |
| `forest_pct`, `water_pct` | `scripts/04_*` | CORINE | `municipios_v2.*` |
| `river_access_score` | `scripts/04g_banio_score_simple.R` | Red hidro CNIG/IGR | `municipios_river_access.*` |
| `mixed_score` | `scripts/05_export_frontend_v2.R` | Derivada | `municipios_v2.*` |

## Reglas de versiónado

- Cada corrida debe registrar fecha UTC y alcance de análisis.
- Cambios metodologicos requieren actualizar `river_method_versión` o versión de dataset.
- Las modificaciones de umbrales deben documentarse en release notes.

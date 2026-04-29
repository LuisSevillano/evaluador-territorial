# QA y validación

Esta página agrupa controles técnicos y metodológicos para revisar una ejecución antes de publicar.

Sirve para evitar errores silenciosos y lecturas apresuradas del ranking.

## Checklist técnico

- Validar que `output/municipios_v2.csv` existe y tiene filas > 0.
- Validar que `frontend/static/data/municipios_v2.json` se actualizó.
- Validar PMTiles en `frontend/static/tiles/`.
- Ejecutar `npm run check` en frontend.

## Validaciones metodológicas

- Revisar distribución de `mixed_score` por percentiles.
- Comprobar que `river_access_score` no se interpreta como calidad de agua.
- Verificar cobertura espacial razonable por provincias.

## Evidencia visual

![Distribución de score mixto](/assets/mixed_score_distribution.png){.theme-image-light}
![Distribución de score mixto](/assets/mixed_score_distribution.dark.png){.theme-image-dark}

![Distribución bloque clima](/assets/climate_block_distribution.png){.theme-image-light}
![Distribución bloque clima](/assets/climate_block_distribution.dark.png){.theme-image-dark}

![Distribución bloque accesibilidad](/assets/access_block_distribution.png){.theme-image-light}
![Distribución bloque accesibilidad](/assets/access_block_distribution.dark.png){.theme-image-dark}

![Distribución bloque naturaleza](/assets/nature_block_distribution.png){.theme-image-light}
![Distribución bloque naturaleza](/assets/nature_block_distribution.dark.png){.theme-image-dark}

![Conteo clases fluviales](/assets/river_class_counts.png){.theme-image-light}
![Conteo clases fluviales](/assets/river_class_counts.dark.png){.theme-image-dark}

## Criterio mínimo para publicar

Cada release debería cumplir:

- Trazabilidad completa métrica-script-fuente.
- Reproducibilidad con comandos documentados.
- Límites explicitados por indicador.
- Ausencia de reglas opacas no documentadas.
- Registro de cambios metodológicos con fecha y justificación.

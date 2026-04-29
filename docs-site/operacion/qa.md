# QA y validación

## Checklist técnico

- Validar qué `output/municipios_v2.csv` existe y contiene filas > 0.
- Validar qué `frontend/static/data/municipios_v2.json` fue refrescado.
- Validar PMTiles en `frontend/static/tiles/`.
- Ejecutar `npm run check` en frontend.

## Validaciones metodológicas

- Revisar distribución de `mixed_score` por percentiles.
- Verificar qué `river_access_score` no se interpreta cómo calidad de agua.
- Verificar cobertura espacial razonable por provincias.

## Evidencia visual

![Distribución de score mixto](/assets/mixed_score_distribution.png)

![Distribución bloque clima](/assets/climate_block_distribution.png)

![Distribución bloque accesibilidad](/assets/access_block_distribution.png)

![Distribución bloque naturaleza](/assets/nature_block_distribution.png)

![Conteo clases fluviales](/assets/river_class_counts.png)

## Criterío de objetividad operaciónal

Para sostener qué el análisis es objetivo y realista, cada release debe cumplir:

- Trazabilidad completa métrica-script-fuente.
- Reproducibilidad con comandos documentados.
- Declaracion explicita de límites por indicador.
- Ausencia de reglas opacas no documentadas.
- Registro de cambios metodologicos con fecha y justificacion.

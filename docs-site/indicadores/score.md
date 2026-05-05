# Score compuesto

Esta página explica cómo se combina toda la información del Atlas en una sola puntuación comparativa.

Sirve para priorizar opciones. No sustituye el análisis local.

## Fórmula global

`mixed_score = 40% puntuación clima + 30% puntuación accesibilidad + 30% puntuación naturaleza`

![Mapa del score mixto municipal](/assets/map_mixed_score.light.png){.theme-image-light}
![Mapa del score mixto municipal](/assets/map_mixed_score.dark.png){.theme-image-dark}

![Distribución de score mixto](/assets/mixed_score_distribution.png){.theme-image-light}
![Distribución de score mixto](/assets/mixed_score_distribution.dark.png){.theme-image-dark}

## Qué resume cada bloque

- Clima `climate_block_score`: precipitación y temperaturas estacionales.
- Accesibilidad `access_block_score`: posición relativa en isocronas de acceso.
- Natualeza `nature_block_score`: entorno natural y acceso fluvial con pesos publicados.

## Ponderación interna de naturaleza

- `forest_norm`: 0.30
- `water_norm`: 0.20
- `naturality_norm`: 0.25
- `diversity_norm`: 0.15
- `river_access_norm`: 0.10

![Ponderación global del score mixto](/assets/score_weights_global_treemap.light.png){.theme-image-light}
![Ponderación global del score mixto](/assets/score_weights_global_treemap.dark.png){.theme-image-dark}

![Ponderación interna del bloque naturaleza](/assets/score_weights_nature_treemap.light.png){.theme-image-light}
![Ponderación interna del bloque naturaleza](/assets/score_weights_nature_treemap.dark.png){.theme-image-dark}

![Contribución media de componentes de naturaleza](/assets/nature_component_mean_contribution.light.png){.theme-image-light}
![Contribución media de componentes de naturaleza](/assets/nature_component_mean_contribution.dark.png){.theme-image-dark}

![Descomposición score mixto: Top 10 municipios](/assets/score_rank_tornado_top10.light.png){.theme-image-light}
![Descomposición score mixto: Top 10 municipios](/assets/score_rank_tornado_top10.dark.png){.theme-image-dark}

## Cómo leer la puntuación

Un `mixed_score` alto suele indicar mejor equilibrio entre bloques dentro del alcance actual. Aún así, hay que leer el desglose: un municipio puede compensar un bloque flojo con otro muy fuerte.

Ejemplo: un municipio con muy buen clima pero accesibilidad baja puede quedar por debajo de otro más equilibrado.

## Límites de interpretación

- El score es comparativo, no causal.
- No convierte automáticamente un valor alto en "mejor decisión".
- Debe complementarse con visita, contexto local y criterio propio.

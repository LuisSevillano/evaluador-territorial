# Score compuesto

Esta página explica cómo se combina toda la información del Atlas en una sola puntuación comparativa.

Sirve para priorizar opciones. No sustituye el análisis local.

## Fórmula global

`mixed_score = 0.4 * climate_block_score + 0.3 * access_block_score + 0.3 * nature_block_score`

![Mapa del score mixto municipal](/assets/map_mixed_score.light.png){.theme-image-light}
![Mapa del score mixto municipal](/assets/map_mixed_score.dark.png){.theme-image-dark}

![Distribución de score mixto](/assets/mixed_score_distribution.png){.theme-image-light}
![Distribución de score mixto](/assets/mixed_score_distribution.dark.png){.theme-image-dark}

## Qué resume cada bloque

- `climate_block_score`: precipitación y temperaturas estacionales.
- `access_block_score`: posición relativa en isocronas de acceso.
- `nature_block_score`: entorno natural y acceso fluvial con pesos publicados.

## Ponderación interna de naturaleza

- `forest_norm`: 0.30
- `water_norm`: 0.20
- `naturality_norm`: 0.25
- `diversity_norm`: 0.15
- `river_access_norm`: 0.10

## Cómo leer la puntuación

Un `mixed_score` alto suele indicar mejor equilibrio entre bloques dentro del alcance actual. Aún así, hay que leer el desglose: un municipio puede compensar un bloque flojo con otro muy fuerte.

Ejemplo: un municipio con muy buen clima pero accesibilidad baja puede quedar por debajo de otro más equilibrado.

## Límites de interpretación

- El score es comparativo, no causal.
- No convierte automáticamente un valor alto en "mejor decisión".
- Debe complementarse con visita, contexto local y criterio propio.

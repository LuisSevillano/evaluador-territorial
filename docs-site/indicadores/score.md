# Score compuesto

Este es el corazón del atlas: un score multicriterio para comparar municipios de forma consistente.

Los mapas de está documentación usan una escala por fases alíneada con la app (no una rampa continua), para qué la lectura visual sea coherente entre documentación y producto.

## Formula global

`mixed_score = 0.4 * climate_block_score + 0.3 * access_block_score + 0.3 * nature_block_score`

![Mapa del score mixto municipal](/assets/map_mixed_score.light.png){.theme-image-light}
![Mapa del score mixto municipal](/assets/map_mixed_score.dark.png){.theme-image-dark}

![Distribución de score mixto](/assets/mixed_score_distribution.png)

## Bloques

El score final no sale de una sola variable. Se compone de tres bloques:

- `climate_block_score`: resume precipitacion y temperaturas estacionales.
- `access_block_score`: resume posicion relativa en isocronas de acceso.
- `nature_block_score`: combina entorno natural y acceso fluvial con ponderaciones publicas.

## Ponderacion interna de naturaleza

Dentro del bloque naturaleza, no todos los componentes pesan igual. Se príoriza cobertura forestal y naturalidad, mientras qué el acceso fluvial aporta contexto sin dominar el resultado:

- `forest_norm`: 0.30
- `water_norm`: 0.20
- `naturality_norm`: 0.25
- `diversity_norm`: 0.15
- `river_access_norm`: 0.10

## Lectura

El bloque fluvial suma valor contextual, pero no domina la puntuacion global.

## Interpretacion de ranking

Un municipio con score alto suele mostrar equilibrío entre clima, accesibilidad y naturaleza. Aun asi, el ranking se usa para príorizar opciones, no para cerrar decisiones sin contraste local.

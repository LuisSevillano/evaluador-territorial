# Score compuesto

Esta página explica cómo se combina toda la información del Atlas en una sola puntuación comparativa.

Sirve para priorizar opciones. No sustituye el análisis local.

## Cómo leerlo en la práctica

El score compuesto es una forma de ordenar municipios cuando quieres mirar varias cosas a la vez. Resume clima, accesibilidad y naturaleza en un único valor.

Un score alto suele indicar buen equilibrio dentro del alcance actual. Pero no significa que el municipio sea "mejor" en todos los sentidos.

La pregunta útil no es solo "qué municipio gana", sino "por qué queda arriba".

Ejemplo: un municipio puede tener muy buen clima y naturaleza, pero accesibilidad baja. Otro puede tener menos atractivo natural, pero estar mejor conectado. El score ayuda a compararlos, pero la decisión depende de qué pese más en el caso concreto.

## Qué resume cada bloque

- **Clima**: lluvia y temperaturas estacionales.
- **Accesibilidad**: posición relativa en tramos de tiempo de acceso.
- **Naturaleza**: entorno natural, agua, relieve y acceso fluvial recreativo potencial.

## Fórmula global

`mixed_score = 40% puntuación clima + 30% puntuación accesibilidad + 30% puntuación naturaleza`

![Ponderación global del score mixto](/assets/score_weights_global_treemap.light.png){.theme-image-light}
![Ponderación global del score mixto](/assets/score_weights_global_treemap.dark.png){.theme-image-dark}

![Mapa del score mixto municipal](/assets/map_mixed_score.light.png){.theme-image-light}
![Mapa del score mixto municipal](/assets/map_mixed_score.dark.png){.theme-image-dark}

![Distribución de score mixto](/assets/mixed_score_distribution.png){.theme-image-light}
![Distribución de score mixto](/assets/mixed_score_distribution.dark.png){.theme-image-dark}

En el dataset, el score final aparece como `mixed_score`.

## Cómo leer la puntuación

Un `mixed_score` alto suele indicar mejor equilibrio entre bloques dentro del alcance actual. Aún así, hay que leer el desglose: un municipio puede compensar un bloque flojo con otro muy fuerte.

![Descomposición score mixto: Top 10 municipios](/assets/score_rank_tornado_top10.light.png){.theme-image-light}
![Descomposición score mixto: Top 10 municipios](/assets/score_rank_tornado_top10.dark.png){.theme-image-dark}

Cuando dos municipios tienen puntuaciones parecidas, conviene tratarlos como alternativas similares y revisar el detalle por bloques.

## Ponderación interna de naturaleza

Cada métrica se normaliza en escala comparativa (0 a 1) antes de combinarse:

- Calidad natural forestal (`forest_nature_quality_norm`): 0.52
- Presencia de agua superficial (`water_norm`): 0.20
- Diversidad de usos y coberturas del suelo (`diversity_norm`): 0.10
- Acceso fluvial recreativo potencial (`river_access_norm`): 0.06
- Relieve (variabilidad y complejidad topográfica) (`relieve_norm`): 0.12

## Trazabilidad de datos y cálculo técnico

Para que el resultado sea auditable, cada componente del score queda ligado a su fuente y a una regla explícita.

- Calidad natural forestal (`forest_nature_quality_norm`): se deriva de coberturas naturales y forestales agregadas por municipio a partir del [Mapa Forestal de España (MFE)](https://www.miteco.gob.es/es/cartografia-y-sig/ide/descargas/biodiversidad/mfe.html).
- Presencia de agua superficial (`water_norm`): se obtiene de la proporción municipal de superficie clasificada como agua en la cartografía de coberturas utilizada en el bloque naturaleza.
- Diversidad de coberturas (`diversity_norm`): resume cuántos tipos de cobertura distintos hay dentro de cada municipio.
- Acceso fluvial recreativo (`river_access_norm`): combina proximidad a red fluvial y calidad/confianza del tramo candidato para uso recreativo potencial.
- Relieve (`relieve_norm`): resume la complejidad topográfica municipal con métricas de altitud, pendiente y rugosidad.

Flujo general de cálculo del score:

1. Cálculo de indicadores por bloque (clima, accesibilidad y naturaleza) a escala municipal.
2. Normalización de cada métrica en escala comparativa dentro del alcance activo.
3. Ponderación por bloques y combinación final en `mixed_score`.

Así, cada valor publicado en un municipio puede rastrearse a su origen de datos y a la regla aplicada en pipeline.

![Ponderación interna del bloque naturaleza](/assets/score_weights_nature_treemap.light.png){.theme-image-light}
![Ponderación interna del bloque naturaleza](/assets/score_weights_nature_treemap.dark.png){.theme-image-dark}

![Contribución media de componentes de naturaleza](/assets/nature_component_mean_contribution.light.png){.theme-image-light}
![Contribución media de componentes de naturaleza](/assets/nature_component_mean_contribution.dark.png){.theme-image-dark}

## Límites de interpretación

- El score es comparativo, no causal.
- No convierte automáticamente un valor alto en "mejor decisión".
- Debe complementarse con visita, contexto local y criterio propio.

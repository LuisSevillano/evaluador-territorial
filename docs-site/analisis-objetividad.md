# Cómo leer los resultados con criterio

Esta página resume cómo revisar el ranking sin confundir un indicador útil con una verdad absoluta.

Sirve para compartir resultados con terceros de forma honesta: mostrando fortalezas y límites.

## Qué significa "objetividad" aquí

En este Atlas, objetividad significa algo concreto: reglas visibles, cálculo reproducible y trazabilidad.

No significa neutralidad perfecta ni ausencia de decisiones metodológicas. Los pesos y umbrales existen, y están documentados para poder revisarlos.

## Evidencias rápidas para comprobar coherencia

Antes de interpretar resultados en profundidad, conviene mirar tres piezas:

- Distribución de `mixed_score`.
- Medias por bloque (`climate_block_score`, `access_block_score`, `nature_block_score`).
- Municipios en los extremos del ranking.

Estas comprobaciones no demuestran "la verdad del territorio", pero ayudan a detectar salidas raras o patrones poco creíbles.

![Bloque naturaleza por municipio](/assets/map_nature_score.light.png){.theme-image-light}
![Bloque naturaleza por municipio](/assets/map_nature_score.dark.png){.theme-image-dark}

## Preguntas de robustez útiles

Para evaluar si el ranking aguanta, conviene revisar:

1. Si cambios razonables de pesos alteran mucho el orden.
2. Si el patrón espacial tiene sentido con la geografía observada.
3. Si cada indicador se interpreta dentro de su alcance real.

## Checklist de confianza

- Se puede trazar cada métrica a su script y fuente.
- La ejecución se puede reproducir con comandos documentados.
- Los límites metodológicos están explícitos.
- Cambios de pesos o umbrales quedan registrados.
- El resultado tabular y el geoespacial son consistentes.

## Qué no conviene hacer

No conviene usar el score para cerrar una decisión de emplazamiento sin contraste local. El Atlas orienta el análisis y reduce parte de la incertidumbre, pero no reemplaza el criterio humano ni la validación en campo.

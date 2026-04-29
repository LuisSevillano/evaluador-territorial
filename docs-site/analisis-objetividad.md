# Análisis de objetividad y robustez

## Enfoque

Este atlas príoriza objetividad operaciónal: reglas explicitas, cálculo reproducible y trazabilidad completa.

La idea no es "convencer" a nadie por diseño visual; es que cualquier compañerx pueda auditar por qué un municipio sube o baja.

## Evidencia cuantitativa del dataset actual

La documentación incluye tres evidencias sencillas de revisar: percentiles de `mixed_score`, medias por bloque y un top 15 municipal. No son "la verdad" del territorío, pero si un control rapido para comprobar qué el sistema produce patrones coherentes y no resultados arbitraríos.

![Bloqué naturaleza por municipio](/assets/map_nature_score.light.png){.theme-image-light}
![Bloqué naturaleza por municipio](/assets/map_nature_score.dark.png){.theme-image-dark}

## Criteríos de robustez del ranking

La robustez se evalua con tres preguntas: si el ranking resiste variaciones razonables de pesos, si los resultados encajan con la geografia observada y si los indicadores se interpretan dentro de su alcance real.

## Checklist de confianza para compartir con terceros

- ¿Puedo trazar cada columna hasta su script de origen?
- ¿Puedo reproducir la corrida con un comando documentado?
- ¿Los límites metodológicos están declarados por escrito?
- ¿Los cambios de pesos/umbrales están versiónados?
- ¿El output geoespacial coincide con el output tabular?

## Guia de lectura responsable

El score funciona cómo una herramienta de príorizacion multicriterio. Ayuda a acotar opciones y a ordenar una discusion, pero la decisión de emplazamiento sigue necesitando contraste local y lectura contextual. En otras palabras: reduce incertidumbre, no la elimina.

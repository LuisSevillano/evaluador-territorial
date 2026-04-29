# Arquitectura del Atlas

Esta página explica cómo se conecta el trabajo técnico de datos con el resultado que se ve en el mapa.

Sirve para entender el recorrido completo antes de entrar al detalle de scripts.

## Cómo funciona en la práctica

La arquitectura tiene tres capas:

1. **Cálculo**: convierte fuentes distintas en indicadores comparables por municipio.
2. **Geoespacial**: prepara archivos ligeros para web (sin perder trazabilidad).
3. **Producto**: muestra resultados en mapa, filtros y fichas municipales.

## Flujo de extremo a extremo

El flujo siempre sigue esta secuencia: definir alcance, preparar base municipal, calcular bloques (clima, accesibilidad y naturaleza), validar calidad y publicar.

Si un municipio sube o baja en ranking, el cambio se puede rastrear hasta una regla concreta o una actualización de datos.

## Qué aporta esta separación por capas

Permite trabajar con orden y evitar cajas negras. El cálculo no depende de la interfaz, y la interfaz no inventa resultados: solo muestra lo que el pipeline genera.

![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.light.png){.theme-image-light}
![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.dark.png){.theme-image-dark}

> Lectura recomendada: los anillos diferenciales ayudan a comparar mejor que las capas solapadas, porque evitan contar varias veces la misma zona visual.

## Límites a tener en cuenta

Esta arquitectura mejora la consistencia del análisis, pero no elimina incertidumbre. Un resultado sólido en datos sigue necesitando contraste local: visitas, contexto social y comprobación en terreno.

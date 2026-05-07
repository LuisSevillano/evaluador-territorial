# Arquitectura del Atlas

Conecta el trabajo de datos con lo que vemos en la aplicación.

Esta página es una explicación breve de cómo se separan las piezas del proyecto. Sirve para entender por qué un cambio en datos, mapa o documentación puede afectar a lugares distintos.

## Cómo funciona

Tres capas:

* **Cálculo**: transforma fuentes en indicadores comparables (rejilla y municipio).
* **Geoespacial**: prepara archivos para el mapa.
* **Producto**: muestra resultados (mapa, filtros y fichas).

## Flujo

Definir alcance → calcular indicadores → validar → exportar → publicar.

Los cambios en ranking son trazables a reglas o datos concretos.

## Visualización

* Vista municipal (general)
* Vista de rejilla (detalle)
* Cambio automático por zoom

## Clave

Separar capas evita cajas negras: el cálculo genera, la interfaz solo muestra.

![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.light.png){.theme-image-light}
![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.dark.png){.theme-image-dark}

## Límites

Esta arquitectura mejora la consistencia del análisis, pero no elimina incertidumbre. Un resultado sólido en datos sigue necesitando contraste local: visitas, contexto social y comprobación en terreno.

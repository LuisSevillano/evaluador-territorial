# Indicadores de accesibilidad

Esta página explica cómo se resume la accesibilidad temporal de cada municipio.

Sirve para comparar facilidad de acceso, no para describir todos los problemas reales de movilidad.

## Cómo leer este bloque

La accesibilidad ayuda a entender cuánto pesa la distancia práctica a centros de referencia. Un municipio mejor conectado suele facilitar visitas, gestiones, servicios y desplazamientos cotidianos.

Aun así, una buena accesibilidad no significa que todo esté resuelto. Puede seguir habiendo dependencia del coche, pocas frecuencias de transporte público o servicios locales limitados.

La lectura útil es comparativa: este lugar queda mejor o peor conectado que otros dentro del mismo alcance.

## Qué se mide

Se usan tres piezas:

- Pertenencia a tramos de tiempo de 1h30 a 4h.
- Una categoría resumen de accesibilidad.
- Una puntuación normalizada para combinar este bloque con clima y naturaleza.

En el diccionario de datos aparecen como `travel_bucket` y `accesibilidad_norm`.

En la versión actual, las isocronas del pipeline vienen de TravelTime API (`/v4/time-map/fast`) y se guardan como capas precomputadas para mantener reproducibilidad.

## Cómo se calcula

Cada municipio se evalúa con un punto representativo y se comprueba en qué anillo temporal cae. Si cae en varios, se prioriza el más favorable para aplicar una regla única.

![Anillos de isocronas diferenciales sobre CCAA y provincias peninsulares](/assets/map_isochrones_diff.light.png){.theme-image-light}
![Anillos de isocronas diferenciales sobre CCAA y provincias peninsulares](/assets/map_isochrones_diff.dark.png){.theme-image-dark}

La leyenda usa los mismos tramos temporales que la app (`<=1h30` a `<=4h00`) para mantener consistencia visual.

![Distribución bloque accesibilidad](/assets/access_block_distribution.png){.theme-image-light}
![Distribución bloque accesibilidad](/assets/access_block_distribution.dark.png){.theme-image-dark}

![Distribución buckets de accesibilidad](/assets/access_bucket_counts.light.png){.theme-image-light}
![Distribución buckets de accesibilidad](/assets/access_bucket_counts.dark.png){.theme-image-dark}

## Cómo interpretarlo en una comparación

Un bucket bajo sugiere mejor acceso relativo. Aún así, no implica que todos los servicios estén cubiertos dentro del municipio.

Ejemplo: un lugar puede quedar bien en isocrona por carretera, pero depender del coche para casi todo o tener pocas frecuencias de transporte público.

## Conectividad Renfe con Madrid

El Atlas incluye una lectura específica de tren para saber si un municipio tiene conexión Renfe con Madrid o si depende de una estación cercana.

La interpretación visible en el panel es sencilla:

- Verde: el municipio contiene conexión directa con Madrid.
- Amarillo: hay una estación con conexión a Madrid a 15 km o menos.
- Rojo: la estación conectada más cercana queda a más de 15 km.

La distancia publicada es en línea recta y no sustituye el tiempo real puerta a puerta. Para ver el criterio completo, consulta [Transporte y tren](/indicadores/transporte-tren).

## Límites

Este bloque resume tiempos de acceso. No mide por sí solo calidad de carreteras, frecuencia real diaria de servicios ni incidencias puntuales de trayecto.

Tampoco sustituye la comprobación concreta de cómo se llega desde una vivienda, finca o zona específica del municipio.

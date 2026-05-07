# Indicadores de accesibilidad

Esta página explica cómo se resume la accesibilidad temporal de cada municipio.

Sirve para comparar facilidad de acceso, no para describir todos los problemas reales de movilidad.

## Qué se mide

Se usan tres piezas:

- Pertenencia a isocronas de 1h30 a 4h.
- `travel_bucket` como categoría resumen.
- `accesibilidad_norm` para combinar este bloque con el resto del modelo.

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

## Cómo interpretarlo

Un bucket bajo sugiere mejor acceso relativo. Aún así, no implica que todos los servicios estén cubiertos dentro del municipio.

Ejemplo: un lugar puede quedar bien en isocrona por carretera, pero depender del coche para casi todo o tener pocas frecuencias de transporte público.

## Límites

Este bloque resume tiempos de acceso. No mide por sí solo calidad de carreteras, frecuencia real diaria de servicios ni incidencias puntuales de trayecto.

## Conectividad Renfe con Madrid

El indicador ferroviario complementario se calcula solo con servicios observados en GTFS de Renfe. No usa nodos OSM para puntuar estaciones, porque una estación cartografiada no garantiza servicio activo.

La primera versión mide conexión directa hacia Madrid sobre todo el calendario disponible en el feed GTFS. Para cada parada se comprueba si existen viajes que pasan por esa parada y posteriormente por una parada Madrid. Después se resume cobertura del calendario, salidas medias diarias, servicio en fin de semana y distancia municipal a la parada conectada más cercana.

No incluye autobús ni transbordos en esta fase.

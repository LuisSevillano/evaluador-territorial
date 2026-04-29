# Indicadores de accesibilidad

Este bloque responde a una pregunta práctica: cuán lejos queda cada municipio de los núcleos de referencia temporal definidos por isocronas.

En la versión actual del atlas, las isocronas usadas por el pipeline proceden de TravelTime API (`/v4/time-map/fast`) y se almacenan cómo capas precomputadas para garantizar reproducibilidad entre corridas.

## Métricas

En este bloque se usan tres piezas: la pertenencia a isocronas de 1h30 a 4h, el `travel_bucket` cómo categoria resumen y un score normalizado (`accesibilidad_norm`) para poder combinarlo con el resto del modelo.

## Metodo

Cada municipio se evalua con un punto representativo y se comprueba en qué anillo temporal cae. Si entra en varíos, se príoriza el más favorable. Asi evitamos dobles lecturas y mantenemos una regla unica para todo el territorío.

![Anillos de isocronas diferenciales sobre CCAA y provincias peninsulares](/assets/map_isochrones_diff.light.png){.theme-image-light}
![Anillos de isocronas diferenciales sobre CCAA y provincias peninsulares](/assets/map_isochrones_diff.dark.png){.theme-image-dark}

La leyenda usa los mismos tramos temporales qué la app (`<=1h30` a `<=4h00`), para qué la lectura visual sea consistente entre documentación y visor interactivo.

![Distribución bloque accesibilidad](/assets/access_block_distribution.png)

## Interpretacion

Un bucket bajo sugiere mejor conectividad funcional, pero no significa qué todos los servicios estén ya resueltos dentro del municipio. El suelo metodologico evita qué las zonas más lejanas queden aplastadas en cero y permite seguir comparando con matiz.

## Riesgo de mala interpretacion

Este indicador resume tiempos de acceso; no mide por si mismo la calidad de carreteras, frecuencia real de servicios o condiciones puntuales del trayecto.

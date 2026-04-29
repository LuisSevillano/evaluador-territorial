# Naturaleza y acceso fluvial recreativo

Esta página explica cómo se evalúa el entorno natural y el acceso potencial a ríos para uso recreativo.

Sirve para comparar municipios con una regla común. No sirve para certificar calidad sanitaria del agua.

## Entorno natural

El bloque combina cobertura forestal, cobertura de agua, superficie artificial y diversidad de usos del suelo. La idea es evitar depender de una sola variable.

En esta ejecución, las métricas se calcularon sobre capas OSM (Geofabrik) como fallback operativo de `04_entorno_corine.R`. Cuando CORINE está disponible y validado, ese mismo script puede usar CORINE como fuente principal.

## Acceso fluvial recreativo

Para ríos, el Atlas publica:

- `river_access_score`
- `river_access_class`
- Tramo de referencia más cercano
- Metadatos de control (distancia, confianza y candidatos en 10 km)

![Acceso fluvial recreativo (score)](/assets/map_river_access.light.png){.theme-image-light}
![Acceso fluvial recreativo (score)](/assets/map_river_access.dark.png){.theme-image-dark}

![Clases de acceso fluvial](/assets/river_class_counts.png){.theme-image-light}
![Clases de acceso fluvial](/assets/river_class_counts.dark.png){.theme-image-dark}

## Regla de cálculo

`river_access_score = distance_score * river_nearest_confidence / 100`

La distancia se traduce por tramos para evitar saltos bruscos poco intuitivos.

## Cómo se decide qué tramo cuenta como "río útil"

No se usa una sola columna. El script combina señales y aplica exclusiones:

1. Señales positivas (nombre, whitelist, anchura, códigos hidro, flags de demarcación).
2. Exclusiones (canales, tramos efímeros o mareales).
3. Control geométrico (descarta tramos demasiado cortos).

Con eso, cada tramo recibe una confianza de 0 a 100. Luego se busca el candidato más cercano a cada municipio y se combina cercanía + confianza.

## Límites importantes

- No mide calidad sanitaria del agua.
- No sustituye el inventario oficial de zonas de baño.
- No garantiza uso recreativo real durante todo el año.

En resumen, este indicador dice "mejor o peor acceso potencial relativo" dentro del alcance analizado.

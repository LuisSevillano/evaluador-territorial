# Naturaleza y acceso fluvial recreativo

Esta página explica cómo se evalúa el entorno natural y el acceso potencial a ríos para uso recreativo.

Sirve para comparar municipios con una regla común. No sirve para certificar calidad sanitaria del agua.

## Cómo leer este bloque

El bloque de naturaleza intenta resumir el contexto ambiental de cada municipio sin depender de una sola señal.

Un lugar puede tener mucha cobertura forestal, pero poca agua superficial. Otro puede tener menos bosque, pero más diversidad de coberturas o mejor acceso fluvial potencial. Por eso el Atlas combina varias piezas.

La lectura correcta es: qué municipios ofrecen un entorno natural relativamente más favorable dentro del alcance actual.

## Qué se mide en entorno natural

El bloque combina cobertura forestal, láminas de agua, superficie artificial y diversidad de usos del suelo. La idea es evitar depender de una sola variable.

`water_pct` es superficie de agua cartografiada. Es útil como contexto, pero no resume la experiencia de agua del municipio: no mide arroyos estrechos, caudal, accesibilidad, aptitud legal ni calidad sanitaria. Por eso la interfaz prioriza distancia al tramo de referencia y clase de acceso fluvial, y deja las láminas de agua como detalle secundario.

También incorpora relieve, porque la variabilidad topográfica puede cambiar mucho la experiencia del territorio.

## Espacios naturales protegidos

De forma opcional, el pipeline puede cruzar la rejilla 2x2 km con la capa oficial de Espacios Naturales Protegidos 2025 del MITECO.

Cuando está activado (`PIPELINE_INCLUDE_PROTECTED_AREAS=1`), la ficha del municipio o celda puede mostrar una lista contextual con formato:

- `Parque Regional: nombre del espacio`
- `Reserva Natural: nombre del espacio`
- `Parque Nacional: nombre del espacio`

La figura procede del campo oficial `ODESIGNATE` y el nombre del campo `SITE_NAME`. Esta información no crea una métrica nueva, no modifica el bloque de naturaleza y no afecta al `mixed_score`.

## Acceso fluvial recreativo

Para ríos, el Atlas publica:

- `river_access_score`
- `river_access_class`
- Tramo de referencia más cercano
- Metadatos de control (distancia, confianza y candidatos en 10 km)

Esto no significa que el agua sea apta para baño. Significa que, con los datos disponibles, hay mejor o peor acceso potencial a un tramo fluvial de referencia.

![Acceso fluvial recreativo (score)](/assets/map_river_access.light.png){.theme-image-light}
![Acceso fluvial recreativo (score)](/assets/map_river_access.dark.png){.theme-image-dark}

![Clases de acceso fluvial](/assets/river_class_counts.png){.theme-image-light}
![Clases de acceso fluvial](/assets/river_class_counts.dark.png){.theme-image-dark}

## Regla de cálculo

`river_access_score = distance_score * river_nearest_confidence / 100`

La distancia se traduce por tramos para evitar saltos bruscos poco intuitivos.

## Fuentes y cálculo técnico

Las métricas de entorno se calculan sobre capas territoriales de coberturas y agua. El acceso fluvial combina cercanía y confianza del tramo candidato.

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

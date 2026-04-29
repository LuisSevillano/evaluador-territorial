# Naturaleza y acceso fluvial recreativo

Esta parte del atlas intenta responder algo muy concreto: si un municipio tiene, en la práctica, buena accesibilidad a ríos que probablemente sean aptos para uso recreativo cotidiano.

No se trata de adivinar calidad sanitaria del agua ni de etiquetar zonas oficiales de baño. Es una aproximación territorial, útil para comparar municipios con un criterio homogéneo.

## Entorno natural

El bloque natural combina cobertura forestal, cobertura de agua, superficie artificial y diversidad de usos del suelo. Con esas piezas se forma una lectura territorial que evita depender de una sola variable.

En esta ejecución concreta, estas métricas se han calculado sobre capas OSM (Geofabrik) como fallback operativo del script `04_entorno_corine.R`. Cuando CORINE está disponible y validado, el mismo script puede usar CORINE como fuente principal.

## Acceso fluvial recreativo

Para ríos, el atlas expone un score de acceso (`river_access_score`), su clase cualitativa, el tramo de referencia más cercano y metadatos de control como distancia, confianza y densidad de candidatos en 10 km.

![Acceso fluvial recreativo (score)](/assets/map_river_access.light.png){.theme-image-light}
![Acceso fluvial recreativo (score)](/assets/map_river_access.dark.png){.theme-image-dark}

![Clases de acceso fluvial](/assets/river_class_counts.png)

## Regla de cálculo

`river_access_score = distance_score * river_nearest_confidence / 100`

La distancia se traduce a un `distance_score` por tramos (de muy cerca a muy lejos) para evitar cambios bruscos poco intuitivos y mantener una lectura estable entre municipios.

## Aclaraciones críticas

Este indicador no mide calidad sanitaria del agua ni sustituye el inventario oficial de zonas de baño. Lo que aporta es una medida comparable de acceso potencial recreativo a red fluvial.

## Por qué este enfoque es conservador

El criterio es conservador porque primero exige señales de río plausible y después descarta explicitamente lo que introduce ruido (canales, tramos efímeros o mareales). A partir de ahí pondera cercanía y confianza, en vez de dar por válido cualquier línea azul del mapa.

## Cómo se determina que un tramo cuenta como "río útil"

El script no usa una sola columna para decidir. Combina varias señales y después aplica exclusiones duras:

1. **Señales positivas**: nombre de río, inclusión en una whitelist de ríos relevantes, anchura suficiente, códigos hidro consistentes y flags de demarcación.
2. **Exclusiones**: segmentos artificiales (canales/acequias/drenajes), tramos efímeros o intermitentes y tramos mareales.
3. **Control geométrico**: descarta tramos demasiado cortos para evitar ruido cartográfico.

Con eso, cada tramo recibe una **confianza** de 0 a 100. Luego, para cada municipio, se busca el tramo candidato más cercano y se combina cercanía + confianza para obtener `river_access_score`.

El resultado no dice "aquí se puede bañar"; dice "aquí hay mejor o peor acceso potencial a red fluvial recreativa" comparado con el resto del ámbito.

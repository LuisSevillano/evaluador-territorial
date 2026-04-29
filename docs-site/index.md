# Atlas territorial de El Buen Vivir

Esta documentación explica cómo se calcula el ranking municipal del proyecto y qué grado de confianza podemos atribuir a cada resultado.

La idea es sencilla: que cualquier persona del equipo pueda seguir el rastro de un valor desde el mapa final hasta la fuente original y el script que lo produjo.

## Qué problema resuelve este atlas

Cuando buscamos el mejor lugar para emplazar El Buen Vivir, aparecen tres preguntas:

1. Donde el **clima** es más favorable.
2. Donde la **accesibilidad** no penaliza la vida diaria.
3. Donde el **entorno natural** aporta calidad territorial real.

El atlas convierte estas preguntas en indicadores comparables, con reglas explicitas y trazabilidad completa.

![Mapa del score mixto municipal](/assets/map_mixed_score.light.png){.theme-image-light}
![Mapa del score mixto municipal](/assets/map_mixed_score.dark.png){.theme-image-dark}

## Qué ofrece (y qué no ofrece)

El atlas ofrece una comparación objetiva entre municipios mediante un sistema reproducible, con trazabilidad completa de métrica a script y fuente. También permite explicar el resultado por bloques (clima, accesibilidad y naturaleza), lo que facilita discutir decisiones con criterios técnicos y no solo por intuición.

Al mismo tiempo, hay límites claros: no sustituye trabajo de campo, no pretende dar una verdad absoluta descontextualizada y no infiere variables que no estén respaldadas por datos (por ejemplo, calidad sanitaria del agua).

## Cómo leer esta documentación

La documentación está dividida en dos capas. La primera, "Entender el atlas", cuenta el enfoque con lenguaje general y ejemplos visuales. La segunda, "Anexo técnico", concentra nomenclatura de scripts, runbooks y detalles de ejecución para quien necesita reproducir o depurar.

Si quieres una lectura corta y clara, empieza por [Arquitectura del atlas](/arquitectura) y sigue con [Por qué confiar en el análisis](/analisis-objetividad). Si después quieres auditar cada variable, salta a [Diccionario completo](/indicadores/data-dictionary).

## Estado actual del alcance

- Scope por defecto: Castilla y León, La Rioja, País Vasco, Cantabria, Asturias, Lugo, Ourense y Guadalajara.
- Unidad de análisis: municipio.
- Salida principal: `mixed_score` + descomposición por bloques.

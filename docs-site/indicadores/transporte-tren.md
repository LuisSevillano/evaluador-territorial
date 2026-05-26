# Transporte y tren

Esta página explica cómo leer la información ferroviaria del Atlas. Sirve para entender si un municipio tiene conexión Renfe con Madrid o si depende de una estación cercana.

El indicador no pretende describir toda la movilidad de un lugar. Resume una pregunta concreta: qué relación tiene el municipio con estaciones Renfe que conectan con Madrid.

## Piloto OpenTripPlanner Burgos-Madrid

El pipeline incorpora un piloto opt-in con OpenTripPlanner para estimar tiempo programado por transporte público desde Madrid hasta la mejor parada GTFS del municipio, usando como origen el mejor resultado entre varios intercambiadores de Madrid.

El escenario base es cualquier día laborable (lunes a viernes) de una semana tipo. Para cada municipio, el piloto prueba cada día laborable hasta 5 paradas GTFS candidatas (por nombre municipal o por cercanía), y se queda con la mejor conexión encontrada. La ventana horaria es de 07:00 a 23:00.

Los orígenes probados son Avenida de América, Moncloa, Estación Sur y Chamartín. El piloto primero prueba cada parada candidata con un origen principal (Avenida de América). Si encuentra ruta, refina probando los 3 orígenes restantes para quedarse con el mejor resultado.

Cuando la parada coincide exactamente con el nombre del municipio, la confianza se marca como `pilot`. Cuando la parada se deduce por cercanía al centroide municipal (hasta 15 km), la confianza se marca como `pilot_nearest_stop`. En la salida se incluyen el nombre de la parada usada, la distancia al centroide (si aplica) y el día laborable con mejor conexión.

Este cálculo solo se genera cuando se ejecuta `PIPELINE_INCLUDE_OTP_TRANSIT=1`. No cambia el score principal ni sustituye las isocronas actuales: añade contexto para auditar si los horarios GTFS publicados ofrecen una conexión razonable.

La lectura debe hacerse con cautela: depende de los GTFS cargados en OTP, de la fecha/hora de referencia y de la cobertura real de los operadores. No representa tráfico, incidencias ni tiempo real.

Los GTFS de NAP se descargan como inputs de pipeline autenticados y quedan como datos operativos locales, no como fuente incorporada al repositorio.

## Qué significa cada color

El panel de municipio muestra tres situaciones posibles.

### Verde: Tren directo a Madrid

Se muestra cuando el municipio seleccionado contiene una estación con conexión directa a Madrid.

Es la situación más clara: la conexión está dentro del propio municipio.

### Amarillo: Estación de tren cercana

Se muestra cuando el municipio no contiene la estación, pero hay una estación con conexión a Madrid a 15 km o menos.

Esto indica una opción cercana, aunque no necesariamente cómoda para todos los usos. La distancia es en línea recta, así que conviene comprobar el acceso real por carretera o transporte local.

### Rojo: Estación a X km

Se muestra cuando la estación más cercana con conexión a Madrid está a más de 15 km.

El número ayuda a dimensionar la distancia, pero no debe leerse como tiempo de viaje. Dos municipios a la misma distancia en línea recta pueden tener accesos reales muy distintos.

## Qué datos se muestran debajo

Cuando el Atlas identifica una estación, el panel puede mostrar:

- Nombre de la estación.
- Municipio o provincia de la estación, si aporta contexto.
- Distancia aproximada en línea recta.
- Salidas estimadas, cuando hay información suficiente.

Las salidas sirven para orientar frecuencia, no para sustituir una consulta de horarios actualizada.

## Qué fuente se usa

Para esta lectura se usan datos GTFS de Renfe. GTFS es un formato habitual para publicar información de transporte: paradas, rutas, viajes y calendarios.

El Atlas usa estos datos porque una estación dibujada en un mapa no garantiza que tenga servicio activo. Por eso, para conexión con Madrid se prioriza servicio observado en los feeds disponibles.

## Qué no mide

Este bloque no mide:

- Autobuses.
- Transbordos posibles.
- Tiempo real puerta a puerta.
- Precio, fiabilidad o incidencias.
- Calidad de acceso desde cada núcleo o barrio.

Tampoco sustituye la comprobación de horarios. Si el tren es importante para una decisión concreta, conviene contrastar la estación y frecuencias antes de cerrar conclusiones.

## Cómo usarlo en una comparación

La lectura práctica es:

- Verde: buen punto a favor si la conexión con Madrid importa.
- Amarillo: señal interesante, pero hay que comprobar cómo se llega a la estación.
- Rojo: no descarta el municipio, pero indica que el tren no debería darse por cercano.

En todos los casos, conviene leerlo junto con accesibilidad general, carretera, servicios y necesidades reales de desplazamiento.

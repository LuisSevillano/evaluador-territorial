# Arquitectura del atlas

La arquitectura está pensada para responder una pregunta concreta: **podemos justificar técnica y metodológicamente por qué un municipio puntua mejor qué otro**.

## Tres capas qué trabajan juntas

El sistema se apoya en tres capas qué se retroalimentan. Primero, una capa de cálculo convierte fuentes muy distintas en indicadores comparables. Después, una capa geoespacial empaqueta esa información para qué se pueda servir en web sin arrastrar archivos gigantes. Por ultimo, la capa de producto presenta los resultados de forma navegable, con mapa, filtros y desglose municipal.

## Flujo de extremo a extremo

En terminos sencillos, el recorrido es siempre el mismo: se define el territorío de trabajo, se prepara la base municipal, se calculan los bloques de clima, accesibilidad y naturaleza, se revisa la calidad del resultado y se publica una versión utilizable en la app. En la parte técnica veras cada script y cada archivo implicado; en está parte nos quedamos con la lógica funcional.

## Resultado visual de está arquitectura

![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.light.png){.theme-image-light}
![Anillos de isocronas diferenciales](/assets/map_isochrones_diff.dark.png){.theme-image-dark}

La imagen superíor ilustra un principio central del atlas: representar accesibilidad en anillos diferenciales evita solape engañoso y facilita comparar gradientes territoriales.

## Por qué está arquitectura es defendible

Se puede defender porque no depende de una caja negra. Cada bloque del score se calcula de forma separada, con reglas visibles y versiónables. Cuando ajustamos pesos o umbrales, ese cambio deja rastro. Y cuando alguien pregunta por qué un municipio sube o baja, la respuestá sale de datos y reglas concretas, no de una intuición.

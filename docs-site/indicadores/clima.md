# Indicadores de clima

Esta página describe qué se mide del clima y cómo interpretarlo en comparaciones municipales.

Sirve para detectar gradientes climáticos útiles, no para decidir una parcela exacta.

## Cómo leer este bloque

El bloque de clima ayuda a responder una pregunta sencilla: qué municipios tienen condiciones más favorables según lluvia, invierno y verano dentro del alcance analizado.

No busca describir cada día del año. Resume patrones medios para comparar lugares con una misma regla.

En la práctica, conviene mirar tres cosas:

- Si el municipio es relativamente húmedo o seco.
- Si el invierno es más o menos suave.
- Si el verano puede resultar más o menos exigente.

Ejemplo práctico: dos municipios pueden tener precipitación parecida, pero verano más suave en uno de ellos. Esa diferencia puede importar para uso cotidiano, consumo de agua o confort estacional.

## Qué mide este bloque

- Precipitación anual agregada por municipio.
- Temperatura media de invierno.
- Temperatura media de verano.
- Enero y julio como referencias mensuales.

En el diccionario de datos estos campos aparecen como `precip_annual_mm`, `temp_winter_mean_c`, `temp_summer_mean_c`, `temp_jan_mean_c` y `temp_jul_mean_c`.

## Cómo se calcula

- Agregación por polígono municipal (no por centroide) con `exactextractr`.
- Período base: 2014-2023.

![Precipitación anual municipal](/assets/map_precip.light.png){.theme-image-light}
![Precipitación anual municipal](/assets/map_precip.dark.png){.theme-image-dark}

![Distribución bloque clima](/assets/climate_block_distribution.png){.theme-image-light}
![Distribución bloque clima](/assets/climate_block_distribution.dark.png){.theme-image-dark}

![Precipitación vs temperatura verano](/assets/climate_scatter_precip_vs_summer.light.png){.theme-image-light}
![Precipitación vs temperatura verano](/assets/climate_scatter_precip_vs_summer.dark.png){.theme-image-dark}

## Limitaciones

- No captura microclima de parcela ni variabilidad horaria.
- No reemplaza medición local cuando la decisión depende de una ubicación concreta.
- No predice episodios extremos ni condiciones de un año concreto.

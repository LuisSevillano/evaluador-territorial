# Indicadores de clima

Esta página describe qué se mide del clima y cómo interpretarlo en comparaciones municipales.

Sirve para detectar gradientes climáticos útiles, no para decidir una parcela exacta.

## Qué mide este bloque

- `precip_annual_mm`: precipitación anual agregada por municipio.
- `temp_winter_mean_c`: media de invierno (dic-ene-feb).
- `temp_summer_mean_c`: media de verano (jun-jul-ago).
- `temp_jan_mean_c`, `temp_jul_mean_c`: referencias mensuales.

## Cómo se calcula

- Agregación por polígono municipal (no por centroide) con `exactextractr`.
- Período base: 2014-2023.

![Precipitación anual municipal](/assets/map_precip.light.png){.theme-image-light}
![Precipitación anual municipal](/assets/map_precip.dark.png){.theme-image-dark}

![Distribución bloque clima](/assets/climate_block_distribution.png){.theme-image-light}
![Distribución bloque clima](/assets/climate_block_distribution.dark.png){.theme-image-dark}

## Cómo leerlo bien

Este bloque ayuda a comparar clima entre municipios del mismo alcance.

Ejemplo práctico: dos municipios pueden tener precipitación parecida, pero verano más suave en uno de ellos; esa diferencia puede ser relevante para uso cotidiano, consumo de agua o confort estacional.

## Limitaciones

- No captura microclima de parcela ni variabilidad horaria.
- No reemplaza medición local cuando la decisión depende de una ubicación concreta.

# Indicadores de clima

El bloque clima mide habitabilidad ambiental a escala municipal a partir de observaciones históricas agregadas por polígono.

## Métricas

- `precip_annual_mm`: precipitacion anual agregada por municipio.
- `temp_winter_mean_c`: media dic-ene-feb.
- `temp_summer_mean_c`: media jun-jul-ago.
- `temp_jan_mean_c`, `temp_jul_mean_c`: medias mensuales de referencia.

## Metodo

- Agregacion por poligono municipal (no centroide) con `exactextractr`.
- Período base: 2014-2023.

![Precipitacion anual municipal](/assets/map_precip.light.png){.theme-image-light}
![Precipitacion anual municipal](/assets/map_precip.dark.png){.theme-image-dark}

![Distribución bloque clima](/assets/climate_block_distribution.png)

## Limitaciones

- No captura microclima de parcela ni variabilidad horaria.

## Lectura recomendada

- Usa este bloque para comparar gradientes macroclimáticos entre territoríos.
- No lo uses para decidir una parcela exacta sin validación local.

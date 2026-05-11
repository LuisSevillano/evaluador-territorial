# Indicadores de clima

Esta página describe qué se mide del clima y cómo interpretarlo en comparaciones municipales.

Sirve para detectar gradientes climáticos útiles, no para decidir una parcela exacta.

## Cómo leer este bloque

El bloque de clima ayuda a responder dos preguntas distintas: si un lugar es climáticamente húmedo con una referencia estable y si destaca frente al conjunto analizado.

No busca describir cada día del año. Resume patrones medios para comparar lugares con una misma regla.

En la práctica, conviene mirar tres cosas:

- Si el municipio es realmente húmedo o seco según una normal climática externa.
- Si tiene ventaja relativa frente al conjunto filtrado o analizado.
- Si el invierno es más o menos suave.
- Si el verano puede resultar más o menos exigente.

Ejemplo práctico: dos municipios pueden tener precipitación parecida, pero verano más suave en uno de ellos. Esa diferencia puede importar para uso cotidiano, consumo de agua o confort estacional.

## Qué mide este bloque

- Precipitación anual agregada por municipio.
- Precipitación de verano e invierno.
- Aridez anual y aridez estival (`P/PET`).
- Meses secos y estacionalidad mensual de la lluvia.
- Score de humedad climática y lectura visual por gotas.
- Temperatura media de invierno.
- Temperatura media de verano.
- Enero y julio como referencias mensuales.

En el diccionario de datos estos campos aparecen como `precip_annual_mm`, `precip_summer_mm`, `precip_winter_mm`, `aridity_index`, `summer_aridity_index`, `dry_months_count`, `precip_seasonality_index`, `moisture_absolute_score`, `summer_drought_score`, `precip_relative_score`, `precip_moisture_score`, `water_drops_level`, `water_drops_label`, `temp_winter_mean_c`, `temp_summer_mean_c`, `temp_jan_mean_c` y `temp_jul_mean_c`.

## Cómo se calcula

- Fuente operativa: TerraClimate.
- Normal climática: 2014-2023.
- Agregación por polígono municipal (no por centroide) con `exactextractr`.
- La humedad climática combina 60% score absoluto, 25% sequía estival y 15% ventaja relativa interna.
- AEMET queda como referencia institucional para validación, calibración y documentación posterior, no como fuente principal de esta primera versión.

## Humedad absoluta y ventaja relativa

La humedad absoluta responde: "este lugar es realmente húmedo según criterios climáticos estables". Usa precipitación, evapotranspiración potencial, aridez, lluvia de verano, meses secos y regularidad mensual.

La ventaja relativa responde: "este lugar es más húmedo que otros lugares del conjunto analizado". Se mantiene porque el Atlas compara subconjuntos, pero no domina el score climático.

Las gotas del visor (`Seco`, `Equilibrado`, `Húmedo`) derivan de humedad absoluta y sequía estival. No cambian al aplicar filtros.

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
- La referencia AEMET no está integrada todavía como fuente de cálculo principal; se usará en una fase posterior para contraste y calibración.

# Fuentes de datos

El atlas combina fuentes climaticas, geoespaciales y de movilidad. La calidad del resultado depende de está capa.

## Clima

- TerraClimate mensual (2014-2023 para climatologia de referencia).

## Cobertura del suelo

- En está corrida, los calculos de cobertura del suelo se han derivado desde capas OSM de Geofabrik (`landuse`, `natural`, `water`) por disponibilidad efectiva en el entorno de ejecución.
- CORINE queda como fuente preferente cuando está disponible y validada en la ruta configurada.

## Accesibilidad

- Isochronas y capas de transporte (OSM + integraciones ferroviarias).
- Las isocronas de referencia se calcularon con la API de TravelTime (`/v4/time-map/fast`) y se consumen cómo geometría ya precomputada en el pipeline.

## Hidrologia recreativa

- Tramos hidrográficos por demarcación (CNIG/IGR descargado localmente).
- Se usa filtrado por señales positivas y exclusiones conservadoras.

## Limitaciones declaradas

- El indicador fluvial no representa calidad sanitaria.
- No identifica zonas oficiales de baño.

## Criterío de seleccion de fuentes

- Preferencia por fuentes abiertas, trazables y con cobertura territorial amplia.
- Fallback documentado cuando una fuente falla o llega incompleta.

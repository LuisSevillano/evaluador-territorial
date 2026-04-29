# Fuentes de datos

Esta página resume de dónde salen los datos que usa el Atlas y con qué criterio se eligen.

Sirve para evaluar alcance y límites de cada bloque.

## Clima

- TerraClimate mensual (2014-2023 como climatología de referencia).

## Cobertura del suelo

- En esta ejecución, coberturas derivadas desde OSM Geofabrik (`landuse`, `natural`, `water`) por disponibilidad efectiva.
- CORINE queda como fuente preferente cuando está disponible y validada en la ruta configurada.

## Accesibilidad

- Isochronas y capas de transporte (OSM + integraciones ferroviarias).
- Las isocronas de referencia se calcularon con TravelTime API (`/v4/time-map/fast`) y se consumen como geometría precomputada.

## Hidrología recreativa

- Tramos hidrográficos por demarcación (CNIG/IGR descargado localmente).
- Filtrado por señales positivas y exclusiones conservadoras.

## Límites declarados

- El indicador fluvial no representa calidad sanitaria.
- No identifica zonas oficiales de baño.
- Puede haber desfases temporales entre fuentes.

## Criterio de selección de fuentes

- Preferencia por fuentes abiertas, trazables y con cobertura amplia.
- Fallback documentado cuando una fuente falla o llega incompleta.

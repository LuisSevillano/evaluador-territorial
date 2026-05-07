# Fuentes de datos

Esta página resume de dónde salen los datos que usa el Atlas y con qué criterio se eligen.

Sirve para evaluar alcance y límites de cada bloque.

La regla general es usar fuentes trazables, con cobertura suficiente y con límites explícitos. Cuando una fuente no alcanza para responder una pregunta, el Atlas debe decirlo en vez de aparentar más precisión de la que tiene.

## Clima

- TerraClimate mensual (2014-2023 como climatología de referencia).

Se usa para comparar patrones medios de lluvia y temperatura, no para describir el microclima exacto de una parcela.

## Cobertura del suelo

- En esta ejecución, coberturas derivadas desde OSM Geofabrik (`landuse`, `natural`, `water`) por disponibilidad efectiva.
- La fuente de coberturas usada en pipeline es OSM Geofabrik.

Estas capas ayudan a resumir entorno natural y artificialización, pero pueden tener diferencias de detalle según zona.

## Accesibilidad

- Isochronas y capas de transporte (OSM + integraciones ferroviarias).
- Las isocronas de referencia se calcularon con TravelTime API (`/v4/time-map/fast`) y se consumen como geometría precomputada.
- La conexión Renfe con Madrid se apoya en GTFS de Renfe para evitar asumir servicio solo por existir una estación cartografiada.

## Hidrología recreativa

- Tramos hidrográficos por demarcación (CNIG/IGR descargado localmente).
- Filtrado por señales positivas y exclusiones conservadoras.

Se usa para estimar acceso fluvial recreativo potencial, no para certificar baño ni calidad sanitaria.

## Límites declarados

- El indicador fluvial no representa calidad sanitaria.
- No identifica zonas oficiales de baño.
- Puede haber desfases temporales entre fuentes.

## Criterio de selección de fuentes

- Preferencia por fuentes abiertas, trazables y con cobertura amplia.
- Fallback documentado cuando una fuente falla o llega incompleta.

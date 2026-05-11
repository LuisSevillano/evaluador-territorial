# Fuentes de datos

Esta página resume de dónde salen los datos que usa el Atlas y con qué criterio se eligen.

Sirve para evaluar alcance y límites de cada bloque.

La regla general es usar fuentes trazables, con cobertura suficiente y con límites explícitos. Cuando una fuente no alcanza para responder una pregunta, el Atlas debe decirlo en vez de aparentar más precisión de la que tiene.

## Clima

- TerraClimate mensual (2014-2023 como normal climática operativa).

Se usa para comparar patrones medios de lluvia, temperatura, evapotranspiración potencial, aridez y sequía estival, no para describir el microclima exacto de una parcela.

AEMET queda como referencia institucional para una fase posterior de validación, calibración y documentación pública, no como fuente principal inicial del cálculo.

## Cobertura del suelo

- En esta ejecución, coberturas derivadas desde OSM Geofabrik (`landuse`, `natural`, `water`) por disponibilidad efectiva.
- La fuente de coberturas usada en pipeline es OSM Geofabrik.

Estas capas ayudan a resumir entorno natural y artificialización, pero pueden tener diferencias de detalle según zona.

## Accesibilidad

- Isochronas y capas de transporte (OSM + integraciones ferroviarias).
- Las isocronas de referencia se calcularon con TravelTime API (`/v4/time-map/fast`) y se consumen como geometría precomputada.
- La conexión Renfe con Madrid se apoya en GTFS de Renfe para evitar asumir servicio solo por existir una estación cartografiada.

## Hidrología recreativa

- Zonas de baño oficiales/inventariadas: censo MAPA/SINAC, zonas recreativas CHD y registros NÁYADE con coordenadas.
- Tramos hidrográficos por demarcación (CNIG/IGR descargado localmente) como proxy de cobertura cuando no hay una zona oficial cercana.
- El proxy fluvial estima caudal estival probable con persistencia, pertenencia a masa de agua/DMA, orden hidrográfico, anchura disponible, longitud del curso y exclusiones de cauces artificiales o temporales.
- La asignación territorial se hace sobre rejilla de 2 km mediante bandas de distancia a candidatos por clase, y luego se agrega a municipio. Su contribución queda capada para no equipararla a una zona declarada.
- En el `mixed_score` de rejilla, el acceso recreativo al agua entra solo como bonus contextualizado por cobertura natural. Esto mantiene la señal local sin convertir las bandas de distancia a zonas de baño en círculos dominantes sobre el mapa.

Se usa para estimar acceso recreativo potencial. Solo las fuentes oficiales/inventariadas aportan máxima confianza; el proxy fluvial no certifica baño ni calidad sanitaria.

## Límites declarados

- El indicador no representa calidad sanitaria.
- Cuando el score procede de `river_summer_proxy`, identifica potencial recreativo por caudal estival probable, no una zona oficial de baño.
- Puede haber desfases temporales entre fuentes.

## Criterio de selección de fuentes

- Preferencia por fuentes abiertas, trazables y con cobertura amplia.
- Fallback documentado cuando una fuente falla o llega incompleta.

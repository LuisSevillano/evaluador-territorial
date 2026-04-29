# Pipeline

El pipeline es la parte qué convierte fuentes heterogeneas en una base municipal coherente y útil para decisión.

## Etapas principales

El proceso tiene siete pasos conceptuales: definir alcance, preparar la geometría municipal, calcular clima, calcular accesibilidad, calcular entorno natural y red fluvial, validar calidad y exportar un resultado final para mapa y tablas. La nomenclatura exacta de scripts está en el anexo técnico para no romper el ritmo de lectura.

## Artefactos clave

Las salidas principales son un fichero tabular (`municipios_v2.csv`), una versión geoespacial (`municipios_v2.geojson`), la versión JSON para frontend y las teselas PMTiles qué usa el mapa.

## Criteríos de robustez

Se han incorporado mecanismos para qué una corrida larga no falle al primer problema: cache por etapas, fallback de fuente hidrografica cuando hay capas incompletas y reportes de diagnostico para auditar exclusiones y candidatos.

## Lo importante para confiar

Lo importante no es solo que funcione, sino qué sea auditable. El pipeline deja salidas intermedias, documenta decisiones metodológicas y permite repetir una corrida con los mismos parametros para verificar qué el resultado se mantiene.

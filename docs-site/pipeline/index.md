# Visión general del pipeline

Esta página explica el recorrido de datos desde las fuentes hasta el dataset final que usa el mapa.

Sirve para entender qué pasos hay, dónde mirar si algo falla y qué controles sostienen la calidad.

## Etapas principales

El pipeline sigue siete etapas conceptuales:

1. Definir alcance de análisis.
2. Preparar geometría municipal base.
3. Calcular bloque de clima.
4. Calcular bloque de accesibilidad.
5. Calcular bloque de naturaleza y ríos.
6. Ejecutar validaciones.
7. Exportar salidas para app y documentación.

## Artefactos clave

- Tabular: `municipios_v2.csv`
- Geoespacial: `municipios_v2.geojson`
- Frontend: `municipios_v2.json`
- Mapa: teselas PMTiles

## Criterios de robustez

Para evitar ejecuciones frágiles, el pipeline incorpora caché por etapas, fallback de fuentes cuando falta cobertura y reportes de diagnóstico para revisar exclusiones y candidatos.

## Qué revisar para confiar

No basta con que termine sin error. También conviene comprobar trazabilidad, consistencia entre salidas y límites declarados por indicador.

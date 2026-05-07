# Visión general del pipeline

Esta página explica el recorrido de datos desde las fuentes hasta el dataset final que usa el mapa.

Sirve para entender qué pasos hay, dónde mirar si algo falla y qué controles sostienen la calidad.

Esta sección es más técnica que las guías de uso. No hace falta leerla para usar el Atlas, pero sí es útil si quieres auditar un resultado, revisar una fuente o entender por qué cambió un ranking después de una actualización.

## En palabras simples

El pipeline es la cocina de datos del Atlas. Toma fuentes externas, las limpia, calcula indicadores, revisa que todo tenga sentido y prepara los archivos que después muestra la aplicación.

La interfaz no inventa resultados: muestra lo que el pipeline ya calculó y exportó.

## Etapas principales

El pipeline sigue siete etapas conceptuales:

1. Definir alcance de análisis.
2. Preparar geometría base (rejilla y municipal).
3. Calcular bloque de clima por celda y agregaciones.
4. Calcular bloque de accesibilidad.
5. Calcular bloque de naturaleza y ríos.
6. Ejecutar validaciones.
7. Exportar salidas para app y documentación.

Cada etapa deja archivos intermedios o finales. Eso permite revisar problemas sin tener que rehacer mentalmente todo el proceso.

## Artefactos clave

- Tabular: `municipios_v2.csv`
- Geoespacial: `municipios_v2.geojson`
- Frontend: `municipios_v2.json`
- Mapa: teselas PMTiles
- Clima mensual por rejilla y provincia: `frontend/static/data/grid-climate/*.json`

## Criterios de robustez

Para evitar ejecuciones frágiles, el pipeline incorpora caché por etapas, fallback de fuentes cuando falta cobertura y reportes de diagnóstico para revisar exclusiones y candidatos.

El objetivo no es solo que el proceso termine. También tiene que producir resultados razonables y coherentes con el territorio.

## Qué revisar para confiar

No basta con que termine sin error. También conviene comprobar trazabilidad, consistencia entre salidas y límites declarados por indicador.

Si necesitas una revisión más concreta, sigue con [QA y validación](/operacion/qa).

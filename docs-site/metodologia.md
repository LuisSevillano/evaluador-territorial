# Cómo se comparan los lugares

Esta página explica la forma de análisis del Atlas: qué datos usa, cómo los convierte en indicadores y qué límites tiene.

Sirve como punto de partida para interpretar resultados sin sobrecargar de detalle técnico.

## Base metodológica

El Atlas combina fuentes observadas y reglas reproducibles:

- Clima observado (TerraClimate) agregado por municipio.
- Coberturas territoriales derivadas desde OSM en la ejecución actual (con soporte para CORINE cuando está disponible y validada).
- Isochronas y nodos de transporte trazables.
- Red fluvial filtrada con criterios explícitos.

## Qué se entiende por objetividad

Objetividad aquí no es "decisión automática". Es transparencia: cualquier persona puede revisar cómo se calcula cada resultado.

- Reglas deterministas (sin heurísticas ocultas).
- Fórmula del score publicada.
- Versionado metodológico.
- QA verificable.

## Ejemplo simple de lectura

Si dos municipios tienen clima parecido, el desempate puede venir por accesibilidad o entorno natural.

En la práctica, esto ayuda a priorizar: por ejemplo, un lugar con buen clima pero muy aislado puede bajar frente a otro algo menos húmedo pero con acceso más fácil a servicios durante todo el año.

## Limitaciones

Hay límites que conviene tener presentes:

- Los datos pueden estar incompletos o desactualizados.
- Una puntuación alta no sustituye una visita.
- Aspectos clave como vida social o encaje personal son difíciles de medir.
- El resultado final necesita interpretación, no lectura automática.

## Qué no afirma este modelo

- No garantiza causalidad socioeconómica.
- No sustituye estudios locales de campo.
- No convierte automáticamente un score alto en mejor decisión final.

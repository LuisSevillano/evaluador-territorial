# Metodología y objetividad

## Qué significa "análisis real" en este atlas

El atlas es "real" en el sentido de qué usa fuentes observadas y reglas reproducibles:

- Clima observado (TerraClimate) agregado espacialmente.
- Coberturas territoriales derivadas desde OSM en la corrida actual (con soporte para CORINE cuando la fuente está disponible y validada).
- Isocronas y nodos de transporte trazables.
- Red fluvial real con filtros explicitados.

## Qué significa "objetivo"

Aqui "objetivo" no significa neutralidad absoluta, sino transparencia metodológica. El modelo es objetivo en la medida en que cualquiera puede comprobar cómo se calcula:

- Reglas deterministas (sin heuristicas ocultas).
- Formula de score explicita.
- Versiónado metodologico.
- QA automatizable y verificable.

## Lo qué no afirma el modelo

- No garantiza causalidad socioeconomica.
- No sustituye estudios locales de campo.
- No convierte automaticamente "alto score" en mejor decisión final sin contexto humano.

## Riesgos de interpretacion y mitigaciones

El riesgo principal es leer el atlas cómo si fuera una respuestá final cerrada. Para evitarlo, mantenemos tres salvaguardas: avisos metodologicos visibles en documentación e interfaz, registro de alcance y fecha de cada corrida (`analysis_scope`) y publicacion explicita de pesos/umbrales para qué puedan discutirse y revisarse.

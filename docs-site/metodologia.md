# Cómo se comparan los lugares

¿Qué datos usa el Atlas? ¿cómo los convierte en indicadores? ¿Qué límites tiene?

Esta página es un buen punto de partida para interpretar los resultados del Atlas sin sobrecargar de detalle técnico.

La idea de fondo es simple: todos los municipios se evalúan con las mismas reglas. Eso permite comparar sin depender solo de impresiones, recomendaciones sueltas o imágenes previas de cada zona.

## La comparación en una frase

El Atlas recoge información de clima, accesibilidad y naturaleza, la lleva a una escala comparable y la resume para que distintos lugares puedan leerse con el mismo criterio.

Esto no convierte la decisión en automática. Solo hace más visible por qué un municipio destaca, por qué otro queda más abajo y qué habría que mirar con más calma.

## Qué significa comparar bien

Comparar bien no es buscar un ganador universal. Es entender perfiles.

Un municipio puede ser fuerte en clima y flojo en accesibilidad. Otro puede ser menos atractivo en entorno natural, pero mucho más fácil para la vida diaria. El Atlas ayuda a ver esas compensaciones.

Por eso conviene leer siempre tres niveles:

1. Resultado general.
2. Desglose por bloques.
3. Contexto del lugar en el mapa.

## Base metodológica

El Atlas combina fuentes observadas y reglas reproducibles:

- Clima observado, calculado en rejilla y agregado para vistas municipales.
- Coberturas territoriales: bosque, agua, superficie artificial y otros usos del suelo.
- Accesibilidad por tramos de tiempo y conectividad de transporte.
- Red fluvial filtrada con criterios explícitos para estimar acceso recreativo potencial.

El detalle de fuentes y scripts está en la sección técnica: [Fuentes de datos](/pipeline/fuentes) y [Trazabilidad](/pipeline/trazabilidad).

## Qué se entiende por objetividad

Objetividad aquí no es _decisión automática_. Es transparencia: cualquier persona puede revisar cómo se calcula cada resultado.

- Reglas deterministas (sin heurísticas ocultas).
- Fórmula del score publicada.
- Versionado metodológico.
- QA verificable.

## Ejemplo simple de lectura

Si dos municipios tienen clima parecido, el desempate puede venir por accesibilidad o entorno natural.

En la práctica, esto ayuda a priorizar: por ejemplo, un lugar con buen clima pero muy aislado puede bajar frente a otro algo menos húmedo pero con acceso más fácil a servicios durante todo el año.

Otro ejemplo: un municipio con mucho entorno natural puede parecer muy atractivo en el mapa, pero si la conexión ferroviaria o la accesibilidad general son débiles, quizá sea mejor leerlo como una opción de interés que necesita comprobación práctica.

## Escala de análisis

El Atlas trabaja con dos niveles conectados:

- **Rejilla** para capturar variabilidad espacial fina.
- **Municipio** para comparación administrativa y lectura de decisión.

Ambos niveles comparten reglas de cálculo, filtros y bloques de score.

La rejilla ayuda a detectar diferencias internas. El municipio ayuda a tomar decisiones con una unidad reconocible y comparable.

## Limitaciones

Hay límites que conviene tener presentes:

- Los datos pueden estar incompletos o desactualizados.
- Aspectos clave como vida social o encaje personal son difíciles de medir.
- El resultado final necesita interpretación, no lectura automática.
- Una media municipal puede ocultar diferencias dentro del propio municipio.
- La distancia en línea recta no equivale siempre a tiempo real de desplazamiento.

## Qué no afirma este modelo

- No garantiza causalidad socioeconómica.
- No sustituye estudios locales de campo.
- No convierte automáticamente un score alto en mejor decisión final.

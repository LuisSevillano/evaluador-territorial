# Cómo usar el Atlas

Esta guía explica el uso del Atlas sin entrar en scripts ni detalles de implementación. Sirve para entender qué mirar primero, cómo leer el mapa y cómo evitar conclusiones rápidas.

## Qué vas a encontrar aquí

- Un recorrido detallado de uso en **Desktop** con todos los componentes explicados.
- Un recorrido detallado de uso en **Mobile** adaptado a la experiencia táctil.
- Una lista de comportamientos esperados para validar que todo funciona correctamente.

## Para quién es esta guía

Esta guía está diseñada para:

- Personas del equipo que necesitan analizar municipios con una base común.
- Personas que van a hacer presentaciones o demos del producto.
- Cualquier persona que quiera entender cómo funciona la interfaz sin leer la documentación técnica.

## Qué guía necesitas

Usa la **Guía de Escritorio** si vas a usar el Atlas desde un ordenador. Usa la **Guía de Móvil** si vas a acceder desde un teléfono o tablet.

1. [Guía de Escritorio](/uso-atlas/desktop) — Uso desde ordenador.
2. [Guía de Móvil](/uso-atlas/mobile) — Uso desde móvil o tablet.
3. [Comportamientos esperados](/uso-atlas/comportamientos) — Valida que todo funciona correctamente.

## Conceptos clave del Atlas

El Atlas ayuda a responder tres preguntas sobre cada municipio:

1. **¿Cuál es el clima?** → Métricas de precipitación y temperatura.
2. **¿Qué accesibilidad tiene?** → Tiempo de viaje a centros de referencia.
3. **¿Qué entorno natural ofrece?** → Cobertura forestal, agua, naturalidad y acceso a ríos.

El **score mixto** combina estas tres dimensiones en un único valor comparativo. Aun así, conviene revisar los bloques por separado para entender por qué un municipio queda arriba o abajo.

### Modo Exploración

El Atlas funciona en dos modos. El **Modo Exploración** ("Exploración: filtros y capas") sirve para detectar patrones espaciales con filtros y capas. Es útil cuando la pregunta es "dónde merece la pena mirar primero".

Para cambiar entre modos, usa el toggle que aparece en la barra superior, entre la leyenda y el enlace a documentación. En móvil, el cambio de modo está disponible en el panel inferior.

### Modo Evaluación

El **Modo Evaluación** ("Evaluación: score y ranking") sirve para comparar municipios concretos. Permite ajustar pesos de clima, accesibilidad y naturaleza, y ver cómo cambia el ranking. La métrica de **robustez** muestra cuántos municipios del top-10 se mantienen con cambios de pesos.

> Nota de interpretación: cambiar pesos no descubre una verdad única. Solo muestra cómo cambia la priorización según criterios distintos.

## Vista general de la interfaz

![Atlas en escritorio](/assets/desktop-full.png)

En la práctica, el uso del Atlas siempre sigue el mismo patrón:

1. **Elegir una métrica** (score mixto, clima, accesibilidad, naturaleza o acceso a baño).
2. **Observar el patrón espacial** en el mapa para identificar zonas con mejor puntuación.
3. **Filtrar** por provincia o rango de score para reducir el ámbito de análisis.
4. **Seleccionar municipios** individuales para ver el detalle en el inspector.
5. **Comparar** resultados entre varios municipios.

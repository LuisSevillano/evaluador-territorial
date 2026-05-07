# Comportamientos esperados

Esta página sirve como checklist funcional de uso. Si algo de esta lista no se cumple, conviene revisarlo antes de compartir resultados o hacer una demo.

## Mapa y métricas

- Cambiar de métrica debe cambiar la simbología del mapa.
- La leyenda debe corresponder al indicador activo.
- La lectura por clases (Muy baja → Muy alta) debe mantenerse consistente.

## Selección municipal

- Al seleccionar un municipio, el panel de detalle debe actualizarse.
- El nombre del municipio y los indicadores mostrados deben corresponder al punto seleccionado.
- Al seleccionar otro municipio, los datos deben sustituirse sin recargar la página.
- En móvil, tras selección y zoom automático, el contorno del municipio debe seguir visible.

## Rejilla y zoom

- En modo automático, la rejilla debe aparecer al acercar y ocultarse al alejar según umbral de zoom.
- La transición entre municipio y rejilla no debe romper la selección activa.
- Al tocar una celda de rejilla, el panel debe mostrar su ficha agregada.

## Desktop

- Sidebar visible con acceso rápido a filtros y métricas.
- Inspector lateral usable sin tapar completamente el mapa.
- Flujo de comparación estable entre varios municipios.

## Mobile

- Controles táctiles accesibles y legibles.
- Panel inferior con transición estable al abrir/cerrar.
- Cambio de métrica y selección municipal sin bloqueos.

## Interpretación

- `mixed_score` debe leerse junto con sus bloques.
- `river_access_score` debe interpretarse como acceso potencial recreativo a río, no como calidad sanitaria del agua.
- El Atlas es una herramienta de priorización; no sustituye validación local de campo.

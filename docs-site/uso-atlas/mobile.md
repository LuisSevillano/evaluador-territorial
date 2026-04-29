# Guía de Móvil

Esta página explica el uso del Atlas en móvil. Sirve para consultar municipios en pantalla pequeña sin perder el contexto del mapa.

![Uso del Atlas en mobile](/assets/mobile-home.png)

## Componentes principales

### 1. Selector de métrica (panel lateral)

En móvil, los botones de métricas se muestran en el panel lateral igual que en escritorio. El funcionamiento es el mismo:

- Tocar un botón para cambiar la métrica activa.
- El mapa se recolorea instantáneamente.

Las métricas disponibles son las mismas que en desktop: puntuación global, precipitación, tiempo de desplazamiento, transporte OSM, servicio Renfe y acceso a baño.

### 2. Mapa interactivo (centro)

El mapa ocupa toda la pantalla y responde a gestos táctiles estándar:

- **Arrastrar**: desplazar el mapa.
- **Zoom con dos dedos**: acercar o alejar.
- **Tocar**: seleccionar un municipio.

El fondo carga por defecto una capa del IGN (Instituto Geográfico Nacional) donde se aprecian nombres de ciudades y relieve. Los municipios se colorean según la métrica activa.

### 3. Panel inferior de detalle (bottom sheet)

Al tocar un municipio, aparece un panel en la parte inferior que muestra:

- Nombre y provincia.
- Score global y desglose por bloques.
- Métricas concretas del municipio.

El panel es desplazable (swipe up) para ver toda la información sin perder contexto del mapa. Para cerrarlo, se arrastra hacia abajo o se toca el mapa.

![Panel de inspector en mobile](/assets/mobile-inspector.png)

### 4. Filtros y Capas (panel inferior)

Los filtros de provincia, rango de score y climatología, así como el selector de capas, se acceden desde el panel inferior:

- **Sel.**: selección de municipio activo.
- **Filtros**: todos los filtros disponibles.
- **Capas**: activar/desactivar capas superpuestas.
- **Rank**: ranking de municipios.
- **Meta**: metadatos y metodología.

![Menú de filtros y capas en mobile](/assets/mobile-menu.png)

## Diferencias clave frente a desktop

| Aspecto | Desktop | Mobile |
|---------|---------|--------|
| Inspector | Panel lateral fijo | Panel inferior desplazable |
| Filtros | Sidebar siempre visible | Panel inferior con tabs |
| Capas | Panel lateral | Panel inferior con tabs |
| Comparación | Varios paneles abiertos | Un panel a la vez |
| Navegación | Mouse y teclado | Táctil gestos |

## Flujo de uso en móvil

1. **Seleccionar métrica** tocando el chip activo en el panel lateral.
2. **Explorar el mapa** con gestos táctiles.
3. **Tocar un municipio** para abrir el panel de detalle.
4. **Desplazar el panel** hacia arriba para ver métricas completas.
5. **Cerrar el panel** tocando el mapa o arrastrando hacia abajo.
6. **Acceder a filtros y capas** desde el panel inferior con los tabs correspondientes.

## Qué revisar en demos o pruebas

- Que los botones de métricas respondan al toque y actualicen el mapa.
- Que al tocar municipios cambie el contenido del panel inferior.
- Que el panel se desplace de forma fluida sin bloquear la interacción con el mapa.
- Que los filtros funcionen correctamente desde el panel de filtros.
- Que las capas se activen/desactiven sin problemas en pantalla pequeña.
- Que el mapa siga siendo legible mientras se consulta el detalle.

## Límites de lectura

- El detalle móvil sirve para comparar rápido, no para cerrar una decisión por sí solo.
- Conviene validar en campo aspectos que no aparecen en el modelo.

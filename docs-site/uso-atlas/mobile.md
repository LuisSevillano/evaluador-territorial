# Guía de Móvil

Vamos a mostrar cómo usar el Atlas en móvil. El Atlas está optimizado para poder consultar toda la información en un espacio limitado sin perder el contexto del mapa, incluyendo la vista por municipios y la vista por rejilla.

![Uso del Atlas en mobile](/assets/mobile-home.png)

## Componentes principales

### 1. Selector de métrica (panel lateral)

En móvil, los botones de métricas se muestran en el panel de *Filtros*. El funcionamiento es el mismo:

- Tocar un botón para cambiar la métrica activa.
- El mapa se recolorea instantáneamente.

Entre otras, las métricas disponibles son: puntuación global, precipitación, tiempo de desplazamiento, relieve, conexión Renfe con Madrid o acceso a baño.

### 2. Mapa interactivo (centro)

El mapa ocupa toda la pantalla y responde a gestos táctiles estándar:

- **Arrastrar**: desplazar el mapa.
- **Zoom con dos dedos**: acercar o alejar.
- **Tocar**: seleccionar un municipio o una celda de rejilla.

El fondo carga por defecto una capa del IGN (Instituto Geográfico Nacional) donde se aprecian nombres de ciudades y relieve. Los municipios se colorean según la métrica activa.

### 3. Panel inferior de detalle

Al tocar un municipio o una celda, aparece un panel en la parte inferior que muestra:

- Nombre y provincia.
- Score global y desglose por bloques.
- Métricas concretas del municipio.

El panel es desplazable para ver toda la información sin perder contexto del mapa. La altura intermedia por defecto se mantiene más compacta para dejar más área visible del mapa. Para cerrarlo, se arrastra hacia abajo o se toca el mapa.

![Panel de inspector en mobile](/assets/mobile-inspector.png)

### 4. Filtros y Capas (panel inferior)

Los filtros de provincia, rango de score y climatología, así como el selector de capas, se acceden desde el panel inferior:

- **Sel.**: selección de municipio activo.
- **Filtros**: todos los filtros disponibles.
- **Capas**: activar/desactivar capas superpuestas.
- **Rank**: ranking de municipios.
- **Meta**: metadatos y metodología.

![Menú de filtros y capas en mobile](/assets/mobile-menu.png)

## Flujo de uso en móvil

1. **Seleccionar métrica** tocando el chip activo en el panel lateral.
2. **Explorar el mapa** con gestos táctiles.
3. **Tocar un municipio o celda** para abrir el panel de detalle.
4. **Desplazar el panel** hacia arriba para ver métricas completas.
5. **Cerrar el panel** tocando el mapa o arrastrando hacia abajo.
6. **Acceder a filtros y capas** desde el panel inferior con los tabs correspondientes.

## Límites de lectura

- El detalle móvil sirve para comparar rápido, para explorar, pero la experiencia siempre será más interesante y completa desde un ordenador donde disponemos de más espacio para mostrar la información.

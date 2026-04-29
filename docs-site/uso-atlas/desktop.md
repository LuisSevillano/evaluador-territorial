# Guía de Escritorio

Esta página muestra cómo usar el Atlas en escritorio para comparar municipios con más contexto. Sirve para revisar mapa, filtros e inspector al mismo tiempo.

![Vista completa del Atlas en desktop](/assets/desktop-full.png)

## Componentes principales

### 1. Mapa interactivo (centro)

El mapa muestra los municipios del ámbito seleccionado. Cada municipio está coloreado según la métrica activa (score mixto, precipitación, transporte, etc.). Al hacer zoom o desplazar el mapa, los datos se actualizan dinámicamente. El fondo del mapa muestra el relieve territorial.

### 2. Selector de métrica (panel lateral)

Los botones del panel lateral permiten cambiar entre:

- **Puntuación global**: combinación ponderada de clima, accesibilidad y naturaleza.
- **Precipitación**: precipitación anual en mm.
- **Tiempo de desplazamiento**: isocronas de tiempo de viaje.
- **Transporte OSM**: proximidad a estaciones de transporte público.
- **Servicio Renfe**: calidad del servicio de tren.
- **Acceso a baño**: proximidad a ríos potencialmente aptos para uso recreativo.

Al cambiar de métrica, el mapa se recolorea instantáneamente. La leyenda superior se actualiza para reflejar las nuevas clases de color.

![Selector de métrica Precipitación](/assets/desktop-precipitacion.png)

### 3. Filtros de búsqueda (panel lateral)

Los filtros están organizados en el panel lateral:

- **Buscar municipio**: escribir nombre para localizar directamente un municipio.
- **Provincia**: filtrar por provincia específica dentro del ámbito.
- **Rango de score**: seleccionar un rango del 0-100 para ver solo municipios dentro de ese intervalo.
- **Filtros de climatología**: precipitación mínima, temperatura mínima de invierno, temperatura máxima de verano, amplitud térmica.

Los filtros combinan lógica "Y" (AND): si filtras por provincia y rango, solo aparecen municipios que cumplan ambas condiciones.

![Panel de filtros](/assets/desktop-filtros.png)

### 4. Inspector de municipio (panel derecho)

Al hacer clic en cualquier municipio del mapa, el inspector muestra:

- Nombre y provincia del municipio.
- Población total.
- Score global (`mixed_score`) y desglose por bloques (clima, accesibilidad, naturaleza).
- Métricas concretas: precipitación anual, distancia a estación de tren, cobertura forestal, distancia al río más cercano, etc.

El inspector permite comparar visualmente los bloques con barras horizontales que indican la posición relativa dentro del ámbito.

![Inspector de municipio abierto](/assets/desktop-inspector.png)

### 5. Selector de capas (panel de capas)

El Atlas permite superponer capas adicionales al mapa base desde el panel de capas:

- **Municipios**: polígonos municipales.
- **Isocronas**: anillos de tiempo de viaje desde los centros de referencia.
- **Uso del suelo**: cobertura de land use.
- **Vegetación**: capa de vegetación.
- **Bosques**: cobertura forestal.
- **Embalses**: embalses y pantanos.
- **Rivers**: ríos y cursos de agua.
- **Base IGN**: mapa base del Instituto Geográfico Nacional.
- **Satélite IGN**: imagen satelital.

Las capas se activan/desactivan independientemente y pueden combinarse para contextualizar geográficamente los resultados.

![Panel de capas](/assets/desktop-capas.png)

## Flujo de uso recomendado

1. **Seleccionar una métrica** desde los botones del panel lateral.
2. **Observar el patrón territorial** en el mapa para identificar zonas con mejor puntuación.
3. **Aplicar filtros** para reducir el conjunto a provincias o rangos de score de interés.
4. **Hacer clic en un municipio** para ver el detalle en el inspector.
5. **Comparar varios municipios** abriendo el inspector de cada uno secuencialmente.
6. **Usar las capas** para contextualizar resultados geográficamente.

## Buenas prácticas

- No te quedes solo con el `mixed_score`: revisa siempre los bloques para entender diferencias reales.
- Cuando dos municipios tengan scores similares, compara el desglose para ver en qué bloque destaca cada uno.
- Usa los filtros para excluir zonas que no te interesan antes de analizar.
- Activa las capas de límites para contextualizar resultados en el mapa.

## Límites de lectura

- Una buena puntuación no sustituye una visita al municipio.
- Puede haber factores clave fuera del modelo: vida social, estacionalidad de servicios o encaje personal.
- Los resultados son comparativos dentro del alcance actual, no una clasificación universal.

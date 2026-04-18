
# Instrucciones para opencode — visor objetivo para localizar “El Buen Vivir”

## 1) Objetivo del proyecto

Construir una aplicación web **Svelte + MapLibre** que ayude a identificar, comparar y priorizar municipios o emplazamientos potenciales para el proyecto **El Buen Vivir** en Castilla y León (con posibilidad de ampliar a otras zonas de España), combinando:

- búsqueda por municipio y por coordenadas,
- visualización de capas ambientales y de accesibilidad,
- evaluación **multicriterio objetiva y reproducible**,
- coste de despliegue **0 € o casi 0 €**,
- pipeline de datos preferentemente en **R**.

La aplicación no debe limitarse a “mostrar mapas”: debe permitir **tomar decisiones comparables** entre lugares.

---

## 2) Principio de diseño: separar “exploración” de “evaluación”

La herramienta tendrá dos modos:

### A. Modo exploración
Para navegar el mapa y responder preguntas como:
- ¿Dónde llueve más o menos?
- ¿Qué municipios tienen mejor accesibilidad desde Madrid?
- ¿Qué tipo de cobertura vegetal hay alrededor?
- ¿Hay ríos, embalses o zonas recreativas cerca?
- ¿Qué distancia/tiempo por carretera hay desde puntos de origen concretos?

### B. Modo evaluación
Para responder:
- ¿Qué municipios son **mejores candidatos** según criterios definidos?
- ¿Cuál es el ranking?
- ¿Qué municipios salen bien en clima pero mal en accesibilidad?
- ¿Qué lugares siguen siendo buenos si cambiamos los pesos?

Esta separación es esencial. Un visor con muchas capas no garantiza objetividad; un sistema con **indicadores, pesos, transparencia metodológica y análisis de sensibilidad** sí.

---

## 3) Recomendación tecnológica

## Frontend
- **SvelteKit**
- **MapLibre GL JS**
- **pmtiles** para capas estáticas pesadas
- Estilos simples, priorizando legibilidad y rapidez

## Datos / procesamiento
- **R** como lenguaje principal de ETL y análisis espacial
- Paquetes previstos:
  - `sf`
  - `terra`
  - `dplyr`
  - `arrow`
  - `duckdb`
  - `jsonlite`
  - `httr2`
  - `exactextractr`
  - `units`
  - `purrr`
  - `stringr`

## Utilidades GIS externas
- **GDAL / ogr2ogr**
- **tippecanoe** para generar vector tiles / MBTiles cuando convenga
- **pmtiles** CLI para convertir MBTiles a PMTiles

## Hosting
- **GitHub Pages** o **Cloudflare Pages** para el frontend estático
- Preferencia:
  - GitHub Pages si el sitio final es muy ligero
  - Cloudflare Pages si el volumen de assets crece o queremos más margen

---

## 4) Decisión importante: arquitectura recomendada

## Opción recomendada: arquitectura estática + preprocesado offline

### Qué significa
Todo lo posible se calcula **antes** del despliegue:
- indicadores climáticos,
- coberturas del suelo,
- distancias a elementos de interés,
- tiempos a municipios desde orígenes fijos,
- puntuaciones y rankings.

Después, el navegador:
- descarga tiles/vector tiles,
- pinta capas,
- filtra,
- recalcula ranking con pesos del usuario,
- muestra fichas y comparativas.

### Por qué esta opción es la mejor
1. **Coste 0** realista.
2. Mucho más robusta que depender de APIs en tiempo real.
3. Más rápida para el usuario.
4. Más fácil de versionar y auditar.
5. Permite trabajar perfectamente con **opencode/codex** en un repo.

### Qué dejamos dinámico
Solo aquello que realmente merezca ser interactivo:
- búsqueda por texto,
- búsqueda por coordenadas,
- reponderación de criterios,
- cálculo puntual de ruta si se decide usar API externa.

---

## 5) Fuentes de datos recomendadas

## 5.1 Municipios y buscador
### Fuente principal
- **IGN / CNIG Nomenclátor Geográfico de Municipios y Entidades de Población**: incluye denominaciones, coordenadas y datos de municipios. citeturn900497search5turn900497search17
- **Límites municipales IGN** para geometrías de municipios. citeturn900497search1turn900497search21

### Uso
- Índice de municipios para el buscador
- Capa base municipal
- Unidad territorial principal para agregación

---

## 5.2 Temperatura y precipitación
### Fuente recomendada
- **Open-Meteo Historical Weather API** para series históricas, con datos desde 1940 y posibilidad de usar ERA5 / ERA5-Land. citeturn443073search1

### Estrategia
No consultar la API desde el navegador para cada interacción. En su lugar:
1. definir una malla o usar centroides municipales,
2. descargar series históricas necesarias,
3. calcular indicadores climáticos agregados,
4. guardar resultados por municipio.

### Indicadores propuestos
- precipitación anual media
- precipitación invernal media
- precipitación estival media
- temperatura media en invierno
- temperatura media en verano
- media de máximas en verano
- media de mínimas en invierno
- número estimado de días muy calurosos
- amplitud térmica estacional

### Nota metodológica
Si la resolución climática es más gruesa que el municipio, dejarlo explícito en la ficha del indicador.

---

## 5.3 Cobertura vegetal / naturaleza del entorno
### Fuente recomendada
- **CORINE Land Cover** de Copernicus / CNIG, con 44 clases temáticas y descarga por área. citeturn900497search0turn900497search4turn900497search8turn900497search16

### Uso
Para cada municipio o buffer alrededor del punto candidato:
- % bosque
- % matorral
- % cultivos
- % superficies artificiales
- % agua
- índice de naturalidad simple
- diversidad de coberturas

### Observación
CORINE no es perfecto para detalle fino de parcela, pero es excelente para una **evaluación territorial comparativa**.

---

## 5.4 Ríos, embalses, zonas recreativas y otros POIs
### Fuente recomendada
- **OpenStreetMap**, consultado mediante Overpass o descargado por extractos, usando su esquema de etiquetas. citeturn443073search3turn443073search7turn443073search11turn443073search15

### Elementos de interés
- ríos y cursos de agua
- embalses / water bodies
- áreas recreativas
- parques
- miradores
- senderos
- zonas de baño
- equipamientos básicos (centro de salud, farmacia, alimentación)
- estaciones de tren / autobús

### Recomendación operativa
Para un prototipo, empezar con:
- extracto OSM de Castilla y León,
- procesado offline,
- generación de capas vectoriales propias.

No depender del endpoint público de Overpass en producción para consultas intensivas.

---

## 5.5 Isochronas y routing
### Alternativa más simple
- **openrouteservice** para rutas e isocronas. El plan estándar gratuito publica límites como 2.000 peticiones/día para directions y 500/día para isochrones. citeturn443073search6turn443073search10

### Recomendación
Separar dos casos:

#### Caso A. Orígenes fijos del proyecto
Ejemplo:
- Madrid centro
- noroeste de Madrid
- Valladolid
- otro punto consensuado del grupo

En este caso:
- precalcular offline isocronas o tiempos de viaje a municipios,
- guardar resultados en el dataset,
- no depender de llamadas en vivo.

#### Caso B. Punto de origen libre introducido por el usuario
En este caso:
- permitir cálculo ad hoc,
- pero marcarlo como “consulta puntual”,
- cachear localmente si procede,
- asumir que depende de una API externa.

### Importante
Para “objetividad”, el ranking principal debe basarse en **orígenes definidos y estables**, no en un origen arbitrario que cambie cada vez.

---

## 5.6 Geocodificación y búsqueda por coordenadas
### Opciones
- Búsqueda por municipio: dataset propio IGN
- Búsqueda por coordenadas: entrada manual `lat, lon`
- Geocodificación por texto adicional: prudencia con **Nominatim público**, que tiene política de uso restrictiva. citeturn900497search2turn900497search10

### Recomendación
Para el MVP:
- **no** depender de geocoder externo para municipios,
- usar índice propio de municipios/entidades,
- admitir pegar coordenadas manuales,
- dejar geocodificación libre para una fase posterior.

---

## 6) Objetividad: cómo modelar la decisión

La objetividad no significa “neutralidad absoluta”; significa:
1. criterios explícitos,
2. datos trazables,
3. transformación reproducible,
4. pesos visibles,
5. análisis de sensibilidad,
6. posibilidad de auditar el resultado.

## 6.1 Unidad de análisis
Elegir una de estas dos:

### Opción 1. Municipio
Más fácil, robusta y razonable para una fase 1.

### Opción 2. Celdas o puntos candidatos
Más precisa, pero bastante más compleja.

### Recomendación
Empezar por **municipio** y permitir luego analizar “puntos concretos” dentro de municipios finalistas.

---

## 6.2 Criterios sugeridos para El Buen Vivir
Propuesta inicial:

### Clima y confort
- temperatura media invierno
- mínima media invierno
- máxima media verano
- precipitación anual
- precipitación estival
- extremos térmicos

### Accesibilidad
- tiempo en coche desde Madrid
- tiempo desde otros puntos acordados
- proximidad a estación o núcleo con servicios

### Entorno natural
- % forestal
- presencia de agua cercana
- diversidad paisajística
- cercanía a espacios recreativos

### Habitabilidad territorial
- tamaño del municipio
- densidad baja/media
- disponibilidad de servicios básicos cercanos
- presión urbana baja

### Riesgos / penalizaciones
- aislamiento excesivo
- calor extremo
- sequedad excesiva
- urbanización intensa
- ausencia de servicios mínimos

---

## 6.3 Normalización
Convertir todos los indicadores a una escala común, por ejemplo 0–100.

Ejemplos:
- más bosque = mejor => escala ascendente
- más tiempo desde Madrid = peor => escala descendente
- precipitación “intermedia” puede ser óptima => función tipo campana
- calor extremo = penalización no lineal

No usar solo min-max bruto sin revisar outliers.

---

## 6.4 Ponderación
Implementar:
- pesos por bloque,
- pesos por indicador,
- presets:
  - “equilibrado”
  - “más naturaleza”
  - “más accesibilidad”
  - “más confort climático”

---

## 6.5 Análisis de sensibilidad
Imprescindible.

La app debe mostrar:
- si el top 10 cambia mucho o poco al mover pesos,
- qué municipios son robustos,
- qué municipios solo salen bien bajo supuestos muy concretos.

Esto da mucha más confianza que un ranking único y rígido.

---

## 7) Qué capas debe incluir el visor

## Capas base
- límites municipales
- etiquetas de municipios
- sombreado suave o base map muy ligera

## Capas temáticas iniciales
1. precipitación media anual
2. temperatura media invierno
3. temperatura media verano
4. mínima media invierno
5. máxima media verano
6. cobertura del suelo dominante
7. % forestal
8. agua superficial (ríos / embalses)
9. zonas recreativas
10. isocronas desde orígenes predefinidos
11. tiempo de viaje por carretera
12. puntuación compuesta / ranking final

## Capas derivadas especialmente útiles
- buffer de 5 km / 10 km alrededor de un municipio o punto
- densidad de elementos recreativos
- distancia al embalse o río más cercano
- distancia a servicios esenciales

---

## 8) Diseño funcional del frontend

## Pantalla principal
- mapa a la izquierda o centro
- panel lateral con:
  - buscador
  - selector de capa
  - filtros
  - pesos
  - ficha del municipio seleccionado

## Ficha de municipio
Debe mostrar:
- nombre
- provincia
- población
- clima resumido
- accesibilidad resumida
- entorno natural resumido
- puntuación total
- desglose por criterios
- posición en ranking
- advertencias metodológicas

## Comparador
Permitir comparar 2–5 municipios:
- radar simple o barras
- tabla con indicadores clave
- diferencias absolutas y relativas

## Transparencia metodológica
Botón visible:
- “cómo se calcula esta puntuación”

Eso debe abrir:
- fórmula
- fuentes
- fecha de actualización
- limitaciones

---

## 9) Estrategia de datos y almacenamiento

## 9.1 Qué guardar como PMTiles
Guardar en PMTiles aquellas capas geográficas que sean:
- relativamente estables,
- pesadas,
- útiles para mapa.

Ejemplos:
- límites municipales simplificados
- coberturas CORINE simplificadas
- hidrografía
- zonas recreativas
- capas agregadas por municipio

PMTiles funciona muy bien en hosting estático porque permite servir tiles desde uno o pocos archivos con peticiones range HTTP. MapLibre dispone de ejemplo y soporte para usar PMTiles como fuente. citeturn443073search12turn443073search16

## 9.2 Qué guardar como Parquet / JSON
- tabla maestra de indicadores por municipio
- metadatos de fuentes
- pesos predefinidos
- fichas resumidas

Recomendación:
- master dataset en **Parquet**
- exportaciones web en **GeoJSON simplificado / JSON**
- tiles para visualización

## 9.3 Qué NO guardar si queremos coste 0
Evitar al principio:
- PostGIS remoto
- tile server propio persistente
- backend complejo
- pipelines que dependan de cron en infraestructura de pago

---

## 10) Pipeline recomendado en R

## Etapa 0. Definir alcance
- fase 1: Castilla y León + Madrid como origen principal
- unidad: municipio
- resolución temporal climática: medias por estación
- sistema de puntuación: 0–100

## Etapa 1. Ingesta
- descargar municipios y límites
- descargar CORINE
- obtener extracto OSM relevante
- descargar/clasificar series climáticas
- definir orígenes de isocronas y rutas

## Etapa 2. Estandarización
- reproyectar todo a CRS común
- limpiar geometrías
- simplificar donde convenga
- generar centroides municipales
- crear buffers estándar

## Etapa 3. Cálculo de indicadores
Por municipio:
- clima
- accesibilidad
- naturaleza
- agua
- recreación
- servicios
- penalizaciones

## Etapa 4. Scoring
- normalizar
- ponderar
- calcular score total
- calcular sensibilidad

## Etapa 5. Publicación
- exportar tabla de indicadores
- exportar GeoJSON simplificado
- generar MBTiles / PMTiles
- publicar assets estáticos

---

## 11) Propuesta de estructura del repositorio

```text
el-buen-vivir-visor/
  README.md
  .gitignore
  frontend/
    src/
    static/
    package.json
    svelte.config.js
    vite.config.ts
  data-raw/
    ign/
    osm/
    climate/
    corine/
    ors/
  data-intermediate/
  data-output/
    json/
    parquet/
    pmtiles/
  scripts/
    00_config.R
    01_download_ign.R
    02_download_climate.R
    03_download_corine.R
    04_prepare_osm.R
    05_compute_indicators.R
    06_compute_scores.R
    07_export_web.R
    08_build_pmtiles.sh
  docs/
    methodology.md
    data-sources.md
    scoring.md
```

---

## 12) Recomendación de roadmap

## Fase 1 — MVP útil
Objetivo: tener algo ya valioso para decidir.

### Incluye
- buscador de municipios
- búsqueda por coordenadas
- mapa base municipal
- 5–8 indicadores clave
- ranking multicriterio
- comparador de municipios
- capas:
  - precipitación
  - temperatura invierno/verano
  - % forestal
  - agua
  - tiempo desde Madrid

### No incluye todavía
- routing dinámico libre
- edición de pesos ultra avanzada
- infinidad de POIs

## Fase 2 — Consolidación
- más POIs
- isocronas desde varios orígenes
- sensibilidad visual
- descarga de informes
- filtros avanzados

## Fase 3 — análisis de parcelas / puntos concretos
- puntos candidatos específicos
- buffers personalizados
- más resolución espacial
- integración de propiedades concretas

---

## 13) Riesgos y decisiones a evitar

### Error 1
Intentar resolver desde el día 1 tanto municipios como parcelas concretas.
**Solución:** empezar por municipio.

### Error 2
Depender excesivamente de APIs públicas en tiempo real.
**Solución:** precalcular offline.

### Error 3
Confundir muchas capas con mejor decisión.
**Solución:** priorizar indicadores y scoring.

### Error 4
Intentar usar el Nominatim público como backend intensivo.
**Solución:** índice propio de municipios y coordenadas manuales. citeturn900497search2

### Error 5
Meter demasiados assets en GitHub Pages.
GitHub Pages publica sitios de hasta 1 GB y tiene límite blando de 100 GB/mes de ancho de banda. citeturn900497search7turn900497search19
**Solución:** simplificar, usar PMTiles y vigilar tamaño final.

---

## 14) Mi recomendación final

Sí, **Svelte + MapLibre + PMTiles + R** es una arquitectura muy buena para este proyecto.

No cambiaría a Python salvo por una razón concreta:
- si más adelante quisiéramos montar servicios geoespaciales propios o pipelines más pesados donde el ecosistema Python tuviera ventaja.

Para vuestro caso, **R es perfectamente válido** si el enfoque es:
- ETL espacial,
- agregación municipal,
- scoring,
- exportación de artefactos estáticos.

La decisión correcta no es “hacer un visor con capas”, sino construir un **sistema de apoyo a la decisión territorial** con:
- metodología transparente,
- datos públicos,
- cálculo reproducible,
- despliegue estático.

---

## 15) Tareas inmediatas para opencode

1. Crear el monorepo con `frontend/`, `scripts/`, `data-raw/`, `data-output/`, `docs/`.
2. Inicializar `frontend` con **SvelteKit**.
3. Integrar **MapLibre GL JS**.
4. Añadir soporte de lectura **PMTiles**.
5. Crear un primer mapa con:
   - límites municipales de Castilla y León,
   - buscador por municipio,
   - panel lateral,
   - selección de municipio.
6. Preparar en R un dataset mínimo por municipio con:
   - nombre
   - provincia
   - población
   - centroides
   - score ficticio de prueba
7. Mostrar ficha del municipio al hacer click.
8. Crear documentación `docs/methodology.md`.
9. Dejar preparado el pipeline de descarga de datos reales.
10. Mantener todo el proyecto orientado a:
   - reproducibilidad,
   - coste 0,
   - claridad metodológica,
   - facilidad para iterar.

---

## 16) Prompt operativo para opencode

```text
Quiero que construyas un MVP de una aplicación web para evaluar municipios candidatos para un proyecto cooperativo rural llamado “El Buen Vivir”.

Stack obligatorio:
- SvelteKit
- MapLibre GL JS
- PMTiles para capas geográficas estáticas
- R para el pipeline de datos

Objetivo funcional:
- buscar municipios y coordenadas,
- visualizar capas temáticas,
- seleccionar un municipio,
- mostrar ficha resumida,
- comparar municipios,
- calcular una puntuación multicriterio transparente.

Requisitos de arquitectura:
- sin backend complejo,
- preferencia por hosting estático,
- datos precalculados offline,
- estructura de proyecto limpia y mantenible.

Crea:
1. estructura de carpetas del monorepo,
2. frontend SvelteKit funcional,
3. componente de mapa con MapLibre,
4. panel lateral con buscador y ficha,
5. soporte preparado para PMTiles,
6. scripts base en R para preparar un dataset municipal,
7. documentación metodológica mínima.

No intentes resolver todavía todo el pipeline real. Primero deja un MVP técnicamente sólido y fácil de extender.

Prioridades:
- claridad del código,
- arquitectura correcta,
- experiencia de usuario simple,
- facilidad para incorporar después clima, coberturas, agua, recreación e isocronas.

Entrega también:
- instrucciones de ejecución local,
- decisiones técnicas adoptadas,
- siguiente lista de tareas priorizadas.
```

---

## 17) Criterio de éxito del MVP

El MVP será exitoso si permite:
- abrir un mapa rápido,
- buscar un municipio,
- ver una ficha clara,
- entender cómo se calculará el ranking,
- incorporar nuevas capas e indicadores sin rehacer la arquitectura.

Si además deja montado el camino para publicar todo como sitio estático, el enfoque será correcto.

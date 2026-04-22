# Propuesta metodologica - rios/bano y transporte (MVP)

## 1) Rios + buffer + caudal + posibilidad de bano

### Fuente sugerida
- Red hidrográfica: IGN/IDEE (hidrografia INSPIRE) u OpenStreetMap (capa lineal como respaldo).
- Caudal: estaciones SAIH/CHD + series de la Confederacion Hidrografica del Duero y Ebro (segun cuenca), usando caudal medio anual o percentil estival.
- Zonas de bano: censo oficial de zonas de bano del Ministerio de Sanidad (NAYADE / SINAC, segun disponibilidad anual).

### Indicadores propuestos
1. `dist_rio_km`: distancia del centroide municipal al cauce principal mas cercano.
2. `rio_proximidad_norm`: normalizacion inversa por tramos (0-1).
3. `caudal_referencia`: caudal medio anual de la estacion representativa de cuenca/subcuenca.
4. `caudal_norm`: normalizacion robusta por cuantiles (evita sesgo por rios extremos).
5. `bano_posible`: booleano de proximidad a zona de bano oficial (p.ej. <= 8-12 km por red vial aproximada o distancia euclidea MVP).

### Modelado recomendado (incremental)
- **Fase MVP**
  - Distancia euclidea municipal a red de rios filtrando por jerarquia minima (evitar arroyos efimeros).
  - Join espacial de municipios con zona de bano oficial mas cercana.
  - Caudal por asignacion de estacion mas cercana dentro de la misma cuenca.
- **Fase 2**
  - Sustituir distancia euclidea por tiempo de acceso por red vial.
  - Ajustar caudal con estacionalidad (especialmente verano).

### Como aproximar "posibilidad de bano" sin inventar
- No inferir calidad de agua si no hay dato oficial.
- Usar solo dos componentes trazables:
  - existencia de zona de bano oficial cercana,
  - proximidad realista al punto de acceso.
- Etiqueta sugerida: `bano_oficial_cercano` en vez de "bano apto" para evitar sobreinterpretacion.

---

## 2) Medios de transporte (propuesta MVP)

### Indicadores candidatos
1. `dist_estacion_tren_km`
2. `dist_parada_bus_interurbano_km` (o nodo principal de bus)
3. `nodos_transporte_30min` (conteo de nodos relevantes en radio/tiempo objetivo)
4. `transporte_relevante_municipio` (booleano: presencia directa en municipio)

### Fuentes razonables
- Red ferroviaria y estaciones: ADIF + datos abiertos MITMA/CNIG.
- Transporte interurbano por bus: GTFS abiertos autonómicos/provinciales cuando existan; como base inicial, inventario de estaciones/autobuses interurbanos por OSM + validacion manual por provincias.

### MVP recomendado (simple y verificable)
- Construir solo dos variables iniciales:
  - `dist_estacion_tren_km`
  - `dist_nodo_bus_km`
- Transformarlas a un bloque `transport_access_norm` por tramos y suelo metodologico (ej. 0.2).
- Mantenerlo fuera del score mixto principal en primera entrega (modo exploracion), y activarlo en evaluacion solo tras validacion de cobertura de datos.

### Criterio de calidad minimo
- Cobertura > 95% de municipios con valor no nulo.
- Documentar claramente huecos de GTFS o estaciones sin geocodificacion precisa.

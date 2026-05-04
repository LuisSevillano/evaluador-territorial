### Estructura de datos para rejilla 2km x 2km

#### Esquema de celda (grid cell)

```typescript
export type GridCell = {
  cell_id: string;           // e.g., "28079_12_34" (municipio_row_col)
  municipio_id: string;      // Código INE municipio
  municipio_nombre: string;
  provincia: string;
  
  // Geométria
  geometry: GeoJSON Polygon;
  area_km2: number;
  
  // Posición en rejilla
  grid_row: number;
  grid_col: number;
  
  // Variables climáticas (calculadas por celda)
  precip_annual_mm?: number;
  temp_winter_mean_c?: number;
  temp_summer_mean_c?: number;
  
  // Río / baño
  river_distance_km?: number;
  river_access_score?: number;
  river_access_class?: string;
  
  // Naturaleza
  natural_cover_pct?: number;
  forest_pct?: number;
  water_pct?: number;
  
  // Isocronas
  isochrone_bucket?: string;
  iso_02h30m?: boolean;
  iso_04h00m?: boolean;
};
```

#### Agregación municipal (desde celdas)

```typescript
// En Municipio.ts - campos agregados
export type MunicipioGridAggregates = {
  // Clima
  precip_annual_mean?: number;    // media de celdas
  temp_winter_mean?: number;      // media de celdas
  temp_summer_mean?: number;      // media de celdas
  
  // Río
  river_access_mean?: number;       // media de celdas
  river_access_max?: number;        // máximo (mejor acceso)
  river_access_p75?: number;        // percentil 75
  pct_cells_river_access_high?: number;  // % celdas con acceso alto
  nearest_good_river_distance?: number; // distancia a río de calidad
  
  // Naturaleza
  natural_cover_mean?: number;       // media de celdas
  pct_cells_natural_high?: number;     // % celdas con cobertura >80%
  
  // Isocronas
  isochrone_best?: string;              // mejor isocrona dentro del municipio
  isochrone_majority?: string;          // isocrona mayoritaria
  pct_area_inside_2h30?: number;       // % área con acceso <2h30
};
```

#### PMTiles recomendado

```
frontend/static/tiles/
  grid/
    grid_{scope}.pmtiles          # Tiles vectoriales de rejilla
    grid_{scope}_metadata.json   # Metadatos
  municipios/
    municipios_{scope}.pmtiles  # Tiles municipales (actual)
```

#### Variables en PMTiles (mínimas para rendimiento)

**Grid PMTiles:**
- `cell_id`, `municipio_id`, `geometry`
- `river_access_score`, `natural_cover_pct`, `precip_annual_mm`
- `isochrone_bucket`

**Municipio PMTiles:**
- `id`, `nombre`, `provincia`, `geometry`
- Variables agregadas para coloreado y scoring

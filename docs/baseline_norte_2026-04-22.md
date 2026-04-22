# Baseline norte - 2026-04-22

## Scope
- Castilla y Leon
- La Rioja
- Pais Vasco
- Cantabria
- Asturias
- Lugo
- Ourense
- Guadalajara

## Pipeline status
- Command: `bash scripts/run_norte_full.sh`
- Result: OK
- Municipal rows: 3356
- Quality checks: no invalid geometry, no duplicated codigo, no invalid travel bucket

## Generated key artifacts
- `frontend/static/data/municipios_v2.json`
- `frontend/static/data/municipios_climate_monthly.json`
- `frontend/static/data/dataset_metadata_v3.json`
- `frontend/static/tiles/municipios.pmtiles`
- `frontend/static/tiles/ccaa.pmtiles`
- `frontend/static/tiles/provincias.pmtiles`
- `frontend/static/data/isochrones/distance_01h30m_filled.json`
- `frontend/static/data/isochrones/distance_02h00m_filled.json`
- `frontend/static/data/isochrones/distance_02h30m_filled.json`
- `frontend/static/data/isochrones/distance_03h30m_filled.json`
- `frontend/static/data/isochrones/distance_04h00m_filled.json`
- `frontend/static/data/isochrones/iso_diff_01h30m.geojson`
- `frontend/static/data/isochrones/iso_diff_01h30m_02h00m.geojson`
- `frontend/static/data/isochrones/iso_diff_02h00m_02h30m.geojson`
- `frontend/static/data/isochrones/iso_diff_02h30m_03h30m.geojson`
- `frontend/static/data/isochrones/iso_diff_03h30m_04h00m.geojson`

## Visual QA checklist
- Legend: no outline/border in color bar, labels stay on one line
- Mode toggle: grouped switch look restored
- CCAA boundaries render above municipal fills
- Isochrones render as line layers from `iso_diff_*.geojson`
- Desktop evaluation layout keeps map visible in exploration
- Mobile build and desktop build both load without runtime errors

# El Buen Vivir - Territorial Observatory

El Buen Vivir is a territorial analysis project focused on municipalities in northern Spain.
It combines climate, accessibility, and nature indicators to help compare municipalities through an interactive map and municipal profile view.

Current default analysis scope in the pipeline: Castilla y Leon + La Rioja + Pais Vasco + Cantabria + Asturias + Lugo + Ourense + Guadalajara.

## What is in this repository

- `frontend/`: SvelteKit web app (map, filters, municipal inspector, SEO metadata)
- `scripts/`: R and shell scripts to build and export the dataset
- `docs/`: indicator notes and reference documentation
- `data/` and `output/`: input sources and generated artifacts

## Tech stack

- Frontend: SvelteKit + TypeScript + MapLibre
- Data pipeline: R (`sf`, `dplyr`, `terra`, `exactextractr`, etc.)
- Tile generation: `tippecanoe` + `pmtiles`

## Run locally

```bash
cd frontend
npm install
npm run dev
```

## Build frontend

```bash
cd frontend
npm run build
```

## Documentation workflow (VitePress)

The repository includes a full docs site in `docs-site/` and it is published under `/docs/` in Netlify.

### Develop docs locally

```bash
cd docs-site
npm install
npm run docs:dev
```

### Rebuild charts and maps used by docs

```bash
Rscript scripts/90_build_docs_maps.R
Rscript scripts/91_build_docs_charts.R
```

### Preview docs exactly as production serves them

```bash
cd frontend
npm run build:with-docs
cd build
python3 -m http.server 4173
```

Open `http://localhost:4173/docs/`.

### Deploy frontend + docs to Netlify

```bash
cd frontend
npm run deploy
```

## Run pipeline with explicit scope

```bash
ANALYSIS_SCOPE=norte Rscript scripts/run_pipeline_v2.R
./scripts/05_build_pmtiles.sh
```

Supported scopes: `avila`, `cyl`, `norte`, `espana`.

Isochrones are exported in two forms:
- cumulative (`distance_*.json`)
- differential rings (`iso_diff_*.geojson`) for non-overlapping map overlays

Quick command (pipeline + tiles + frontend checks):

```bash
./scripts/run_norte_full.sh
```

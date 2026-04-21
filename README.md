# El Buen Vivir - Territorial Observatory

El Buen Vivir is a territorial analysis project focused on municipalities in Castilla y Leon (Spain).
It combines climate, accessibility, and nature indicators to help compare municipalities through an interactive map and municipal profile view.

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

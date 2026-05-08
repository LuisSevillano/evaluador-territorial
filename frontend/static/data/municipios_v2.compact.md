# municipios_v2 compact format

This directory contains a compact transport format for `municipios_v2.json` used by the frontend.

## Files

- `municipios_v2.compact.json`
  - `version`: format version
  - `fields`: ordered field codes (`0`, `1`, ..., `z`, `10`, ...)
  - `rows`: municipality values aligned by index with `fields`
- `municipios_v2.dictionary.json`
  - `version`: format version
  - `codeToKey`: map from field code to original long key

## Why

- avoids repeating long keys (e.g. `precip_annual_mm`) thousands of times
- reduces transfer size for frontend dataset downloads
- keeps full fidelity: decoded objects preserve original key names

## Regeneration

Run from `frontend/`:

```bash
npm run data:compact
```

This reads `static/data/municipios_v2.json` and regenerates both compact files.

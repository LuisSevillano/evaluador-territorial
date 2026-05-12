# Contexto De Producto

## Identidad
- Producto: Observatorio Territorial El Buen Vivir.
- Proposito: evaluar y comparar municipios para residencia/vida territorial usando indicadores climaticos, accesibilidad, entorno natural, relieve, agua recreativa y contexto territorial.
- La experiencia objetivo actual es un producto unificado de exploracion y evaluacion, no dos modos separados.

## Alcance Vigente
- El scope operativo por defecto es `norte`, definido en `scripts/00_config.R` mediante `ANALYSIS_SCOPE`.
- En el estado actual del codigo, `norte` incluye Castilla y Leon, La Rioja, Pais Vasco, Cantabria, Asturias, Lugo, Ourense, Guadalajara y Madrid.
- No asumir que `norte` equivale solo a Castilla y Leon ni que Madrid esta fuera: verificar `scripts/00_config.R` si el alcance importa para el cambio.

## Modelo De Valor
- El score principal expuesto es `mixed_score`.
- `mixed_score` es comparativo dentro del scope activo; no presentarlo como valor absoluto universal.
- La interpretacion debe explicar posicion relativa, tradeoffs y contexto, no prometer calidad objetiva de vida.

## Semantica De Indicadores
- `river_access_score` significa acceso fluvial recreativo potencial o acceso hibrido a zonas de bano si se activa esa rama del pipeline.
- No describir `river_access_score` como calidad sanitaria del agua.
- `precip_moisture_score` es humedad climatica hibrida basada principalmente en TerraClimate 1991-2020 como referencia absoluta, no solo percentil interno.
- `precip_relative_score` es ventaja relativa dentro del scope activo y debe explicarse separada de la humedad climatica absoluta.
- `water_drops_level`/`water_drops_label` son una lectura visual fija de humedad y sequia estival; no deben depender de filtros.
- Las isocronas son precalculadas y no representan trafico en tiempo real.
- La unidad de calculo base para varios indicadores es grid 2x2 km agregado a municipio; evitar prometer precision de parcela.

## Roadmap Vivo
- El roadmap vigente esta en `docs/NEXT_STEPS_ROADMAP.md`.
- Prioridades candidatas actuales: accesibilidad a relieve, reportes de timing/cache, confidence score y comparativas municipio/provincia/percentiles.
- Antes de implementar una idea de producto, comprobar si ya aparece como backlog para preservar el lenguaje y la intencion existente.

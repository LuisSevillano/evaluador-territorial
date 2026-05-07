# Fuentes de zonas de bano

Este documento registra las fuentes identificadas para mejorar el calculo de acceso fluvial recreativo (zonas de bano) y reducir cuellos de botella del pipeline.

## Objetivo

- Priorizar fuentes oficiales con geometrias reutilizables.
- Cubrir primero el ambito operativo (`ANALYSIS_SCOPE=norte`) y despues escalar a estatal.
- Mantener trazabilidad de origen, licencia y fecha de descarga.

## Fuentes identificadas

## 1) CHD (Confederacion Hidrografica del Duero)

- Tipo: WFS oficial (descarga `shape-zip` en EPSG:25830).
- Cobertura: demarcacion del Duero.
- Estado: candidata prioritaria para integrar en el pipeline por ser vectorial y directa.

### 1.1 Zonas recreativas

- URL:
  `https://mirame.chduero.es/geoserver/mirame/wfs?typeName=mirame:Zonas_Recreativas&service=wfs&version=1.1.0&request=GetFeature&outputFormat=shape-zip&srsName=EPSG:25830&format_options=CHARSET:UTF-8`

### 1.2 Zonas de influencia de zonas recreativas

- URL:
  `https://mirame.chduero.es/geoserver/mirame/wfs?typeName=mirame:Zonas_Influencia_Zonas_Recreativas&service=wfs&version=1.1.0&request=GetFeature&outputFormat=shape-zip&srsName=EPSG:25830&format_options=CHARSET:UTF-8`

## 2) Catalogo estatal de aguas de bano (MAGRAMA/MAPA)

- Tipo: ZIP oficial.
- Cobertura: nacional.
- URL:
  `https://www.mapama.gob.es/app/descargas/descargafichero.aspx?f=censoaguasbano_2025.zip`
- Estado: fuente clave para escalar a Espana; pendiente revisar contenido exacto (schema, geometria, codigos administrativos, campos de estado y temporada).

## 3) NAYADE ciudadano (buscador)

- URL:
  `https://nayadeciudadano.sanidad.gob.es/Splayas/ciudadano/ciudadanoZonaAction.do`
- Tipo: aplicacion web de consulta.
- Observacion: muestra listado por CCAA/provincia/municipio.
- Viabilidad de extraccion:
  - Probable, pero requiere analizar peticiones de red (formularios/parametros) para automatizar descarga o scraping estable.
  - Recomendado usarla como respaldo de validacion y no como fuente primaria si no hay endpoint documentado estable.

## 4) Fuente no oficial (complementaria)

- Sitio:
  `https://conalforjas.com/piscinas-naturales/`
- Archivo descargado localmente:
  `/Users/portatil/Documents/projects/evaluador-territorial/data/raw/bathing_areas/Zonas de Baño Gratuitas.kml`
- Estado: util para cobertura adicional exploratoria; no sustituye fuentes oficiales.

## Priorizacion recomendada de integracion

1. CHD WFS (zonas recreativas + zonas de influencia) para mejorar rapido el ambito norte.
2. Catalogo estatal `censoaguasbano_2025.zip` para generalizar metodologia.
3. NAYADE para contraste/QA (y extraccion solo si se confirma endpoint estable).
4. KML no oficial como capa auxiliar opcional.

## Notas para implementacion en pipeline

- Guardar descargas en `data/raw/bathing_areas/` con subcarpetas por fuente (`chd`, `mapa`, `nayade`, `community`).
- Generar un feature intermedio de candidatos de bano con campos minimos armonizados:
  - `source`, `source_id`, `name`, `geometry`, `scope`, `confidence`, `license_note`, `downloaded_at`.
- En el score, separar:
  - proximidad a zona de bano oficial,
  - proximidad a tramo fluvial apto,
  - y fusion metodologica final (evitar mezclar semanticas sin trazabilidad).

## Registro de esta incorporacion

- Fecha de registro: 2026-05-05
- Registrado en: `docs-site/pipeline/zonas-bano.md`
- Responsable: equipo de datos (pendiente de implementacion tecnica)

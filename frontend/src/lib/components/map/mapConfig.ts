import type maplibregl from 'maplibre-gl';

export const municipiosSourceId = 'municipios-centroides-source';
export const municipiosLayerId = 'municipios-centroides-layer';
export const municipiosPmtilesSourceId = 'municipios-pmtiles-source';
export const municipiosPolygonsFillLayerId = 'municipios-polygons-fill-layer';
export const municipiosPolygonsLineLayerId = 'municipios-polygons-line-layer';
export const municipiosHoverLineLayerId = 'municipios-polygons-hover-line-layer';
export const municipiosSelectedLineLayerId = 'municipios-polygons-selected-line-layer';
export const provinciasPmtilesSourceId = 'provincias-pmtiles-source';
export const provinciasLineLayerId = 'provincias-line-layer';
export const ccaaPmtilesSourceId = 'ccaa-pmtiles-source';
export const ccaaLineLayerId = 'ccaa-line-layer';
export const gridPmtilesSourceId = 'grid-pmtiles-source';
export const gridFillLayerId = 'grid-fill-layer';
export const gridLineLayerId = 'grid-line-layer';
export const gridHoverLineLayerId = 'grid-hover-line-layer';
export const ignWmsSourceId = 'ign-wms-source';
export const ignWmsLayerId = 'ign-wms-layer';
export const ignSatelliteSourceId = 'ign-satellite-wms-source';
export const ignSatelliteLayerId = 'ign-satellite-wms-layer';
export const ignRiversSourceId = 'ign-rivers-wms-source';
export const ignRiversLayerId = 'ign-rivers-wms-layer';
export const ignReservoirsSourceId = 'ign-reservoirs-wms-source';
export const ignReservoirsLayerId = 'ign-reservoirs-wms-layer';
export const forestLayerId = 'forest-layer';
export const landUseLayerId = 'landuse-layer';
export const landUsePmtilesSourceId = 'landuse-pmtiles-source';
export const vegetationLayerId = 'vegetation-layer';
export const landUseSourceLayerName = 'usos_suelo';
export const sourceLayerName = 'municipios';
export const provinciasSourceLayerName = 'provincias';
export const ccaaSourceLayerName = 'ccaa';
export const municipiosMinVisibleZoom = 5;
export const GRID_FORCE_MIN_ZOOM = 6;

export const isochroneLayers = [
	{ key: 'iso_04h00m', sourceId: 'isochrones-04h00m-source', layerId: 'isochrones-04h00m-line', url: '/data/isochrones/iso_diff_03h30m_04h00m.geojson', color: '#7b1f1f' },
	{ key: 'iso_03h30m', sourceId: 'isochrones-03h30m-source', layerId: 'isochrones-03h30m-line', url: '/data/isochrones/iso_diff_02h30m_03h30m.geojson', color: '#d97706' },
	{ key: 'iso_02h30m', sourceId: 'isochrones-02h30m-source', layerId: 'isochrones-02h30m-line', url: '/data/isochrones/iso_diff_02h00m_02h30m.geojson', color: '#4d7c0f' },
	{ key: 'iso_02h00m', sourceId: 'isochrones-02h00m-source', layerId: 'isochrones-02h00m-line', url: '/data/isochrones/iso_diff_01h30m_02h00m.geojson', color: '#1f8a70' },
	{ key: 'iso_01h30m', sourceId: 'isochrones-01h30m-source', layerId: 'isochrones-01h30m-line', url: '/data/isochrones/iso_diff_01h30m.geojson', color: '#0f4c5c' }
] as const;

export const landUsePalette: Array<{ key: string; color: string; label: string }> = [
	{ key: 'forest', color: '#1b5e20', label: 'Bosque' },
	{ key: 'park', color: '#4caf50', label: 'Parque' },
	{ key: 'residential', color: '#ef6c00', label: 'Residencial' },
	{ key: 'industrial', color: '#6d4c41', label: 'Industrial' },
	{ key: 'farmland', color: '#c0a060', label: 'Agrario' },
	{ key: 'cemetery', color: '#455a64', label: 'Cementerio' }
];

export const landUseFillColorExpression: any = [
	'match',
	['downcase', ['coalesce', ['to-string', ['get', 'fclass']], 'unknown']],
	'forest', '#1b5e20',
	'wood', '#2e7d32',
	'park', '#4caf50',
	'residential', '#ef6c00',
	'industrial', '#6d4c41',
	'commercial', '#8d6e63',
	'farmland', '#c0a060',
	'farm', '#b6904f',
	'cemetery', '#455a64',
	'#607d8b'
];

export const baseStyle: maplibregl.StyleSpecification = {
	version: 8,
	sources: {},
	layers: [{ id: 'background', type: 'background', paint: { 'background-color': '#ede4d4' } }]
};

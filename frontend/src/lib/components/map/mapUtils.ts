import type maplibregl from 'maplibre-gl';
import type { FeatureCollection, Point } from 'geojson';
import type { Municipio } from '$lib/types/municipio';

export const toFeatureCollection = (items: Municipio[]): FeatureCollection<Point> => ({
	type: 'FeatureCollection',
	features: items.map((m) => ({
		type: 'Feature',
		geometry: { type: 'Point', coordinates: [m.lon, m.lat] },
		properties: {
			id: m.id,
			nombre: m.nombre,
			provincia: m.provincia,
			precip_annual_mm: m.precip_annual_mm,
			travel_bucket: m.travel_bucket
		}
	}))
});

export const buildIdFilterExpression = (id: string | null) => {
	if (!id) return ['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], '__none__'];
	const numeric = Number.parseInt(id, 10);
	return [
		'any',
		['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], id],
		['==', ['to-number', ['coalesce', ['get', 'id'], ['get', 'codigo']]], numeric]
	];
};

export const setLayerVisibility = (map: maplibregl.Map | undefined, layerId: string, visible: boolean) => {
	if (!map || !map.getLayer(layerId)) return;
	map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
};

export const slugifyProvinceName = (value: string) =>
	value
		.normalize('NFD')
		.replace(/[\u0300-\u036f]/g, '')
		.replace(/\//g, '-')
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '_')
		.replace(/^_+|_+$/g, '');

import type maplibregl from 'maplibre-gl';
import type { Municipio } from '$lib/types/municipio';
import { normalizeProvinceName } from '$lib/state/provinces';

export type BoundsPack = {
	raw: [[number, number], [number, number]];
	padded: [[number, number], [number, number]];
};

export const getMunicipiosBounds = (source: Municipio[]): BoundsPack | null => {
	if (source.length === 0) return null;
	const points = source.filter((m) => Number.isFinite(m.lon) && Number.isFinite(m.lat));
	if (points.length === 0) return null;

	let minLon = Number.POSITIVE_INFINITY;
	let minLat = Number.POSITIVE_INFINITY;
	let maxLon = Number.NEGATIVE_INFINITY;
	let maxLat = Number.NEGATIVE_INFINITY;

	for (const point of points) {
		if (point.lon < minLon) minLon = point.lon;
		if (point.lon > maxLon) maxLon = point.lon;
		if (point.lat < minLat) minLat = point.lat;
		if (point.lat > maxLat) maxLat = point.lat;
	}

	if (!Number.isFinite(minLon + minLat + maxLon + maxLat)) return null;

	const lonSpan = Math.max(maxLon - minLon, 0.01);
	const latSpan = Math.max(maxLat - minLat, 0.01);
	const padLon = Math.max(lonSpan * 0.45, 0.55);
	const padLat = Math.max(latSpan * 0.45, 0.38);

	const raw: [[number, number], [number, number]] = [[minLon, minLat], [maxLon, maxLat]];
	const padded: [[number, number], [number, number]] = [
		[Math.max(-180, minLon - padLon), Math.max(-85, minLat - padLat)],
		[Math.min(180, maxLon + padLon), Math.min(85, maxLat + padLat)]
	];

	return { raw, padded };
};

export const centerToBounds = (
	map: maplibregl.Map,
	bounds: BoundsPack,
	zoom: number,
	duration = 0
) => {
	const centerLon = (bounds.raw[0][0] + bounds.raw[1][0]) / 2;
	const centerLat = (bounds.raw[0][1] + bounds.raw[1][1]) / 2;
	map.setCenter([centerLon, centerLat], { duration });
	map.setZoom(zoom);
};

export const getAutoFitZoom = (provinceFilter: string) =>
	normalizeProvinceName(provinceFilter) === 'Todas' ? 5.2 : 6.2;

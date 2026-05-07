import type maplibregl from 'maplibre-gl';

export const applyPolygonFilter = (
	map: maplibregl.Map,
	visibleMunicipioIds: string[],
	municipiosLength: number,
	fillLayerId: string,
	lineLayerId: string,
	onAfterApply?: () => void
) => {
	if (municipiosLength === 0) {
		if (map.getLayer(fillLayerId)) map.setFilter(fillLayerId, null);
		if (map.getLayer(lineLayerId)) map.setFilter(lineLayerId, null);
		onAfterApply?.();
		return;
	}

	if (visibleMunicipioIds.length === 0) {
		const noneExpr: any = ['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], '__none__'];
		if (map.getLayer(fillLayerId)) map.setFilter(fillLayerId, noneExpr);
		if (map.getLayer(lineLayerId)) map.setFilter(lineLayerId, noneExpr);
		return;
	}

	const targetIds = Array.from(new Set(visibleMunicipioIds));
	if (municipiosLength > 0 && targetIds.length >= municipiosLength) {
		if (map.getLayer(fillLayerId)) map.setFilter(fillLayerId, null);
		if (map.getLayer(lineLayerId)) map.setFilter(lineLayerId, null);
		onAfterApply?.();
		return;
	}

	const targetIdsNumeric = targetIds.map((id) => Number.parseInt(id, 10)).filter((n) => Number.isFinite(n));
	const expr: any = [
		'any',
		['in', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], ['literal', targetIds]],
		['in', ['to-number', ['coalesce', ['get', 'id'], ['get', 'codigo']]], ['literal', targetIdsNumeric]]
	];
	if (map.getLayer(fillLayerId)) map.setFilter(fillLayerId, expr);
	if (map.getLayer(lineLayerId)) map.setFilter(lineLayerId, expr);
	onAfterApply?.();
};

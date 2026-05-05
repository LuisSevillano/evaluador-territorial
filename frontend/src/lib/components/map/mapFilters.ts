import type maplibregl from 'maplibre-gl';
import { bucketOrder, type TravelBucketFilter } from '$lib/state/filters';
import { normalizeProvinceName } from '$lib/state/provinces';

type GridFilterParams = {
	map: maplibregl.Map;
	gridFillLayerId: string;
	gridLineLayerId: string;
	gridHoverLineLayerId: string;
	visibilityGridVisible: boolean;
	selectedMunicipio?: { id?: string; codigo?: string } | null;
	maxTravelBucket: TravelBucketFilter;
	provinceFilter: string;
};

const setGridFilters = (map: maplibregl.Map, expr: any, ids: { fill: string; line: string; hover: string }) => {
	if (map.getLayer(ids.fill)) map.setFilter(ids.fill, expr);
	if (map.getLayer(ids.line)) map.setFilter(ids.line, expr);
	if (map.getLayer(ids.hover)) map.setFilter(ids.hover, expr);
};

export const applyGridFilter = ({
	map,
	gridFillLayerId,
	gridLineLayerId,
	gridHoverLineLayerId,
	visibilityGridVisible,
	selectedMunicipio,
	maxTravelBucket,
	provinceFilter
}: GridFilterParams) => {
	const ids = { fill: gridFillLayerId, line: gridLineLayerId, hover: gridHoverLineLayerId };

	if (selectedMunicipio?.id?.startsWith('cell_')) {
		setGridFilters(map, null, ids);
		return;
	}

	const hasTravelFilter = maxTravelBucket !== null;
	const hasProvinceFilter = provinceFilter && provinceFilter !== 'Todas';
	const hasSelectedMunicipio = selectedMunicipio?.id || selectedMunicipio?.codigo;

	if (!visibilityGridVisible) {
		if (hasSelectedMunicipio) {
			const selectedId = selectedMunicipio?.id ?? selectedMunicipio?.codigo;
			if (!selectedId) {
				setGridFilters(map, null, ids);
				return;
			}
			const numeric = Number.parseInt(selectedId, 10);
			const expr: any = Number.isFinite(numeric)
				? [
						'any',
						['==', ['to-string', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], selectedId],
						['==', ['to-number', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], numeric]
					]
				: ['==', ['to-string', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], selectedId];
			setGridFilters(map, expr, ids);
		} else {
			setGridFilters(map, null, ids);
		}
		return;
	}

	const filterParts: any[] = [];

	if (hasTravelFilter) {
		const selectedRank = bucketOrder[maxTravelBucket as keyof typeof bucketOrder] ?? 6;
		filterParts.push([
			'in',
			['get', 'isochrone_bucket'],
			['literal', Object.entries(bucketOrder).filter(([, r]) => r <= selectedRank).map(([b]) => b)]
		]);
	}

	if (hasProvinceFilter) {
		const normalizedProvince = normalizeProvinceName(provinceFilter);
		filterParts.push(['==', ['get', 'provincia'], normalizedProvince]);
	}

	if (filterParts.length === 0) {
		setGridFilters(map, null, ids);
		return;
	}

	const finalExpr = filterParts.length === 1 ? filterParts[0] : ['all', ...filterParts];
	setGridFilters(map, finalExpr, ids);
};

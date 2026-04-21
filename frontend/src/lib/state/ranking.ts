import type { Municipio } from '$lib/types/municipio';
import type { TravelBucket } from '$lib/state/filters';
import type { WeightsNormalized } from '$lib/state/scoring';
import { scoreForMunicipio } from '$lib/state/scoring';

export type SortField =
	| 'nombre'
	| 'provincia'
	| 'travel_bucket'
	| 'precip_annual_mm'
	| 'temp_winter_mean_c'
	| 'temp_summer_mean_c'
	| 'mixed_score';

export type SortDirection = 'asc' | 'desc';

export const nextSortState = (
	currentField: SortField,
	currentDirection: SortDirection,
	nextField: SortField
): { sortBy: SortField; sortDirection: SortDirection } => {
	if (currentField === nextField) {
		return {
			sortBy: currentField,
			sortDirection: currentDirection === 'asc' ? 'desc' : 'asc'
		};
	}

	const direction: SortDirection =
		nextField === 'nombre' || nextField === 'provincia' || nextField === 'travel_bucket'
			? 'asc'
			: 'desc';

	return { sortBy: nextField, sortDirection: direction };
};

const bucketRank = (
	bucket: string,
	bucketOrder: Record<TravelBucket, number>
): number => bucketOrder[bucket as TravelBucket] ?? bucketOrder['>4h00'];

export const sortRows = (
	rows: Municipio[],
	sortBy: SortField,
	sortDirection: SortDirection,
	weights: WeightsNormalized,
	bucketOrder: Record<TravelBucket, number>
): Municipio[] => {
	return [...rows].sort((a, b) => {
		let cmp = 0;
		if (sortBy === 'travel_bucket') {
			cmp = bucketRank(a.travel_bucket, bucketOrder) - bucketRank(b.travel_bucket, bucketOrder);
		} else if (sortBy === 'nombre' || sortBy === 'provincia') {
			cmp = a[sortBy].localeCompare(b[sortBy], 'es');
		} else if (sortBy === 'mixed_score') {
			cmp = scoreForMunicipio(a, weights) - scoreForMunicipio(b, weights);
		} else {
			cmp = (a[sortBy] ?? 0) - (b[sortBy] ?? 0);
		}
		return sortDirection === 'asc' ? cmp : -cmp;
	});
};

export const sensitivityTop10Overlap = (currentRows: Municipio[], baselineTopIds: string[]): number => {
	const currentTop = currentRows.slice(0, 10).map((m) => m.id);
	return currentTop.filter((id) => baselineTopIds.includes(id)).length;
};

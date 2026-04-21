import type { SortDirection, SortField } from '$lib/state/ranking';

export const createRankingStore = () => {
	const state = $state({
		sortBy: 'mixed_score' as SortField,
		sortDirection: 'desc' as SortDirection
	});

	return { state };
};

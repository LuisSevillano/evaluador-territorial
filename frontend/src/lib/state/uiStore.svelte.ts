import type { MapColorMetric } from '$lib/components/map/coloring';
import type { MapViewMode } from '$lib/state/mapViewMode';

export type SheetTab = 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';

export const createUiStore = () => {
	const state = $state({
		isBottomSheetOpen: false,
		mapColorMetric: 'mixed_score' as MapColorMetric,
		activeSheetTab: 'filtr' as SheetTab,
		isMobileView: false,
		desktopPanel: 'rank' as 'rank' | 'shortlist',
		mapViewMode: 'auto' as MapViewMode
	});

	return { state };
};
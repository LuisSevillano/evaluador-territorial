import type { MapColorMetric } from '$lib/components/map/coloring';
import type { MapViewMode } from '$lib/state/mapViewMode';

export type ViewMode = 'exploracion' | 'evaluacion';
export type SheetTab = 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';

export const createUiStore = () => {
	const state = $state({
		isBottomSheetOpen: false,
		mapColorMetric: 'mixed_score' as MapColorMetric,
		viewMode: 'exploracion' as ViewMode,
		activeSheetTab: 'filtro' as SheetTab,
		isMobileView: false,
		desktopEvalPanel: 'top' as 'top' | 'shortlist',
		mapViewMode: 'auto' as MapViewMode
	});

	return { state };
};

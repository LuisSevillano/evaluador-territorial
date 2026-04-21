export type ViewMode = 'exploracion' | 'evaluacion';
export type SheetTab = 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';
export type MapColorMetric = 'precip_annual_mm' | 'mixed_score';

export const createUiStore = () => {
	const state = $state({
		isBottomSheetOpen: false,
		mapColorMetric: 'mixed_score' as MapColorMetric,
		viewMode: 'exploracion' as ViewMode,
		activeSheetTab: 'filtr' as SheetTab,
		isMobileView: false,
		desktopEvalPanel: 'top' as 'top' | 'shortlist'
	});

	return { state };
};

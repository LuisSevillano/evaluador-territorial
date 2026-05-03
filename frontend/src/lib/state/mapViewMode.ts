export type MapViewMode = 'auto' | 'municipality' | 'grid';

export const GRID_MIN_ZOOM = 10.8;

export type MapViewState = {
	mode: MapViewMode;
	selectedMunicipioId: string | null;
	currentZoom: number;
};

export const getEffectiveVisibility = (state: MapViewState) => {
	const gridVisible =
		state.mode === 'grid' ||
		(state.mode === 'auto' && (state.selectedMunicipioId !== null || state.currentZoom >= GRID_MIN_ZOOM));

	const municipalityFillVisible =
		state.mode === 'municipality' ||
		(state.mode === 'auto' && !gridVisible);

	return {
		gridVisible,
		municipalityFillVisible,
		municipalityLineVisible: true,
		showBoundaries: true
	};
};

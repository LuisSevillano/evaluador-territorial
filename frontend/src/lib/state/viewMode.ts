import type { SheetTab, ViewMode } from '$lib/state/urlState';

export const modeCopy: Record<ViewMode, { tagline: string; helper: string }> = {
	exploracion: {
		tagline: 'Exploracion: filtros y capas',
		helper: 'Ajusta filtros territoriales y explora el mapa.'
	},
	evaluacion: {
		tagline: 'Evaluacion: score y ranking',
		helper: 'Ajusta score, pesos y ranking para comparar municipios.'
	}
};

export const tabForMode = (
	mode: ViewMode,
	tab: SheetTab,
	isMobile: boolean,
	hasSelection: boolean
): SheetTab => {
	if (mode === 'exploracion' && tab === 'rank') return 'filtr';
	if (mode === 'evaluacion' && isMobile && !hasSelection && tab === 'filtr') return 'rank';
	return tab;
};

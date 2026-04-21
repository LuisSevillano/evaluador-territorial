import type { SheetTab, ViewMode } from '$lib/state/urlState';

export const modeCopy: Record<ViewMode, { tagline: string; helper: string }> = {
	exploracion: {
		tagline: 'Exploración: filtros y capas',
		helper: 'Ajusta filtros territoriales y explora el mapa.'
	},
	evaluacion: {
		tagline: 'Evaluación: score y ranking',
		helper: 'Ajusta score, pesos y ranking para comparar municipios.'
	}
};

export const tabForMode = (
	mode: ViewMode,
	tab: SheetTab,
	_isMobile: boolean,
	_hasSelection: boolean
): SheetTab => {
	if (mode === 'exploracion' && tab === 'rank') return 'filtr';
	return tab;
};

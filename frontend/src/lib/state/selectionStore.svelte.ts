import type { Municipio } from '$lib/types/municipio';

export const createSelectionStore = () => {
	const state = $state({
		selectedMunicipio: null as Municipio | null,
		pendingSelectedMunicipioId: null as string | null,
		shortlistedIds: [] as string[]
	});

	const clearSelection = () => {
		state.selectedMunicipio = null;
		state.pendingSelectedMunicipioId = null;
	};

	const toggleShortlist = (municipioId: string) => {
		const exists = state.shortlistedIds.includes(municipioId);
		state.shortlistedIds = exists
			? state.shortlistedIds.filter((id) => id !== municipioId)
			: [...state.shortlistedIds, municipioId];
		return !exists;
	};

	return {
		state,
		clearSelection,
		toggleShortlist
	};
};

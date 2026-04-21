export const layerLabels: Record<string, string> = {
	municipios: 'Municipios',
	landuse: 'Usos del suelo',
	vegetation: 'Cobertura vegetal',
	forest: 'Masa forestal',
	reservoirs: 'Embalses IGN',
	rivers: 'Rios IGN'
};

export type LayerVisibilityState = {
	showMunicipioPolygons: boolean;
	showLandUseLayer: boolean;
	showVegetationLayer: boolean;
	showForestLayer: boolean;
	showIgnReservoirs: boolean;
	showIgnRivers: boolean;
};

export const isLayerVisible = (layerKey: string, state: LayerVisibilityState): boolean => {
	if (layerKey === 'municipios') return state.showMunicipioPolygons;
	if (layerKey === 'landuse') return state.showLandUseLayer;
	if (layerKey === 'vegetation') return state.showVegetationLayer;
	if (layerKey === 'forest') return state.showForestLayer;
	if (layerKey === 'reservoirs') return state.showIgnReservoirs;
	if (layerKey === 'rivers') return state.showIgnRivers;
	return false;
};

export const createLayersStore = () => {
	const state = $state({
		showMunicipioPolygons: true,
		showMunicipioPoints: false,
		showIgnWmsBase: true,
		showIgnSatellite: false,
		showIgnRivers: false,
		showIgnReservoirs: false,
		showForestLayer: false,
		showLandUseLayer: false,
		showVegetationLayer: false,
		layerOrder: ['municipios', 'landuse', 'reservoirs', 'rivers'] as string[]
	});

	return { state };
};

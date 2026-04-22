export const createLayersStore = () => {
	const state = $state({
		showMunicipioPolygons: true,
		showIsochronesLayer: false,
		showMunicipioPoints: false,
		showIgnWmsBase: true,
		showIgnSatellite: false,
		showIgnRivers: false,
		showIgnReservoirs: false,
		showForestLayer: false,
		showLandUseLayer: false,
		showVegetationLayer: false,
		layerOrder: ['municipios', 'isochrones', 'landuse', 'reservoirs', 'rivers'] as string[]
	});

	return { state };
};

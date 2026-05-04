import { DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';
import type { TravelBucketFilter } from '$lib/state/filters';

export const createFiltersStore = () => {
	const state = $state({
		query: '',
		provinceFilter: 'Todas',
		maxTravelBucket: null as TravelBucketFilter,
		minPrecipAnnual: 0,
		minWinterTemp: -10,
		maxSummerTemp: 40,
		maxThermalAmplitude: 21,
		minCompositeScore: 0,
		climateWeight: DEFAULT_WEIGHTS_RAW.climateWeight,
		accessWeight: DEFAULT_WEIGHTS_RAW.accessWeight,
		natureWeight: DEFAULT_WEIGHTS_RAW.natureWeight
	});

	const clear = () => {
		state.provinceFilter = 'Todas';
		state.maxTravelBucket = null;
		state.minPrecipAnnual = 0;
		state.minWinterTemp = -10;
		state.maxSummerTemp = 40;
		state.maxThermalAmplitude = 21;
		state.minCompositeScore = 0;
	};

	return { state, clear };
};

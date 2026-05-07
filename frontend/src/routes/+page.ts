import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';

export const load = async ({ fetch }: { fetch: typeof globalThis.fetch }) => {
	return {
		municipios: [] as Municipio[],
		climateMonthly: [] as MunicipioClimateMonthly[],
		datasetMetadata: null as DatasetMetadata | null
	};
};

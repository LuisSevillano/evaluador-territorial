import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';

export const load = async ({ fetch }: { fetch: typeof globalThis.fetch }) => {
	const primaryResponse = await fetch('/data/municipios_v2.json');
	const fallbackResponse = await fetch('/data/municipios.sample.json');
	const response = primaryResponse.ok ? primaryResponse : fallbackResponse;
	const municipios = (await response.json()) as Municipio[];

	const monthlyResponse = await fetch('/data/municipios_climate_monthly.json');
	const climateMonthly = monthlyResponse.ok
		? ((await monthlyResponse.json()) as MunicipioClimateMonthly[])
		: [];

	const metadataResponse = await fetch('/data/dataset_metadata_v3.json');
	const datasetMetadata = metadataResponse.ok
		? ((await metadataResponse.json()) as DatasetMetadata)
		: null;

	return {
		municipios,
		climateMonthly,
		datasetMetadata
	};
};

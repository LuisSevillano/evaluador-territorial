import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
import { loadMunicipiosDataset } from '$lib/utils/municipiosDataset';

export const load = async ({ fetch }: { fetch: typeof globalThis.fetch }) => {
	const [municipios, climateMonthlyResp, metadataResp] = await Promise.all([
		loadMunicipiosDataset(fetch),
		fetch('/data/municipios_climate_monthly.json'),
		fetch('/data/dataset_metadata_v3.json')
	]);

	const [climateMonthly, datasetMetadata] = await Promise.all([
		climateMonthlyResp.ok
			? (climateMonthlyResp.json() as Promise<MunicipioClimateMonthly[]>)
			: Promise.resolve([] as MunicipioClimateMonthly[]),
		metadataResp.ok
			? (metadataResp.json() as Promise<DatasetMetadata>)
			: Promise.resolve(null as DatasetMetadata | null)
	]);

	return {
		municipios: municipios as Municipio[],
		climateMonthly,
		datasetMetadata
	};
};

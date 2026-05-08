import type { Municipio } from '$lib/types/municipio';

type CompactPayload = {
	version: number;
	fields: string[];
	rows: unknown[][];
};

type DictionaryPayload = {
	version: number;
	codeToKey: Record<string, string>;
};

const decodeCompactMunicipios = (
	compact: CompactPayload,
	dictionary: DictionaryPayload
): Municipio[] => {
	const resolvedFields = compact.fields.map((code) => dictionary.codeToKey[code] ?? code);
	return compact.rows.map((values) => {
		const municipio: Record<string, unknown> = {};
		for (let index = 0; index < resolvedFields.length; index += 1) {
			municipio[resolvedFields[index]] = values[index];
		}
		return municipio as Municipio;
	});
};

export const loadMunicipiosDataset = async (fetchFn: typeof fetch): Promise<Municipio[]> => {
	try {
		const [compactResp, dictionaryResp] = await Promise.all([
			fetchFn('/data/municipios_v2.compact.json'),
			fetchFn('/data/municipios_v2.dictionary.json')
		]);

		if (compactResp.ok && dictionaryResp.ok) {
			const [compact, dictionary] = await Promise.all([
				compactResp.json() as Promise<CompactPayload>,
				dictionaryResp.json() as Promise<DictionaryPayload>
			]);
			return decodeCompactMunicipios(compact, dictionary);
		}
	} catch (_error) {
		// fallback below
	}

	const fallbackResp = await fetchFn('/data/municipios_v2.json');
	if (fallbackResp.ok) return (await fallbackResp.json()) as Municipio[];

	const sampleResp = await fetchFn('/data/municipios.sample.json');
	if (sampleResp.ok) return (await sampleResp.json()) as Municipio[];

	return [];
};

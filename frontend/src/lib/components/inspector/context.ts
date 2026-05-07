import type { Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';

export type ScoreWeights = { climate: number; access: number; nature: number };

export type BlockKey = 'clima' | 'accesibilidad' | 'naturaleza';

export type BlockBreakdown = {
	key: BlockKey;
	label: string;
	raw: number;
	avgRaw: number;
	weight: number;
	contribution: number;
	delta: number;
};

export type DriverEvidence = {
	key: BlockKey;
	effect: 'beneficia' | 'penaliza';
	impact: number;
	summary: string;
};

export type MunicipioContext = {
	rank: number;
	total: number;
	percentile: number;
	selectedScore: number;
	provinceAvg: number;
	bucketAvg: number;
	globalAvg: number;
	topDriver: BlockBreakdown;
	mainPenalty: BlockBreakdown;
	blockBreakdown: BlockBreakdown[];
	positiveDrivers: DriverEvidence[];
	negativeDrivers: DriverEvidence[];
	tempAmplitude: number | null;
	wettest: MunicipioClimateMonthly | null;
	driest: MunicipioClimateMonthly | null;
};

const mean = (values: number[]) => {
	if (values.length === 0) return 0;
	return values.reduce((acc, value) => acc + value, 0) / values.length;
};

const median = (values: number[]) => {
	if (values.length === 0) return 0;
	const sorted = [...values].sort((a, b) => a - b);
	const middle = Math.floor(sorted.length / 2);
	if (sorted.length % 2 === 0) return (sorted[middle - 1] + sorted[middle]) / 2;
	return sorted[middle];
};

const scoreBlocks = (municipio: Municipio) => ({
	clima: municipio.climate_block_score ?? municipio.precip_norm ?? 0.5,
	accesibilidad: municipio.access_block_score ?? municipio.accesibilidad_norm ?? 0.5,
	naturaleza: municipio.nature_block_score ?? municipio.naturality_norm ?? 0.5
});

const scoreFor = (municipio: Municipio, weights: ScoreWeights) => {
	const blocks = scoreBlocks(municipio);
	return (
		weights.climate * blocks.clima +
		weights.access * blocks.accesibilidad +
		weights.nature * blocks.naturaleza
	);
};

const bucketLabel = (bucket: string) => {
	if (bucket === '<=1h30' || bucket === '<=2h00') return 'alta';
	if (bucket === '<=2h30' || bucket === '<=3h30') return 'media';
	return 'baja';
};

export const buildMunicipioContext = ({
	selectedMunicipio,
	municipios,
	climateSeries,
	weights
}: {
	selectedMunicipio: Municipio | null;
	municipios: Municipio[];
	climateSeries: MunicipioClimateMonthly[];
	weights: ScoreWeights;
}): MunicipioContext | null => {
	if (!selectedMunicipio || municipios.length === 0) return null;

	const ranked = [...municipios].sort((a, b) => scoreFor(b, weights) - scoreFor(a, weights));
	const rank = ranked.findIndex((m) => m.id === selectedMunicipio.id) + 1;
	const total = ranked.length;
	const percentile = Math.max(0, Math.min(100, ((total - rank) / Math.max(1, total - 1)) * 100));

	const sameProvince = municipios.filter((m) => m.provincia === selectedMunicipio.provincia);
	const sameBucket = municipios.filter((m) => m.travel_bucket === selectedMunicipio.travel_bucket);

	const selectedScore = scoreFor(selectedMunicipio, weights);
	const provinceAvg = mean(sameProvince.map((m) => scoreFor(m, weights)));
	const bucketAvg = mean(sameBucket.map((m) => scoreFor(m, weights)));
	const globalAvg = mean(municipios.map((m) => scoreFor(m, weights)));

	const selectedBlocks = scoreBlocks(selectedMunicipio);
	const avgBlocks = {
		clima: median(municipios.map((m) => scoreBlocks(m).clima)),
		accesibilidad: median(municipios.map((m) => scoreBlocks(m).accesibilidad)),
		naturaleza: median(municipios.map((m) => scoreBlocks(m).naturaleza))
	};

	const breakdown: BlockBreakdown[] = [
		{
			key: 'clima',
			label: 'Lluvia',
			raw: selectedBlocks.clima,
			avgRaw: avgBlocks.clima,
			weight: weights.climate,
			contribution: weights.climate * selectedBlocks.clima,
			delta: weights.climate * (selectedBlocks.clima - avgBlocks.clima)
		},
		{
			key: 'accesibilidad',
			label: 'Acceso',
			raw: selectedBlocks.accesibilidad,
			avgRaw: avgBlocks.accesibilidad,
			weight: weights.access,
			contribution: weights.access * selectedBlocks.accesibilidad,
			delta: weights.access * (selectedBlocks.accesibilidad - avgBlocks.accesibilidad)
		},
		{
			key: 'naturaleza',
			label: 'Naturaleza',
			raw: selectedBlocks.naturaleza,
			avgRaw: avgBlocks.naturaleza,
			weight: weights.nature,
			contribution: weights.nature * selectedBlocks.naturaleza,
			delta: weights.nature * (selectedBlocks.naturaleza - avgBlocks.naturaleza)
		}
	];

	const blockDetails: Record<BlockKey, string> = {
		clima:
			selectedBlocks.clima >= avgBlocks.clima
				? `Bloque climático por encima de la mediana del conjunto (${selectedMunicipio.precip_annual_mm.toFixed(0)} mm anuales).`
				: `Bloque climático por debajo de la mediana del conjunto (${selectedMunicipio.precip_annual_mm.toFixed(0)} mm anuales).`,
		accesibilidad:
			selectedMunicipio.travel_bucket === '>4h00'
				? `Desplazamiento largo (${selectedMunicipio.travel_bucket}), con encaje bajo en accesibilidad.`
				: selectedMunicipio.travel_bucket === '<=1h30' || selectedMunicipio.travel_bucket === '<=2h00'
					? `Desplazamiento corto (${selectedMunicipio.travel_bucket}), buen encaje de acceso.`
					: `Accesibilidad intermedia (${selectedMunicipio.travel_bucket}).`,
		naturaleza: `Entorno natural ${selectedBlocks.naturaleza >= avgBlocks.naturaleza ? 'por encima de la mediana' : 'por debajo de la mediana'} de los municipios analizados.`
	};

	const driverCandidates: DriverEvidence[] = breakdown.map((item) => ({
		key: item.key,
		effect: item.delta >= 0 ? 'beneficia' : 'penaliza',
		impact: item.delta,
		summary: blockDetails[item.key]
	}));

	const positiveDrivers = driverCandidates
		.filter((item) => item.impact > 0)
		.sort((a, b) => b.impact - a.impact);
	const negativeDrivers = driverCandidates
		.filter((item) => item.impact < 0)
		.sort((a, b) => a.impact - b.impact);

	const sortedByImpact = [...breakdown].sort((a, b) => b.delta - a.delta);
	const topDriver = sortedByImpact[0] ?? breakdown[0];
	const mainPenalty = sortedByImpact[sortedByImpact.length - 1] ?? breakdown[breakdown.length - 1];

	const monthly = climateSeries.filter((r) => Number.isFinite(r.month));
	const precipSorted = [...monthly].sort((a, b) => b.precip_mm - a.precip_mm);
	const tempSorted = [...monthly].sort((a, b) => a.temp_mean_c - b.temp_mean_c);
	const tempAmplitude =
		tempSorted.length > 1
			? tempSorted[tempSorted.length - 1].temp_mean_c - tempSorted[0].temp_mean_c
			: null;

	return {
		rank,
		total,
		percentile,
		selectedScore,
		provinceAvg,
		bucketAvg,
		globalAvg,
		topDriver,
		mainPenalty,
		blockBreakdown: breakdown,
		positiveDrivers,
		negativeDrivers,
		tempAmplitude,
		wettest: precipSorted[0] ?? null,
		driest: precipSorted[precipSorted.length - 1] ?? null
	};
};

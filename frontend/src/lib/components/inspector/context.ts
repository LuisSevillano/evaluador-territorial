import type { Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';

export type ScoreWeights = { climate: number; access: number; nature: number };

export type BlockKey = 'clima' | 'accesibilidad' | 'naturaleza';

export type BlockBreakdown = {
	key: BlockKey;
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
		clima: mean(municipios.map((m) => scoreBlocks(m).clima)),
		accesibilidad: mean(municipios.map((m) => scoreBlocks(m).accesibilidad)),
		naturaleza: mean(municipios.map((m) => scoreBlocks(m).naturaleza))
	};

	const breakdown: BlockBreakdown[] = [
		{
			key: 'clima',
			raw: selectedBlocks.clima,
			avgRaw: avgBlocks.clima,
			weight: weights.climate,
			contribution: weights.climate * selectedBlocks.clima,
			delta: weights.climate * (selectedBlocks.clima - avgBlocks.clima)
		},
		{
			key: 'accesibilidad',
			raw: selectedBlocks.accesibilidad,
			avgRaw: avgBlocks.accesibilidad,
			weight: weights.access,
			contribution: weights.access * selectedBlocks.accesibilidad,
			delta: weights.access * (selectedBlocks.accesibilidad - avgBlocks.accesibilidad)
		},
		{
			key: 'naturaleza',
			raw: selectedBlocks.naturaleza,
			avgRaw: avgBlocks.naturaleza,
			weight: weights.nature,
			contribution: weights.nature * selectedBlocks.naturaleza,
			delta: weights.nature * (selectedBlocks.naturaleza - avgBlocks.naturaleza)
		}
	];

	const averagePrecip = mean(municipios.map((m) => m.precip_annual_mm));
	const averageForest = mean(municipios.map((m) => m.forest_pct ?? 0));
	const averageWater = mean(municipios.map((m) => m.water_pct ?? 0));

	const blockDetails: Record<BlockKey, string> = {
		clima:
			selectedMunicipio.precip_annual_mm >= averagePrecip
				? `PPT anual ${selectedMunicipio.precip_annual_mm.toFixed(0)} mm (media ${averagePrecip.toFixed(0)} mm).`
				: `PPT anual ${selectedMunicipio.precip_annual_mm.toFixed(0)} mm por debajo de media (${averagePrecip.toFixed(0)} mm).`,
		accesibilidad:
			selectedMunicipio.travel_bucket === '>4h00'
				? `Distancia alta: ${selectedMunicipio.travel_bucket}, lo que penaliza accesibilidad.`
				: selectedMunicipio.travel_bucket === '<=1h30' || selectedMunicipio.travel_bucket === '<=2h00'
					? `Distancia corta: ${selectedMunicipio.travel_bucket}, lo que beneficia accesibilidad.`
					: `Accesibilidad ${bucketLabel(selectedMunicipio.travel_bucket)} (${selectedMunicipio.travel_bucket}).`,
		naturaleza: `Forestal ${Number(selectedMunicipio.forest_pct ?? 0).toFixed(1)}% (media ${averageForest.toFixed(1)}%) · Agua ${Number(selectedMunicipio.water_pct ?? 0).toFixed(1)}% (media ${averageWater.toFixed(1)}%).`
	};

	const driverCandidates: DriverEvidence[] = breakdown.map((item) => ({
		key: item.key,
		effect: item.delta >= 0 ? 'beneficia' : 'penaliza',
		impact: item.delta,
		summary: `${blockDetails[item.key]} Bloque ${item.raw.toFixed(3)} vs media ${item.avgRaw.toFixed(3)} (impacto ${item.delta >= 0 ? '+' : ''}${item.delta.toFixed(3)}).`
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

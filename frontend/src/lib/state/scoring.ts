import type { Municipio } from '$lib/types/municipio';

export type Preset = 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto';

export type WeightsRaw = {
	climateWeight: number;
	accessWeight: number;
	natureWeight: number;
};

export type WeightsNormalized = {
	climate: number;
	access: number;
	nature: number;
};

export const DEFAULT_WEIGHTS_RAW: WeightsRaw = {
	climateWeight: 40,
	accessWeight: 30,
	natureWeight: 30
};

export const DEFAULT_WEIGHTS_NORMALIZED: WeightsNormalized = {
	climate: 0.4,
	access: 0.3,
	nature: 0.3
};

export const BASELINE_WEIGHTS: WeightsNormalized = DEFAULT_WEIGHTS_NORMALIZED;

export const normalizeWeights = (raw: WeightsRaw): WeightsNormalized => {
	const total = raw.climateWeight + raw.accessWeight + raw.natureWeight;
	if (!total) return DEFAULT_WEIGHTS_NORMALIZED;
	return {
		climate: raw.climateWeight / total,
		access: raw.accessWeight / total,
		nature: raw.natureWeight / total
	};
};

const summerHeatPenaltyFactor = (tempSummerMeanC?: number): number => {
	if (!Number.isFinite(tempSummerMeanC)) return 1;
	const summer = tempSummerMeanC as number;
	const threshold = 22.5;
	const hardHeat = 24.2;
	const maxPenalty = 0.15;
	if (summer <= threshold) return 1;
	const ratio = Math.min(1, (summer - threshold) / (hardHeat - threshold));
	return 1 - ratio * maxPenalty;
};

export const scoreForMunicipio = (m: Municipio, weights: WeightsNormalized): number => {
	const climate = m.climate_block_score ?? m.precip_norm ?? 0.5;
	const access = m.access_block_score ?? m.accesibilidad_norm ?? 0.5;
	const nature = m.nature_block_score ?? m.naturality_norm ?? 0.5;
	const baseScore = weights.climate * climate + weights.access * access + weights.nature * nature;
	return baseScore * summerHeatPenaltyFactor(m.temp_summer_mean_c);
};

export const activePresetFromWeights = (raw: WeightsRaw): Preset | null => {
	if (
		raw.climateWeight === DEFAULT_WEIGHTS_RAW.climateWeight &&
		raw.accessWeight === DEFAULT_WEIGHTS_RAW.accessWeight &&
		raw.natureWeight === DEFAULT_WEIGHTS_RAW.natureWeight
	)
		return 'equilibrado';
	if (raw.climateWeight === 25 && raw.accessWeight === 20 && raw.natureWeight === 55)
		return 'naturaleza';
	if (raw.climateWeight === 25 && raw.accessWeight === 55 && raw.natureWeight === 20)
		return 'accesibilidad';
	if (raw.climateWeight === 55 && raw.accessWeight === 20 && raw.natureWeight === 25)
		return 'clima';
	if (raw.climateWeight === 70 && raw.accessWeight === 15 && raw.natureWeight === 15)
		return 'clima_estricto';
	return null;
};

export const weightsForPreset = (preset: Preset): WeightsRaw => {
	if (preset === 'equilibrado') return DEFAULT_WEIGHTS_RAW;
	if (preset === 'naturaleza') return { climateWeight: 25, accessWeight: 20, natureWeight: 55 };
	if (preset === 'accesibilidad') return { climateWeight: 25, accessWeight: 55, natureWeight: 20 };
	if (preset === 'clima_estricto') return { climateWeight: 70, accessWeight: 15, natureWeight: 15 };
	return { climateWeight: 55, accessWeight: 20, natureWeight: 25 };
};

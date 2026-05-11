export type MetricTone = 'good' | 'mid' | 'bad';

const fastAccessBuckets = new Set(['<=1h30', '<=2h00']);
const mediumAccessBuckets = new Set(['<=2h30', '<=3h30']);

export const accessToneFromBucket = (bucket: string): MetricTone => {
	if (fastAccessBuckets.has(bucket)) return 'good';
	if (mediumAccessBuckets.has(bucket)) return 'mid';
	return 'bad';
};

export const climateToneFromPrecip = (precipAnnualMm: number): MetricTone => {
	if (!Number.isFinite(precipAnnualMm)) return 'mid';
	if (precipAnnualMm >= 900) return 'good';
	if (precipAnnualMm >= 600) return 'mid';
	return 'bad';
};

export const climateToneFromBlockScore = (climateBlockScore?: number, precipNorm?: number): MetricTone => {
	const climateScore = climateBlockScore ?? precipNorm;
	if (typeof climateScore !== 'number' || !Number.isFinite(climateScore)) return 'mid';
	if (climateScore >= 0.66) return 'good';
	if (climateScore >= 0.4) return 'mid';
	return 'bad';
};

export const climateToneFromMoistureScore = (moistureScore?: number): MetricTone => {
	if (typeof moistureScore !== 'number' || !Number.isFinite(moistureScore)) return 'mid';
	if (moistureScore >= 0.72) return 'good';
	if (moistureScore >= 0.45) return 'mid';
	return 'bad';
};

export const renfeMadridToneFromScore = (score?: number): MetricTone => {
	if (typeof score !== 'number' || !Number.isFinite(score)) return 'bad';
	if (score >= 0.66) return 'good';
	if (score >= 0.42) return 'mid';
	return 'bad';
};

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

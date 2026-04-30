export type ScoreBand = 'very-low' | 'low' | 'mid' | 'high' | 'very-high';

const defaultThresholds = [0.319, 0.354, 0.3885, 0.4283] as const;

export const normalizeScoreThresholds = (thresholds?: number[]) => {
	if (!thresholds || thresholds.length !== 4) return [...defaultThresholds];
	const finite = thresholds.every((t) => Number.isFinite(t));
	if (!finite) return [...defaultThresholds];
	return [...thresholds].sort((a, b) => a - b);
};

export const classifyMixedScore = (score: number, thresholds?: number[]): ScoreBand => {
	const t = normalizeScoreThresholds(thresholds);
	if (score <= t[0]) return 'very-low';
	if (score <= t[1]) return 'low';
	if (score <= t[2]) return 'mid';
	if (score <= t[3]) return 'high';
	return 'very-high';
};

export const labelForScoreBand = (band: ScoreBand) => {
	if (band === 'very-low') return 'Muy bajo';
	if (band === 'low') return 'Bajo';
	if (band === 'mid') return 'Intermedio';
	if (band === 'high') return 'Alto';
	return 'Muy alto';
};

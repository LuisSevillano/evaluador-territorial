import type { Municipio } from '$lib/types/municipio';

export type MapColorMetric = 'mixed_score' | 'precip_annual_mm';

export const scoreThresholds = [0.24, 0.3, 0.36, 0.42] as const;
export const scoreColors = ['#8c1d18', '#d94841', '#f59f00', '#66c24a', '#15803d'] as const;

export const precipThresholds = [500, 700, 900, 1100] as const;
export const precipColors = ['#f3d7ac', '#d8c5a4', '#a8c1be', '#7cbac0', '#265d7f'] as const;
export const missingDataColor = '#9ca3af';

const resolveBucketColor = (value: number, thresholds: readonly number[], colors: readonly string[]) => {
	if (value <= thresholds[0]) return colors[0];
	if (value <= thresholds[1]) return colors[1];
	if (value <= thresholds[2]) return colors[2];
	if (value <= thresholds[3]) return colors[3];
	return colors[4];
};

export const buildMunicipioColorExpression = (municipios: Municipio[], mapColorMetric: MapColorMetric) => {
	const keyAccessor: any = ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]];
	const expression: any[] = ['match', keyAccessor];

	for (const municipio of municipios) {
		const hasOfficialName = typeof municipio.nombre === 'string' && municipio.nombre.trim().length > 0;
		const hasScoreInputs =
			Number.isFinite(municipio.climate_block_score) &&
			Number.isFinite(municipio.access_block_score) &&
			Number.isFinite(municipio.nature_block_score) &&
			Number.isFinite(municipio.mixed_score);
		const hasPrecipData = Number.isFinite(municipio.precip_annual_mm);
		const hasMetricData = mapColorMetric === 'mixed_score' ? hasScoreInputs : hasPrecipData;
		const isMissingData = !hasOfficialName || !hasMetricData;

		const value =
			mapColorMetric === 'mixed_score'
				? (municipio.mixed_score ?? 0)
				: (municipio.precip_annual_mm ?? 0);
		const color = isMissingData
			? missingDataColor
			: mapColorMetric === 'mixed_score'
				? resolveBucketColor(value as number, scoreThresholds, scoreColors)
				: resolveBucketColor(value as number, precipThresholds, precipColors);

		expression.push(municipio.id, color);
		const strippedId = String(Number.parseInt(municipio.id, 10));
		if (strippedId && strippedId !== municipio.id) expression.push(strippedId, color);
	}

	expression.push(missingDataColor);
	return expression;
};

export const getLegendConfig = (mapColorMetric: MapColorMetric) =>
	mapColorMetric === 'mixed_score'
		? {
				title: 'Puntuacion territorial',
				thresholds: [...scoreThresholds],
				colors: [...scoreColors],
				formatLabel: (value: number) => value.toFixed(2),
				labels: ['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta']
		  }
		: {
					title: 'Gradiente de precipitacion',
				thresholds: [...precipThresholds],
				colors: [...precipColors],
				formatLabel: (value: number) => `${Math.round(value)}`,
				labels: ['Seco', 'Semiseco', 'Intermedio', 'Humedo', 'Muy humedo']
			  };

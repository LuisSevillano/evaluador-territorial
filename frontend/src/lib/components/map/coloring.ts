import type { Municipio } from '$lib/types/municipio';
import { formatScorePercent } from '$lib/utils/numberFormat';

export type MapColorMetric =
	| 'mixed_score'
	| 'precip_moisture_score'
	| 'precip_annual_mm'
	| 'transporte_norm'
	| 'servicio_renfe_norm'
	| 'river_access_score'
	| 'travel_bucket';

export type LegendConfig = {
	title: string;
	thresholds: readonly number[];
	colors: readonly string[];
	formatLabel: (value: number) => string;
	labels?: readonly string[];
};

export const scoreThresholds = [0.319, 0.354, 0.3885, 0.4283] as const;
export const scoreColors = ['#8c1d18', '#d94841', '#f59f00', '#66c24a', '#15803d'] as const;

export const precipThresholds = [410, 483, 606, 952] as const;
export const precipColors = ['#f3d7ac', '#d8c5a4', '#a8c1be', '#7cbac0', '#265d7f'] as const;
export const moistureThresholds = [0.35, 0.45, 0.72, 0.86] as const;
export const moistureColors = ['#c56a42', '#d8a15f', '#b8c9b4', '#6aa9b8', '#245f7a'] as const;

export const transporteThresholds = [0.2, 0.4, 0.6, 0.8] as const;
export const transporteColors = ['#15803d', '#66c24a', '#f59f00', '#d94841', '#8c1d18'] as const;

export const renfeServiceThresholds = [0.2, 0.4, 0.6, 0.8] as const;
export const renfeServiceColors = ['#15803d', '#66c24a', '#f59f00', '#d94841', '#8c1d18'] as const;
export const riverAccessThresholds = [20, 40, 60, 80] as const;
export const riverAccessColors = ['#8c1d18', '#d94841', '#f59f00', '#66c24a', '#15803d'] as const;

export const travelBucketOrder = ['<=1h30', '<=2h00', '<=2h30', '<=3h30', '<=4h00', '>4h00'] as const;
export const travelBucketColors = ['#0f4c5c', '#1f8a70', '#4d7c0f', '#d97706', '#7b1f1f', '#5f5f5f'] as const;

export const missingDataColor = '#9ca3af';

const quantile = (sortedValues: number[], q: number) => {
	if (sortedValues.length === 0) return NaN;
	if (sortedValues.length === 1) return sortedValues[0];
	const pos = (sortedValues.length - 1) * q;
	const base = Math.floor(pos);
	const rest = pos - base;
	const next = sortedValues[Math.min(base + 1, sortedValues.length - 1)];
	return sortedValues[base] + rest * (next - sortedValues[base]);
};

const deriveScoreThresholds = (municipios: Municipio[]) => {
	const values = municipios
		.map((m) => m.mixed_score)
		.filter((value): value is number => Number.isFinite(value))
		.sort((a, b) => a - b);

	if (values.length < 20) return [...scoreThresholds];
	const first = values[0];
	const last = values[values.length - 1];
	if (first === last) return [...scoreThresholds];

	const dynamic = [0.2, 0.4, 0.6, 0.8]
		.map((q) => quantile(values, q))
		.filter((v) => Number.isFinite(v));

	if (dynamic.length !== 4) return [...scoreThresholds];
	return dynamic;
};

export const getScoreThresholdsForMunicipios = (municipios: Municipio[]) =>
	deriveScoreThresholds(municipios);

const resolveBucketColor = (value: number, thresholds: readonly number[], colors: readonly string[]) => {
	if (value <= thresholds[0]) return colors[0];
	if (value <= thresholds[1]) return colors[1];
	if (value <= thresholds[2]) return colors[2];
	if (value <= thresholds[3]) return colors[3];
	return colors[4];
};

export const buildMunicipioColorExpression = (municipios: Municipio[], mapColorMetric: MapColorMetric) => {
	if (municipios.length === 0) return missingDataColor;

	const keyAccessor: any = ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]];
	const expression: any[] = ['match', keyAccessor];
	const activeScoreThresholds =
		mapColorMetric === 'mixed_score' ? deriveScoreThresholds(municipios) : [...scoreThresholds];

	for (const municipio of municipios) {
		const hasOfficialName = typeof municipio.nombre === 'string' && municipio.nombre.trim().length > 0;
		
		let hasMetricData = false;
		let value = 0;
		
		if (mapColorMetric === 'mixed_score') {
			hasMetricData =
				Number.isFinite(municipio.climate_block_score) &&
				Number.isFinite(municipio.access_block_score) &&
				Number.isFinite(municipio.nature_block_score) &&
				Number.isFinite(municipio.mixed_score);
			value = municipio.mixed_score ?? 0;
		} else if (mapColorMetric === 'precip_moisture_score') {
			hasMetricData = Number.isFinite(municipio.precip_moisture_score);
			value = municipio.precip_moisture_score ?? 0;
		} else if (mapColorMetric === 'precip_annual_mm') {
			hasMetricData = Number.isFinite(municipio.precip_annual_mm);
			value = municipio.precip_annual_mm ?? 0;
		} else if (mapColorMetric === 'transporte_norm') {
			hasMetricData = Number.isFinite(municipio.transporte_norm);
			value = municipio.transporte_norm ?? 0;
		} else if (mapColorMetric === 'servicio_renfe_norm') {
			hasMetricData = Number.isFinite(municipio.renfe_madrid_service_norm ?? municipio.servicio_renfe_norm);
			value = municipio.renfe_madrid_service_norm ?? municipio.servicio_renfe_norm ?? 0;
		} else if (mapColorMetric === 'river_access_score') {
			hasMetricData = Number.isFinite(municipio.river_access_score);
			value = municipio.river_access_score ?? 0;
		} else if (mapColorMetric === 'travel_bucket') {
			hasMetricData = typeof municipio.travel_bucket === 'string' && municipio.travel_bucket.length > 0;
		}
		
		const isMissingData = !hasOfficialName || !hasMetricData;

		const travelBucketColor =
			municipio.travel_bucket === '<=1h30'
				? travelBucketColors[0]
				: municipio.travel_bucket === '<=2h00'
					? travelBucketColors[1]
					: municipio.travel_bucket === '<=2h30'
						? travelBucketColors[2]
						: municipio.travel_bucket === '<=3h30'
							? travelBucketColors[3]
							: municipio.travel_bucket === '<=4h00'
								? travelBucketColors[4]
								: travelBucketColors[5];

		const color = isMissingData
			? missingDataColor
			: mapColorMetric === 'mixed_score'
				? resolveBucketColor(value as number, activeScoreThresholds, scoreColors)
				: mapColorMetric === 'precip_moisture_score'
					? resolveBucketColor(value as number, moistureThresholds, moistureColors)
				: mapColorMetric === 'precip_annual_mm'
					? resolveBucketColor(value as number, precipThresholds, precipColors)
				: mapColorMetric === 'travel_bucket'
					? travelBucketColor
				: mapColorMetric === 'river_access_score'
					? resolveBucketColor(value as number, riverAccessThresholds, riverAccessColors)
				: mapColorMetric === 'servicio_renfe_norm'
						? resolveBucketColor(value as number, renfeServiceThresholds, renfeServiceColors)
						: resolveBucketColor(value as number, transporteThresholds, transporteColors);

		expression.push(municipio.id, color);
		const strippedId = String(Number.parseInt(municipio.id, 10));
		if (strippedId && strippedId !== municipio.id) expression.push(strippedId, color);
	}

	expression.push(missingDataColor);
	return expression;
};

export const getLegendConfig = (
	mapColorMetric: MapColorMetric,
	municipios: Municipio[] = []
): LegendConfig =>
	mapColorMetric === 'mixed_score'
		? {
				title: 'Puntuación territorial',
				thresholds: deriveScoreThresholds(municipios),
				colors: [...scoreColors],
				formatLabel: (value: number) => `${formatScorePercent(value)}%`,
				labels: ['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta']
		  }
		: mapColorMetric === 'precip_moisture_score'
			? {
					title: 'Humedad climática',
					thresholds: [...moistureThresholds],
					colors: [...moistureColors],
					formatLabel: (value: number) => `${Math.round(value * 100)}%`,
					labels: ['Muy seca', 'Seca', 'Equilibrada', 'Húmeda', 'Muy húmeda']
			  }
		: mapColorMetric === 'transporte_norm'
			? {
					title: 'Proximidad transporte',
					thresholds: [...transporteThresholds],
					colors: [...transporteColors],
					formatLabel: (value: number) => (value * 100).toFixed(0) + '%',
					labels: ['Muy lejos', 'Lejos', 'Cercano', 'Muy cercano', 'Óptimo']
				}
			: mapColorMetric === 'servicio_renfe_norm'
				? {
						title: 'Renfe a Madrid',
						thresholds: [...renfeServiceThresholds],
						colors: [...renfeServiceColors],
						formatLabel: (value: number) => (value * 100).toFixed(0) + '%',
						labels: ['Muy bajo', 'Bajo', 'Medio', 'Alto', 'Óptimo']
				  }
			: mapColorMetric === 'river_access_score'
				? {
					title: 'Acceso fluvial recreativo',
					thresholds: [...riverAccessThresholds],
					colors: [...riverAccessColors],
					formatLabel: (value: number) => `${Math.round(value)}`,
					labels: ['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta']
				  }
				: mapColorMetric === 'travel_bucket'
					? {
							title: 'Tiempo de desplazamiento',
							thresholds: [],
							colors: [...travelBucketColors],
							formatLabel: (value: number) => `${value}`,
							labels: [...travelBucketOrder]
					  }
				: {
						title: 'Gradiente de precipitación',
						thresholds: [...precipThresholds],
						colors: [...precipColors],
						formatLabel: (value: number) => `${Math.round(value)}`,
						labels: ['Seco', 'Semiseco', 'Intermedio', 'Húmedo', 'Muy húmedo']
					};

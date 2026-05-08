import type { MunicipioClimateMonthly } from '$lib/types/municipio';

type MonthlyAccumulator = { sumTemp: number; sumPrecip: number; count: number };

const meanSeriesFromRows = (rows: MunicipioClimateMonthly[]): MunicipioClimateMonthly[] => {
	const byMonth = new Map<number, MonthlyAccumulator>();
	for (const row of rows) {
		const bucket = byMonth.get(row.month) ?? { sumTemp: 0, sumPrecip: 0, count: 0 };
		bucket.sumTemp += row.temp_mean_c;
		bucket.sumPrecip += row.precip_mm;
		bucket.count += 1;
		byMonth.set(row.month, bucket);
	}

	return Array.from(byMonth.entries())
		.map(([month, values]) => ({
			id: '__aggregate__',
			nombre: '__aggregate__',
			provincia: '__aggregate__',
			month,
			temp_mean_c: values.count ? values.sumTemp / values.count : 0,
			precip_mm: values.count ? values.sumPrecip / values.count : 0
		}))
		.sort((a, b) => a.month - b.month);
};

export const selectedMunicipioClimateSeries = (
	rows: MunicipioClimateMonthly[],
	municipioId: string | null
): MunicipioClimateMonthly[] => {
	if (!municipioId) return [];
	return rows.filter((r) => r.id === municipioId).sort((a, b) => a.month - b.month);
};

export const selectedProvinciaClimateSeries = (
	rows: MunicipioClimateMonthly[],
	provincia: string | null
): MunicipioClimateMonthly[] => {
	if (!provincia) return [];
	return meanSeriesFromRows(rows.filter((row) => row.provincia === provincia));
};

export const ccaaClimateSeries = (rows: MunicipioClimateMonthly[]): MunicipioClimateMonthly[] => {
	if (rows.length === 0) return [];
	return meanSeriesFromRows(rows);
};

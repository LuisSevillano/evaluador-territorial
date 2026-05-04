export type TravelBucket = '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';
export type TravelBucketFilter = TravelBucket | null;

export const bucketOrder: Record<TravelBucket, number> = {
	'<=1h30': 1,
	'<=2h00': 2,
	'<=2h30': 3,
	'<=3h30': 4,
	'<=4h00': 5,
	'>4h00': 6
};

export const travelBuckets: Array<{ value: TravelBucketFilter; label: string }> = [
	{ value: null, label: 'Sin límite' },
	{ value: '<=1h30', label: '1,5h' },
	{ value: '<=2h00', label: '2h' },
	{ value: '<=2h30', label: '2,5h' },
	{ value: '<=3h30', label: '3,5h' },
	{ value: '<=4h00', label: '4h' }
];

export const isPlausibleTemp = (value: number) => Number.isFinite(value) && value > -60 && value < 60;

export const isPlausiblePrecipAnnual = (value: number) =>
	Number.isFinite(value) && value >= 0 && value < 20000;

export const clampNumber = (value: number, min: number, max: number) =>
	Math.min(max, Math.max(min, value));

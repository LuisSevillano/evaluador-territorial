const trimTrailingZeros = (value: string) => value.replace(/\.0+$|(?<=\.[0-9]*[1-9])0+$/u, '');

export const formatSmartNumber = (value: number): string => {
	if (!Number.isFinite(value)) return '-';
	const decimals = Math.abs(value) < 1 ? 3 : 1;
	return trimTrailingZeros(value.toFixed(decimals));
};

export const formatScorePercent = (score: number): string => {
	if (!Number.isFinite(score)) return '-';
	return formatSmartNumber(score * 100);
};

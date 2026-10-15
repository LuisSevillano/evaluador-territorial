export const normalizeProvinceName = (province: string) => {
	if (province === 'Araba/Álava' || province === 'Araba / Álava' || province === 'Araba/Alava') {
		return 'Álava';
	}
	return province;
};

export const toggleProvinceSelection = (selected: string[], province: string): string[] => {
	const normalized = normalizeProvinceName(province);
	const current = selected.map(normalizeProvinceName);
	return current.includes(normalized)
		? current.filter((name) => name !== normalized)
		: [...current, normalized];
};

export const normalizeProvinceName = (province: string) => {
	if (province === 'Araba/Álava' || province === 'Araba / Álava' || province === 'Araba/Alava') {
		return 'Álava';
	}
	return province;
};

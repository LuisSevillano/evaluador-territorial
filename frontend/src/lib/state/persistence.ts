export const loadStringArray = (key: string): string[] => {
	if (typeof localStorage === 'undefined') return [];
	const raw = localStorage.getItem(key);
	if (!raw) return [];
	try {
		const parsed = JSON.parse(raw) as unknown;
		return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === 'string') : [];
	} catch {
		return [];
	}
};

export const saveStringArray = (key: string, values: string[]): void => {
	if (typeof localStorage === 'undefined') return;
	localStorage.setItem(key, JSON.stringify(values));
};

export const loadBooleanFlag = (key: string): boolean => {
	if (typeof localStorage === 'undefined') return false;
	return localStorage.getItem(key) === '1';
};

export const saveBooleanFlag = (key: string, value: boolean): void => {
	if (typeof localStorage === 'undefined') return;
	if (value) {
		localStorage.setItem(key, '1');
		return;
	}
	localStorage.removeItem(key);
};

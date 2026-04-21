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

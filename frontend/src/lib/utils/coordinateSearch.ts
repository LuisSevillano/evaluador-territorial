export type CoordinateMatch = { lat: number; lon: number; label: string };

export const parseCoordinateQuery = (value: string): CoordinateMatch | null => {
	const match = value
		.trim()
		.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);
	if (!match) return null;
	const lat = Number.parseFloat(match[1]);
	const lon = Number.parseFloat(match[2]);
	if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
	if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
	return { lat, lon, label: `${lat}, ${lon}` };
};

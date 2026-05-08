export type IdealistaCoordinateSource = 'html_staticmap' | 'html_json' | 'gallery' | 'regex';

export type IdealistaCoordinates = {
	listingId: string;
	lat: number;
	lon: number;
	normalizedUrl?: string;
	source: IdealistaCoordinateSource;
	confidence: 'high' | 'medium' | 'low';
};

export type IdealistaLookupErrorCode =
	| 'invalid_url'
	| 'blocked'
	| 'not_found'
	| 'parse_failed'
	| 'network_error';

export type IdealistaUrlParts = {
	listingId: string;
	normalizedUrl: string;
};

const IDEALISTA_HOST_RE = /(^|\.)idealista\.com$/i;
const IDEALISTA_LISTING_PATH_RE = /\/inmueble\/(\d+)/i;
const STATIC_MAP_CENTER_RE = /staticmap[\s\S]{0,1600}[?&]center=(-?\d+(?:\.\d+)?)(?:%2C|%252C|,)(-?\d+(?:\.\d+)?)/i;
const JSON_LAT_LON_RES = [
	/"(?:latitude|lat)"\s*:\s*(-?\d+(?:\.\d+)?)[\s\S]{0,220}?"(?:longitude|lng|lon)"\s*:\s*(-?\d+(?:\.\d+)?)/i,
	/"(?:longitude|lng|lon)"\s*:\s*(-?\d+(?:\.\d+)?)[\s\S]{0,220}?"(?:latitude|lat)"\s*:\s*(-?\d+(?:\.\d+)?)/i
];

const isFiniteCoordinate = (lat: number, lon: number) =>
	Number.isFinite(lat) && Number.isFinite(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;

const normalizeEmbeddedText = (value: string) =>
	value
		.replace(/&amp;/g, '&')
		.replace(/&#38;/g, '&')
		.replace(/&quot;/g, '"')
		.replace(/&#34;/g, '"')
		.replace(/&#39;/g, "'")
		.replace(/\\u0026/gi, '&')
		.replace(/\\u003d/gi, '=')
		.replace(/\\u002c/gi, ',')
		.replace(/\\u002f/gi, '/')
		.replace(/\\\//g, '/');

export const parseIdealistaUrl = (value: string): IdealistaUrlParts | null => {
	const raw = value.trim();
	if (!raw) return null;

	let url: URL;
	try {
		url = new URL(raw.startsWith('http') ? raw : `https://${raw}`);
	} catch {
		return null;
	}

	if (!IDEALISTA_HOST_RE.test(url.hostname)) return null;
	const match = url.pathname.match(IDEALISTA_LISTING_PATH_RE);
	if (!match) return null;

	const listingId = match[1];
	return {
		listingId,
		normalizedUrl: `https://www.idealista.com/inmueble/${listingId}/`
	};
};

export const extractIdealistaListingId = (value: string) => parseIdealistaUrl(value)?.listingId ?? null;

export const normalizeIdealistaUrl = (value: string) => parseIdealistaUrl(value)?.normalizedUrl ?? null;

export const extractIdealistaCoordinatesFromText = (
	text: string,
	listingId = ''
): IdealistaCoordinates | null => {
	const decoded = normalizeEmbeddedText(text);
	const staticMapMatch = decoded.match(STATIC_MAP_CENTER_RE);
	if (staticMapMatch) {
		const lat = Number.parseFloat(staticMapMatch[1]);
		const lon = Number.parseFloat(staticMapMatch[2]);
		if (isFiniteCoordinate(lat, lon)) {
			return { listingId, lat, lon, source: 'html_staticmap', confidence: 'high' };
		}
	}

	for (const [index, re] of JSON_LAT_LON_RES.entries()) {
		const match = decoded.match(re);
		if (!match) continue;
		const first = Number.parseFloat(match[1]);
		const second = Number.parseFloat(match[2]);
		const lat = index === 0 ? first : second;
		const lon = index === 0 ? second : first;
		if (isFiniteCoordinate(lat, lon)) {
			return { listingId, lat, lon, source: 'html_json', confidence: 'medium' };
		}
	}

	return null;
};

export const withIdealistaCoordinateMetadata = (
	match: IdealistaCoordinates,
	metadata: Pick<IdealistaCoordinates, 'listingId' | 'normalizedUrl'>
): IdealistaCoordinates => ({
	...match,
	listingId: metadata.listingId,
	normalizedUrl: metadata.normalizedUrl
});

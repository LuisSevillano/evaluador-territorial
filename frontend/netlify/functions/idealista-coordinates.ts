import {
	extractIdealistaCoordinatesFromText,
	parseIdealistaUrl,
	withIdealistaCoordinateMetadata,
	type IdealistaLookupErrorCode
} from '../../src/lib/utils/idealistaCoordinates';

type NetlifyEvent = {
	queryStringParameters?: Record<string, string | undefined> | null;
};

type NetlifyResponse = {
	statusCode: number;
	headers: Record<string, string>;
	body: string;
};

const jsonHeaders = {
	'content-type': 'application/json; charset=utf-8',
	'cache-control': 'no-store'
};

const respond = (statusCode: number, body: unknown): NetlifyResponse => ({
	statusCode,
	headers: jsonHeaders,
	body: JSON.stringify(body)
});

const errorResponse = (statusCode: number, errorCode: IdealistaLookupErrorCode, message: string) =>
	respond(statusCode, { ok: false, errorCode, message });

const fetchText = async (url: string, referer: string) => {
	const controller = new AbortController();
	const timeout = globalThis.setTimeout(() => controller.abort(), 9000);

	try {
		const response = await fetch(url, {
			signal: controller.signal,
			headers: {
				accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
				'accept-language': 'es-ES,es;q=0.9',
				'cache-control': 'no-cache',
				pragma: 'no-cache',
				referer,
				'user-agent':
					'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36'
			}
		});
		return {
			status: response.status,
			ok: response.ok,
			text: await response.text()
		};
	} finally {
		globalThis.clearTimeout(timeout);
	}
};

export const handler = async (event: NetlifyEvent): Promise<NetlifyResponse> => {
	const rawUrl = event.queryStringParameters?.url;
	const parsed = rawUrl ? parseIdealistaUrl(rawUrl) : null;

	if (!parsed) {
		return errorResponse(400, 'invalid_url', 'URL de Idealista no valida.');
	}

	try {
		const detail = await fetchText(parsed.normalizedUrl, parsed.normalizedUrl);
		if (detail.status === 403 || detail.status === 429) {
			return errorResponse(502, 'blocked', 'Idealista ha bloqueado o limitado la peticion.');
		}
		if (detail.status === 404) {
			return errorResponse(404, 'not_found', 'No se ha encontrado el anuncio en Idealista.');
		}
		if (!detail.ok) {
			return errorResponse(502, 'network_error', `Idealista ha devuelto HTTP ${detail.status}.`);
		}

		const detailMatch = extractIdealistaCoordinatesFromText(detail.text, parsed.listingId);
		if (detailMatch) {
			return respond(200, {
				ok: true,
				...withIdealistaCoordinateMetadata(detailMatch, parsed)
			});
		}

		const galleryUrl = `https://www.idealista.com/es/openDetailGallery/${parsed.listingId}?isVacational=false`;
		const gallery = await fetchText(galleryUrl, parsed.normalizedUrl);
		if (gallery.status === 403 || gallery.status === 429) {
			return errorResponse(502, 'blocked', 'Idealista ha bloqueado o limitado la peticion al endpoint de galeria.');
		}
		if (gallery.ok) {
			const galleryMatch = extractIdealistaCoordinatesFromText(gallery.text, parsed.listingId);
			if (galleryMatch) {
				return respond(200, {
					ok: true,
					...withIdealistaCoordinateMetadata({ ...galleryMatch, source: 'gallery' }, parsed)
				});
			}
		}

		return errorResponse(422, 'parse_failed', 'No se han encontrado coordenadas en la respuesta de Idealista.');
	} catch (error) {
		const message = error instanceof Error && error.name === 'AbortError'
			? 'Timeout consultando Idealista.'
			: 'No se ha podido consultar Idealista.';
		return errorResponse(502, 'network_error', message);
	}
};

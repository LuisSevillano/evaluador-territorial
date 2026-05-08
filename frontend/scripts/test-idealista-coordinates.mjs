import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const tmp = mkdtempSync(join(tmpdir(), 'idealista-coordinates-'));

try {
	execFileSync(
		'npx',
		[
			'tsc',
			'--outDir',
			tmp,
			'--module',
			'es2022',
			'--target',
			'es2022',
			'--moduleResolution',
			'bundler',
			'--skipLibCheck',
			'--strict',
			'src/lib/utils/idealistaCoordinates.ts'
		],
		{ stdio: 'inherit' }
	);

	const util = await import(join(tmp, 'idealistaCoordinates.js'));

	assert.deepEqual(util.parseIdealistaUrl('https://www.idealista.com/inmueble/111348306/video/1/?utm_source=x'), {
		listingId: '111348306',
		normalizedUrl: 'https://www.idealista.com/inmueble/111348306/'
	});
	assert.equal(util.extractIdealistaListingId('www.idealista.com/inmueble/83950084/'), '83950084');
	assert.equal(util.normalizeIdealistaUrl('https://www.idealista.com/inmueble/102142391/?foo=bar'), 'https://www.idealista.com/inmueble/102142391/');
	assert.equal(util.parseIdealistaUrl('https://example.com/inmueble/111348306/'), null);

	const htmlStaticMap = '"map":{"src":"https://maps.googleapis.com/maps/api/staticmap?size=720x492&center=42.10523660%2C-2.41485920&maptype=roadmap"}';
	assert.deepEqual(util.extractIdealistaCoordinatesFromText(htmlStaticMap, '111348306'), {
		listingId: '111348306',
		lat: 42.1052366,
		lon: -2.4148592,
		source: 'html_staticmap',
		confidence: 'high'
	});

	const htmlEncodedStaticMap = '&quot;map&quot;:{&quot;src&quot;:&quot;https://maps.googleapis.com/maps/api/staticmap?center=40.4168%2C-3.7038&amp;zoom=16&quot;}';
	assert.deepEqual(util.extractIdealistaCoordinatesFromText(htmlEncodedStaticMap, 'x'), {
		listingId: 'x',
		lat: 40.4168,
		lon: -3.7038,
		source: 'html_staticmap',
		confidence: 'high'
	});

	const jsEscapedStaticMap = '"src":"https:\\/\\/maps.googleapis.com\\/maps\\/api\\/staticmap?size=720x492\\u0026center=42.10523660%252C-2.41485920\\u0026maptype=roadmap"';
	assert.deepEqual(util.extractIdealistaCoordinatesFromText(jsEscapedStaticMap, 'escaped'), {
		listingId: 'escaped',
		lat: 42.1052366,
		lon: -2.4148592,
		source: 'html_staticmap',
		confidence: 'high'
	});

	const embeddedJson = '{"addressVisibility":"EXACT","latitude":43.2627,"longitude":-2.9253}';
	assert.deepEqual(util.extractIdealistaCoordinatesFromText(embeddedJson, 'json'), {
		listingId: 'json',
		lat: 43.2627,
		lon: -2.9253,
		source: 'html_json',
		confidence: 'medium'
	});

	assert.equal(util.extractIdealistaCoordinatesFromText('<html>No coordinates</html>', 'none'), null);

	console.log('OK: idealista coordinate parser tests passed');
} finally {
	rmSync(tmp, { recursive: true, force: true });
}

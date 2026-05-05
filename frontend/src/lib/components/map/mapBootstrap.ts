import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';

export const registerPmtilesProtocol = () => {
	const protocol = new Protocol();
	maplibregl.addProtocol('pmtiles', protocol.tile);
	return () => maplibregl.removeProtocol('pmtiles');
};

export const parseHashView = (): { zoom: number; center: [number, number] } | null => {
	if (typeof window === 'undefined') return null;
	const hash = window.location.hash;
	if (!hash.startsWith('#map=')) return null;
	const parts = hash.slice(5).split('/');
	if (parts.length !== 3) return null;
	const zoom = Number(parts[0]);
	const lat = Number(parts[1]);
	const lon = Number(parts[2]);
	if (!Number.isFinite(zoom) || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
	return { zoom, center: [lon, lat] };
};

export const writeHashView = (map: maplibregl.Map) => {
	if (typeof window === 'undefined') return;
	const center = map.getCenter();
	const zoom = map.getZoom();
	const nextHash = `#map=${zoom.toFixed(2)}/${center.lat.toFixed(5)}/${center.lng.toFixed(5)}`;
	if (window.location.hash !== nextHash) {
		history.replaceState(history.state, '', `${window.location.pathname}${window.location.search}${nextHash}`);
	}
};

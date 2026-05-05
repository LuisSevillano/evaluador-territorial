import maplibregl from 'maplibre-gl';
import { baseStyle } from './mapConfig';
import { parseHashView } from './mapBootstrap';

type InitParams = {
	mapContainer: HTMLDivElement;
	onWebglRestored: () => void;
	onAfterCreate?: (map: maplibregl.Map) => void;
};

export const createMapInstance = ({ mapContainer, onWebglRestored, onAfterCreate }: InitParams) => {
	const map = new maplibregl.Map({
		container: mapContainer,
		style: baseStyle,
		center: [-4.7, 41.8],
		zoom: 6,
		attributionControl: false
	});

	const hashView = parseHashView();
	if (hashView) map.jumpTo({ center: hashView.center, zoom: hashView.zoom });

	map.addControl(new maplibregl.NavigationControl(), 'top-right');

	map.on('webglcontextlost', () => {
		console.warn('WebGL context lost, attempting recovery...');
	});

	map.on('webglcontextrestored', () => {
		console.log('WebGL context restored, reinitializing...');
		onWebglRestored();
	});

	onAfterCreate?.(map);

	return { map, hasHashView: Boolean(hashView) };
};

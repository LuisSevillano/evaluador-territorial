import type maplibregl from 'maplibre-gl';
import {
	ccaaLineLayerId,
	ccaaPmtilesSourceId,
	ccaaSourceLayerName,
	gridFillLayerId,
	gridHoverLineLayerId,
	gridLineLayerId,
	gridPmtilesSourceId,
	ignReservoirsLayerId,
	ignReservoirsSourceId,
	ignRiversLayerId,
	ignRiversSourceId,
	isochroneLayers,
	isochronesPmtilesSourceId,
	isochronesSourceLayerName,
	landUseFillColorExpression,
	landUseLayerId,
	landUsePmtilesSourceId,
	landUseSourceLayerName,
	provinciasLineLayerId,
	provinciasPmtilesSourceId,
	provinciasSourceLayerName,
	GRID_FORCE_MIN_ZOOM
} from './mapConfig';

export const addIsochroneLayers = (map: maplibregl.Map) => {
	try {
		if (!map.getSource(isochronesPmtilesSourceId)) {
			map.addSource(isochronesPmtilesSourceId, {
				type: 'vector',
				url: 'pmtiles:///tiles/isochrones.pmtiles'
			});
		}
	} catch (_error) {
		return;
	}

	for (const isochrone of isochroneLayers) {
		try {
			if (!map.getLayer(isochrone.layerId)) {
				map.addLayer({
					id: isochrone.layerId,
					type: 'line',
					source: isochronesPmtilesSourceId,
					'source-layer': isochronesSourceLayerName,
					filter: ['==', ['get', 'iso_key'], isochrone.key],
					paint: { 'line-color': isochrone.color, 'line-width': ['interpolate', ['linear'], ['zoom'], 5, 1.2, 8, 2.4, 10, 3.6], 'line-opacity': 0.9 }
				});
			}
		} catch (_error) {}
	}
};

export const addIgnHydroWmsLayers = (map: maplibregl.Map) => {
	map.addSource(ignRiversSourceId, { type: 'raster', tiles: ['https://servicios.idee.es/wms-inspire/hidrografia?service=WMS&request=GetMap&layers=HY.Network&styles=&format=image/png&transparent=true&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'], tileSize: 256 });
	map.addSource(ignReservoirsSourceId, { type: 'raster', tiles: ['https://servicios.idee.es/wms-inspire/hidrografia?service=WMS&request=GetMap&layers=HY.PhysicalWaters.Waterbodies&styles=&format=image/png&transparent=true&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'], tileSize: 256 });
	map.addLayer({ id: ignReservoirsLayerId, type: 'raster', source: ignReservoirsSourceId, paint: { 'raster-opacity': 0.78 } });
	map.addLayer({ id: ignRiversLayerId, type: 'raster', source: ignRiversSourceId, paint: { 'raster-opacity': 0.82 } });
};

export const addProvinciasBoundaries = (map: maplibregl.Map) => {
	try {
		map.addSource(provinciasPmtilesSourceId, { type: 'vector', url: 'pmtiles:///tiles/provincias.pmtiles' });
		map.addLayer({ id: provinciasLineLayerId, type: 'line', source: provinciasPmtilesSourceId, 'source-layer': provinciasSourceLayerName, paint: { 'line-color': '#ffffff', 'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1, 7, 1.5], 'line-opacity': 1 } });
	} catch (_error) {}
};

export const addCcaaBoundaries = (map: maplibregl.Map) => {
	try {
		map.addSource(ccaaPmtilesSourceId, { type: 'vector', url: 'pmtiles:///tiles/ccaa.pmtiles' });
		map.addLayer({ id: ccaaLineLayerId, type: 'line', source: ccaaPmtilesSourceId, 'source-layer': ccaaSourceLayerName, paint: { 'line-color': '#000000', 'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1, 8, 2], 'line-opacity': 1 } });
	} catch (_error) {}
};

export const addGridPmtiles = (map: maplibregl.Map, activeGridPmtilesPath: string, gridFillColorExpression: any) => {
	if (map.getSource(gridPmtilesSourceId)) return;
	map.addSource(gridPmtilesSourceId, { type: 'vector', url: `pmtiles://${activeGridPmtilesPath}`, promoteId: 'cell_id', minzoom: GRID_FORCE_MIN_ZOOM });
	map.addLayer({ id: gridLineLayerId, type: 'line', source: gridPmtilesSourceId, 'source-layer': 'grid', paint: { 'line-color': '#a1a1aa', 'line-width': ['interpolate', ['linear'], ['zoom'], 7, 0.18, 14, 1.2], 'line-opacity': ['interpolate', ['linear'], ['zoom'], 7, 0.06, 12, 0.42] } });
	map.addLayer({ id: gridFillLayerId, type: 'fill', source: gridPmtilesSourceId, 'source-layer': 'grid', paint: { 'fill-color': gridFillColorExpression, 'fill-opacity': 0.62 } });
	map.addLayer({ id: gridHoverLineLayerId, type: 'line', source: gridPmtilesSourceId, 'source-layer': 'grid', paint: { 'line-color': '#ffffff', 'line-width': ['interpolate', ['linear'], ['zoom'], 4, 2.2, 8, 4.2, 10, 5.4], 'line-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0] } });
};

export const ensureLandUseLayer = (map: maplibregl.Map) => {
	if (!map.getSource(landUsePmtilesSourceId)) map.addSource(landUsePmtilesSourceId, { type: 'vector', url: 'pmtiles:///tiles/usos_suelo.pmtiles' });
	if (!map.getLayer(landUseLayerId)) {
		map.addLayer({ id: landUseLayerId, type: 'fill', source: landUsePmtilesSourceId, 'source-layer': landUseSourceLayerName, minzoom: 7, paint: { 'fill-color': landUseFillColorExpression as any, 'fill-opacity': 0.52, 'fill-outline-color': 'rgba(34,34,34,0.45)' } });
	}
};

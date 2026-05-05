import type maplibregl from 'maplibre-gl';
import {
	ccaaLineLayerId,
	gridHoverLineLayerId,
	ignReservoirsLayerId,
	ignRiversLayerId,
	isochroneLayers,
	landUseLayerId,
	municipiosHoverLineLayerId,
	municipiosPolygonsFillLayerId,
	municipiosPolygonsLineLayerId,
	municipiosSelectedLineLayerId,
	provinciasLineLayerId,
	vegetationLayerId,
	forestLayerId
} from './mapConfig';

export const applyLayerOrdering = (map: maplibregl.Map, layerOrder: string[]) => {
	const mapLayerIds: Record<string, string> = {
		municipios: municipiosPolygonsFillLayerId,
		isochrones: isochroneLayers[0].layerId,
		landuse: landUseLayerId,
		vegetation: vegetationLayerId,
		forest: forestLayerId,
		reservoirs: ignReservoirsLayerId,
		rivers: ignRiversLayerId
	};

	for (const layerKey of layerOrder) {
		if (layerKey === 'isochrones') {
			for (const isochrone of isochroneLayers) {
				if (map.getLayer(isochrone.layerId)) map.moveLayer(isochrone.layerId, ccaaLineLayerId);
			}
			continue;
		}
		const layerId = mapLayerIds[layerKey];
		if (!layerId || !map.getLayer(layerId)) continue;
		map.moveLayer(layerId, ccaaLineLayerId);
	}
	if (map.getLayer(municipiosPolygonsLineLayerId)) map.moveLayer(municipiosPolygonsLineLayerId);
	if (map.getLayer(provinciasLineLayerId)) map.moveLayer(provinciasLineLayerId);
	if (map.getLayer(ccaaLineLayerId)) map.moveLayer(ccaaLineLayerId);
	if (map.getLayer(gridHoverLineLayerId)) map.moveLayer(gridHoverLineLayerId);
	if (map.getLayer(municipiosHoverLineLayerId)) map.moveLayer(municipiosHoverLineLayerId);
	if (map.getLayer(municipiosSelectedLineLayerId)) map.moveLayer(municipiosSelectedLineLayerId);
};

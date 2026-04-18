<script lang="ts">
	import { onMount } from 'svelte';
	import maplibregl from 'maplibre-gl';
	import { Protocol } from 'pmtiles';
	import type { FeatureCollection, Point } from 'geojson';
	import type { Municipio } from '$lib/types/municipio';
	import 'maplibre-gl/dist/maplibre-gl.css';

	type Props = {
		municipios?: Municipio[];
		selectedMunicipio?: Municipio | null;
		showMunicipioPolygons?: boolean;
		showMunicipioPoints?: boolean;
		showIgnWmsBase?: boolean;
		mapColorMetric?: 'precip_annual_mm' | 'mixed_score';
		showForestLayer?: boolean;
		showLandUseLayer?: boolean;
		showVegetationLayer?: boolean;
		visibleMunicipioIds?: string[];
		polygonDataUrl?: string;
		pmtilesUrl?: string;
		onMapSelection?: (municipio: Municipio) => void;
	};

	let {
		municipios = [],
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showMunicipioPoints = true,
		showIgnWmsBase = false,
		mapColorMetric = 'mixed_score',
		showForestLayer = false,
		showLandUseLayer = false,
		showVegetationLayer = false,
		visibleMunicipioIds = [],
		polygonDataUrl = '/data/municipios_final.geojson',
		pmtilesUrl = '/tiles/municipios.pmtiles',
		onMapSelection = () => undefined
	}: Props = $props();

	let mapContainer: HTMLDivElement;
	let map: maplibregl.Map;
	let usingPmtiles = $state(true);

	const municipiosSourceId = 'municipios-centroides-source';
	const municipiosLayerId = 'municipios-centroides-layer';
	const municipiosPmtilesSourceId = 'municipios-pmtiles-source';
	const municipiosPolygonsSourceId = 'municipios-geojson-fallback-source';
	const municipiosPolygonsFillLayerId = 'municipios-polygons-fill-layer';
	const municipiosPolygonsLineLayerId = 'municipios-polygons-line-layer';
	const municipiosHoverLineLayerId = 'municipios-polygons-hover-line-layer';
	const municipiosSelectedLineLayerId = 'municipios-polygons-selected-line-layer';
	const provinciasPmtilesSourceId = 'provincias-pmtiles-source';
	const provinciasGeojsonSourceId = 'provincias-geojson-source';
	const provinciasLineLayerId = 'provincias-line-layer';
	const ignWmsSourceId = 'ign-wms-source';
	const ignWmsLayerId = 'ign-wms-layer';
	const forestSourceId = 'forest-source';
	const forestLayerId = 'forest-layer';
	const landUseSourceId = 'landuse-source';
	const landUseLayerId = 'landuse-layer';
	const vegetationSourceId = 'vegetation-source';
	const vegetationLayerId = 'vegetation-layer';
	const sourceLayerName = 'municipios';
	const provinciasSourceLayerName = 'provincias';
	let hoveredMunicipioId = $state<string | null>(null);
	let hoverPopup: maplibregl.Popup | null = null;

	const scoreColorExpression: any = [
		'interpolate',
		['linear'],
		['to-number', ['get', 'mixed_score'], 0],
		0,
		'#d8d2c4',
		0.35,
		'#8db8b0',
		0.65,
		'#4f8da3',
		1,
		'#1f4f68'
	];

	const precipColorExpression: any = [
		'interpolate',
		['linear'],
		['to-number', ['get', 'precip_annual_mm'], 600],
		300,
		'#f3d7ac',
		600,
		'#7cbac0',
		900,
		'#265d7f'
	];

	const getMapFillExpression = () => (mapColorMetric === 'mixed_score' ? scoreColorExpression : precipColorExpression);

	const baseStyle: maplibregl.StyleSpecification = {
		version: 8,
		sources: {},
		layers: [
			{
				id: 'background',
				type: 'background',
				paint: { 'background-color': '#ede4d4' }
			}
		]
	};

	const toFeatureCollection = (items: Municipio[]): FeatureCollection<Point> => ({
		type: 'FeatureCollection',
		features: items.map((m) => ({
			type: 'Feature',
			geometry: { type: 'Point', coordinates: [m.lon, m.lat] },
			properties: {
				id: m.id,
				nombre: m.nombre,
				provincia: m.provincia,
				precip_annual_mm: m.precip_annual_mm,
				travel_bucket: m.travel_bucket
			}
		}))
	});

	const refreshMunicipiosSource = () => {
		if (!map) return;
		const source = map.getSource(municipiosSourceId) as maplibregl.GeoJSONSource | undefined;
		if (!source) return;
		source.setData(toFeatureCollection(municipios) as any);
	};

	const getMunicipioByFeature = (feature: maplibregl.MapGeoJSONFeature | undefined) => {
		if (!feature) return null;
		const featureId = String(feature.properties?.id ?? feature.properties?.codigo ?? '');
		return municipios.find((m) => m.id === featureId || m.codigo === featureId) ?? null;
	};

	const setLayerVisibility = (layerId: string, visible: boolean) => {
		if (!map || !map.getLayer(layerId)) return;
		map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
	};

	const buildIdFilterExpression = (id: string | null) => {
		if (!id) return ['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], '__none__'];
		const numeric = Number.parseInt(id, 10);
		return [
			'any',
			['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], id],
			['==', ['to-number', ['coalesce', ['get', 'id'], ['get', 'codigo']]], numeric]
		];
	};

	const syncHighlightFilters = () => {
		if (!map) return;
		if (map.getLayer(municipiosHoverLineLayerId))
			map.setFilter(municipiosHoverLineLayerId, buildIdFilterExpression(hoveredMunicipioId) as any);
		if (map.getLayer(municipiosSelectedLineLayerId))
			map.setFilter(
				municipiosSelectedLineLayerId,
				buildIdFilterExpression(selectedMunicipio?.id ?? null) as any
			);
	};

	const addHighlightLayers = (source: string, sourceLayer?: string) => {
		if (!map) return;
		const sourceLayerConfig = sourceLayer ? { 'source-layer': sourceLayer } : {};

		map.addLayer({
			id: municipiosHoverLineLayerId,
			type: 'line',
			source,
			...sourceLayerConfig,
			paint: {
				'line-color': '#f8f7f1',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.4, 9, 3.2],
				'line-opacity': 0.95
			},
			filter: buildIdFilterExpression(null) as any
		});

		map.addLayer({
			id: municipiosSelectedLineLayerId,
			type: 'line',
			source,
			...sourceLayerConfig,
			paint: {
				'line-color': '#bb5b31',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.6, 9, 3.8],
				'line-opacity': 1
			},
			filter: buildIdFilterExpression(null) as any
		});
	};

	const applyPolygonFilter = () => {
		if (!map) return;

		if (visibleMunicipioIds.length === 0) {
			const noneExpr: any = ['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], '__none__'];
			if (map.getLayer(municipiosPolygonsFillLayerId)) map.setFilter(municipiosPolygonsFillLayerId, noneExpr);
			if (map.getLayer(municipiosPolygonsLineLayerId)) map.setFilter(municipiosPolygonsLineLayerId, noneExpr);
			return;
		}

		const targetIds = Array.from(new Set(visibleMunicipioIds));

		if (municipios.length > 0 && targetIds.length >= municipios.length) {
			if (map.getLayer(municipiosPolygonsFillLayerId)) map.setFilter(municipiosPolygonsFillLayerId, null);
			if (map.getLayer(municipiosPolygonsLineLayerId)) map.setFilter(municipiosPolygonsLineLayerId, null);
			return;
		}

		const targetIdsNumeric = targetIds
			.map((id) => Number.parseInt(id, 10))
			.filter((n) => Number.isFinite(n));

		const expr: any = [
			'any',
			['in', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], ['literal', targetIds]],
			[
				'in',
				['to-number', ['coalesce', ['get', 'id'], ['get', 'codigo']]],
				['literal', targetIdsNumeric]
			]
		];
		if (map.getLayer(municipiosPolygonsFillLayerId))
			map.setFilter(municipiosPolygonsFillLayerId, expr);
		if (map.getLayer(municipiosPolygonsLineLayerId))
			map.setFilter(municipiosPolygonsLineLayerId, expr);
		syncHighlightFilters();
	};

	const addMunicipiosFallbackGeojson = () => {
		if (!map) return;

		map.addSource(municipiosPolygonsSourceId, { type: 'geojson', data: polygonDataUrl });

		map.addLayer({
			id: municipiosPolygonsFillLayerId,
			type: 'fill',
			source: municipiosPolygonsSourceId,
			paint: {
				'fill-color': getMapFillExpression(),
				'fill-opacity': 0.36
			}
		});

		map.addLayer({
			id: municipiosPolygonsLineLayerId,
			type: 'line',
			source: municipiosPolygonsSourceId,
			paint: {
				'line-color': '#113a46',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.35, 9, 1.3],
				'line-opacity': 0.82
			}
		});

		addHighlightLayers(municipiosPolygonsSourceId);

		map.on('click', municipiosPolygonsFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
			const feature = e.features?.[0];
			if (!feature) return;
			const id = String(feature.properties?.id ?? feature.properties?.codigo ?? '');
			const selected = municipios.find((m) => m.id === id);
			if (selected) onMapSelection(selected);
		});
	};

	const addMunicipiosPmtiles = () => {
		if (!map || !pmtilesUrl) return false;
		try {
			map.addSource(municipiosPmtilesSourceId, {
				type: 'vector',
				url: `pmtiles://${pmtilesUrl}`
			});

		map.addLayer({
			id: municipiosPolygonsFillLayerId,
			type: 'fill',
			source: municipiosPmtilesSourceId,
			'source-layer': sourceLayerName,
			paint: {
				'fill-color': getMapFillExpression(),
				'fill-opacity': 0.36
			}
		});

			map.addLayer({
				id: municipiosPolygonsLineLayerId,
				type: 'line',
				source: municipiosPmtilesSourceId,
				'source-layer': sourceLayerName,
				paint: {
					'line-color': '#113a46',
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.35, 9, 1.3],
					'line-opacity': 0.82
				}
			});

			addHighlightLayers(municipiosPmtilesSourceId, sourceLayerName);

			map.on('click', municipiosPolygonsFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
				const feature = e.features?.[0];
				if (!feature) return;
				const id = String(feature.properties?.id ?? feature.properties?.codigo ?? '');
				const selected = municipios.find((m) => m.id === id);
				if (selected) onMapSelection(selected);
			});

			return true;
		} catch (error) {
			console.warn('PMTiles no disponible, cambiando a fallback GeoJSON.', error);
			return false;
		}
	};

	const addOptionalOverlayLayers = async () => {
		if (!map) return;
		const files = [
			{ url: '/data/masa_forestal.geojson', source: forestSourceId, layer: forestLayerId, color: '#2f6f3f' },
			{ url: '/data/usos_suelo.geojson', source: landUseSourceId, layer: landUseLayerId, color: '#8a6d3b' },
			{ url: '/data/cobertura_vegetal.geojson', source: vegetationSourceId, layer: vegetationLayerId, color: '#3e8f5c' }
		] as const;

		for (const file of files) {
			try {
				const response = await fetch(file.url);
				if (!response.ok) continue;
				const geojson = await response.json();
				map.addSource(file.source, { type: 'geojson', data: geojson as any });
				map.addLayer({
					id: file.layer,
					type: 'fill',
					source: file.source,
					paint: {
						'fill-color': file.color,
						'fill-opacity': 0.2
					}
				});
			} catch (_error) {
				// optional layers are best effort
			}
		}
	};

	const addProvinciasBoundaries = () => {
		if (!map) return;
		let added = false;
		try {
			map.addSource(provinciasPmtilesSourceId, {
				type: 'vector',
				url: 'pmtiles:///tiles/provincias.pmtiles'
			});
			map.addLayer({
				id: provinciasLineLayerId,
				type: 'line',
				source: provinciasPmtilesSourceId,
				'source-layer': provinciasSourceLayerName,
				paint: {
					'line-color': '#691f11',
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.2, 7, 3.2],
					'line-opacity': 0.95
				}
			});
			added = true;
		} catch (error) {
			console.warn('No se pudo cargar provincias PMTiles, usando GeoJSON fallback.', error);
		}

		if (added) return;

		map.addSource(provinciasGeojsonSourceId, {
			type: 'geojson',
			data: '/data/provincias_boundaries.geojson'
		});

		map.addLayer({
			id: provinciasLineLayerId,
			type: 'line',
			source: provinciasGeojsonSourceId,
			paint: {
				'line-color': '#691f11',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.2, 7, 3.2],
				'line-opacity': 0.95
			}
		});
	};

	const registerPmtiles = () => {
		const protocol = new Protocol();
		maplibregl.addProtocol('pmtiles', protocol.tile);
		return () => maplibregl.removeProtocol('pmtiles');
	};

	onMount(() => {
		const unregisterPmtiles = registerPmtiles();

		map = new maplibregl.Map({
			container: mapContainer,
			style: baseStyle,
			center: [-4.7, 41.8],
			zoom: 6.2,
			attributionControl: false
		});

		map.addControl(new maplibregl.NavigationControl(), 'top-right');

		map.on('load', () => {
			map.addSource(ignWmsSourceId, {
				type: 'raster',
				tiles: [
					'https://www.ign.es/wms-inspire/ign-base?service=WMS&request=GetMap&layers=IGNBaseTodo&styles=&format=image/png&transparent=true&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'
				],
				tileSize: 256
			});

			map.addLayer({
				id: ignWmsLayerId,
				type: 'raster',
				source: ignWmsSourceId,
				paint: { 'raster-opacity': 0.9 }
			});

			usingPmtiles = addMunicipiosPmtiles();
			if (!usingPmtiles) addMunicipiosFallbackGeojson();
			addProvinciasBoundaries();
			void addOptionalOverlayLayers();

			map.addSource(municipiosSourceId, {
				type: 'geojson',
				data: toFeatureCollection(municipios) as any
			});

			setLayerVisibility(ignWmsLayerId, showIgnWmsBase);
			setLayerVisibility(municipiosPolygonsFillLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosPolygonsLineLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosHoverLineLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosSelectedLineLayerId, showMunicipioPolygons);
			applyPolygonFilter();

			map.on('mouseenter', municipiosPolygonsFillLayerId, () => {
				map.getCanvas().style.cursor = 'pointer';
			});

			map.on('mousemove', municipiosPolygonsFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
				const feature = e.features?.[0];
				const selectedFeatureMunicipio = getMunicipioByFeature(feature);
				hoveredMunicipioId = feature
					? String(feature.properties?.id ?? feature.properties?.codigo ?? '')
					: null;
				syncHighlightFilters();
				if (!selectedFeatureMunicipio) return;
				if (!hoverPopup) {
					hoverPopup = new maplibregl.Popup({ closeButton: false, closeOnClick: false, offset: 12 });
				}
				hoverPopup
					.setLngLat(e.lngLat)
					.setHTML(
						`<strong>${selectedFeatureMunicipio.nombre}</strong><br>${selectedFeatureMunicipio.provincia}<br>Bucket: ${selectedFeatureMunicipio.travel_bucket}<br>Score: ${(selectedFeatureMunicipio.mixed_score ?? 0).toFixed(2)}`
					)
					.addTo(map);
			});

			map.on('mouseleave', municipiosPolygonsFillLayerId, () => {
				map.getCanvas().style.cursor = '';
				hoveredMunicipioId = null;
				syncHighlightFilters();
				hoverPopup?.remove();
			});
		});

		return () => {
			unregisterPmtiles();
			map?.remove();
		};
	});

	$effect(() => {
		refreshMunicipiosSource();
	});

	$effect(() => {
		applyPolygonFilter();
	});

	$effect(() => {
		if (!map) return;
		setLayerVisibility(ignWmsLayerId, showIgnWmsBase);
		setLayerVisibility(municipiosPolygonsFillLayerId, showMunicipioPolygons);
		setLayerVisibility(municipiosPolygonsLineLayerId, showMunicipioPolygons);
		setLayerVisibility(municipiosHoverLineLayerId, showMunicipioPolygons);
		setLayerVisibility(municipiosSelectedLineLayerId, showMunicipioPolygons);
		setLayerVisibility(municipiosLayerId, showMunicipioPoints);
		setLayerVisibility(forestLayerId, showForestLayer);
		setLayerVisibility(landUseLayerId, showLandUseLayer);
		setLayerVisibility(vegetationLayerId, showVegetationLayer);
	});

	$effect(() => {
		if (!map || !map.getLayer(municipiosPolygonsFillLayerId)) return;
		map.setPaintProperty(municipiosPolygonsFillLayerId, 'fill-color', getMapFillExpression() as any);
	});

	$effect(() => {
		syncHighlightFilters();
	});

	$effect(() => {
		if (!map || !selectedMunicipio) return;
		map.flyTo({ center: [selectedMunicipio.lon, selectedMunicipio.lat], zoom: 9, speed: 0.8 });
	});
</script>

<div class="map-shell">
	<div class="map-header">
		<div>
			<h3>Atlas Municipal</h3>
			<p>{usingPmtiles ? 'Render vectorial PMTiles' : 'Render fallback GeoJSON'}</p>
		</div>
		<div class="legend">
			<span>{mapColorMetric === 'mixed_score' ? 'Bajo' : 'Seco'}</span>
			<div class="scale"></div>
			<span>{mapColorMetric === 'mixed_score' ? 'Alto' : 'Humedo'}</span>
		</div>
	</div>
	<div class="map" bind:this={mapContainer} aria-label="Mapa principal"></div>
</div>

<style>
	.map-shell {
		height: 100%;
		min-height: 0;
		padding: 1rem;
		display: grid;
		grid-template-rows: auto minmax(0, 1fr);
		gap: 0.6rem;
	}

	.map-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		border: 1px solid rgba(16, 44, 54, 0.25);
		border-radius: 14px;
		background: rgba(246, 240, 226, 0.88);
		backdrop-filter: blur(4px);
	}

	h3 {
		font-family: 'Fraunces', serif;
		font-size: 1.05rem;
		margin: 0;
	}

	p {
		margin: 0.15rem 0 0;
		font-size: 0.82rem;
		color: #304744;
	}

	.legend {
		display: flex;
		align-items: center;
		gap: 0.55rem;
		font-size: 0.73rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #2d4240;
	}

	.scale {
		width: 84px;
		height: 10px;
		border-radius: 999px;
		background: linear-gradient(90deg, #d97706, #0ea5a4, #1d4ed8);
		border: 1px solid rgba(18, 40, 44, 0.35);
	}

	.map {
		width: 100%;
		height: 100%;
		min-height: 0;
		border-radius: 14px;
		overflow: hidden;
		border: 1px solid rgba(16, 44, 54, 0.25);
		box-shadow:
			0 10px 26px rgba(16, 44, 54, 0.15),
			inset 0 0 0 1px rgba(255, 255, 255, 0.35);
	}

	@media (max-width: 900px) {
		.map-shell {
			padding: 0.7rem;
			min-height: 52dvh;
		}

		.map-header {
			flex-direction: column;
			align-items: flex-start;
			gap: 0.5rem;
		}
	}
</style>

<script lang="ts">
	import { onMount } from 'svelte';
	import maplibregl from 'maplibre-gl';
	import { Protocol } from 'pmtiles';
	import type { FeatureCollection, Point } from 'geojson';
	import type { Municipio } from '$lib/types/municipio';
	import MapHeader from '$lib/components/map/MapHeader.svelte';
	import LandUseLegend from '$lib/components/map/LandUseLegend.svelte';
	import MapLoadingBadge from '$lib/components/map/MapLoadingBadge.svelte';
	import {
		type MapColorMetric,
		buildMunicipioColorExpression,
		getLegendConfig
	} from '$lib/components/map/coloring';
	import 'maplibre-gl/dist/maplibre-gl.css';

	type Props = {
		municipios?: Municipio[];
		selectedMunicipio?: Municipio | null;
		showMunicipioPolygons?: boolean;
		showMunicipioPoints?: boolean;
		showIgnWmsBase?: boolean;
		showIgnSatellite?: boolean;
		showIgnRivers?: boolean;
		showIgnReservoirs?: boolean;
		mapColorMetric?: MapColorMetric;
		showForestLayer?: boolean;
		showLandUseLayer?: boolean;
		showVegetationLayer?: boolean;
		layerOrder?: string[];
		visibleMunicipioIds?: string[];
		provinceFilter?: string;
		pmtilesUrl?: string;
		onMapSelection?: (municipio: Municipio | null) => void;
	};

	let {
		municipios = [],
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showMunicipioPoints = true,
		showIgnWmsBase = false,
		showIgnSatellite = false,
		showIgnRivers = false,
		showIgnReservoirs = false,
		mapColorMetric = 'mixed_score',
		showForestLayer = false,
		showLandUseLayer = false,
		showVegetationLayer = false,
		layerOrder = ['municipios', 'landuse', 'reservoirs', 'rivers'],
		visibleMunicipioIds = [],
		provinceFilter = 'Todas',
		pmtilesUrl = '/tiles/municipios.pmtiles',
		onMapSelection = () => undefined
	}: Props = $props();

	let mapContainer: HTMLDivElement;
	let map: maplibregl.Map;
	let mapReady = $state(false);

	const municipiosSourceId = 'municipios-centroides-source';
	const municipiosLayerId = 'municipios-centroides-layer';
	const municipiosPmtilesSourceId = 'municipios-pmtiles-source';
	const municipiosPolygonsFillLayerId = 'municipios-polygons-fill-layer';
	const municipiosPolygonsLineLayerId = 'municipios-polygons-line-layer';
	const municipiosHoverLineLayerId = 'municipios-polygons-hover-line-layer';
	const municipiosSelectedLineLayerId = 'municipios-polygons-selected-line-layer';
	const provinciasPmtilesSourceId = 'provincias-pmtiles-source';
	const provinciasGeojsonSourceId = 'provincias-geojson-source';
	const provinciasLineLayerId = 'provincias-line-layer';
	const ignWmsSourceId = 'ign-wms-source';
	const ignWmsLayerId = 'ign-wms-layer';
	const ignSatelliteSourceId = 'ign-satellite-wms-source';
	const ignSatelliteLayerId = 'ign-satellite-wms-layer';
	const ignRiversSourceId = 'ign-rivers-wms-source';
	const ignRiversLayerId = 'ign-rivers-wms-layer';
	const ignReservoirsSourceId = 'ign-reservoirs-wms-source';
	const ignReservoirsLayerId = 'ign-reservoirs-wms-layer';
	const forestSourceId = 'forest-source';
	const forestLayerId = 'forest-layer';
	const landUseSourceId = 'landuse-source';
	const landUseLayerId = 'landuse-layer';
	const landUsePmtilesSourceId = 'landuse-pmtiles-source';
	const vegetationSourceId = 'vegetation-source';
	const vegetationLayerId = 'vegetation-layer';
	const landUseSourceLayerName = 'usos_suelo';
	const sourceLayerName = 'municipios';
	const provinciasSourceLayerName = 'provincias';
	const municipiosMinVisibleZoom = 5;
	let hoveredFeatureId: string | number | null = null;
	let isMapLoading = $state(true);
	let loadedOverlayLayers = $state({ forest: false, landuse: false, vegetation: false });
	let lastSelectedFilterId: string | null = null;
	let lastFittedProvince: string | null = null;
	let activeMunicipiosSourceId = municipiosPmtilesSourceId;
	let activeMunicipiosSourceLayer: string | undefined = sourceLayerName;
	let initialBoundsApplied = $state(false);

	const legendConfig = $derived.by(() => getLegendConfig(mapColorMetric));

	const paintColorExpression = $derived.by(() =>
		buildMunicipioColorExpression(municipios, mapColorMetric)
	);

	const landUsePalette: Array<{ key: string; color: string; label: string }> = [
		{ key: 'forest', color: '#1b5e20', label: 'Bosque' },
		{ key: 'park', color: '#4caf50', label: 'Parque' },
		{ key: 'residential', color: '#ef6c00', label: 'Residencial' },
		{ key: 'industrial', color: '#6d4c41', label: 'Industrial' },
		{ key: 'farmland', color: '#c0a060', label: 'Agrario' },
		{ key: 'cemetery', color: '#455a64', label: 'Cementerio' }
	];

	const landUseFillColorExpression: any = [
		'match',
		['downcase', ['coalesce', ['to-string', ['get', 'fclass']], 'unknown']],
		'forest',
		'#1b5e20',
		'wood',
		'#2e7d32',
		'park',
		'#4caf50',
		'residential',
		'#ef6c00',
		'industrial',
		'#6d4c41',
		'commercial',
		'#8d6e63',
		'farmland',
		'#c0a060',
		'farm',
		'#b6904f',
		'cemetery',
		'#455a64',
		'#607d8b'
	];

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

	const setLayerVisibility = (layerId: string, visible: boolean) => {
		if (!map || !map.getLayer(layerId)) return;
		map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
	};

	const buildIdFilterExpression = (id: string | null) => {
		if (!id)
			return ['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], '__none__'];
		const numeric = Number.parseInt(id, 10);
		return [
			'any',
			['==', ['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]], id],
			['==', ['to-number', ['coalesce', ['get', 'id'], ['get', 'codigo']]], numeric]
		];
	};

	const findMunicipioByFeatureId = (rawId: string | number | null | undefined) => {
		if (rawId === null || rawId === undefined) return null;
		const idText = String(rawId).trim();
		if (!idText) return null;

		const direct = municipios.find((m) => m.id === idText || m.codigo === idText);
		if (direct) return direct;

		const numericId = Number.parseInt(idText, 10);
		if (!Number.isFinite(numericId)) return null;

		return (
			municipios.find(
				(m) => Number.parseInt(m.id, 10) === numericId || Number.parseInt(m.codigo, 10) === numericId
			) ?? null
		);
	};

	const syncHighlightFilters = () => {
		if (!map) return;
		const selectedId = selectedMunicipio?.id ?? null;
		if (selectedId !== lastSelectedFilterId && map.getLayer(municipiosSelectedLineLayerId)) {
			map.setFilter(municipiosSelectedLineLayerId, buildIdFilterExpression(selectedId) as any);
			lastSelectedFilterId = selectedId;
		}
	};

	const setHoverFeatureState = (nextId: string | number | null) => {
		if (!map) return;
		if (hoveredFeatureId !== null) {
			const prevTarget: any = { source: activeMunicipiosSourceId, id: hoveredFeatureId };
			if (activeMunicipiosSourceLayer) prevTarget.sourceLayer = activeMunicipiosSourceLayer;
			map.setFeatureState(prevTarget, { hover: false });
		}

		hoveredFeatureId = nextId;

		if (hoveredFeatureId !== null) {
			const nextTarget: any = { source: activeMunicipiosSourceId, id: hoveredFeatureId };
			if (activeMunicipiosSourceLayer) nextTarget.sourceLayer = activeMunicipiosSourceLayer;
			map.setFeatureState(nextTarget, { hover: true });
		}
	};

	const addHighlightLayers = (source: string, sourceLayer?: string) => {
		if (!map) return;
		const sourceLayerConfig = sourceLayer ? { 'source-layer': sourceLayer } : {};

		map.addLayer({
			id: municipiosHoverLineLayerId,
			type: 'line',
			source,
			minzoom: municipiosMinVisibleZoom,
			...sourceLayerConfig,
			paint: {
				'line-color': '#ffffff',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 2.2, 8, 4.2, 10, 5.4],
				'line-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0]
			}
		});

		map.addLayer({
			id: municipiosSelectedLineLayerId,
			type: 'line',
			source,
			minzoom: municipiosMinVisibleZoom,
			...sourceLayerConfig,
			paint: {
				'line-color': '#bb5b31',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1.6, 9, 3.8],
				'line-opacity': 1
			},
			filter: buildIdFilterExpression(null) as any
		});
	};

	const mapLayerIds: Record<string, string> = {
		municipios: municipiosPolygonsFillLayerId,
		landuse: landUseLayerId,
		vegetation: vegetationLayerId,
		forest: forestLayerId,
		reservoirs: ignReservoirsLayerId,
		rivers: ignRiversLayerId
	};

	const applyLayerOrdering = () => {
		if (!map) return;
		for (const layerKey of layerOrder) {
			const layerId = mapLayerIds[layerKey];
			if (!layerId || !map.getLayer(layerId)) continue;
			map.moveLayer(layerId, provinciasLineLayerId);
		}
		if (map.getLayer(provinciasLineLayerId)) map.moveLayer(provinciasLineLayerId);
		if (map.getLayer(municipiosPolygonsLineLayerId)) map.moveLayer(municipiosPolygonsLineLayerId);
		if (map.getLayer(municipiosHoverLineLayerId)) map.moveLayer(municipiosHoverLineLayerId);
		if (map.getLayer(municipiosSelectedLineLayerId)) map.moveLayer(municipiosSelectedLineLayerId);
	};

	const applyPolygonFilter = () => {
		if (!map) return;

		if (visibleMunicipioIds.length === 0) {
			const noneExpr: any = [
				'==',
				['to-string', ['coalesce', ['get', 'id'], ['get', 'codigo']]],
				'__none__'
			];
			if (map.getLayer(municipiosPolygonsFillLayerId))
				map.setFilter(municipiosPolygonsFillLayerId, noneExpr);
			if (map.getLayer(municipiosPolygonsLineLayerId))
				map.setFilter(municipiosPolygonsLineLayerId, noneExpr);
			return;
		}

		const targetIds = Array.from(new Set(visibleMunicipioIds));

		if (municipios.length > 0 && targetIds.length >= municipios.length) {
			if (map.getLayer(municipiosPolygonsFillLayerId))
				map.setFilter(municipiosPolygonsFillLayerId, null);
			if (map.getLayer(municipiosPolygonsLineLayerId))
				map.setFilter(municipiosPolygonsLineLayerId, null);
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

	const getMunicipiosBounds = () => {
		if (municipios.length === 0) return null;

		const points = municipios.filter((m) => Number.isFinite(m.lon) && Number.isFinite(m.lat));
		if (points.length === 0) return null;

		let minLon = Number.POSITIVE_INFINITY;
		let minLat = Number.POSITIVE_INFINITY;
		let maxLon = Number.NEGATIVE_INFINITY;
		let maxLat = Number.NEGATIVE_INFINITY;

		for (const point of points) {
			if (point.lon < minLon) minLon = point.lon;
			if (point.lon > maxLon) maxLon = point.lon;
			if (point.lat < minLat) minLat = point.lat;
			if (point.lat > maxLat) maxLat = point.lat;
		}

		if (!Number.isFinite(minLon + minLat + maxLon + maxLat)) return null;

		const lonSpan = Math.max(maxLon - minLon, 0.01);
		const latSpan = Math.max(maxLat - minLat, 0.01);
		const padLon = Math.max(lonSpan * 0.08, 0.12);
		const padLat = Math.max(latSpan * 0.08, 0.08);

		const raw: [[number, number], [number, number]] = [
			[minLon, minLat],
			[maxLon, maxLat]
		];

		const padded: [[number, number], [number, number]] = [
			[Math.max(-180, minLon - padLon), Math.max(-85, minLat - padLat)],
			[Math.min(180, maxLon + padLon), Math.min(85, maxLat + padLat)]
		];

		return { raw, padded };
	};

	const applyMaxBoundsToMunicipios = () => {
		if (!map) return;
		const bounds = getMunicipiosBounds();
		if (!bounds) return;
		map.setMaxBounds(bounds.padded as maplibregl.LngLatBoundsLike);
	};

	const fitToMunicipios = () => {
		if (!map) return;
		const bounds = getMunicipiosBounds();
		if (!bounds) return;

		map.fitBounds(
			bounds.raw,
			{
				padding: { top: 36, right: 42, bottom: 44, left: 42 },
				maxZoom: 7.4,
				duration: 0
			}
		);
	};

	const addMunicipiosPmtiles = () => {
		if (!map || !pmtilesUrl) return false;
		try {
			map.addSource(municipiosPmtilesSourceId, {
				type: 'vector',
				url: `pmtiles://${pmtilesUrl}`,
				promoteId: 'id'
			});
			activeMunicipiosSourceId = municipiosPmtilesSourceId;
			activeMunicipiosSourceLayer = sourceLayerName;

			map.addLayer({
				id: municipiosPolygonsFillLayerId,
				type: 'fill',
				source: municipiosPmtilesSourceId,
				'source-layer': sourceLayerName,
				minzoom: municipiosMinVisibleZoom,
				paint: {
					'fill-color': paintColorExpression as any,
					'fill-opacity': 0.62
				}
			});

			map.addLayer({
				id: municipiosPolygonsLineLayerId,
				type: 'line',
				source: municipiosPmtilesSourceId,
				'source-layer': sourceLayerName,
				minzoom: municipiosMinVisibleZoom,
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
				const selected = findMunicipioByFeatureId(
					feature.id ?? feature.properties?.id ?? feature.properties?.codigo
				);
				if (selected) onMapSelection(selected);
			});

			return true;
		} catch (error) {
			console.error('PMTiles de municipios no disponible; no se cargara fallback GeoJSON.', error);
			return false;
		}
	};

	const ensureOptionalOverlayLayer = async (target: 'forest' | 'landuse' | 'vegetation') => {
		if (!map || loadedOverlayLayers[target]) return;

		if (target === 'landuse') {
			try {
				if (!map.getSource(landUsePmtilesSourceId)) {
					map.addSource(landUsePmtilesSourceId, {
						type: 'vector',
						url: 'pmtiles:///tiles/usos_suelo.pmtiles'
					});
				}
				if (!map.getLayer(landUseLayerId)) {
					map.addLayer({
						id: landUseLayerId,
						type: 'fill',
						source: landUsePmtilesSourceId,
						'source-layer': landUseSourceLayerName,
						minzoom: 7,
						paint: {
							'fill-color': landUseFillColorExpression as any,
							'fill-opacity': 0.52,
							'fill-outline-color': 'rgba(34,34,34,0.45)'
						}
					});
				}
				loadedOverlayLayers = { ...loadedOverlayLayers, landuse: true };
				applyLayerOrdering();
			} catch (_error) {
				// optional layers are best effort
			}
			return;
		}

		console.warn(`Capa ${target} desactivada: requiere PMTiles dedicado (sin fallback GeoJSON).`);
	};

	const addIgnHydroWmsLayers = () => {
		if (!map) return;

		map.addSource(ignRiversSourceId, {
			type: 'raster',
			tiles: [
				'https://servicios.idee.es/wms-inspire/hidrografia?service=WMS&request=GetMap&layers=HY.Network&styles=&format=image/png&transparent=true&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'
			],
			tileSize: 256
		});

		map.addSource(ignReservoirsSourceId, {
			type: 'raster',
			tiles: [
				'https://servicios.idee.es/wms-inspire/hidrografia?service=WMS&request=GetMap&layers=HY.PhysicalWaters.Waterbodies&styles=&format=image/png&transparent=true&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'
			],
			tileSize: 256
		});

		map.addLayer({
			id: ignReservoirsLayerId,
			type: 'raster',
			source: ignReservoirsSourceId,
			paint: { 'raster-opacity': 0.78 }
		});

		map.addLayer({
			id: ignRiversLayerId,
			type: 'raster',
			source: ignRiversSourceId,
			paint: { 'raster-opacity': 0.82 }
		});
	};

	const addProvinciasBoundaries = () => {
		if (!map) return;
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
					'line-color': '#ffffff',
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1, 7, 2],
					'line-opacity': 1
				}
			});
		} catch (error) {
			console.error('No se pudo cargar provincias PMTiles (sin fallback GeoJSON).', error);
		}
	};

	const registerPmtiles = () => {
		const protocol = new Protocol();
		maplibregl.addProtocol('pmtiles', protocol.tile);
		return () => maplibregl.removeProtocol('pmtiles');
	};

		onMount(() => {
		const unregisterPmtiles = registerPmtiles();
		initialBoundsApplied = false;

		map = new maplibregl.Map({
			container: mapContainer,
			style: baseStyle,
			center: [-4.7, 41.8],
			zoom: 6,
			attributionControl: false
		});

		map.addControl(new maplibregl.NavigationControl(), 'top-right');

		map.on('load', () => {
			mapReady = false;
			isMapLoading = true;
			map.addSource(ignSatelliteSourceId, {
				type: 'raster',
				tiles: [
					'https://www.ign.es/wms-inspire/pnoa-ma?service=WMS&request=GetMap&layers=OI.OrthoimageCoverage&styles=&format=image/jpeg&transparent=false&version=1.3.0&crs=EPSG:3857&width=256&height=256&bbox={bbox-epsg-3857}'
				],
				tileSize: 256
			});

			map.addLayer({
				id: ignSatelliteLayerId,
				type: 'raster',
				source: ignSatelliteSourceId,
				paint: { 'raster-opacity': 1 }
			});

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

			addMunicipiosPmtiles();
			addIgnHydroWmsLayers();
			addProvinciasBoundaries();

			map.addSource(municipiosSourceId, {
				type: 'geojson',
				data: toFeatureCollection(municipios) as any
			});

			setLayerVisibility(ignWmsLayerId, showIgnWmsBase);
			setLayerVisibility(ignSatelliteLayerId, showIgnSatellite);
			setLayerVisibility(ignRiversLayerId, showIgnRivers);
			setLayerVisibility(ignReservoirsLayerId, showIgnReservoirs);
			setLayerVisibility(municipiosPolygonsFillLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosPolygonsLineLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosHoverLineLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosSelectedLineLayerId, showMunicipioPolygons);
			applyPolygonFilter();
			applyLayerOrdering();
			applyMaxBoundsToMunicipios();

			map.on('click', (event) => {
				const hits = map.queryRenderedFeatures(event.point, {
					layers: [municipiosPolygonsFillLayerId]
				});
				if (hits.length === 0) onMapSelection(null);
			});

			map.on('mouseenter', municipiosPolygonsFillLayerId, () => {
				map.getCanvas().style.cursor = 'pointer';
			});

			map.on('mousemove', municipiosPolygonsFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
				const feature = e.features?.[0];
				const nextHoveredId = feature
					? (feature.id ?? feature.properties?.id ?? feature.properties?.codigo ?? null)
					: null;
				if (nextHoveredId === hoveredFeatureId) return;
				setHoverFeatureState(nextHoveredId);
			});

			map.on('mouseleave', municipiosPolygonsFillLayerId, () => {
				map.getCanvas().style.cursor = '';
				setHoverFeatureState(null);
			});

			mapReady = true;
			if (!initialBoundsApplied) {
				fitToMunicipios();
				initialBoundsApplied = true;
			}
			isMapLoading = false;
		});

		map.on('dataloading', () => {
			isMapLoading = true;
		});

		map.on('idle', () => {
			isMapLoading = false;
		});

		return () => {
			mapReady = false;
			initialBoundsApplied = false;
			unregisterPmtiles();
			map?.remove();
		};
	});

	$effect(() => {
		refreshMunicipiosSource();
		applyMaxBoundsToMunicipios();
	});

	$effect(() => {
		applyPolygonFilter();
	});

	$effect(() => {
		if (!map) return;
		setLayerVisibility(ignWmsLayerId, showIgnWmsBase);
		setLayerVisibility(ignSatelliteLayerId, showIgnSatellite);
		setLayerVisibility(ignRiversLayerId, showIgnRivers);
		setLayerVisibility(ignReservoirsLayerId, showIgnReservoirs);
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
		if (showForestLayer) void ensureOptionalOverlayLayer('forest');
		if (showLandUseLayer) void ensureOptionalOverlayLayer('landuse');
		if (showVegetationLayer) void ensureOptionalOverlayLayer('vegetation');
		applyLayerOrdering();
	});

	$effect(() => {
		const colorExpr = paintColorExpression;
		if (!mapReady || !map || !map.getLayer(municipiosPolygonsFillLayerId)) return;
		map.setPaintProperty(municipiosPolygonsFillLayerId, 'fill-color', colorExpr as any);
	});

	$effect(() => {
		syncHighlightFilters();
	});

	$effect(() => {
		applyLayerOrdering();
	});

	$effect(() => {
		if (!map || !selectedMunicipio) return;
		if (!Number.isFinite(selectedMunicipio.lon) || !Number.isFinite(selectedMunicipio.lat)) return;
		map.flyTo({ center: [selectedMunicipio.lon, selectedMunicipio.lat], zoom: 9, speed: 0.8 });
	});

	$effect(() => {
		if (!map || !mapReady) return;
		if (selectedMunicipio) return;

		if (provinceFilter === 'Todas') {
			if (lastFittedProvince !== null) {
				fitToMunicipios();
			}
			lastFittedProvince = null;
			return;
		}

		if (lastFittedProvince === provinceFilter) return;

		const provincePoints = municipios.filter(
			(m) => m.provincia === provinceFilter && Number.isFinite(m.lon) && Number.isFinite(m.lat)
		);
		if (provincePoints.length === 0) return;

		let minLon = Infinity;
		let maxLon = -Infinity;
		let minLat = Infinity;
		let maxLat = -Infinity;

		for (const point of provincePoints) {
			if (point.lon < minLon) minLon = point.lon;
			if (point.lon > maxLon) maxLon = point.lon;
			if (point.lat < minLat) minLat = point.lat;
			if (point.lat > maxLat) maxLat = point.lat;
		}

		if (!Number.isFinite(minLon + maxLon + minLat + maxLat)) return;

		const lonPad = Math.max((maxLon - minLon) * 0.12, 0.08);
		const latPad = Math.max((maxLat - minLat) * 0.12, 0.06);

		map.fitBounds(
			[
				[Math.max(-180, minLon - lonPad), Math.max(-85, minLat - latPad)],
				[Math.min(180, maxLon + lonPad), Math.min(85, maxLat + latPad)]
			],
			{
				padding: { top: 42, right: 40, bottom: 42, left: 40 },
				maxZoom: 9,
				duration: 500
			}
		);

		lastFittedProvince = provinceFilter;
	});
</script>

<div class="map-shell">
	<MapHeader {legendConfig} />
	<div class="map-frame">
		<div class="map" bind:this={mapContainer} aria-label="Mapa principal"></div>
		{#if isMapLoading}
			<MapLoadingBadge />
		{/if}
	</div>
	{#if showLandUseLayer}
		<LandUseLegend palette={landUsePalette} />
	{/if}
</div>

<style>
	.map-shell {
		height: 100%;
		min-height: 0;
		position: relative;
		padding: 1rem;
		display: grid;
		grid-template-rows: auto minmax(0, 1fr);
		gap: 0.6rem;
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

	.map-frame {
		position: relative;
		min-height: 0;
		height: 100%;
	}

	@media (max-width: 900px) {
		.map-shell {
			padding: 0.7rem;
			min-height: 52dvh;
			grid-template-rows: minmax(0, 1fr);
			gap: 0;
		}
	}
</style>

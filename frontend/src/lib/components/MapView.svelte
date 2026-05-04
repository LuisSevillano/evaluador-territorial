<script lang="ts">
	import { onMount } from 'svelte';
	import maplibregl from 'maplibre-gl';
	import { Protocol } from 'pmtiles';
	import type { FeatureCollection, Point } from 'geojson';
	import type { Municipio } from '$lib/types/municipio';
	import { normalizeProvinceName } from '$lib/state/provinces';
	import LandUseLegend from '$lib/components/map/LandUseLegend.svelte';
	import MapLoadingBadge from '$lib/components/map/MapLoadingBadge.svelte';
	import ViewControl from '$lib/components/map/ViewControl.svelte';
	import {
		type MapColorMetric,
		buildMunicipioColorExpression,
		getScoreThresholdsForMunicipios,
		scoreColors,
		missingDataColor
	} from '$lib/components/map/coloring';
	import 'maplibre-gl/dist/maplibre-gl.css';
	import { type MapViewMode } from '$lib/state/mapViewMode';

	import { bucketOrder, type TravelBucketFilter } from '$lib/state/filters';

	type Props = {
		municipios?: Municipio[];
		allMunicipios?: Municipio[];
		selectedMunicipio?: Municipio | null;
		showMunicipioPolygons?: boolean;
		showIsochronesLayer?: boolean;
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
		maxTravelBucket?: TravelBucketFilter;
		pmtilesUrl?: string;
		onMapSelection?: (municipio: Municipio | null) => void;
		onToggleIgnSatellite?: (visible: boolean) => void;
		onToggleIgnWmsBase?: (visible: boolean) => void;
		isMobileView?: boolean;
		isBottomSheetOpen?: boolean;
		viewMode?: MapViewMode;
		onViewModeChange?: (mode: MapViewMode) => void;
	};

	let {
		municipios = [],
		allMunicipios,
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showIsochronesLayer = false,
		showMunicipioPoints = true,
		showIgnWmsBase = false,
		showIgnSatellite = false,
		showIgnRivers = false,
		showIgnReservoirs = false,
		mapColorMetric = 'mixed_score',
		showForestLayer = false,
		showLandUseLayer = false,
		showVegetationLayer = false,
		layerOrder = ['municipios', 'isochrones', 'landuse', 'reservoirs', 'rivers'],
		visibleMunicipioIds = [],
		provinceFilter = 'Todas',
		maxTravelBucket = null,
		pmtilesUrl = '/tiles/municipios.pmtiles',
		onMapSelection = () => undefined,
		onToggleIgnSatellite = () => undefined,
		onToggleIgnWmsBase = () => undefined,
		isMobileView = false,
		isBottomSheetOpen = false,
		viewMode: viewModeProp = 'auto',
		onViewModeChange = () => undefined
	}: Props = $props();

	let mapContainer: HTMLDivElement;
	let map: maplibregl.Map;
	let mapReady = $state(false);
	let hasInitialHashView = $state(false);
	let lockAutoFitFromHash = $state(false);

	const viewMode = $derived(viewModeProp ?? 'auto');

	const municipiosSourceId = 'municipios-centroides-source';
	const municipiosLayerId = 'municipios-centroides-layer';
	const municipiosPmtilesSourceId = 'municipios-pmtiles-source';
	const municipiosPolygonsFillLayerId = 'municipios-polygons-fill-layer';
	const municipiosPolygonsLineLayerId = 'municipios-polygons-line-layer';
	const isochroneLayers = [
		{
			key: 'iso_04h00m',
			sourceId: 'isochrones-04h00m-source',
			layerId: 'isochrones-04h00m-line',
			url: '/data/isochrones/iso_diff_03h30m_04h00m.geojson',
			color: '#7b1f1f'
		},
		{
			key: 'iso_03h30m',
			sourceId: 'isochrones-03h30m-source',
			layerId: 'isochrones-03h30m-line',
			url: '/data/isochrones/iso_diff_02h30m_03h30m.geojson',
			color: '#d97706'
		},
		{
			key: 'iso_02h30m',
			sourceId: 'isochrones-02h30m-source',
			layerId: 'isochrones-02h30m-line',
			url: '/data/isochrones/iso_diff_02h00m_02h30m.geojson',
			color: '#4d7c0f'
		},
		{
			key: 'iso_02h00m',
			sourceId: 'isochrones-02h00m-source',
			layerId: 'isochrones-02h00m-line',
			url: '/data/isochrones/iso_diff_01h30m_02h00m.geojson',
			color: '#1f8a70'
		},
		{
			key: 'iso_01h30m',
			sourceId: 'isochrones-01h30m-source',
			layerId: 'isochrones-01h30m-line',
			url: '/data/isochrones/iso_diff_01h30m.geojson',
			color: '#0f4c5c'
		}
	] as const;
	const municipiosHoverLineLayerId = 'municipios-polygons-hover-line-layer';
	const municipiosSelectedLineLayerId = 'municipios-polygons-selected-line-layer';
	const provinciasPmtilesSourceId = 'provincias-pmtiles-source';
	const provinciasGeojsonSourceId = 'provincias-geojson-source';
	const provinciasLineLayerId = 'provincias-line-layer';
	const ccaaPmtilesSourceId = 'ccaa-pmtiles-source';
	const ccaaLineLayerId = 'ccaa-line-layer';
	const gridPmtilesSourceId = 'grid-pmtiles-source';
	const gridFillLayerId = 'grid-fill-layer';
	const gridLineLayerId = 'grid-line-layer';
	const gridHoverLineLayerId = 'grid-hover-line-layer';
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
	const ccaaSourceLayerName = 'ccaa';
	const municipiosMinVisibleZoom = 5;
	let hoveredFeatureId: string | number | null = null;
	let hoveredFeatureSource: string = municipiosPmtilesSourceId;
	let hoveredFeatureSourceLayer: string = sourceLayerName;
	let isMapLoading = $state(true);
	let loadedOverlayLayers = $state({ forest: false, landuse: false, vegetation: false });
	let lastSelectedFilterId: string | null = null;
	let activeMunicipiosSourceId = municipiosPmtilesSourceId;
	let activeMunicipiosSourceLayer: string | undefined = sourceLayerName;
	let initialBoundsApplied = $state(false);
	let lastAutoFitSignature = $state('');

	const GRID_MIN_ZOOM = 6;
	const GRID_FORCE_MIN_ZOOM = 6;
	let currentZoom = $state(0);
	let activeGridPmtilesPath = $state('/tiles/grid/grid_norte.pmtiles');

	$effect(() => {
		if (provinceFilter === 'Todas' && viewMode === 'grid' && currentZoom < GRID_MIN_ZOOM) {
			if (viewModeProp !== 'auto') {
				onViewModeChange('auto');
			}
		}
	});

	const visibility = $derived.by(() => {
		const gridVisible =
			viewMode === 'grid' ||
			(viewMode === 'auto' && currentZoom >= GRID_MIN_ZOOM);

		const municipalityFillVisible =
			viewMode === 'municipality' ||
			(viewMode === 'auto' && !gridVisible);

		return {
			gridVisible,
			municipalityFillVisible: municipalityFillVisible,
			municipalityLineVisible: true,
			showBoundaries: true
		};
	});

	const controlViewMode = $derived.by(() => {
		if (viewMode !== 'auto') return viewMode;
		return visibility.gridVisible ? 'grid' : 'municipality';
	});

	const applyVisibilityBasedOnMode = () => {
		if (!map) return;
		const v = visibility;
		const showGrid = v.gridVisible;
		const showMunicipios = showMunicipioPolygons && v.municipalityFillVisible;
		setLayerVisibility(municipiosPolygonsFillLayerId, showMunicipios);
		setLayerVisibility(municipiosPolygonsLineLayerId, showMunicipios);
		setLayerVisibility(gridFillLayerId, showGrid);
		setLayerVisibility(gridLineLayerId, showGrid || v.municipalityLineVisible);
		setLayerVisibility(gridHoverLineLayerId, showGrid);
	};



	const paintColorExpression = $derived.by(() =>
		buildMunicipioColorExpression(municipios, mapColorMetric)
	);

	const gridFillColorExpression = $derived.by(() => {
		if (mapColorMetric !== 'mixed_score') {
			return missingDataColor;
		}

		const thresholds = getScoreThresholdsForMunicipios(municipios);
		return [
			'case',
			['!', ['has', 'mixed_score']],
			missingDataColor,
			[
				'step',
				['to-number', ['get', 'mixed_score']],
				scoreColors[0],
				thresholds[0],
				scoreColors[1],
				thresholds[1],
				scoreColors[2],
				thresholds[2],
				scoreColors[3],
				thresholds[3],
				scoreColors[4]
			]
		] as any;
	});

	const applyGridFillPaint = () => {
		if (!map || !map.getLayer(gridFillLayerId)) return;
		map.setPaintProperty(gridFillLayerId, 'fill-color', gridFillColorExpression);
	};

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
				(m) =>
					Number.parseInt(m.id, 10) === numericId || Number.parseInt(m.codigo, 10) === numericId
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

	const setHoverFeatureState = (
		nextId: string | number | null,
		source: string = activeMunicipiosSourceId,
		sourceLayer: string = activeMunicipiosSourceLayer ?? sourceLayerName
	) => {
		if (!map) return;
		if (hoveredFeatureId !== null) {
			const prevTarget: any = { source: hoveredFeatureSource, id: hoveredFeatureId };
			prevTarget.sourceLayer = hoveredFeatureSourceLayer;
			map.setFeatureState(prevTarget, { hover: false });
		}

		hoveredFeatureId = nextId;
		hoveredFeatureSource = source;
		hoveredFeatureSourceLayer = sourceLayer;

		if (hoveredFeatureId !== null) {
			const nextTarget: any = { source, id: hoveredFeatureId };
			nextTarget.sourceLayer = sourceLayer;
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
		isochrones: isochroneLayers[0].layerId,
		landuse: landUseLayerId,
		vegetation: vegetationLayerId,
		forest: forestLayerId,
		reservoirs: ignReservoirsLayerId,
		rivers: ignRiversLayerId
	};

	const applyLayerOrdering = () => {
		if (!map) return;
		for (const layerKey of layerOrder) {
			if (layerKey === 'isochrones') {
				for (const isochrone of isochroneLayers) {
					if (map.getLayer(isochrone.layerId))
						map.moveLayer(isochrone.layerId, ccaaLineLayerId);
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

	const getMunicipiosBounds = (data?: Municipio[]) => {
		const source = data ?? allMunicipios ?? municipios;
		if (source.length === 0) return null;

		const points = source.filter((m) => Number.isFinite(m.lon) && Number.isFinite(m.lat));
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
		const padLon = Math.max(lonSpan * 0.45, 0.55);
		const padLat = Math.max(latSpan * 0.45, 0.38);

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
		const bounds = getMunicipiosBounds(allMunicipios);
		if (!bounds) return;
		map.setMaxBounds(bounds.padded as maplibregl.LngLatBoundsLike);
	};

	const fitToMunicipios = () => {
		if (!map) return;
		const bounds = getMunicipiosBounds(getWorkingMunicipios());
		if (!bounds) return;

		map.fitBounds(bounds.raw, {
			padding: getFitPadding(),
			maxZoom: 7.4,
			duration: 0
		});
	};

	const getWorkingMunicipios = () => {
		const source = municipios;
		if (source.length === 0) return source;
		if (!visibleMunicipioIds || visibleMunicipioIds.length === 0) return source;

		const idSet = new Set(visibleMunicipioIds);
		const filtered = source.filter((m) => idSet.has(m.id) || idSet.has(m.codigo));
		return filtered.length > 0 ? filtered : source;
	};

	const getFitPadding = (): maplibregl.PaddingOptions => {
		if (isMobileView) {
			return {
				top: 72,
				right: 24,
				bottom: isBottomSheetOpen ? 300 : 120,
				left: 24
			};
		}

		return {
			top: 56,
			right: 88,
			bottom: 70,
			left: 88
		};
	};

	const autoFitToWorkingMunicipios = (duration = 450) => {
		if (!map || !mapReady || selectedMunicipio) return;
		const bounds = getMunicipiosBounds(getWorkingMunicipios());
		if (!bounds) return;

		const signature = [
			isMobileView ? 'm' : 'd',
			isBottomSheetOpen ? 'open' : 'closed',
			provinceFilter,
			String(visibleMunicipioIds.length),
			...bounds.raw.flat().map((n) => n.toFixed(4))
		].join('|');

		if (signature === lastAutoFitSignature) return;

		map.fitBounds(bounds.raw, {
			padding: getFitPadding(),
			maxZoom: normalizeProvinceName(provinceFilter) === 'Todas' ? 7.4 : 9,
			duration
		});

		lastAutoFitSignature = signature;
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
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.28, 9, 0.95],
					'line-opacity': 0.56
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
			console.error('PMTiles de municipios no disponible; no se cargará fallback GeoJSON.', error);
			return false;
		}
	};

	const addIsochroneLayers = () => {
		if (!map) return;
		for (const isochrone of isochroneLayers) {
			try {
				if (!map.getSource(isochrone.sourceId)) {
					map.addSource(isochrone.sourceId, {
						type: 'geojson',
						data: isochrone.url
					});
				}
				if (!map.getLayer(isochrone.layerId)) {
					map.addLayer({
						id: isochrone.layerId,
						type: 'line',
						source: isochrone.sourceId,
						paint: {
							'line-color': isochrone.color,
							'line-width': ['interpolate', ['linear'], ['zoom'], 5, 1.2, 8, 2.4, 10, 3.6],
							'line-opacity': 0.9
						}
					});
				}
			} catch (error) {
				console.error(`No se pudo cargar ${isochrone.url}`, error);
			}
		}
	};

	const setIsochroneVisibility = (visible: boolean) => {
		if (!map) return;
		for (const isochrone of isochroneLayers) {
			setLayerVisibility(isochrone.layerId, visible);
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
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1, 7, 1.5],
					'line-opacity': 1
				}
			});
		} catch (error) {
			console.error('No se pudo cargar provincias PMTiles (sin fallback GeoJSON).', error);
		}
	};

	const addGridPmtiles = () => {
		if (!map) return;
		if (map.getSource(gridPmtilesSourceId)) return;
		try {
			map.addSource(gridPmtilesSourceId, {
				type: 'vector',
				url: `pmtiles://${activeGridPmtilesPath}`,
				promoteId: 'cell_id',
				minzoom: GRID_FORCE_MIN_ZOOM,
				maxzoom: 14
			});

			map.addLayer({
				id: gridLineLayerId,
				type: 'line',
				source: gridPmtilesSourceId,
				'source-layer': 'grid',
				paint: {
					'line-color': '#a1a1aa',
					'line-width': ['interpolate', ['linear'], ['zoom'], 7, 0.18, 14, 1.2],
					'line-opacity': ['interpolate', ['linear'], ['zoom'], 7, 0.06, 12, 0.42]
				}
			});

			map.addLayer({
				id: gridFillLayerId,
				type: 'fill',
				source: gridPmtilesSourceId,
				'source-layer': 'grid',
				paint: {
					'fill-color': gridFillColorExpression,
					'fill-opacity': 0.62
				}
			});

			map.addLayer({
				id: gridHoverLineLayerId,
				type: 'line',
				source: gridPmtilesSourceId,
				'source-layer': 'grid',
				paint: {
					'line-color': '#ffffff',
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 2.2, 8, 4.2, 10, 5.4],
					'line-opacity': ['case', ['boolean', ['feature-state', 'hover'], false], 1, 0]
				}
			});

			applyGridFillPaint();
		} catch (error) {
			console.error('No se pudo cargar grid PMTiles.', error);
		}
	};

	const slugifyProvinceName = (value: string) =>
		value
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '')
			.replace(/\//g, '-')
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '_')
			.replace(/^_+|_+$/g, '');

	const resolveGridPmtilesPath = () => {
		const fromSelected = selectedMunicipio?.provincia?.trim();
		const fromFilter = provinceFilter && provinceFilter !== 'Todas' ? provinceFilter.trim() : null;
		const province = fromSelected || fromFilter;
		if (!province) return '/tiles/grid/grid_norte.pmtiles';
		return `/tiles/grid/provincias/grid_${slugifyProvinceName(province)}.pmtiles`;
	};

	const refreshGridSource = () => {
		if (!map) return;
		const nextPath = resolveGridPmtilesPath();
		if (nextPath === activeGridPmtilesPath) return;
		activeGridPmtilesPath = nextPath;

		const hadFill = Boolean(map.getLayer(gridFillLayerId));
		if (map.getLayer(gridFillLayerId)) map.removeLayer(gridFillLayerId);
		if (map.getLayer(gridLineLayerId)) map.removeLayer(gridLineLayerId);
		if (map.getLayer(gridHoverLineLayerId)) map.removeLayer(gridHoverLineLayerId);
		if (map.getSource(gridPmtilesSourceId)) map.removeSource(gridPmtilesSourceId);
		addGridPmtiles();
		if (hadFill) {
			applyGridFillPaint();
			applyGridFilter();
			applyVisibilityBasedOnMode();
			applyLayerOrdering();
		}
	};

	const parseHashView = (): { zoom: number; center: [number, number] } | null => {
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

	const writeHashView = () => {
		if (!map || typeof window === 'undefined') return;
		const center = map.getCenter();
		const zoom = map.getZoom();
		const nextHash = `#map=${zoom.toFixed(2)}/${center.lat.toFixed(5)}/${center.lng.toFixed(5)}`;
		if (window.location.hash !== nextHash) {
			history.replaceState(history.state, '', `${window.location.pathname}${window.location.search}${nextHash}`);
		}
	};


	const applyGridFilter = () => {
		if (!map) return;

		const setFilters = (expr: any) => {
			if (map.getLayer(gridFillLayerId)) map.setFilter(gridFillLayerId, expr);
			if (map.getLayer(gridLineLayerId)) map.setFilter(gridLineLayerId, expr);
			if (map.getLayer(gridHoverLineLayerId)) map.setFilter(gridHoverLineLayerId, expr);
		};

		if (selectedMunicipio?.id?.startsWith('cell_')) {
			setFilters(null);
			return;
		}

		const hasTravelFilter = maxTravelBucket !== null;
		const hasProvinceFilter = provinceFilter && provinceFilter !== 'Todas';
		const hasSelectedMunicipio = selectedMunicipio?.id || selectedMunicipio?.codigo;

		if (!visibility.gridVisible) {
			if (hasSelectedMunicipio) {
				const selectedId = selectedMunicipio?.id ?? selectedMunicipio?.codigo;
				if (!selectedId) {
					setFilters(null);
					return;
				}
				const numeric = Number.parseInt(selectedId, 10);
				const expr: any = Number.isFinite(numeric)
					? [
							'any',
							['==', ['to-string', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], selectedId],
							['==', ['to-number', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], numeric]
						]
					: ['==', ['to-string', ['coalesce', ['get', 'municipio_id'], ['get', 'codigo']]], selectedId];
				setFilters(expr);
			} else {
				setFilters(null);
			}
			return;
		}

		const filterParts: any[] = [];

		if (hasTravelFilter) {
			const selectedRank = bucketOrder[maxTravelBucket as keyof typeof bucketOrder] ?? 6;
			const isochroneExpr: any = [
				'in',
				['get', 'isochrone_bucket'],
				['literal', Object.entries(bucketOrder).filter(([, r]) => r <= selectedRank).map(([b]) => b)]
			];
			filterParts.push(isochroneExpr);
		}

		if (hasProvinceFilter) {
			const normalizedProvince = normalizeProvinceName(provinceFilter);
			const provinceExpr: any = ['==', ['get', 'provincia'], normalizedProvince];
			filterParts.push(provinceExpr);
		}

		if (filterParts.length === 0) {
			setFilters(null);
			return;
		}

		const finalExpr = filterParts.length === 1 ? filterParts[0] : ['all', ...filterParts];
		setFilters(finalExpr);
	};

	const addCcaaBoundaries = () => {
		if (!map) return;
		try {
			map.addSource(ccaaPmtilesSourceId, {
				type: 'vector',
				url: 'pmtiles:///tiles/ccaa.pmtiles'
			});
			map.addLayer({
				id: ccaaLineLayerId,
				type: 'line',
				source: ccaaPmtilesSourceId,
				'source-layer': ccaaSourceLayerName,
				paint: {
					'line-color': '#000000',
					'line-width': ['interpolate', ['linear'], ['zoom'], 4, 1, 8, 2],
					'line-opacity': 1
				}
			});
		} catch (error) {
			console.error('No se pudo cargar CCAA PMTiles (sin fallback GeoJSON).', error);
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
		hasInitialHashView = false;
		lockAutoFitFromHash = false;
		let resizeObserver: ResizeObserver | null = null;

		try {
			map = new maplibregl.Map({
				container: mapContainer,
				style: baseStyle,
				center: [-4.7, 41.8],
				zoom: 6,
				attributionControl: false
			});
		} catch (err) {
			console.error('Failed to initialize map:', err);
			isMapLoading = false;
			return;
		}

		const hashView = parseHashView();
		if (hashView) {
			hasInitialHashView = true;
			lockAutoFitFromHash = true;
			map.jumpTo({ center: hashView.center, zoom: hashView.zoom });
		}

		map.addControl(new maplibregl.NavigationControl(), 'top-right');

		map.on('webglcontextlost', () => {
			console.warn('WebGL context lost, attempting recovery...');
		});

		map.on('webglcontextrestored', () => {
			console.log('WebGL context restored, reinitializing...');
			map.remove();
			isMapLoading = true;
			mapReady = false;
			location.reload();
		});

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
			addGridPmtiles();
			addIgnHydroWmsLayers();
			addProvinciasBoundaries();
			addCcaaBoundaries();
			addIsochroneLayers();

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
			setIsochroneVisibility(showIsochronesLayer);
			setLayerVisibility(municipiosHoverLineLayerId, showMunicipioPolygons);
			setLayerVisibility(municipiosSelectedLineLayerId, showMunicipioPolygons);
			applyPolygonFilter();
			applyLayerOrdering();
			applyMaxBoundsToMunicipios();

			map.on('click', (event) => {
				const gridHits = map.queryRenderedFeatures(event.point, {
					layers: [gridFillLayerId, gridLineLayerId]
				});
				if (gridHits.length > 0) {
					const props = gridHits[0].properties;
					if (props?.cell_id) {
						const sourceMunicipios = (allMunicipios && allMunicipios.length > 0 ? allMunicipios : municipios) as Municipio[];
						const parentMunicipio = sourceMunicipios.find(
							(m) => String(m.codigo ?? m.id) === String(props.municipio_id)
						);
						const parentProvince = normalizeProvinceName(
							((parentMunicipio as any)?.provincia_nombre_geo ?? parentMunicipio?.provincia ?? props.provincia) as string
						);
						const cellAsMunicipio = {
							id: props.cell_id,
							codigo: props.municipio_id,
							nombre: props.municipio_nombre,
							provincia: parentProvince,
							population: undefined,
							mixed_score: props.mixed_score,
							precip_annual_mm: props.precip_annual ?? props.precip_annual_mm,
							temp_winter_mean_c: props.temp_winter,
							temp_summer_mean_c: props.temp_summer,
							temp_jan_mean_c: props.temp_winter,
							temp_jul_mean_c: props.temp_summer,
							travel_bucket: props.isochrone_bucket,
							forest_pct: props.natural_cover_pct,
							water_pct: undefined,
							artificial_pct: undefined,
							naturality_index: undefined,
							landcover_diversity: undefined,
							forest_norm: undefined,
							water_norm: undefined,
							artificial_norm: undefined,
							naturality_norm: props.natural_cover_norm,
							diversity_norm: undefined,
							river_access_norm: props.river_access_norm,
							river_access_score: props.river_access_score,
							river_access_class: props.river_buffer_class,
							river_nearest_name: undefined,
							river_nearest_distance_km: props.river_distance_km,
							climate_block_score: props.climate_block_score,
							access_block_score: props.access_block_score,
							nature_block_score: props.nature_block_score,
							dist_estacion_tren_km: undefined,
							dist_parada_bus_km: undefined,
							transporte_norm: props.accesibilidad_norm,
							dist_renfe_km: undefined,
							renfe_salidas_dia: undefined,
							renfe_tipo_servicio: undefined,
							servicio_renfe_norm: props.accesibilidad_norm,
							relieve_norm: 0.5,
							relieve_score_raw: undefined,
							iso_01h30m: props.isochrone_bucket === '<=1h30',
							iso_02h00m: props.isochrone_bucket === '<=2h00',
							iso_02h30m: props.isochrone_bucket === '<=2h30',
							iso_03h30m: props.isochrone_bucket === '<=3h30',
							iso_04h00m: props.isochrone_bucket === '<=4h00',
							precip_norm: props.precip_norm,
							temp_verano_norm: props.temp_verano_norm,
							temp_invierno_norm: props.temp_invierno_norm,
							accesibilidad_norm: props.accesibilidad_norm,
						} as unknown as Municipio;
						onMapSelection(cellAsMunicipio);
					}
					return;
				}

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

			map.on('mouseenter', gridFillLayerId, () => {
				map.getCanvas().style.cursor = 'pointer';
			});

			map.on('mousemove', gridFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
				const feature = e.features?.[0];
				const nextHoveredId = feature ? (feature.properties?.cell_id ?? null) : null;
				if (nextHoveredId === hoveredFeatureId) return;
				setHoverFeatureState(nextHoveredId, gridPmtilesSourceId, 'grid');
			});

			map.on('mouseleave', gridFillLayerId, () => {
				map.getCanvas().style.cursor = '';
				setHoverFeatureState(null, gridPmtilesSourceId, 'grid');
			});

			mapReady = true;
			if (!initialBoundsApplied && !hasInitialHashView) {
				fitToMunicipios();
				lastAutoFitSignature = '';
				initialBoundsApplied = true;
			} else if (!initialBoundsApplied) {
				initialBoundsApplied = true;
			}
			isMapLoading = false;
		});

		map.on('zoomend', () => {
			currentZoom = map.getZoom();
			writeHashView();
		});

		map.on('moveend', () => {
			writeHashView();
		});

		map.on('dragstart', () => {
			lockAutoFitFromHash = false;
		});

		map.on('zoomstart', () => {
			lockAutoFitFromHash = false;
		});

		map.on('dataloading', () => {
			isMapLoading = true;
		});

		map.on('idle', () => {
			isMapLoading = false;
		});

		if (typeof ResizeObserver !== 'undefined') {
			resizeObserver = new ResizeObserver(() => {
				if (!map) return;
				requestAnimationFrame(() => {
					if (!map || !mapContainer) return;
					if (mapContainer.clientWidth === 0 || mapContainer.clientHeight === 0) return;
					map.resize();
				});
			});
			resizeObserver.observe(mapContainer);
		}

		return () => {
			mapReady = false;
			initialBoundsApplied = false;
			resizeObserver?.disconnect();
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
		const gridActive = visibility.gridVisible;
		const showMunicipiosPolygons = showMunicipioPolygons && !gridActive;
		setLayerVisibility(municipiosPolygonsFillLayerId, showMunicipiosPolygons);
		setLayerVisibility(municipiosPolygonsLineLayerId, showMunicipiosPolygons);
		setIsochroneVisibility(showIsochronesLayer);
		setLayerVisibility(municipiosHoverLineLayerId, showMunicipiosPolygons);
		setLayerVisibility(municipiosSelectedLineLayerId, showMunicipiosPolygons);
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
		if (!mapReady || !map || !map.getLayer(gridFillLayerId)) return;
		applyGridFillPaint();
	});

	$effect(() => {
		syncHighlightFilters();
	});

	$effect(() => {
		if (!map) return;
		applyVisibilityBasedOnMode();
		applyGridFilter();
		applyLayerOrdering();
	});

	$effect(() => {
		if (!map || !mapReady) return;
		const province = selectedMunicipio?.provincia ?? provinceFilter;
		refreshGridSource();
	});

	$effect(() => {
		if (!map || !selectedMunicipio) return;
		if (!Number.isFinite(selectedMunicipio.lon) || !Number.isFinite(selectedMunicipio.lat)) return;
		map.flyTo({ center: [selectedMunicipio.lon, selectedMunicipio.lat], zoom: 9, speed: 0.8 });
	});

	$effect(() => {
		if (!map || !mapReady) return;
		if (selectedMunicipio) return;
		if (lockAutoFitFromHash) return;
		if (hasInitialHashView) {
			hasInitialHashView = false;
			return;
		}
		autoFitToWorkingMunicipios();
	});
</script>

<div class="map-shell">
	<div class="map-frame">
		<div class="map" bind:this={mapContainer} aria-label="Mapa principal"></div>
		<div class="map-overlay-stack">
			<div class="map-quick-controls" role="group" aria-label="Controles rápidos del mapa">
				<button
					type="button"
					class:active={showIgnWmsBase && !showIgnSatellite}
					onclick={() => {
						onToggleIgnWmsBase(true);
						onToggleIgnSatellite(false);
					}}
				>
					Base IGN
				</button>
				<button
					type="button"
					class:active={showIgnSatellite}
					onclick={() => {
						onToggleIgnSatellite(true);
						onToggleIgnWmsBase(false);
					}}
				>
					Satelite
				</button>
			</div>
			<ViewControl
				viewMode={viewMode}
				autoResolvedMode={controlViewMode === 'grid' ? 'grid' : 'municipality'}
				gridMinZoom={currentZoom}
				onChange={(mode) => {
					onViewModeChange(mode);
				}}
			/>
			{#if isMapLoading}
				<MapLoadingBadge />
			{/if}
		</div>
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
		display: block;
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

	.map-quick-controls {
		z-index: 8;
		display: inline-flex;
		gap: 0;
		padding: 0.18rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.26);
		background: rgba(255, 252, 245, 0.9);
		box-shadow: 0 4px 10px rgba(16, 44, 54, 0.2);
	}

	.map-quick-controls button {
		width: auto;
		border: 0;
		background: transparent;
		color: #3f5652;
		font-size: 0.74rem;
		font-weight: 600;
		padding: 0.34rem 0.72rem;
		border-radius: 999px;
		cursor: pointer;
		transition:
			background-color 180ms ease,
			color 180ms ease;
	}

	.map-quick-controls button.active {
		background: #2f7d85;
		color: #f7f4ec;
	}

	.map-overlay-stack {
		position: absolute;
		top: 0.9rem;
		left: 0.9rem;
		z-index: 20;
		display: grid;
		gap: 0.35rem;
		justify-items: start;
	}

	@media (max-width: 900px) {
		.map-shell {
			padding: 0.7rem;
			min-height: 52dvh;
		}

		.map-overlay-stack {
			top: 0.8rem;
			left: 0.8rem;
		}
	}
</style>

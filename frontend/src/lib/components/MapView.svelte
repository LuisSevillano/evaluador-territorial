<script lang="ts">
	import { onMount } from 'svelte';
	import maplibregl from 'maplibre-gl';
	import type { Point } from 'geojson';
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
	import {
		ccaaLineLayerId,
		ccaaPmtilesSourceId,
		ccaaSourceLayerName,
		GRID_FORCE_MIN_ZOOM,
		gridFillLayerId,
		gridHoverLineLayerId,
		gridLineLayerId,
		gridPmtilesSourceId,
		ignReservoirsLayerId,
		ignReservoirsSourceId,
		ignRiversLayerId,
		ignRiversSourceId,
		ignSatelliteLayerId,
		ignSatelliteSourceId,
		ignWmsLayerId,
		ignWmsSourceId,
		isochroneLayers,
		landUseFillColorExpression,
		landUseLayerId,
		landUsePalette,
		landUsePmtilesSourceId,
		landUseSourceLayerName,
		municipiosHoverLineLayerId,
		municipiosLayerId,
		municipiosMinVisibleZoom,
		municipiosPmtilesSourceId,
		municipiosPolygonsFillLayerId,
		municipiosPolygonsLineLayerId,
		municipiosSelectedLineLayerId,
		municipiosSourceId,
		provinciasLineLayerId,
		provinciasPmtilesSourceId,
		provinciasSourceLayerName,
		sourceLayerName,
		vegetationLayerId,
		forestLayerId
	} from '$lib/components/map/mapConfig';
	import {
		buildIdFilterExpression,
		setLayerVisibility,
		slugifyProvinceName,
		toFeatureCollection
	} from '$lib/components/map/mapUtils';
	import {
		centerToBounds,
		getAutoFitZoom,
		getMunicipiosBounds
	} from '$lib/components/map/mapViewport';
	import {
		addCcaaBoundaries as addCcaaBoundariesLayer,
		addGridPmtiles as addGridPmtilesLayer,
		addIgnHydroWmsLayers as addIgnHydroWmsLayersLayer,
		addIsochroneLayers as addIsochroneLayersLayer,
		addProvinciasBoundaries as addProvinciasBoundariesLayer,
		ensureLandUseLayer
	} from '$lib/components/map/mapLayers';
	import { registerMapInteractions } from '$lib/components/map/mapInteractions';
	import { applyGridFilter as applyGridFilterHelper } from '$lib/components/map/mapFilters';
	import { applyLayerOrdering as applyLayerOrderingHelper } from '$lib/components/map/mapOrdering';
	import { applyPolygonFilter as applyPolygonFilterHelper } from '$lib/components/map/mapPolygonFilters';
	import { registerPmtilesProtocol, writeHashView } from '$lib/components/map/mapBootstrap';
	import { createMapInstance } from '$lib/components/map/mapRuntime';
	import 'maplibre-gl/dist/maplibre-gl.css';
	import { type MapViewMode } from '$lib/state/mapViewMode';

	import { type TravelBucketFilter } from '$lib/state/filters';

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

	const provinciasGeojsonSourceId = 'provincias-geojson-source';
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

	const getGridMinZoom = () => (isMobileView ? 8.5 : 6);
	let currentZoom = $state(0);
	let activeGridPmtilesPath = $state('/tiles/grid/grid_norte.pmtiles');

	$effect(() => {
		if (provinceFilter === 'Todas' && viewMode === 'grid' && currentZoom < getGridMinZoom()) {
			if (viewModeProp !== 'auto') {
				onViewModeChange('auto');
			}
		}
	});

	const visibility = $derived.by(() => {
		const gridVisible =
			viewMode === 'grid' || (viewMode === 'auto' && currentZoom >= getGridMinZoom());

		const municipalityFillVisible =
			viewMode === 'municipality' || (viewMode === 'auto' && !gridVisible);

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
		setLayerVisibility(map, municipiosPolygonsFillLayerId, showMunicipios);
		setLayerVisibility(map, municipiosPolygonsLineLayerId, showMunicipios);
		setLayerVisibility(map, gridFillLayerId, showGrid);
		setLayerVisibility(map, gridLineLayerId, showGrid || v.municipalityLineVisible);
		setLayerVisibility(map, gridHoverLineLayerId, showGrid);
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


	const refreshMunicipiosSource = () => {
		if (!map) return;
		const source = map.getSource(municipiosSourceId) as maplibregl.GeoJSONSource | undefined;
		if (!source) return;
		source.setData(toFeatureCollection(municipios) as any);
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
				'line-color': '#ffffff',
				'line-width': ['interpolate', ['linear'], ['zoom'], 4, 2.4, 9, 4.6],
				'line-opacity': 1
			},
			filter: buildIdFilterExpression(null) as any
		});
	};

	const applyLayerOrdering = () => {
		if (!map) return;
		applyLayerOrderingHelper(map, layerOrder);
	};

	const applyPolygonFilter = () => {
		if (!map) return;
		applyPolygonFilterHelper(
			map,
			visibleMunicipioIds,
			municipios.length,
			municipiosPolygonsFillLayerId,
			municipiosPolygonsLineLayerId,
			syncHighlightFilters
		);
	};

	const applyMaxBoundsToMunicipios = () => {
		if (!map) return;

		if (isMobileView) {
			map.setMaxBounds(null);
			return;
		}

		const source = allMunicipios ?? municipios;
		const munBounds = getMunicipiosBounds(source);
		if (!munBounds) return;
		map.setMaxBounds(munBounds.padded as maplibregl.LngLatBoundsLike);
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

	const centerOnMunicipios = () => {
		if (!map) return;
		const bounds = getMunicipiosBounds(getWorkingMunicipios());
		if (!bounds) return;
		const zoom = isMobileView ? 5.2 : 5.8;
		centerToBounds(map, bounds, zoom, 0);
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
				bottom: isBottomSheetOpen ? 380 : 180,
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

		if (isMobileView) {
			const zoom = getAutoFitZoom(provinceFilter);
			centerToBounds(map, bounds, zoom, duration);
		} else {
			map.fitBounds(bounds.raw, {
				padding: getFitPadding(),
				maxZoom: normalizeProvinceName(provinceFilter) === 'Todas' ? 7.4 : 9,
				duration
			});
		}

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
		addIsochroneLayersLayer(map);
	};

	const setIsochroneVisibility = (visible: boolean) => {
		if (!map) return;
		for (const isochrone of isochroneLayers) {
			setLayerVisibility(map, isochrone.layerId, visible);
		}
	};

	const ensureOptionalOverlayLayer = async (target: 'forest' | 'landuse' | 'vegetation') => {
		if (!map || loadedOverlayLayers[target]) return;

		if (target === 'landuse') {
			try {
				ensureLandUseLayer(map);
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
		addIgnHydroWmsLayersLayer(map);
	};

	const addProvinciasBoundaries = () => {
		if (!map) return;
		addProvinciasBoundariesLayer(map);
	};

	const addGridPmtiles = () => {
		if (!map) return;
		addGridPmtilesLayer(map, activeGridPmtilesPath, gridFillColorExpression);
		applyGridFillPaint();
	};


	const resolveGridPmtilesPath = () => {
		const fromFilter = provinceFilter && provinceFilter !== 'Todas' ? provinceFilter.trim() : null;
		const province = fromFilter;
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


	const applyGridFilter = () => {
		if (!map) return;
		applyGridFilterHelper({
			map,
			gridFillLayerId,
			gridLineLayerId,
			gridHoverLineLayerId,
			visibilityGridVisible: visibility.gridVisible,
			selectedMunicipio,
			maxTravelBucket,
			provinceFilter
		});
	};

	const addCcaaBoundaries = () => {
		if (!map) return;
		addCcaaBoundariesLayer(map);
	};

	onMount(() => {
		const unregisterPmtiles = registerPmtilesProtocol();
		initialBoundsApplied = false;
		hasInitialHashView = false;
		lockAutoFitFromHash = false;
		let resizeObserver: ResizeObserver | null = null;

		try {
			const created = createMapInstance({
				mapContainer,
				onWebglRestored: () => {
					map.remove();
					isMapLoading = true;
					mapReady = false;
					location.reload();
				}
			});
			map = created.map;
			hasInitialHashView = created.hasHashView;
			lockAutoFitFromHash = created.hasHashView;
		} catch (err) {
			console.error('Failed to initialize map:', err);
			isMapLoading = false;
			return;
		}

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

			setLayerVisibility(map, ignWmsLayerId, showIgnWmsBase);
			setLayerVisibility(map, ignSatelliteLayerId, showIgnSatellite);
			setLayerVisibility(map, ignRiversLayerId, showIgnRivers);
			setLayerVisibility(map, ignReservoirsLayerId, showIgnReservoirs);
			setLayerVisibility(map, municipiosPolygonsFillLayerId, showMunicipioPolygons);
			setLayerVisibility(map, municipiosPolygonsLineLayerId, showMunicipioPolygons);
			setIsochroneVisibility(showIsochronesLayer);
			setLayerVisibility(map, municipiosHoverLineLayerId, showMunicipioPolygons);
			setLayerVisibility(
				map,
				municipiosSelectedLineLayerId,
				showMunicipioPolygons || !!selectedMunicipio
			);
			applyPolygonFilter();
			applyLayerOrdering();
			applyMaxBoundsToMunicipios();

			registerMapInteractions({
				map,
				municipios,
				allMunicipios,
				onMapSelection,
				municipiosPolygonsFillLayerId,
				gridFillLayerId,
				gridLineLayerId,
				gridPmtilesSourceId,
				getHoveredFeatureId: () => hoveredFeatureId,
				setHoverFeatureState
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
			writeHashView(map);
		});

		map.on('moveend', () => {
			writeHashView(map);
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
		setLayerVisibility(map, ignWmsLayerId, showIgnWmsBase);
		setLayerVisibility(map, ignSatelliteLayerId, showIgnSatellite);
		setLayerVisibility(map, ignRiversLayerId, showIgnRivers);
		setLayerVisibility(map, ignReservoirsLayerId, showIgnReservoirs);
		const gridActive = visibility.gridVisible;
		const showMunicipiosPolygons = showMunicipioPolygons && !gridActive;
		const keepSelectedOutline = !!selectedMunicipio;
		setLayerVisibility(map, municipiosPolygonsFillLayerId, showMunicipiosPolygons);
		setLayerVisibility(map, municipiosPolygonsLineLayerId, showMunicipiosPolygons);
		setIsochroneVisibility(showIsochronesLayer);
		setLayerVisibility(map, municipiosHoverLineLayerId, showMunicipiosPolygons);
		setLayerVisibility(
			map,
			municipiosSelectedLineLayerId,
			showMunicipiosPolygons || keepSelectedOutline
		);
		setLayerVisibility(map, municipiosLayerId, showMunicipioPoints);
		setLayerVisibility(map, forestLayerId, showForestLayer);
		setLayerVisibility(map, landUseLayerId, showLandUseLayer);
		setLayerVisibility(map, vegetationLayerId, showVegetationLayer);
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
		refreshGridSource();
	});

	$effect(() => {
		if (!map || !selectedMunicipio) return;
		if (!Number.isFinite(selectedMunicipio.lon) || !Number.isFinite(selectedMunicipio.lat)) return;
		const zoom = isMobileView ? 7 : 9;
		map.flyTo({ center: [selectedMunicipio.lon, selectedMunicipio.lat], zoom, speed: 0.8 });
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
				{viewMode}
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

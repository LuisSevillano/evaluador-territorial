<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import type { MapColorMetric } from '$lib/components/map/coloring';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import InspectorPanel from '$lib/components/InspectorPanel.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import RankingList from '$lib/components/RankingList.svelte';
import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import ColorLegend from '$lib/components/ColorLegend.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import MunicipioSearch from '$lib/components/ui/MunicipioSearch.svelte';
	import ClimateFilters from '$lib/components/filters/ClimateFilters.svelte';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { classifyMixedScore, labelForScoreBand } from '$lib/components/map/scoreClassification';
	import { applyUrlToState, buildUrlFromState } from '$lib/state/urlSync';
	import { normalizeProvinceName } from '$lib/state/provinces';
	import { FILTER_HELP } from '$lib/state/filterHelp';
	
	import {
		bucketOrder,
		isPlausiblePrecipAnnual,
		isPlausibleTemp,
		travelBuckets,
		type TravelBucket
	} from '$lib/state/filters';
	import {
		isLayerVisible,
		layerLabels,
		type LayerVisibilityState
	} from '$lib/state/layers';
	import {
		ccaaClimateSeries,
		selectedMunicipioClimateSeries,
		selectedProvinciaClimateSeries
	} from '$lib/state/climate';
	import {
		panelStateOnClearSelection,
		panelStateOnSelect,
		panelStateOnTabClick
	} from '$lib/state/panel';
	import { loadStringArray, saveStringArray } from '$lib/state/persistence';
	import { createSelectionStore } from '$lib/state/selectionStore.svelte';
	import { createUiStore } from '$lib/state/uiStore.svelte';
	import { createFiltersStore } from '$lib/state/filtersStore.svelte';
import { createLayersStore } from '$lib/state/layersStore.svelte';
import { createRankingStore } from '$lib/state/rankingStore.svelte';
import { exportShortlistCsv, exportShortlistJson } from '$lib/state/shortlistExport';
	import {
		activePresetFromWeights,
		BASELINE_WEIGHTS,
		DEFAULT_WEIGHTS_RAW,
		normalizeWeights,
		scoreForMunicipio,
		weightsForPreset,
		type Preset
	} from '$lib/state/scoring';
	import {
		nextSortState,
		sensitivityTop10Overlap,
		sortRows,
		type SortField
	} from '$lib/state/ranking';
	import { MapPin, SlidersHorizontal, Layers, BarChart3, Info } from 'lucide-svelte';
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';

	type PageData = {
		municipios: Municipio[];
		climateMonthly: MunicipioClimateMonthly[];
		datasetMetadata: DatasetMetadata | null;
	};
	let { data }: { data: PageData } = $props();

	let municipios = $state<Municipio[]>([]);
	let climateMonthly = $state<MunicipioClimateMonthly[]>([]);
	let gridClimateMonthly = $state<MunicipioClimateMonthly[]>([]);
	let gridClimateLoading = $state(false);
	const loadedGridProvinces = $state(new Set<string>());
	const uiStore = createUiStore();
	const filtersStore = createFiltersStore();
	const layersStore = createLayersStore();
	const rankingStore = createRankingStore();
	const isBottomSheetOpen = $derived(uiStore.state.isBottomSheetOpen);
	const mapColorMetric = $derived(uiStore.state.mapColorMetric);
	const activeSheetTab = $derived(uiStore.state.activeSheetTab);
	const isMobileView = $derived(uiStore.state.isMobileView);
	const desktopPanel = $derived(uiStore.state.desktopPanel);
	const query = $derived(filtersStore.state.query);
	const provinceFilter = $derived(filtersStore.state.provinceFilter);
	const maxTravelBucket = $derived(filtersStore.state.maxTravelBucket);
	const minPrecipAnnual = $derived(filtersStore.state.minPrecipAnnual);
	const minWinterTemp = $derived(filtersStore.state.minWinterTemp);
	const maxSummerTemp = $derived(filtersStore.state.maxSummerTemp);
	const maxThermalAmplitude = $derived(filtersStore.state.maxThermalAmplitude);
	const maxThermalAmplitudeLimit = $derived.by(() => {
		const amplitudes = municipios
			.map((m) => m.temp_jul_mean_c - m.temp_jan_mean_c)
			.filter((value) => Number.isFinite(value));
		if (amplitudes.length === 0) return 25;
		const maxDatasetAmplitude = Math.max(...amplitudes);
		return Math.max(25, Math.ceil(maxDatasetAmplitude / 5) * 5);
	});
	const minCompositeScore = $derived(filtersStore.state.minCompositeScore);
	const climateWeight = $derived(filtersStore.state.climateWeight);
	const accessWeight = $derived(filtersStore.state.accessWeight);
	const natureWeight = $derived(filtersStore.state.natureWeight);
	const showMunicipioPolygons = $derived(layersStore.state.showMunicipioPolygons);
	const showIsochronesLayer = $derived(layersStore.state.showIsochronesLayer);
	const showMunicipioPoints = $derived(layersStore.state.showMunicipioPoints);
	const showIgnWmsBase = $derived(layersStore.state.showIgnWmsBase);
	const showIgnSatellite = $derived(layersStore.state.showIgnSatellite);
	const showIgnRivers = $derived(layersStore.state.showIgnRivers);
	const showIgnReservoirs = $derived(layersStore.state.showIgnReservoirs);
	const showForestLayer = $derived(layersStore.state.showForestLayer);
	const showLandUseLayer = $derived(layersStore.state.showLandUseLayer);
	const showVegetationLayer = $derived(layersStore.state.showVegetationLayer);
	const layerOrder = $derived(layersStore.state.layerOrder);
	const selectionStore = createSelectionStore();
	const selectedMunicipio = $derived(selectionStore.state.selectedMunicipio);
	const shortlistedIds = $derived(selectionStore.state.shortlistedIds);
	const municipiosPmtilesUrl = '/tiles/municipios.pmtiles';
	const sortBy = $derived(rankingStore.state.sortBy);
	const sortDirection = $derived(rankingStore.state.sortDirection);
	let urlStateReady = $state(false);
	let showDesktopEvalTable = $state(false);
	let didHydrateThermalAmplitudeDefault = $state(false);
	let desktopTableReady = $state(false);
	let desktopTableLoading = $state(true);
	let tableScrollTop = $state(0);
	let tableViewportHeight = $state(520);
	let desktopTableEl = $state<HTMLDivElement | null>(null);
	const tableRowHeight = 38;
	const tableOverscan = 24;

	const provinciasDisponibles = $derived([
		'Todas',
		...Array.from(
			new Set(
				municipios.map((m) => normalizeProvinceName((m as any).provincia_nombre_geo ?? m.provincia))
			)
		)
			.filter((provincia) => provincia && provincia !== '53')
			.sort((a, b) => a.localeCompare(b, 'es'))
	]);

	const labelAccesibilidad = (bucket: string) => {
		if (bucket === '<=1h30' || bucket === '<=2h00') return 'alta';
		if (bucket === '<=2h30' || bucket === '<=3h30') return 'media';
		return 'baja';
	};

	const normalizedWeights = $derived(
		normalizeWeights({
			climateWeight,
			accessWeight,
			natureWeight
		})
	);

	const municipiosScoredForView = $derived(
		municipios.map((m) => ({
			...m,
			mixed_score: Number(scoreForMunicipio(m, normalizedWeights).toFixed(4))
		}))
	);

	const municipiosFiltradosBase = $derived(
		municipiosScoredForView.filter((m) => {
			const provinceName = normalizeProvinceName((m as any).provincia_nombre_geo ?? m.provincia);
			const provinceOk =
				provinceFilter === 'Todas' ||
				provinceName === normalizeProvinceName(provinceFilter);
			const bucketOk =
				maxTravelBucket === null ||
				(bucketOrder[m.travel_bucket as TravelBucket] ?? bucketOrder['>4h00']) <=
				bucketOrder[maxTravelBucket];
			const precipOk = isPlausiblePrecipAnnual(m.precip_annual_mm)
				? m.precip_annual_mm >= minPrecipAnnual
				: true;
			const winterOk = isPlausibleTemp(m.temp_winter_mean_c)
				? m.temp_winter_mean_c >= minWinterTemp
				: true;
			const summerOk = isPlausibleTemp(m.temp_summer_mean_c)
				? m.temp_summer_mean_c <= maxSummerTemp
				: true;
			const amplitude = m.temp_jul_mean_c - m.temp_jan_mean_c;
			const amplitudeOk = Number.isFinite(amplitude)
				? amplitude <= maxThermalAmplitude
				: true;
			const scoreOk = Number.isFinite(m.mixed_score)
				? m.mixed_score >= minCompositeScore
				: true;
			return provinceOk && bucketOk && precipOk && winterOk && summerOk && amplitudeOk && scoreOk;
		})
	);

	const municipiosFiltrados = $derived(municipiosFiltradosBase);

	const baselineWeights = BASELINE_WEIGHTS;
	const baselineTopIds = $derived(
		[...municipiosFiltrados]
			.sort((a, b) => scoreForMunicipio(b, baselineWeights) - scoreForMunicipio(a, baselineWeights))
			.slice(0, 10)
			.map((m) => m.id)
	);

	const tableRows = $derived(
		sortRows(municipiosFiltrados, sortBy, sortDirection, bucketOrder)
	);

	const virtualWindow = $derived.by(() => {
		const total = tableRows.length;
		const visibleCount = Math.max(20, Math.ceil(tableViewportHeight / tableRowHeight) + tableOverscan * 2);
		const start = Math.max(0, Math.floor(tableScrollTop / tableRowHeight) - tableOverscan);
		const end = Math.min(total, start + visibleCount);
		const paddingTop = start * tableRowHeight;
		const paddingBottom = Math.max(0, (total - end) * tableRowHeight);
		return { start, end, paddingTop, paddingBottom };
	});

	const virtualTableRows = $derived(tableRows.slice(virtualWindow.start, virtualWindow.end));

	const sensitivityOverlap = $derived(sensitivityTop10Overlap(tableRows, baselineTopIds));

	const shortlistMunicipios = $derived(
		municipiosScoredForView
			.filter((m) => shortlistedIds.includes(m.id))
			.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
	);

	const activeFiltersSummary = $derived(
		[
			provinceFilter !== 'Todas' ? `provincia=${provinceFilter}` : null,
			maxTravelBucket !== null ? `acc<=${maxTravelBucket}` : null,
			minPrecipAnnual !== 0 ? `ppt>=${minPrecipAnnual}` : null,
			minWinterTemp !== -10 ? `t_inv>=${minWinterTemp}` : null,
			maxSummerTemp !== 40 ? `t_ver<=${maxSummerTemp}` : null,
			maxThermalAmplitude < maxThermalAmplitudeLimit ? `amp<=${maxThermalAmplitude.toFixed(1)}` : null,
			minCompositeScore > 0 ? `score>=${minCompositeScore.toFixed(2)}` : null
		].filter(Boolean) as string[]
	);

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);

	const activePreset = $derived.by(() =>
		activePresetFromWeights({ climateWeight, accessWeight, natureWeight })
	);

	const layerVisibility = (): LayerVisibilityState => ({
		showMunicipioPolygons,
		showIsochronesLayer,
		showLandUseLayer,
		showVegetationLayer,
		showForestLayer,
		showIgnReservoirs,
		showIgnRivers,
		showIgnWmsBase,
		showIgnSatellite
	});

	const toggleLayerVisibility = (layerKey: string, checked: boolean) => {
		if (layerKey === 'municipios') layersStore.state.showMunicipioPolygons = checked;
		else if (layerKey === 'isochrones') layersStore.state.showIsochronesLayer = checked;
		else if (layerKey === 'landuse') layersStore.state.showLandUseLayer = checked;
		else if (layerKey === 'vegetation') layersStore.state.showVegetationLayer = checked;
		else if (layerKey === 'forest') layersStore.state.showForestLayer = checked;
		else if (layerKey === 'reservoirs') layersStore.state.showIgnReservoirs = checked;
		else if (layerKey === 'rivers') layersStore.state.showIgnRivers = checked;
	};

	const layerItems = $derived(
		layerOrder.map((layerKey) => ({
			key: layerKey,
			label: layerLabels[layerKey] ?? layerKey,
			visible: isLayerVisible(layerKey, layerVisibility())
		}))
	);

	const activeLayerCount = $derived(
		(showMunicipioPolygons ? 1 : 0) +
			(showIsochronesLayer ? 1 : 0) +
			(showLandUseLayer ? 1 : 0) +
			(showVegetationLayer ? 1 : 0) +
			(showForestLayer ? 1 : 0) +
			(showIgnReservoirs ? 1 : 0) +
			(showIgnRivers ? 1 : 0) +
			(showIgnWmsBase ? 1 : 0) +
			(showIgnSatellite ? 1 : 0)
	);

	const mapColorLabel = $derived.by(() => {
		if (mapColorMetric === 'mixed_score') return 'Puntuación global';
		if (mapColorMetric === 'precip_annual_mm') return 'Precipitación anual';
		if (mapColorMetric === 'travel_bucket') return 'Tiempo de desplazamiento';
		if (mapColorMetric === 'transporte_norm') return 'Transporte OSM';
		if (mapColorMetric === 'servicio_renfe_norm') return 'Servicio Renfe';
		if (mapColorMetric === 'river_access_score') return 'Acceso a baño';
		return 'Puntuación global';
	});

	const topbarLegendConfig = $derived(getLegendConfig(mapColorMetric, municipiosScoredForView));
	const mixedScoreThresholds = $derived(getLegendConfig('mixed_score', municipiosScoredForView).thresholds as number[]);
	const formatMixedScore = (score?: number) => {
		if (!Number.isFinite(score)) return '-';
		const band = classifyMixedScore(score as number, mixedScoreThresholds);
		return `${labelForScoreBand(band)} (${(score as number).toFixed(3)})`;
	};
	const topbarLegendTitle = $derived(isMobileView ? 'Puntuación' : topbarLegendConfig.title);

	const topCandidate = $derived(tableRows[0] ?? null);

	const visibleMunicipioIds = $derived(municipiosFiltrados.map((m) => m.id));

	const selectedClimateSeries = $derived(
		selectedMunicipioClimateSeries(
			selectedMunicipio?.id?.startsWith('cell_')
				? gridClimateMonthly
				: climateMonthly,
			selectedMunicipio?.id?.startsWith('cell_')
				? selectedMunicipio.id
				: selectedMunicipio?.id ?? null
		)
	);

	const selectedProvinceClimateSeries = $derived(
		selectedProvinciaClimateSeries(climateMonthly, selectedMunicipio?.provincia ?? null)
	);

	const selectedCcaaClimateSeries = $derived(ccaaClimateSeries(climateMonthly));

	const handleSelectMunicipio = (municipio: Municipio | null) => {
		if (!municipio) {
			selectionStore.state.selectedMunicipio = null;
			return;
		}
		selectionStore.state.selectedMunicipio = municipio;
		const panel = panelStateOnSelect(activeSheetTab, isMobileView);
		uiStore.state.activeSheetTab = panel.tab;
		queueMicrotask(() => {
			uiStore.state.isBottomSheetOpen = panel.open;
		});
	};

	const handleClearSelectedMunicipio = () => {
		selectionStore.clearSelection();
		const panel = panelStateOnClearSelection(activeSheetTab, isMobileView);
		uiStore.state.activeSheetTab = panel.tab;
		uiStore.state.isBottomSheetOpen = panel.open;
	};

	const handleSelectSheetTab = (tab: 'sel' | 'filtr' | 'capas' | 'rank' | 'meta') => {
		const panel = panelStateOnTabClick(tab);
		uiStore.state.activeSheetTab = panel.tab;
		uiStore.state.isBottomSheetOpen = panel.open;
	};

	const handleExportShortlistCsv = () => exportShortlistCsv(shortlistMunicipios);
	const handleExportShortlistJson = () => exportShortlistJson(shortlistMunicipios);

	const handleClearFilters = () => {
		filtersStore.clear();
		filtersStore.state.maxThermalAmplitude = maxThermalAmplitudeLimit;
	};

	const handleToggleShortlist = (municipioId: string) => {
		const wasAdded = selectionStore.toggleShortlist(municipioId);
		if (wasAdded) {
			uiStore.state.desktopPanel = 'shortlist';
		}
	};

	const handleChangeSort = (newSortBy: SortField) => {
		const next = nextSortState(sortBy, sortDirection, newSortBy);
		rankingStore.state.sortBy = next.sortBy;
		rankingStore.state.sortDirection = next.sortDirection;
	};

	const handleLayerOrderChange = (nextOrder: string[]) => {
		layersStore.state.layerOrder = nextOrder;
	};

	const setMapColorMetric = (value: MapColorMetric) => {
		uiStore.state.mapColorMetric = value;
		layersStore.state.showMunicipioPolygons = true;
		if (value === 'travel_bucket') {
			layersStore.state.showIsochronesLayer = true;
			return;
		}
		layersStore.state.showIsochronesLayer = false;
	};

	const handlePresetWeights = (preset: Preset) => {
		setMapColorMetric('mixed_score');
		const weights = weightsForPreset(preset);
		filtersStore.state.climateWeight = weights.climateWeight;
		filtersStore.state.accessWeight = weights.accessWeight;
		filtersStore.state.natureWeight = weights.natureWeight;
	};

	const handleClimateWeightChange = (value: number) => {
		filtersStore.state.climateWeight = value;
		setMapColorMetric('mixed_score');
	};

	const handleAccessWeightChange = (value: number) => {
		filtersStore.state.accessWeight = value;
		setMapColorMetric('mixed_score');
	};

	const handleNatureWeightChange = (value: number) => {
		filtersStore.state.natureWeight = value;
		setMapColorMetric('mixed_score');
	};


	$effect(() => {
		municipios = data.municipios ?? [];
		climateMonthly = data.climateMonthly ?? [];
	});

	const loadGridClimate = async (provincia: string) => {
		if (loadedGridProvinces.has(provincia)) return;
		if (gridClimateLoading) return;
		
		gridClimateLoading = true;
		const slug = provincia
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '')
			.toLowerCase()
			.replace(/\//g, '_')
			.replace(/[^a-z0-9_]/g, '_')
			.replace(/_+/g, '_')
			.replace(/^_+|_+$/g, '');
		try {
			const res = await fetch(`/data/grid_climate/grid_climate_${slug}.json`);
			if (res.ok) {
				const data = await res.json() as MunicipioClimateMonthly[];
				gridClimateMonthly = [...gridClimateMonthly, ...data];
				loadedGridProvinces.add(provincia);
			}
		} catch (e) {
			console.error('Error loading grid climate:', e);
		} finally {
			gridClimateLoading = false;
		}
	};

	$effect(() => {
		if (selectedMunicipio?.id?.startsWith('cell_') && selectedMunicipio.provincia) {
			loadGridClimate(selectedMunicipio.provincia);
		}
	});

	$effect(() => {
		if (typeof window === 'undefined') return;
		const updateViewport = () => {
			uiStore.state.isMobileView = window.innerWidth <= 900;
		};
		updateViewport();
		window.addEventListener('resize', updateViewport);
		return () => window.removeEventListener('resize', updateViewport);
	});

	$effect(() => {
		if (typeof window === 'undefined' || urlStateReady) return;
		const { next, pendingSelectedMunicipioId } = applyUrlToState(window.location.search, {
			mapViewMode: uiStore.state.mapViewMode,
			query,
			provinceFilter,
			maxTravelBucket,
			minPrecipAnnual,
			minWinterTemp,
			maxSummerTemp,
			maxThermalAmplitude,
			maxThermalAmplitudeDefault: maxThermalAmplitudeLimit,
			minCompositeScore,
			climateWeight,
			accessWeight,
			natureWeight,
			activeSheetTab,
			isMobileView,
			isBottomSheetOpen,
			selectedMunicipioId: selectedMunicipio?.id
		});
		Object.assign(uiStore.state, {
			mapViewMode: next.mapViewMode ?? uiStore.state.mapViewMode,
			activeSheetTab: next.activeSheetTab ?? uiStore.state.activeSheetTab,
			isBottomSheetOpen: next.isBottomSheetOpen ?? uiStore.state.isBottomSheetOpen
		});
		Object.assign(filtersStore.state, {
			query: next.query ?? filtersStore.state.query,
			provinceFilter:
				next.provinceFilter !== undefined
					? normalizeProvinceName(next.provinceFilter)
					: filtersStore.state.provinceFilter,
			maxTravelBucket: next.maxTravelBucket ?? filtersStore.state.maxTravelBucket,
			minPrecipAnnual: next.minPrecipAnnual ?? filtersStore.state.minPrecipAnnual,
			minWinterTemp: next.minWinterTemp ?? filtersStore.state.minWinterTemp,
			maxSummerTemp: next.maxSummerTemp ?? filtersStore.state.maxSummerTemp,
			maxThermalAmplitude:
				next.maxThermalAmplitude !== undefined
					? Math.min(next.maxThermalAmplitude, maxThermalAmplitudeLimit)
					: filtersStore.state.maxThermalAmplitude,
			minCompositeScore: next.minCompositeScore ?? filtersStore.state.minCompositeScore,
			climateWeight: next.climateWeight ?? filtersStore.state.climateWeight,
			accessWeight: next.accessWeight ?? filtersStore.state.accessWeight,
			natureWeight: next.natureWeight ?? filtersStore.state.natureWeight
		});
		selectionStore.state.pendingSelectedMunicipioId = pendingSelectedMunicipioId;

		urlStateReady = true;
	});

	$effect(() => {
		if (typeof window === 'undefined' || !urlStateReady) return;
		if (didHydrateThermalAmplitudeDefault) return;
		const hasAmplitudeInUrl = new URLSearchParams(window.location.search).has('ta');
		if (!hasAmplitudeInUrl && filtersStore.state.maxThermalAmplitude === 21 && maxThermalAmplitudeLimit > 21) {
			filtersStore.state.maxThermalAmplitude = maxThermalAmplitudeLimit;
		}
		didHydrateThermalAmplitudeDefault = true;
	});

	$effect(() => {
		if (typeof window === 'undefined' || !urlStateReady) return;
		const params = buildUrlFromState({
			mapViewMode: uiStore.state.mapViewMode,
			query,
			provinceFilter,
			maxTravelBucket,
			minPrecipAnnual,
			minWinterTemp,
			maxSummerTemp,
			maxThermalAmplitude,
			maxThermalAmplitudeDefault: maxThermalAmplitudeLimit,
			minCompositeScore,
			climateWeight,
			accessWeight,
			natureWeight,
			activeSheetTab,
			isMobileView,
			isBottomSheetOpen: uiStore.state.isBottomSheetOpen,
			selectedMunicipioId: selectedMunicipio?.id
		});

		const queryString = params.toString();
		const nextUrl = queryString ? `${window.location.pathname}?${queryString}` : window.location.pathname;
		const nextUrlWithHash = `${nextUrl}${window.location.hash || ''}`;
		window.history.replaceState({}, '', nextUrlWithHash);
	});

	$effect(() => {
		if (selectedMunicipio && !selectedMunicipio.id.startsWith('cell_') && !municipiosScoredForView.some((m) => m.id === selectedMunicipio?.id)) {
			selectionStore.state.selectedMunicipio = null;
		}
	});

	$effect(() => {
		const pendingSelectedMunicipioId = selectionStore.state.pendingSelectedMunicipioId;
		if (!pendingSelectedMunicipioId || municipiosScoredForView.length === 0) return;
		const fromUrl = municipiosScoredForView.find((m) => m.id === pendingSelectedMunicipioId) ?? null;
		if (!fromUrl) {
			selectionStore.state.pendingSelectedMunicipioId = null;
			return;
		}
		selectionStore.state.selectedMunicipio = fromUrl;
		selectionStore.state.pendingSelectedMunicipioId = null;
	});

	$effect(() => {
		if (!selectedMunicipio) return;
		const refreshed = municipiosScoredForView.find((m) => m.id === selectedMunicipio?.id) ?? null;
		if (refreshed && refreshed.id === selectedMunicipio.id) {
			const changedScore = Math.abs((refreshed.mixed_score ?? 0) - (selectedMunicipio.mixed_score ?? 0)) > 0.0001;
			if (changedScore) selectionStore.state.selectedMunicipio = refreshed;
		}
	});

	$effect(() => {
		selectionStore.state.shortlistedIds = loadStringArray('ebv-shortlist-v1');
	});

	$effect(() => {
		saveStringArray('ebv-shortlist-v1', shortlistedIds);
	});

	$effect(() => {
		if (!desktopTableEl) return;
		tableViewportHeight = desktopTableEl.clientHeight;
	});

	$effect(() => {
		if (typeof window === 'undefined') return;
		desktopTableReady = false;
		desktopTableLoading = !isMobileView;
		if (isMobileView) return;
		const activate = () => {
			desktopTableReady = true;
			desktopTableLoading = false;
		};
		if ('requestIdleCallback' in window) {
			const id = (window as any).requestIdleCallback(activate, { timeout: 700 });
			return () => (window as any).cancelIdleCallback?.(id);
		}
		const t = globalThis.setTimeout(activate, 250);
		return () => globalThis.clearTimeout(t);
	});

	$effect(() => {
		if (typeof window === 'undefined' || isMobileView || !desktopTableReady) return;
		tableRows.length;
		sortBy;
		sortDirection;
		provinceFilter;
		minCompositeScore;
		desktopTableLoading = true;
		const t = globalThis.setTimeout(() => {
			desktopTableLoading = false;
		}, 140);
		return () => globalThis.clearTimeout(t);
	});
</script>

<svelte:head>
	<title>El Buen Vivir | Visor Territorial de Municipios</title>
	<meta name="description" content="Herramienta analítica para evaluar municipios según climatología, accesibilidad y naturaleza. Explora datos, compara territorios y toma decisiones informadas." />
	<meta name="keywords" content="municipios, análisis territorial, Castilla y León, climatología, accesibilidad, naturaleza, score municipal, visor geográfico" />
	<meta name="author" content="El Buen Vivir" />
	<meta name="robots" content="index, follow" />
	<meta name="theme-color" content="#2f7d85" />

	<!-- Open Graph / Facebook -->
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://observatorio-territorial.netlify.app/" />
	<meta property="og:title" content="El Buen Vivir | Visor Territorial de Municipios" />
	<meta property="og:description" content="Herramienta analítica para evaluar municipios según climatología, accesibilidad y naturaleza en Castilla y León." />
	<meta property="og:site_name" content="El Buen Vivir" />
	<meta property="og:locale" content="es_ES" />
	<meta property="og:image" content="https://observatorio-territorial.netlify.app/og-image-v2.jpg" />
	<meta property="og:image:secure_url" content="https://observatorio-territorial.netlify.app/og-image-v2.jpg" />
	<meta property="og:image:type" content="image/jpeg" />
	<meta property="og:image:alt" content="Observatorio Territorial El Buen Vivir" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />

	<!-- Twitter / X -->
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:url" content="https://observatorio-territorial.netlify.app/" />
	<meta name="twitter:title" content="El Buen Vivir | Visor Territorial" />
	<meta name="twitter:description" content="Evalúa municipios por clima, accesibilidad y naturaleza. Herramienta de análisis territorial." />
	<meta name="twitter:image" content="https://observatorio-territorial.netlify.app/og-image-v2.jpg" />

	<!-- Telegram / WhatsApp -->
	<meta property="telegram:channel" content="@elbuenvivir" />

	<!-- Canonical -->
	<link rel="canonical" href="https://observatorio-territorial.netlify.app/" />
	<link rel="icon" type="image/svg+xml" href="/favicon.svg" />
	<link rel="apple-touch-icon" href="/favicon.svg" />
</svelte:head>

<header class="topbar">
	<div class="topbar-brand">
		<a class="topbar-brand-title" href="/" aria-label="Ir al inicio de El Buen Vivir">
			<strong>El Buen Vivir</strong>
		</a>
		<div class="topbar-brand-meta">
			<small>Explora y evalúa · {municipiosFiltrados.length}/{municipios.length}</small>
			<a
				class="topbar-docs-link-mobile"
				href="https://observatorio-territorial.netlify.app/docs/"
				rel="noopener noreferrer"
				aria-label="Abrir la documentación técnica del proyecto"
			>
				Documentación
			</a>
		</div>
	</div>
	<div class="topbar-controls">
		<a class="topbar-docs-link" href="https://observatorio-territorial.netlify.app/docs/" rel="noopener noreferrer" aria-label="Abrir la documentación técnica del proyecto">
			<span>Documentación</span>
		</a>
		<div class="topbar-legend">
			<ColorLegend
				title={topbarLegendTitle}
				thresholds={topbarLegendConfig.thresholds}
				colors={topbarLegendConfig.colors as any[]}
				labels={topbarLegendConfig.labels as any[]}
				formatLabel={topbarLegendConfig.formatLabel}
				width={320}
			/>
		</div>
	</div>
</header>

<section class="mode-strip">
	<p><strong>Explora y evalúa.</strong> Ajusta filtros, pesos y criterios para encontrar el municipio ideal.</p>
	<div class="mode-strip-metrics">
		<span>Color mapa: {mapColorLabel}</span>
		<span>Capas activas: {activeLayerCount}</span>
		<span>Filtro provincia: {provinceFilter}</span>
		<span>Pesos: clima {climateWeight} · acceso {accessWeight} · naturaleza {natureWeight}</span>
	</div>
</section>

<main>
		<div class="panel-wrapper">
			<Sidebar
				{query}
				municipios={municipiosFiltrados}
				searchMunicipios={municipiosScoredForView}
				allMunicipiosCount={municipios.length}
				{selectedMunicipio}
				{showMunicipioPolygons}
				{showIsochronesLayer}
				{showIgnWmsBase}
				{showIgnSatellite}
				{showIgnRivers}
				{showIgnReservoirs}
				{mapColorMetric}
				{showForestLayer}
				{showLandUseLayer}
				{showVegetationLayer}
				{provinceFilter}
				{provinciasDisponibles}
				{maxTravelBucket}
				{minPrecipAnnual}
				{minWinterTemp}
				{maxSummerTemp}
				{maxThermalAmplitude}
				{maxThermalAmplitudeLimit}
				{minCompositeScore}
				{layerOrder}
				activeFiltersSummary={activeFiltersSummary}
				shortlistMunicipios={shortlistMunicipios}
				shortlistedIds={shortlistedIds}
				
				weights={normalizedWeights}
				weightsRaw={{ climateWeight, accessWeight, natureWeight }}
				sensitivityOverlap={sensitivityOverlap}
				datasetMetadata={data.datasetMetadata}
				labelAccesibilidad={labelAccesibilidad}
				climateSeries={selectedClimateSeries}
				onQueryChange={(value) => (filtersStore.state.query = value)}
				onSelectMunicipio={handleSelectMunicipio}
				onToggleMunicipioPolygons={(value) => (layersStore.state.showMunicipioPolygons = value)}
				onToggleIsochronesLayer={(value) => (layersStore.state.showIsochronesLayer = value)}
				onToggleIgnWmsBase={(value) => (layersStore.state.showIgnWmsBase = value)}
				onToggleIgnSatellite={(value: boolean) => (layersStore.state.showIgnSatellite = value)}
				onToggleIgnRivers={(value: boolean) => (layersStore.state.showIgnRivers = value)}
				onToggleIgnReservoirs={(value: boolean) => (layersStore.state.showIgnReservoirs = value)}
				onMapColorMetricChange={setMapColorMetric}
				onToggleForestLayer={(value) => (layersStore.state.showForestLayer = value)}
				onToggleLandUseLayer={(value) => (layersStore.state.showLandUseLayer = value)}
				onToggleVegetationLayer={(value) => (layersStore.state.showVegetationLayer = value)}
				onProvinceFilterChange={(value) => (filtersStore.state.provinceFilter = value)}
				onMaxTravelBucketChange={(value) => (filtersStore.state.maxTravelBucket = value)}
				onMinPrecipAnnualChange={(value) => (filtersStore.state.minPrecipAnnual = value)}
				onMinWinterTempChange={(value) => (filtersStore.state.minWinterTemp = value)}
				onMaxSummerTempChange={(value) => (filtersStore.state.maxSummerTemp = value)}
				onMaxThermalAmplitudeChange={(value) => (filtersStore.state.maxThermalAmplitude = value)}
				onMinCompositeScoreChange={(value: number) => (filtersStore.state.minCompositeScore = value)}
				onClearFilters={handleClearFilters}
				onLayerOrderChange={handleLayerOrderChange}
				onToggleShortlist={handleToggleShortlist}
				onClimateWeightChange={handleClimateWeightChange}
				onAccessWeightChange={handleAccessWeightChange}
				onNatureWeightChange={handleNatureWeightChange}
				onPresetWeights={handlePresetWeights}
			/>
		</div>

		<section class="map-wrap" class:table-hidden={false}>
			<div class="map-desktop-zone">
				<MapView
					municipios={municipiosScoredForView}
					allMunicipios={municipios}
					{selectedMunicipio}
					{showMunicipioPolygons}
					{showIsochronesLayer}
					{showMunicipioPoints}
					{showIgnWmsBase}
					{showIgnSatellite}
					{showIgnRivers}
					{showIgnReservoirs}
					{mapColorMetric}
					onToggleIgnSatellite={(value) => (layersStore.state.showIgnSatellite = value)}
					onToggleIgnWmsBase={(value) => (layersStore.state.showIgnWmsBase = value)}
					{showForestLayer}
					{showLandUseLayer}
					{showVegetationLayer}
					{layerOrder}
					{visibleMunicipioIds}
					{provinceFilter}
					{maxTravelBucket}
					{isMobileView}
					{isBottomSheetOpen}
					pmtilesUrl={municipiosPmtilesUrl}
					onMapSelection={handleSelectMunicipio}
					viewMode={uiStore.state.mapViewMode}
					onViewModeChange={(mode) => (uiStore.state.mapViewMode = mode)}
				/>
			</div>
			<section class="desktop-table" aria-label="Tabla analítica de municipios">
				<div
					class="desktop-table-inner"
					bind:this={desktopTableEl}
					onscroll={(event) => (tableScrollTop = (event.currentTarget as HTMLDivElement).scrollTop)}
				>
					{#if (desktopTableReady && !desktopTableLoading) || isMobileView}
					<table>
						<thead>
							<tr>
								<th><button onclick={() => handleChangeSort('nombre')}>Municipio {sortBy === 'nombre' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('provincia')}>Provincia {sortBy === 'provincia' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('travel_bucket')}>Acc {sortBy === 'travel_bucket' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('precip_annual_mm')}>Precip {sortBy === 'precip_annual_mm' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('temp_winter_mean_c')}>T.inv {sortBy === 'temp_winter_mean_c' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('temp_summer_mean_c')}>T.ver {sortBy === 'temp_summer_mean_c' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
								<th><button onclick={() => handleChangeSort('mixed_score')}>Score {sortBy === 'mixed_score' ? (sortDirection === 'asc' ? '↑' : '↓') : ''}</button></th>
							</tr>
						</thead>
						<tbody>
							<tr class="spacer-row" aria-hidden="true" style={`height:${virtualWindow.paddingTop}px`}><td colspan="7"></td></tr>
							{#each virtualTableRows as municipio (municipio.id)}
								<tr onclick={() => handleSelectMunicipio(municipio)}>
									<td>{municipio.nombre}</td>
									<td>{municipio.provincia}</td>
									<td>{municipio.travel_bucket}</td>
									<td>{municipio.precip_annual_mm}</td>
									<td>{municipio.temp_winter_mean_c}</td>
									<td>{municipio.temp_summer_mean_c}</td>
								<td>{formatMixedScore(municipio.mixed_score)}</td>
								</tr>
							{/each}
							<tr class="spacer-row" aria-hidden="true" style={`height:${virtualWindow.paddingBottom}px`}><td colspan="7"></td></tr>
						</tbody>
					</table>
					{:else}
						<div class="table-loading-wrap">
							<div class="table-loading">Cargando tabla...</div>
							<div class="table-skeleton" aria-hidden="true">
								{#each Array(9) as _, idx}
									<div class="skeleton-row" style={`animation-delay:${idx * 40}ms`}>
										<span class="sk sk-sm"></span>
										<span class="sk sk-lg"></span>
										<span class="sk sk-md"></span>
										<span class="sk sk-md"></span>
										<span class="sk sk-md"></span>
										<span class="sk sk-md"></span>
										<span class="sk sk-lg"></span>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			</section>
			<BottomSheet initialHeight="34vh" expandedHeight="62vh" peekHeight="5.2rem" snapPoints={[0.14, 0.66, 0.94]} bind:isOpen={uiStore.state.isBottomSheetOpen}>
				{#snippet children()}
					<div class="sheet-tabs" role="tablist" aria-label="Panel móvil">
						<button
							class:active={activeSheetTab === 'sel'}
							class:has-selection={Boolean(selectedMunicipio)}
							onclick={() => handleSelectSheetTab('sel')}
							aria-label={selectedMunicipio ? `Selección activa: ${selectedMunicipio.nombre}` : 'Selección'}
						>
							<MapPin size={16} />Sel.
						</button>
						<button class:active={activeSheetTab === 'filtr'} onclick={() => handleSelectSheetTab('filtr')}><SlidersHorizontal size={16} />Filtros</button>
						<button class:active={activeSheetTab === 'capas'} onclick={() => handleSelectSheetTab('capas')}><Layers size={16} />Capas</button>
						<button class:active={activeSheetTab === 'rank'} onclick={() => handleSelectSheetTab('rank')}><BarChart3 size={16} />Rank</button>
						<button class:active={activeSheetTab === 'meta'} onclick={() => handleSelectSheetTab('meta')}><Info size={16} />Meta</button>
					</div>
					<div class="sheet-content">
						{#if activeSheetTab === 'sel'}
							{#if selectedMunicipio}
								<InspectorPanel
									{selectedMunicipio}
									municipios={municipiosScoredForView}
									shortlistedIds={shortlistedIds}
									weights={normalizedWeights}
									weightsRaw={{ climateWeight, accessWeight, natureWeight }}
									sensitivityOverlap={sensitivityOverlap}
									
									climateSeries={selectedClimateSeries}
									provinceClimateSeries={selectedProvinceClimateSeries}
									ccaaClimateSeries={selectedCcaaClimateSeries}
									isGridCell={selectedMunicipio?.id?.startsWith('cell_') ?? false}
									gridClimateLoading={gridClimateLoading}
									onToggleShortlist={handleToggleShortlist}
									onClimateWeightChange={handleClimateWeightChange}
									onAccessWeightChange={handleAccessWeightChange}
									onNatureWeightChange={handleNatureWeightChange}
									onPresetWeights={handlePresetWeights}
									onClearMunicipio={handleClearSelectedMunicipio}
								/>
							{:else}
								<p class="sheet-empty">Selecciona un municipio en el mapa para ver su ficha.</p>
								<button
									class="sheet-clear"
									onclick={() => handleSelectSheetTab('rank')}
								>
									Ir al ranking
								</button>
							{/if}
						{:else if activeSheetTab === 'filtr'}
							<div class="sheet-block">
								<p class="sheet-meta">Ajusta filtros y criterios para encontrar el municipio ideal.</p>
								<section class="sheet-section">
									<p class="sheet-subtitle">Filtros base</p>
									<div class="sheet-score-item">
										<label for="sheet-search">Buscar municipio</label>
										<MunicipioSearch
											query={query}
											municipios={municipiosScoredForView}
											searchMunicipios={municipiosFiltradosBase}
											inputId="sheet-search"
											variant="sheet"
											onQueryChange={(value) => (filtersStore.state.query = value)}
											onSelectMunicipio={handleSelectMunicipio}
										/>
									</div>
									<div class="sheet-label-help-row sheet-label-help-row-nowrap">
										<label for="sheet-province">Provincia</label>
										<FilterHelp text={FILTER_HELP.province} />
									</div>
								<select id="sheet-province" value={provinceFilter} onchange={(e) => (filtersStore.state.provinceFilter = (e.currentTarget as HTMLSelectElement).value)}>
										{#each provinciasDisponibles as provincia}
											<option value={provincia}>{provincia}</option>
										{/each}
									</select>
									<p class="sheet-subtitle sheet-subtitle-help">Accesibilidad máxima <FilterHelp text={FILTER_HELP.accessibility} /></p>
									<div class="chips-row">
										{#each travelBuckets as bucket}
											<ChipButton label={bucket.label} size="small" compact={true} active={maxTravelBucket === bucket.value} onclick={() => (filtersStore.state.maxTravelBucket = bucket.value)} />
										{/each}
									</div>
									<p class="sheet-subtitle">Filtros de climatología</p>
									<ClimateFilters
										variant="sheet"
										idPrefix="sheet"
										{minPrecipAnnual}
										{minWinterTemp}
										{maxSummerTemp}
										{maxThermalAmplitude}
										{maxThermalAmplitudeLimit}
										
										{minCompositeScore}
										onMinPrecipAnnualChange={(value) => (filtersStore.state.minPrecipAnnual = value)}
										onMinWinterTempChange={(value) => (filtersStore.state.minWinterTemp = value)}
										onMaxSummerTempChange={(value) => (filtersStore.state.maxSummerTemp = value)}
										onMaxThermalAmplitudeChange={(value) => (filtersStore.state.maxThermalAmplitude = value)}
										onMinCompositeScoreChange={(value) => (filtersStore.state.minCompositeScore = value)}
									/>
								</section>
								<section class="sheet-section sheet-section-score">
										<div class="sheet-score-summary">
											<span>Clima: {climateWeight} · Accesibilidad: {accessWeight} · Naturaleza: {natureWeight}</span>
											<span>Robustez top-10: {sensitivityOverlap}/10</span>
										</div>
										<p class="sheet-subtitle">Ajuste del score</p>
										<div class="chips-row">
											<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => handlePresetWeights('equilibrado')} />
											<ChipButton label="Naturaleza" active={activePreset === 'naturaleza'} onclick={() => handlePresetWeights('naturaleza')} />
											<ChipButton label="Accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => handlePresetWeights('accesibilidad')} />
											<ChipButton label="Clima" active={activePreset === 'clima'} onclick={() => handlePresetWeights('clima')} />
											<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => handlePresetWeights('clima_estricto')} />
										</div>
									<div class="sheet-slider-grid">
										<div class="sheet-score-item">
											<label for="sheet-w-clima">Peso clima: {climateWeight}</label>
												<input id="sheet-w-clima" type="range" min="0" max="100" step="1" value={climateWeight} oninput={(e) => handleClimateWeightChange(toNumber(e))} />
											</div>
											<div class="sheet-score-item">
												<label for="sheet-w-acceso">Peso accesibilidad: {accessWeight}</label>
												<input id="sheet-w-acceso" type="range" min="0" max="100" step="1" value={accessWeight} oninput={(e) => handleAccessWeightChange(toNumber(e))} />
											</div>
											<div class="sheet-score-item">
												<label for="sheet-w-nat">Peso naturaleza: {natureWeight}</label>
												<input id="sheet-w-nat" type="range" min="0" max="100" step="1" value={natureWeight} oninput={(e) => handleNatureWeightChange(toNumber(e))} />
											</div>
										</div>
									</section>
								<div class="sheet-actions">
									<button class="sheet-clear" onclick={handleClearFilters}>Limpiar filtros</button>
									<button class="sheet-clear" onclick={() => handleSelectSheetTab('rank')}>Ir a ranking</button>
								</div>
							</div>
						{:else if activeSheetTab === 'capas'}
							<div class="sheet-block">
							<p class="sheet-subtitle sheet-subtitle-help">Color municipal <FilterHelp text={FILTER_HELP.mapColor} /></p>
								<div class="chips-row">
								<ChipButton label="Puntuación global" active={mapColorMetric === 'mixed_score'} onclick={() => setMapColorMetric('mixed_score')} />
								<ChipButton label="Precipitación" active={mapColorMetric === 'precip_annual_mm'} onclick={() => setMapColorMetric('precip_annual_mm')} />
								<ChipButton label="Tiempo de desplazamiento" active={mapColorMetric === 'travel_bucket'} onclick={() => setMapColorMetric('travel_bucket')} />
								<ChipButton label="Transporte OSM" active={mapColorMetric === 'transporte_norm'} onclick={() => setMapColorMetric('transporte_norm')} />
								<ChipButton label="Servicio Renfe" active={mapColorMetric === 'servicio_renfe_norm'} onclick={() => setMapColorMetric('servicio_renfe_norm')} />
								<ChipButton label="Acceso a baño" active={mapColorMetric === 'river_access_score'} onclick={() => setMapColorMetric('river_access_score')} />
							</div>
								<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={handleLayerOrderChange} />
								<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => (layersStore.state.showIgnWmsBase = (e.currentTarget as HTMLInputElement).checked)} /> Base IGN</label>
								<label><input type="checkbox" checked={showIgnSatellite} onchange={(e) => (layersStore.state.showIgnSatellite = (e.currentTarget as HTMLInputElement).checked)} /> Satélite IGN</label>
							</div>
						{:else if activeSheetTab === 'rank'}
							<div class="sheet-rank">
								<p class="sheet-meta">Top 25 en base a score mixto actual.</p>
								<RankingList rows={tableRows} limit={25} compact={true} onSelect={handleSelectMunicipio} scoreThresholds={mixedScoreThresholds} />
							</div>
						{:else}
							<section class="sheet-meta-panel" aria-label="Metodología y metadatos">
								<h3>Datos y metodología</h3>
								{#if data.datasetMetadata}
									<ul>
										<li><strong>Versión:</strong> {data.datasetMetadata.dataset_version}</li>
										<li><strong>Generado:</strong> {new Date(data.datasetMetadata.generated_at_utc).toLocaleDateString('es-ES')}</li>
										<li><strong>Período clima:</strong> {data.datasetMetadata.climate_period}</li>
										<li><strong>Fuente clima:</strong> {data.datasetMetadata.climate_source}</li>
										<li><strong>Alcance:</strong> {data.datasetMetadata.analysis_scope}</li>
									</ul>
								{:else}
									<p class="sheet-meta">No hay metadatos de dataset disponibles.</p>
								{/if}
								<div class="sheet-export-actions">
									<button class="sheet-clear" onclick={handleExportShortlistCsv} disabled={shortlistMunicipios.length === 0}>Exportar shortlist CSV</button>
									<button class="sheet-clear" onclick={handleExportShortlistJson} disabled={shortlistMunicipios.length === 0}>Exportar shortlist JSON</button>
								</div>
							</section>
						{/if}
					</div>
				{/snippet}
			</BottomSheet>
		</section>

		<div class="inspector-desktop">
			{#if !selectedMunicipio}
				<section class="desktop-ranking">
					<h2>Análisis y ranking</h2>
					<p>Selecciona un municipio para ver su ficha o usa este ranking para comparar.</p>
					<div class="desktop-toggle" role="tablist" aria-label="Vista de evaluación">
						<button
							type="button"
							class:active={desktopPanel === 'rank'}
							onclick={() => (uiStore.state.desktopPanel = 'rank')}
						>
							Top 25
						</button>
						<button
							type="button"
							class:active={desktopPanel === 'shortlist'}
							onclick={() => (uiStore.state.desktopPanel = 'shortlist')}
						>
							Shortlist ({shortlistMunicipios.length})
						</button>
					</div>
					{#if desktopPanel === 'rank'}
						<p class="muted">Top 25 por score mixto · robustez {sensitivityOverlap}/10</p>
						<RankingList rows={tableRows} limit={25} onSelect={handleSelectMunicipio} scoreThresholds={mixedScoreThresholds} />
					{:else}
						{#if shortlistMunicipios.length > 0}
							<p class="muted">Municipios guardados en shortlist.</p>
							<RankingList rows={shortlistMunicipios} limit={200} onSelect={handleSelectMunicipio} scoreThresholds={mixedScoreThresholds} />
						{:else}
							<p class="muted">Tu shortlist está vacía. Abre un municipio y pulsa "Guardar shortlist".</p>
						{/if}
					{/if}
				</section>
			{:else}
				<InspectorPanel
					{selectedMunicipio}
					municipios={municipiosScoredForView}
					shortlistedIds={shortlistedIds}
					weights={normalizedWeights}
					weightsRaw={{ climateWeight, accessWeight, natureWeight }}
					sensitivityOverlap={sensitivityOverlap}
					
					climateSeries={selectedClimateSeries}
					provinceClimateSeries={selectedProvinceClimateSeries}
					ccaaClimateSeries={selectedCcaaClimateSeries}
					isGridCell={selectedMunicipio?.id?.startsWith('cell_') ?? false}
					gridClimateLoading={gridClimateLoading}
					onToggleShortlist={handleToggleShortlist}
					onClimateWeightChange={handleClimateWeightChange}
					onAccessWeightChange={handleAccessWeightChange}
					onNatureWeightChange={handleNatureWeightChange}
					onPresetWeights={handlePresetWeights}
					onClearMunicipio={handleClearSelectedMunicipio}
				/>
			{/if}
		</div>
	</main>

<style>
	.topbar {
		height: 56px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.8rem;
		padding: 0.55rem 0.9rem;
		border-bottom: 1px solid rgba(21, 32, 33, 0.16);
		background: linear-gradient(180deg, rgba(253, 250, 244, 0.96), rgba(246, 239, 226, 0.96));
	}
	.topbar-brand {
		display: grid;
		line-height: 1.1;
	}
	.topbar-brand-title {
		text-decoration: none;
		color: inherit;
	}
	.topbar-brand-title:visited {
		color: inherit;
	}
	.topbar-brand-meta {
		display: flex;
		align-items: baseline;
		gap: 0.35rem;
	}
	.topbar-brand strong {
		font-family: 'Fraunces', serif;
		font-size: 1.38rem;
	}
	.topbar-brand small {
		font-size: 0.72rem;
		color: #405753;
	}
	.topbar-controls {
		display: flex;
		align-items: center;
		gap: 2rem;
		margin-left: auto;
	}
	.topbar-docs-link {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.34rem 0.62rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.24);
		background: rgba(255, 255, 255, 0.82);
		font-size: 0.74rem;
		font-weight: 600;
		letter-spacing: 0.02em;
		text-decoration: none;
		color: #264944;
		transition: transform 120ms ease, background-color 120ms ease;
	}
	.topbar-docs-link:visited {
		color: #264944;
	}
	.topbar-docs-link:hover {
		background: rgba(255, 255, 255, 0.98);
		transform: translateY(-1px);
	}
	.topbar-docs-link:focus-visible {
		outline: 2px solid rgba(47, 125, 133, 0.65);
		outline-offset: 2px;
	}
	.topbar-docs-link-mobile {
		display: none;
	}
	.topbar-legend {
		display: block;
		min-width: 0;
	}
	.topbar-mode {
		display: block;
	}
	.mode-strip {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.8rem;
		padding: 0.45rem 0.9rem;
		border-bottom: 1px solid rgba(21, 32, 33, 0.14);
		background: rgba(245, 239, 226, 0.78);
	}
	.mode-strip.evaluation {
		background: rgba(236, 245, 242, 0.9);
	}
	.mode-strip p {
		margin: 0;
		font-size: 0.78rem;
		color: #3d5652;
	}
	.mode-strip-metrics {
		display: flex;
		gap: 0.4rem;
		flex-wrap: wrap;
		justify-content: flex-end;
		align-items: center;
	}
	.mode-strip-metrics span {
		font-size: 0.72rem;
		padding: 0.2rem 0.45rem;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.68);
		border: 1px solid rgba(21, 32, 33, 0.14);
		color: #405a56;
	}
	main {
		height: calc(100dvh - 106px);
		display: grid;
		grid-template-columns: 440px 1fr 360px;
		grid-template-rows: minmax(0, 1fr);
		gap: 0;
		overflow: hidden;
		box-sizing: border-box;
	}
	.map-wrap {
		min-width: 0;
		min-height: 0;
		height: 100%;
		overflow: hidden;
		background: rgba(251, 246, 236, 0.72);
		box-sizing: border-box;
		position: relative;
		display: flex;
		flex-direction: column;
	}
	.map-wrap.table-hidden {
		grid-template-rows: minmax(0, 1fr) auto;
	}
	.map-desktop-zone {
		min-height: 0;
		flex: 1;
		overflow: hidden;
	}
	.desktop-table-toggle-wrap {
		display: flex;
		justify-content: flex-end;
		padding: 0.35rem 0.5rem 0.2rem;
		border-top: 1px solid rgba(21, 32, 33, 0.1);
		background: rgba(255, 251, 243, 0.88);
	}
	.desktop-table-toggle {
		border: 1px solid rgba(21, 32, 33, 0.2);
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.86);
		padding: 0.26rem 0.6rem;
		font-size: 0.72rem;
		color: #3f5853;
		cursor: pointer;
	}
	.desktop-table {
		border-top: 1px solid rgba(21, 32, 33, 0.14);
		background: rgba(255, 251, 243, 0.9);
		min-height: 0;
		height: 26%;
		flex-shrink: 0;
	}
	.desktop-table-inner {
		height: 100%;
		overflow: auto;
	}
	.desktop-table table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8rem;
	}
	.desktop-table thead {
		position: sticky;
		top: 0;
		z-index: 1;
		background: rgba(245, 239, 226, 0.98);
	}
	.desktop-table th,
	.desktop-table td {
		border-bottom: 1px solid rgba(21, 32, 33, 0.12);
		padding: 0.32rem 0.45rem;
		white-space: nowrap;
		text-align: right;
	}
	.desktop-table th:first-child,
	.desktop-table td:first-child {
		text-align: left;
	}
	.desktop-table th button {
		width: auto;
		border: 0;
		padding: 0;
		background: transparent;
		font-size: 0.71rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		cursor: pointer;
		color: #3f5652;
	}
	.desktop-table tbody tr {
		cursor: pointer;
	}
	.desktop-table tbody tr:hover {
		background: rgba(33, 102, 109, 0.08);
	}
	.desktop-table tbody tr.spacer-row {
		cursor: default;
	}
	.desktop-table tbody tr.spacer-row:hover {
		background: transparent;
	}
	.table-loading {
		display: grid;
		place-items: center;
		height: auto;
		font-size: 0.82rem;
		color: #3f5652;
	}
	.table-loading-wrap {
		display: grid;
		gap: 0.5rem;
		padding: 0.6rem;
	}
	.table-skeleton {
		display: grid;
		gap: 0.28rem;
	}
	.skeleton-row {
		display: grid;
		grid-template-columns: 0.5fr 1.6fr 0.8fr 0.7fr 0.7fr 0.7fr 1fr;
		gap: 0.4rem;
		height: 28px;
		align-items: center;
	}
	.sk {
		display: inline-block;
		height: 12px;
		border-radius: 999px;
		background: linear-gradient(90deg, rgba(203, 193, 174, 0.34), rgba(236, 228, 212, 0.86), rgba(203, 193, 174, 0.34));
		background-size: 220% 100%;
		animation: skeleton-shimmer 1.35s ease-in-out infinite;
	}
	.sk-sm { width: 60%; }
	.sk-md { width: 78%; }
	.sk-lg { width: 94%; }
	@keyframes skeleton-shimmer {
		0% { background-position: 100% 0; }
		100% { background-position: -100% 0; }
	}
	.panel-wrapper {
		display: contents;
	}
	.inspector-desktop {
		min-width: 0;
		min-height: 0;
		overflow-y: auto;
		height: 100%;
		background: rgba(251, 246, 236, 0.95);
		border-left: 1px solid rgba(21, 32, 33, 0.12);
	}
	.desktop-ranking {
		padding: 1rem;
		display: grid;
		gap: 0.5rem;
	}
	.desktop-ranking h2 {
		margin: 0;
		font-family: 'Fraunces', serif;
		font-size: 1.22rem;
	}
	.desktop-ranking p {
		margin: 0;
		font-size: 0.82rem;
		color: #3f5652;
		line-height: 1.3;
	}
	.desktop-toggle {
		display: inline-flex;
		gap: 0.25rem;
		padding: 0.2rem;
		border: 1px solid rgba(21, 32, 33, 0.18);
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.65);
		width: fit-content;
	}
	.desktop-toggle button {
		border: 0;
		border-radius: 999px;
		padding: 0.28rem 0.62rem;
		font-size: 0.72rem;
		background: transparent;
		color: #425a56;
		cursor: pointer;
	}
	.desktop-toggle button.active {
		background: rgba(47, 125, 133, 0.15);
		color: #2f7d85;
		font-weight: 600;
	}
	.desktop-ranking .muted {
		font-size: 0.76rem;
		color: #4b6460;
	}
	.desktop-score-panel {
		margin-top: 0.5rem;
		padding: 0.85rem;
		display: grid;
		gap: 0.45rem;
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		background: rgba(255, 255, 255, 0.72);
	}
	.desktop-score-panel h3 {
		margin: 0;
		font-family: 'Fraunces', serif;
		font-size: 1.02rem;
	}
	.chips-row {
		display: flex;
		flex-wrap: wrap;
		column-gap: 0.35rem;
		row-gap: 0.45rem;
	}
	.desktop-score-control {
		display: grid;
		gap: 0.28rem;
		max-width: 240px;
	}
	.desktop-score-control label {
		font-size: 0.76rem;
		letter-spacing: 0.02em;
		color: #3f5853;
	}
	.desktop-score-control input[type='range'] {
		height: 10px;
	}
	.sheet-tabs,
	.sheet-content {
		display: none;
	}
	@media (max-width: 900px) {
		.topbar {
			height: 50px;
			padding: 0.25rem 0.5rem;
			gap: 0.4rem;
			overflow: hidden;
		}
		.topbar-controls {
			gap: 0.2rem;
		}
		.topbar-docs-link {
			display: none;
		}
		.topbar-docs-link {
			padding: 0.22rem 0.45rem;
			font-size: 0.65rem;
			gap: 0.22rem;
		}
		.topbar-docs-link-mobile {
			display: block;
			font-size: 0.58rem;
			color: #2f676a;
			text-decoration: underline;
			text-underline-offset: 0.11rem;
			white-space: nowrap;
		}
		.topbar-brand-meta {
			display: grid;
			gap: 0.08rem;
		}
		.topbar-legend {
			display: block;
			transform: scale(0.9);
		}
		.mode-strip {
			display: none;
		}
		.topbar-mode {
			display: none;
		}
		.topbar-brand strong {
			font-size: 0.98rem;
		}
		.topbar-brand small {
			display: block;
			font-size: 0.58rem;
			white-space: nowrap;
		}
		main {
			display: block;
			height: calc(100vh - 50px);
			height: calc(100dvh - 50px);
			min-height: calc(100vh - 50px);
			min-height: calc(100dvh - 50px);
			padding: 0;
			gap: 0;
			overflow: hidden;
		}
		.map-wrap {
			display: block;
			height: calc(100vh - 50px);
			height: calc(100dvh - 50px);
			min-height: calc(100vh - 50px);
			min-height: calc(100dvh - 50px);
			border-radius: 0;
			box-shadow: none;
		}
		.map-wrap :global(.map-shell) {
			height: 100%;
		}
		.desktop-table {
			display: none;
		}
		.desktop-table-toggle-wrap {
			display: none;
		}
		.map-desktop-zone {
			height: 100%;
		}
		.panel-wrapper {
			display: none;
		}
		.sheet-tabs {
			display: grid;
			grid-template-columns: repeat(5, minmax(0, 1fr));
			gap: 0.25rem;
			position: sticky;
			top: 0;
			padding: 0.2rem 0 0.45rem;
			background: linear-gradient(180deg, rgba(252, 248, 238, 0.98), rgba(248, 242, 226, 0.96));
			z-index: 2;
		}
		.sheet-tabs button {
			border: 0;
			border-radius: 8px;
			padding: 0.4rem 0.2rem;
			font-size: 0.68rem;
			display: inline-flex;
			align-items: center;
			justify-content: center;
			gap: 0.22rem;
			background: transparent;
			color: #3d5551;
		}
		.sheet-tabs button :global(svg) {
			width: 15px;
			height: 15px;
		}
		.sheet-tabs button.active {
			background: rgba(47, 125, 133, 0.14);
			color: #2f7d85;
			font-weight: 600;
		}
		.sheet-tabs button.has-selection {
			position: relative;
		}
		.sheet-tabs button.has-selection::after {
			content: '';
			position: absolute;
			top: 0.22rem;
			right: 0.35rem;
			width: 0.42rem;
			height: 0.42rem;
			border-radius: 999px;
			background: #2f7d85;
			box-shadow: 0 0 0 2px rgba(252, 248, 238, 0.95);
		}
		.sheet-content {
			display: block;
			padding-bottom: 0.3rem;
		}
		.sheet-empty {
			font-size: 0.82rem;
			color: #415955;
			margin: 0.35rem 0;
		}
		.sheet-block {
			display: grid;
			gap: 0.45rem;
		}
		.sheet-section {
			display: grid;
			gap: 0.4rem;
			padding: 0.5rem;
			border: 1px solid rgba(21, 32, 33, 0.13);
			border-radius: 10px;
			background: rgba(255, 255, 255, 0.45);
		}
		.sheet-section-score {
			padding-top: 0.45rem;
		}
		.sheet-score-summary {
			display: flex;
			flex-wrap: wrap;
			gap: 0.25rem;
		}
		.sheet-score-summary span {
			font-size: 0.68rem;
			padding: 0.16rem 0.45rem;
			border-radius: 999px;
			border: 1px solid rgba(21, 32, 33, 0.16);
			background: rgba(255, 255, 255, 0.6);
			color: #3d5652;
		}
		.sheet-slider-grid {
			display: grid;
			grid-template-columns: repeat(2, minmax(0, 1fr));
			gap: 0.45rem 0.5rem;
		}
		.sheet-score-item {
			display: grid;
			gap: 0.2rem;
		}
		.sheet-label-help-row {
			display: inline-flex;
			align-items: center;
			gap: 0.3rem;
			flex-wrap: nowrap;
		}
		.sheet-label-help-row label {
			display: inline;
			min-width: 0;
			line-height: 1.15;
		}
		.sheet-label-help-row :global(.help-wrap) {
			flex: 0 0 auto;
			margin-top: 0;
		}
		.sheet-label-help-row-nowrap label {
			white-space: nowrap;
		}
		.sheet-block label {
			font-size: 0.75rem;
			color: #3f5753;
		}
		.sheet-subtitle {
			margin: 0.3rem 0 0.05rem;
			font-size: 0.7rem;
			font-weight: 700;
			letter-spacing: 0.06em;
			text-transform: uppercase;
			color: #3d5551;
		}
		.sheet-subtitle-help {
			display: inline-flex;
			align-items: center;
			gap: 0.3rem;
			white-space: nowrap;
		}
		.sheet-subtitle-help :global(.help-wrap) {
			flex: 0 0 auto;
		}
		@media (max-width: 435px) {
			.sheet-label-help-row label,
			.sheet-subtitle-help {
				font-size: 0.68rem;
			}
		}
		.sheet-block select {
			border: 1px solid rgba(21, 32, 33, 0.2);
			border-radius: 8px;
			height: 30px;
			padding: 0 0.5rem;
			font-size: 0.8rem;
			line-height: 1.2;
			background: rgba(255, 255, 255, 0.86);
		}
		.chips-row {
			column-gap: 0.25rem;
			row-gap: 0.25rem;
		}
		.sheet-clear {
			width: auto;
			justify-self: start;
			border: 1px solid rgba(21, 32, 33, 0.22);
			border-radius: 999px;
			background: rgba(255, 255, 255, 0.8);
			padding: 0.3rem 0.6rem;
			font-size: 0.75rem;
		}
		.sheet-actions {
			display: flex;
			flex-wrap: wrap;
			gap: 0.35rem;
			padding: 0.15rem 0 calc(env(safe-area-inset-bottom) + 0.1rem);
		}
		.sheet-rank {
			display: grid;
			gap: 0.2rem;
		}
		.sheet-meta-panel {
			display: grid;
			gap: 0.45rem;
		}
		.sheet-meta-panel h3 {
			margin: 0;
			font-family: 'Fraunces', serif;
			font-size: 1rem;
		}
		.sheet-meta-panel ul {
			margin: 0;
			padding-left: 1rem;
			display: grid;
			gap: 0.2rem;
		}
		.sheet-meta-panel li {
			font-size: 0.76rem;
			color: #3f5753;
		}
		.sheet-export-actions {
			display: flex;
			gap: 0.35rem;
			flex-wrap: wrap;
		}
		.sheet-export-actions .sheet-clear[disabled] {
			opacity: 0.5;
			cursor: not-allowed;
		}
		.sheet-meta {
			margin: 0.1rem 0 0.2rem;
			font-size: 0.72rem;
			color: #48605c;
		}
		.inspector-desktop {
			display: none;
		}
	}
</style>

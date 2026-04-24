<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import type { MapColorMetric } from '$lib/components/map/coloring';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import InspectorPanel from '$lib/components/InspectorPanel.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import ModeToggle from '$lib/components/ui/ModeToggle.svelte';
	import RankingList from '$lib/components/RankingList.svelte';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import ColorLegend from '$lib/components/ColorLegend.svelte';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { applyUrlToState, buildUrlFromState } from '$lib/state/urlSync';
	import { modeCopy, tabForMode } from '$lib/state/viewMode';
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
	const uiStore = createUiStore();
	const filtersStore = createFiltersStore();
	const layersStore = createLayersStore();
	const rankingStore = createRankingStore();
	const isBottomSheetOpen = $derived(uiStore.state.isBottomSheetOpen);
	const mapColorMetric = $derived(uiStore.state.mapColorMetric);
	const viewMode = $derived(uiStore.state.viewMode);
	const activeSheetTab = $derived(uiStore.state.activeSheetTab);
	const isMobileView = $derived(uiStore.state.isMobileView);
	const desktopEvalPanel = $derived(uiStore.state.desktopEvalPanel);
	const query = $derived(filtersStore.state.query);
	const provinceFilter = $derived(filtersStore.state.provinceFilter);
	const maxTravelBucket = $derived(filtersStore.state.maxTravelBucket);
	const minPrecipAnnual = $derived(filtersStore.state.minPrecipAnnual);
	const minWinterTemp = $derived(filtersStore.state.minWinterTemp);
	const maxSummerTemp = $derived(filtersStore.state.maxSummerTemp);
	const maxThermalAmplitude = $derived(filtersStore.state.maxThermalAmplitude);
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

	const provinciasDisponibles = $derived([
		'Todas',
		...Array.from(new Set(municipios.map((m) => m.provincia)))
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
			const queryText = query.trim().toLowerCase();
			const queryOk =
				queryText.length === 0 ||
				m.nombre.toLowerCase().includes(queryText) ||
				m.provincia.toLowerCase().includes(queryText);
			const provinceOk = provinceFilter === 'Todas' || m.provincia === provinceFilter;
			const bucketOk =
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
			return queryOk && provinceOk && bucketOk && precipOk && winterOk && summerOk && amplitudeOk && scoreOk;
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
		sortRows(municipiosFiltrados, sortBy, sortDirection, normalizedWeights, bucketOrder)
	);

	const sensitivityOverlap = $derived(sensitivityTop10Overlap(tableRows, baselineTopIds));

	const shortlistMunicipios = $derived(
		municipiosScoredForView
			.filter((m) => shortlistedIds.includes(m.id))
			.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
	);

	const activeFiltersSummary = $derived(
		[
			provinceFilter !== 'Todas' ? `provincia=${provinceFilter}` : null,
			maxTravelBucket !== '>4h00' ? `acc<=${maxTravelBucket}` : null,
			minPrecipAnnual !== 0 ? `ppt>=${minPrecipAnnual}` : null,
			minWinterTemp !== -10 ? `t_inv>=${minWinterTemp}` : null,
			maxSummerTemp !== 40 ? `t_ver<=${maxSummerTemp}` : null,
			maxThermalAmplitude < 21 ? `amp<=${maxThermalAmplitude.toFixed(1)}` : null,
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

	const mapColorLabel = $derived(
		mapColorMetric === 'mixed_score' ? 'Puntuacion global' : 'Precipitacion anual'
	);

	const topbarLegendConfig = $derived(getLegendConfig(mapColorMetric));

	const topCandidate = $derived(tableRows[0] ?? null);

	const visibleMunicipioIds = $derived(municipiosFiltrados.map((m) => m.id));

	const selectedClimateSeries = $derived(
		selectedMunicipioClimateSeries(climateMonthly, selectedMunicipio?.id ?? null)
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
	};

	const handleToggleShortlist = (municipioId: string) => {
		const wasAdded = selectionStore.toggleShortlist(municipioId);
		if (wasAdded) {
			uiStore.state.desktopEvalPanel = 'shortlist';
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

	const handlePresetWeights = (preset: Preset) => {
		uiStore.state.mapColorMetric = 'mixed_score';
		const weights = weightsForPreset(preset);
		filtersStore.state.climateWeight = weights.climateWeight;
		filtersStore.state.accessWeight = weights.accessWeight;
		filtersStore.state.natureWeight = weights.natureWeight;
	};

	const handleClimateWeightChange = (value: number) => {
		filtersStore.state.climateWeight = value;
		uiStore.state.mapColorMetric = 'mixed_score';
	};

	const handleAccessWeightChange = (value: number) => {
		filtersStore.state.accessWeight = value;
		uiStore.state.mapColorMetric = 'mixed_score';
	};

	const handleNatureWeightChange = (value: number) => {
		filtersStore.state.natureWeight = value;
		uiStore.state.mapColorMetric = 'mixed_score';
	};


	$effect(() => {
		municipios = data.municipios ?? [];
		climateMonthly = data.climateMonthly ?? [];
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
			viewMode,
			query,
			provinceFilter,
			maxTravelBucket,
			minPrecipAnnual,
			minWinterTemp,
			maxSummerTemp,
			maxThermalAmplitude,
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
			viewMode: next.viewMode ?? uiStore.state.viewMode,
			activeSheetTab: next.activeSheetTab ?? uiStore.state.activeSheetTab,
			isBottomSheetOpen: next.isBottomSheetOpen ?? uiStore.state.isBottomSheetOpen
		});
		Object.assign(filtersStore.state, {
			query: next.query ?? filtersStore.state.query,
			provinceFilter: next.provinceFilter ?? filtersStore.state.provinceFilter,
			maxTravelBucket: next.maxTravelBucket ?? filtersStore.state.maxTravelBucket,
			minPrecipAnnual: next.minPrecipAnnual ?? filtersStore.state.minPrecipAnnual,
			minWinterTemp: next.minWinterTemp ?? filtersStore.state.minWinterTemp,
			maxSummerTemp: next.maxSummerTemp ?? filtersStore.state.maxSummerTemp,
			maxThermalAmplitude: next.maxThermalAmplitude ?? filtersStore.state.maxThermalAmplitude,
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
		const params = buildUrlFromState({
			viewMode,
			query,
			provinceFilter,
			maxTravelBucket,
			minPrecipAnnual,
			minWinterTemp,
			maxSummerTemp,
			maxThermalAmplitude,
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
		window.history.replaceState({}, '', nextUrl);
	});

	$effect(() => {
		if (selectedMunicipio && !municipiosScoredForView.some((m) => m.id === selectedMunicipio?.id)) {
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
		if (viewMode === 'evaluacion') {
			uiStore.state.mapColorMetric = 'mixed_score';
		}
		uiStore.state.activeSheetTab = tabForMode(
			viewMode,
			activeSheetTab,
			isMobileView,
			Boolean(selectedMunicipio)
		);
	});

	$effect(() => {
		if (viewMode === 'exploracion') showDesktopEvalTable = false;
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
	<a class="topbar-brand" href="/" aria-label="Ir al inicio de El Buen Vivir">
		<strong>El Buen Vivir</strong>
		<small>{modeCopy[viewMode].tagline} · {municipiosFiltrados.length}/{municipios.length}</small>
	</a>
	<div class="topbar-controls">
		<div class="topbar-legend">
			<ColorLegend
				title={topbarLegendConfig.title}
				thresholds={topbarLegendConfig.thresholds}
				colors={topbarLegendConfig.colors as any[]}
				labels={topbarLegendConfig.labels as any[]}
				formatLabel={topbarLegendConfig.formatLabel}
				width={220}
			/>
		</div>
		<div class="topbar-mode">
			<ModeToggle mode={viewMode} onChange={(nextMode) => (uiStore.state.viewMode = nextMode)} />
		</div>
	</div>
</header>

<section class="mode-strip" class:evaluation={viewMode === 'evaluacion'}>
	{#if viewMode === 'exploracion'}
		<p><strong>Exploración activa.</strong> Ajusta filtros y capas para reconocer patrones territoriales.</p>
		<div class="mode-strip-metrics">
			<span>Color mapa: {mapColorLabel}</span>
			<span>Capas activas: {activeLayerCount}</span>
			<span>Filtro provincia: {provinceFilter}</span>
		</div>
	{:else}
		<p><strong>Evaluación activa.</strong> El ranking usa los pesos actuales y se actualiza en tiempo real.</p>
		<div class="mode-strip-metrics">
			<span>Pesos C/A/N: {climateWeight}/{accessWeight}/{natureWeight}</span>
			<span>Robustez top-10: {sensitivityOverlap}/10</span>
			<span>Top actual: {topCandidate ? `${topCandidate.nombre} (${topCandidate.mixed_score?.toFixed(3) ?? '-'})` : 'sin datos'}</span>
		</div>
	{/if}
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
				{minCompositeScore}
				{layerOrder}
				activeFiltersSummary={activeFiltersSummary}
				shortlistMunicipios={shortlistMunicipios}
				shortlistedIds={shortlistedIds}
				isEvaluationMode={viewMode === 'evaluacion'}
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
				onMapColorMetricChange={(value) => (uiStore.state.mapColorMetric = value)}
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

		<section class="map-wrap" class:table-hidden={viewMode === 'evaluacion' && !showDesktopEvalTable}>
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
					{showForestLayer}
					{showLandUseLayer}
					{showVegetationLayer}
					{layerOrder}
					{visibleMunicipioIds}
					{provinceFilter}
					pmtilesUrl={municipiosPmtilesUrl}
					onMapSelection={handleSelectMunicipio}
				/>
			</div>
			{#if viewMode === 'evaluacion'}
				<div class="desktop-table-toggle-wrap">
					<button type="button" class="desktop-table-toggle" onclick={() => (showDesktopEvalTable = !showDesktopEvalTable)}>
						{showDesktopEvalTable ? 'Ocultar tabla completa' : 'Mostrar tabla completa'}
					</button>
				</div>
			{/if}
			{#if viewMode !== 'evaluacion' || showDesktopEvalTable}
			<section class="desktop-table" aria-label="Tabla analítica de municipios">
				<div class="desktop-table-inner">
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
							{#each tableRows as municipio (municipio.id)}
								<tr onclick={() => handleSelectMunicipio(municipio)}>
									<td>{municipio.nombre}</td>
									<td>{municipio.provincia}</td>
									<td>{municipio.travel_bucket}</td>
									<td>{municipio.precip_annual_mm}</td>
									<td>{municipio.temp_winter_mean_c}</td>
									<td>{municipio.temp_summer_mean_c}</td>
									<td>{municipio.mixed_score?.toFixed(3) ?? '-'}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</section>
			{/if}
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
									isEvaluationMode={viewMode === 'evaluacion'}
									climateSeries={selectedClimateSeries}
									provinceClimateSeries={selectedProvinceClimateSeries}
									ccaaClimateSeries={selectedCcaaClimateSeries}
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
									onclick={() => {
										uiStore.state.viewMode = 'evaluacion';
										handleSelectSheetTab('rank');
									}}
								>
									Ir al ranking
								</button>
							{/if}
						{:else if activeSheetTab === 'filtr'}
							<div class="sheet-block">
								<ModeToggle mode={viewMode} onChange={(nextMode) => (uiStore.state.viewMode = nextMode)} />
								<p class="sheet-meta">{modeCopy[viewMode].helper}</p>
								<section class="sheet-section">
									<p class="sheet-subtitle">Filtros base</p>
									<label for="sheet-province">Provincia</label>
								<select id="sheet-province" value={provinceFilter} onchange={(e) => (filtersStore.state.provinceFilter = (e.currentTarget as HTMLSelectElement).value)}>
										{#each provinciasDisponibles as provincia}
											<option value={provincia}>{provincia}</option>
										{/each}
									</select>
									<div class="chips-row">
										{#each travelBuckets as bucket}
											<ChipButton label={bucket.label} size="small" compact={true} active={maxTravelBucket === bucket.value} onclick={() => (filtersStore.state.maxTravelBucket = bucket.value)} />
										{/each}
									</div>
									<p class="sheet-subtitle">Filtros de climatología</p>
									<div class="sheet-slider-grid">
										<div class="sheet-score-item">
											<label for="sheet-min-precip">Precipitación mínima anual: {minPrecipAnnual} mm</label>
											<input id="sheet-min-precip" type="range" min="0" max="1800" step="10" value={minPrecipAnnual} oninput={(e) => (filtersStore.state.minPrecipAnnual = toNumber(e))} />
										</div>
										<div class="sheet-score-item">
											<label for="sheet-min-winter">Temp. invierno mínima: {minWinterTemp} C</label>
											<input id="sheet-min-winter" type="range" min="-15" max="15" step="0.5" value={minWinterTemp} oninput={(e) => (filtersStore.state.minWinterTemp = toNumber(e))} />
										</div>
										<div class="sheet-score-item">
											<label for="sheet-max-summer">Temp. verano máxima: {maxSummerTemp} C</label>
											<input id="sheet-max-summer" type="range" min="15" max="40" step="0.5" value={maxSummerTemp} oninput={(e) => (filtersStore.state.maxSummerTemp = toNumber(e))} />
										</div>
										<div class="sheet-score-item">
											<label for="sheet-max-amplitude">Amplitud térmica máxima: {maxThermalAmplitude.toFixed(1)} C</label>
											<input id="sheet-max-amplitude" type="range" min="12" max="21" step="0.1" value={maxThermalAmplitude} oninput={(e) => (filtersStore.state.maxThermalAmplitude = toNumber(e))} />
										</div>
									</div>
								</section>
								{#if viewMode === 'evaluacion'}
									<section class="sheet-section sheet-section-score">
										<div class="sheet-score-summary">
											<span>Pesos C/A/N: {climateWeight}/{accessWeight}/{natureWeight}</span>
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
												<label for="sheet-min-score">Score mínimo visible: {minCompositeScore.toFixed(2)}</label>
												<input id="sheet-min-score" type="range" min="0" max="1" step="0.01" value={minCompositeScore} oninput={(e) => (filtersStore.state.minCompositeScore = toNumber(e))} />
											</div>
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
								{/if}
								<div class="sheet-actions">
									<button class="sheet-clear" onclick={handleClearFilters}>Limpiar filtros</button>
									{#if viewMode === 'evaluacion'}
										<button class="sheet-clear" onclick={() => handleSelectSheetTab('rank')}>Ir a ranking</button>
									{/if}
								</div>
							</div>
						{:else if activeSheetTab === 'capas'}
							<div class="sheet-block">
								<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={handleLayerOrderChange} />
								<div class="chips-row">
									<ChipButton label="Puntuación global" active={mapColorMetric === 'mixed_score'} onclick={() => (uiStore.state.mapColorMetric = 'mixed_score')} />
									<ChipButton label="Precipitación" active={mapColorMetric === 'precip_annual_mm'} onclick={() => (uiStore.state.mapColorMetric = 'precip_annual_mm')} />
								</div>
								<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => (layersStore.state.showIgnWmsBase = (e.currentTarget as HTMLInputElement).checked)} /> Base IGN</label>
								<label><input type="checkbox" checked={showIgnSatellite} onchange={(e) => (layersStore.state.showIgnSatellite = (e.currentTarget as HTMLInputElement).checked)} /> Satélite IGN</label>
							</div>
						{:else if activeSheetTab === 'rank'}
							<div class="sheet-rank">
								{#if viewMode === 'evaluacion'}
									<p class="sheet-meta">Top 25 en base a score mixto actual.</p>
									<RankingList rows={tableRows} limit={25} compact={true} onSelect={handleSelectMunicipio} />
								{:else}
									<p class="sheet-meta">El ranking se utiliza en modo evaluación.</p>
									<button class="sheet-clear" onclick={() => { uiStore.state.viewMode = 'evaluacion'; handleSelectSheetTab('rank'); }}>Cambiar a evaluación</button>
								{/if}
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
			{#if viewMode === 'evaluacion' && !selectedMunicipio}
				<section class="desktop-ranking">
					<h2>Evaluación</h2>
					<p>Selecciona un municipio para ver su ficha o usa este ranking para comparar.</p>
					<div class="desktop-toggle" role="tablist" aria-label="Vista de evaluación">
						<button
							type="button"
							class:active={desktopEvalPanel === 'top'}
							onclick={() => (uiStore.state.desktopEvalPanel = 'top')}
						>
							Top 25
						</button>
						<button
							type="button"
							class:active={desktopEvalPanel === 'shortlist'}
							onclick={() => (uiStore.state.desktopEvalPanel = 'shortlist')}
						>
							Shortlist ({shortlistMunicipios.length})
						</button>
					</div>
					{#if desktopEvalPanel === 'top'}
						<p class="muted">Top 25 por score mixto · robustez {sensitivityOverlap}/10</p>
						<RankingList rows={tableRows} limit={25} onSelect={handleSelectMunicipio} />
					{:else}
						{#if shortlistMunicipios.length > 0}
							<p class="muted">Municipios guardados en shortlist.</p>
							<RankingList rows={shortlistMunicipios} limit={200} onSelect={handleSelectMunicipio} />
						{:else}
							<p class="muted">Tu shortlist está vacía. Abre un municipio y pulsa "Guardar shortlist".</p>
						{/if}
					{/if}

					<section class="desktop-score-panel">
						<h3>Ajuste del score</h3>
						<p class="muted">Estos pesos cambian el score y el ranking; el filtro de score mínimo del panel izquierdo decide qué municipios se muestran en mapa y tabla.</p>
						<div class="chips-row">
							<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => handlePresetWeights('equilibrado')} />
							<ChipButton label="Priorizar naturaleza" active={activePreset === 'naturaleza'} onclick={() => handlePresetWeights('naturaleza')} />
							<ChipButton label="Priorizar accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => handlePresetWeights('accesibilidad')} />
							<ChipButton label="Priorizar clima" active={activePreset === 'clima'} onclick={() => handlePresetWeights('clima')} />
							<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => handlePresetWeights('clima_estricto')} />
						</div>
						<div class="desktop-score-control">
							<label for="desktop-rw-climate">Peso clima: {climateWeight}</label>
							<input id="desktop-rw-climate" type="range" min="0" max="100" step="1" value={climateWeight} oninput={(e) => handleClimateWeightChange(toNumber(e))} />
						</div>
						<div class="desktop-score-control">
							<label for="desktop-rw-access">Peso accesibilidad: {accessWeight}</label>
							<input id="desktop-rw-access" type="range" min="0" max="100" step="1" value={accessWeight} oninput={(e) => handleAccessWeightChange(toNumber(e))} />
						</div>
						<div class="desktop-score-control">
							<label for="desktop-rw-nature">Peso naturaleza: {natureWeight}</label>
							<input id="desktop-rw-nature" type="range" min="0" max="100" step="1" value={natureWeight} oninput={(e) => handleNatureWeightChange(toNumber(e))} />
						</div>
						<p class="muted">Normalizados: clima {(normalizedWeights.climate * 100).toFixed(0)}% · acces {(normalizedWeights.access * 100).toFixed(0)}% · nat {(normalizedWeights.nature * 100).toFixed(0)}%</p>
						<p class="muted">Robustez top-10 vs base equilibrada: {sensitivityOverlap}/10</p>
					</section>
				</section>
			{:else if viewMode === 'exploracion' && !selectedMunicipio}
				<section class="desktop-ranking">
					<h2>Exploración</h2>
					<p>Explora el mapa, capas y filtros. Al seleccionar un municipio verás la ficha completa aquí.</p>
				</section>
			{:else}
				<InspectorPanel
					{selectedMunicipio}
					municipios={municipiosScoredForView}
					shortlistedIds={shortlistedIds}
					weights={normalizedWeights}
					weightsRaw={{ climateWeight, accessWeight, natureWeight }}
					sensitivityOverlap={sensitivityOverlap}
					isEvaluationMode={viewMode === 'evaluacion'}
					climateSeries={selectedClimateSeries}
					provinceClimateSeries={selectedProvinceClimateSeries}
					ccaaClimateSeries={selectedCcaaClimateSeries}
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
		text-decoration: none;
		color: inherit;
	}
	.topbar-brand:visited {
		color: inherit;
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
		gap: 0.6rem;
		margin-left: auto;
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
		.topbar-legend {
			display: block;
			transform: scale(0.8);
			transform-origin: right center;
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
		.sheet-block select {
			border: 1px solid rgba(21, 32, 33, 0.2);
			border-radius: 8px;
			padding: 0.4rem 0.5rem;
			font-size: 0.8rem;
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

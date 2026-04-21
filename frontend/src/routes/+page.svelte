<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import InspectorPanel from '$lib/components/InspectorPanel.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import ModeToggle from '$lib/components/ui/ModeToggle.svelte';
	import RankingList from '$lib/components/RankingList.svelte';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import ColorLegend from '$lib/components/ColorLegend.svelte';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { buildUrlState, parseUrlState } from '$lib/state/urlState';
	import { modeCopy, tabForMode } from '$lib/state/viewMode';
	import {
		bucketOrder,
		clampNumber,
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
		type SortDirection,
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
	let selectedMunicipio = $state<Municipio | null>(null);
	let isBottomSheetOpen = $state(false);
	let query = $state('');
	let showMunicipioPolygons = $state(true);
	let showMunicipioPoints = $state(false);
	let showIgnWmsBase = $state(true);
	let showIgnSatellite = $state(false);
	let showIgnRivers = $state(false);
	let showIgnReservoirs = $state(false);
	let mapColorMetric = $state<'precip_annual_mm' | 'mixed_score'>('mixed_score');
	let viewMode = $state<'exploracion' | 'evaluacion'>('exploracion');
	let activeSheetTab = $state<'sel' | 'filtr' | 'capas' | 'rank' | 'meta'>('filtr');
	let isMobileView = $state(false);
	let desktopEvalPanel = $state<'top' | 'shortlist'>('top');
	let showForestLayer = $state(false);
	let showLandUseLayer = $state(false);
	let showVegetationLayer = $state(false);
	let minCompositeScore = $state(0);
	let layerOrder = $state<string[]>([
		'municipios',
		'landuse',
		'reservoirs',
		'rivers'
	]);
	const municipiosPmtilesUrl = '/tiles/municipios.pmtiles';
	let provinceFilter = $state('Todas');
	let shortlistedIds = $state<string[]>([]);
	let sortBy = $state<SortField>('mixed_score');
	let sortDirection = $state<SortDirection>('desc');

	let maxTravelBucket = $state<TravelBucket>('>4h00');
	let minPrecipAnnual = $state(0);
	let minWinterTemp = $state(-10);
	let maxSummerTemp = $state(40);
	let maxThermalAmplitude = $state(21);
	let climateWeight = $state(DEFAULT_WEIGHTS_RAW.climateWeight);
	let accessWeight = $state(DEFAULT_WEIGHTS_RAW.accessWeight);
	let natureWeight = $state(DEFAULT_WEIGHTS_RAW.natureWeight);
	let urlStateReady = $state(false);
	let pendingSelectedMunicipioId = $state<string | null>(null);

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
		showLandUseLayer,
		showVegetationLayer,
		showForestLayer,
		showIgnReservoirs,
		showIgnRivers
	});

	const toggleLayerVisibility = (layerKey: string, checked: boolean) => {
		if (layerKey === 'municipios') showMunicipioPolygons = checked;
		else if (layerKey === 'landuse') showLandUseLayer = checked;
		else if (layerKey === 'vegetation') showVegetationLayer = checked;
		else if (layerKey === 'forest') showForestLayer = checked;
		else if (layerKey === 'reservoirs') showIgnReservoirs = checked;
		else if (layerKey === 'rivers') showIgnRivers = checked;
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
			selectedMunicipio = null;
			return;
		}
		selectedMunicipio = municipio;
		const panel = panelStateOnSelect(activeSheetTab, isMobileView);
		activeSheetTab = panel.tab;
		queueMicrotask(() => {
			isBottomSheetOpen = panel.open;
		});
	};

	const handleClearSelectedMunicipio = () => {
		selectedMunicipio = null;
		pendingSelectedMunicipioId = null;
		const panel = panelStateOnClearSelection(activeSheetTab, isMobileView);
		activeSheetTab = panel.tab;
		isBottomSheetOpen = panel.open;
	};

	const handleSelectSheetTab = (tab: 'sel' | 'filtr' | 'capas' | 'rank' | 'meta') => {
		const panel = panelStateOnTabClick(tab);
		activeSheetTab = panel.tab;
		isBottomSheetOpen = panel.open;
	};

	const downloadFile = (filename: string, content: string, mimeType: string) => {
		if (typeof window === 'undefined') return;
		const blob = new Blob([content], { type: mimeType });
		const url = URL.createObjectURL(blob);
		const link = document.createElement('a');
		link.href = url;
		link.download = filename;
		link.click();
		URL.revokeObjectURL(url);
	};

	const csvCell = (value: string | number | undefined | null) => {
		if (value === undefined || value === null) return '';
		const text = String(value);
		return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
	};

	const handleExportShortlistCsv = () => {
		if (shortlistMunicipios.length === 0) return;
		const headers = ['id', 'codigo', 'nombre', 'provincia', 'travel_bucket', 'mixed_score'];
		const rows = shortlistMunicipios.map((m) =>
			[
				m.id,
				m.codigo,
				m.nombre,
				m.provincia,
				m.travel_bucket,
				m.mixed_score?.toFixed(4) ?? ''
			]
				.map(csvCell)
				.join(',')
		);
		downloadFile('shortlist_el_buen_vivir.csv', `${headers.join(',')}\n${rows.join('\n')}`, 'text/csv;charset=utf-8');
	};

	const handleExportShortlistJson = () => {
		if (shortlistMunicipios.length === 0) return;
		downloadFile(
			'shortlist_el_buen_vivir.json',
			JSON.stringify(shortlistMunicipios, null, 2),
			'application/json;charset=utf-8'
		);
	};

	const handleClearFilters = () => {
		provinceFilter = 'Todas';
		maxTravelBucket = '>4h00';
		minPrecipAnnual = 0;
		minWinterTemp = -10;
		maxSummerTemp = 40;
		maxThermalAmplitude = 21;
		minCompositeScore = 0;
	};

	const handleToggleShortlist = (municipioId: string) => {
		const wasShortlisted = shortlistedIds.includes(municipioId);
		shortlistedIds = wasShortlisted
			? shortlistedIds.filter((id) => id !== municipioId)
			: [...shortlistedIds, municipioId];
		if (!wasShortlisted) {
			desktopEvalPanel = 'shortlist';
		}
	};

	const handleChangeSort = (newSortBy: SortField) => {
		const next = nextSortState(sortBy, sortDirection, newSortBy);
		sortBy = next.sortBy;
		sortDirection = next.sortDirection;
	};

	const handleLayerOrderChange = (nextOrder: string[]) => {
		layerOrder = nextOrder;
	};

	const handlePresetWeights = (preset: Preset) => {
		mapColorMetric = 'mixed_score';
		const weights = weightsForPreset(preset);
		climateWeight = weights.climateWeight;
		accessWeight = weights.accessWeight;
		natureWeight = weights.natureWeight;
	};

	const handleClimateWeightChange = (value: number) => {
		climateWeight = value;
		mapColorMetric = 'mixed_score';
	};

	const handleAccessWeightChange = (value: number) => {
		accessWeight = value;
		mapColorMetric = 'mixed_score';
	};

	const handleNatureWeightChange = (value: number) => {
		natureWeight = value;
		mapColorMetric = 'mixed_score';
	};


	$effect(() => {
		municipios = data.municipios ?? [];
		climateMonthly = data.climateMonthly ?? [];
	});

	$effect(() => {
		if (typeof window === 'undefined') return;
		const updateViewport = () => {
			isMobileView = window.innerWidth <= 900;
		};
		updateViewport();
		window.addEventListener('resize', updateViewport);
		return () => window.removeEventListener('resize', updateViewport);
	});

	$effect(() => {
		if (typeof window === 'undefined' || urlStateReady) return;
		const state = parseUrlState(window.location.search);

		if (state.mode) viewMode = state.mode;
		if (state.q) query = state.q;
		if (state.province) provinceFilter = state.province;
		if (state.travel) maxTravelBucket = state.travel;

		if (state.ppt !== undefined) minPrecipAnnual = clampNumber(state.ppt, 0, 1800);
		if (state.tw !== undefined) minWinterTemp = clampNumber(state.tw, -15, 15);
		if (state.ts !== undefined) maxSummerTemp = clampNumber(state.ts, 15, 40);
		if (state.ta !== undefined) maxThermalAmplitude = clampNumber(state.ta, 12, 21);
		if (state.score !== undefined) minCompositeScore = clampNumber(state.score, 0, 1);

		if (state.cw !== undefined) climateWeight = clampNumber(state.cw, 0, 100);
		if (state.aw !== undefined) accessWeight = clampNumber(state.aw, 0, 100);
		if (state.nw !== undefined) natureWeight = clampNumber(state.nw, 0, 100);

		if (state.tab)
			activeSheetTab = tabForMode(
				state.mode ?? viewMode,
				state.tab,
				window.innerWidth <= 900,
				Boolean(state.sel)
			);
		if (state.sel) pendingSelectedMunicipioId = state.sel;
		if (state.open && window.innerWidth <= 900) isBottomSheetOpen = true;

		urlStateReady = true;
	});

	$effect(() => {
		if (typeof window === 'undefined' || !urlStateReady) return;
		const params = buildUrlState({
			mode: viewMode,
			q: query.trim().length > 0 ? query.trim() : undefined,
			province: provinceFilter !== 'Todas' ? provinceFilter : undefined,
			travel: maxTravelBucket !== '>4h00' ? maxTravelBucket : undefined,
			ppt: minPrecipAnnual !== 0 ? minPrecipAnnual : undefined,
			tw: minWinterTemp !== -10 ? minWinterTemp : undefined,
			ts: maxSummerTemp !== 40 ? maxSummerTemp : undefined,
			ta: maxThermalAmplitude < 21 ? Number(maxThermalAmplitude.toFixed(1)) : undefined,
			score: minCompositeScore > 0 ? minCompositeScore : undefined,
			cw: viewMode === 'evaluacion' ? climateWeight : undefined,
			aw: viewMode === 'evaluacion' ? accessWeight : undefined,
			nw: viewMode === 'evaluacion' ? natureWeight : undefined,
			tab: isMobileView && activeSheetTab !== 'filtr' ? activeSheetTab : undefined,
			sel: selectedMunicipio?.id,
			open: isMobileView ? isBottomSheetOpen : undefined
		});

		const queryString = params.toString();
		const nextUrl = queryString ? `${window.location.pathname}?${queryString}` : window.location.pathname;
		window.history.replaceState({}, '', nextUrl);
	});

	$effect(() => {
		if (selectedMunicipio && !municipiosScoredForView.some((m) => m.id === selectedMunicipio?.id)) {
			selectedMunicipio = null;
		}
	});

	$effect(() => {
		if (!pendingSelectedMunicipioId || municipiosScoredForView.length === 0) return;
		const fromUrl = municipiosScoredForView.find((m) => m.id === pendingSelectedMunicipioId) ?? null;
		if (!fromUrl) {
			pendingSelectedMunicipioId = null;
			return;
		}
		selectedMunicipio = fromUrl;
		pendingSelectedMunicipioId = null;
	});

	$effect(() => {
		if (!selectedMunicipio) return;
		const refreshed = municipiosScoredForView.find((m) => m.id === selectedMunicipio?.id) ?? null;
		if (refreshed && refreshed.id === selectedMunicipio.id) {
			const changedScore = Math.abs((refreshed.mixed_score ?? 0) - (selectedMunicipio.mixed_score ?? 0)) > 0.0001;
			if (changedScore) selectedMunicipio = refreshed;
		}
	});

	$effect(() => {
		shortlistedIds = loadStringArray('ebv-shortlist-v1');
	});

	$effect(() => {
		saveStringArray('ebv-shortlist-v1', shortlistedIds);
	});

	$effect(() => {
		if (viewMode === 'evaluacion') {
			mapColorMetric = 'mixed_score';
		}
		activeSheetTab = tabForMode(viewMode, activeSheetTab, isMobileView, Boolean(selectedMunicipio));
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
		<strong>El Buen Vivir</strong>
		<small>{modeCopy[viewMode].tagline} · {municipiosFiltrados.length}/{municipios.length}</small>
	</div>
	<div class="topbar-controls">
		<div class="topbar-legend">
			<ColorLegend
				title={topbarLegendConfig.title}
				thresholds={topbarLegendConfig.thresholds}
				colors={topbarLegendConfig.colors}
				formatLabel={topbarLegendConfig.formatLabel}
				width={148}
			/>
		</div>
		<div class="topbar-mode">
			<ModeToggle mode={viewMode} onChange={(nextMode) => (viewMode = nextMode)} />
		</div>
	</div>
</header>

<section class="mode-strip" class:evaluation={viewMode === 'evaluacion'}>
	{#if viewMode === 'exploracion'}
		<p><strong>Exploracion activa.</strong> Ajusta filtros y capas para reconocer patrones territoriales.</p>
		<div class="mode-strip-metrics">
			<span>Color mapa: {mapColorLabel}</span>
			<span>Capas activas: {activeLayerCount}</span>
			<span>Filtro provincia: {provinceFilter}</span>
		</div>
	{:else}
		<p><strong>Evaluacion activa.</strong> El ranking usa los pesos actuales y se actualiza en tiempo real.</p>
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
				onQueryChange={(value) => (query = value)}
				onSelectMunicipio={handleSelectMunicipio}
				onToggleMunicipioPolygons={(value) => (showMunicipioPolygons = value)}
				onToggleIgnWmsBase={(value) => (showIgnWmsBase = value)}
				onToggleIgnSatellite={(value: boolean) => (showIgnSatellite = value)}
				onToggleIgnRivers={(value: boolean) => (showIgnRivers = value)}
				onToggleIgnReservoirs={(value: boolean) => (showIgnReservoirs = value)}
				onMapColorMetricChange={(value) => (mapColorMetric = value)}
				onToggleForestLayer={(value) => (showForestLayer = value)}
				onToggleLandUseLayer={(value) => (showLandUseLayer = value)}
				onToggleVegetationLayer={(value) => (showVegetationLayer = value)}
				onProvinceFilterChange={(value) => (provinceFilter = value)}
				onMaxTravelBucketChange={(value) => (maxTravelBucket = value)}
				onMinPrecipAnnualChange={(value) => (minPrecipAnnual = value)}
				onMinWinterTempChange={(value) => (minWinterTemp = value)}
				onMaxSummerTempChange={(value) => (maxSummerTemp = value)}
				onMaxThermalAmplitudeChange={(value) => (maxThermalAmplitude = value)}
				onMinCompositeScoreChange={(value: number) => (minCompositeScore = value)}
				onClearFilters={handleClearFilters}
				onLayerOrderChange={handleLayerOrderChange}
				onToggleShortlist={handleToggleShortlist}
				onClimateWeightChange={handleClimateWeightChange}
				onAccessWeightChange={handleAccessWeightChange}
				onNatureWeightChange={handleNatureWeightChange}
				onPresetWeights={handlePresetWeights}
			/>
		</div>

		<section class="map-wrap">
			<div class="map-desktop-zone">
				<MapView
					municipios={municipiosScoredForView}
					{selectedMunicipio}
					{showMunicipioPolygons}
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
			<section class="desktop-table" aria-label="Tabla analitica de municipios">
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
			<BottomSheet initialHeight="34vh" expandedHeight="62vh" peekHeight="5.2rem" snapPoints={[0.12, 0.55, 0.92]} bind:isOpen={isBottomSheetOpen}>
				{#snippet children()}
					<div class="sheet-tabs" role="tablist" aria-label="Panel movil">
						<button class:active={activeSheetTab === 'sel'} onclick={() => handleSelectSheetTab('sel')}><MapPin size={16} />Sel</button>
						<button class:active={activeSheetTab === 'filtr'} onclick={() => handleSelectSheetTab('filtr')}><SlidersHorizontal size={16} />Filtr</button>
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
										viewMode = 'evaluacion';
										handleSelectSheetTab('rank');
									}}
								>
									Ir al ranking
								</button>
							{/if}
						{:else if activeSheetTab === 'filtr'}
							<div class="sheet-block">
								<ModeToggle mode={viewMode} onChange={(nextMode) => (viewMode = nextMode)} />
								<p class="sheet-meta">{modeCopy[viewMode].helper}</p>
								<label for="sheet-province">Provincia</label>
								<select id="sheet-province" value={provinceFilter} onchange={(e) => (provinceFilter = (e.currentTarget as HTMLSelectElement).value)}>
									{#each provinciasDisponibles as provincia}
										<option value={provincia}>{provincia}</option>
									{/each}
								</select>
								<div class="chips-row">
									{#each travelBuckets as bucket}
										<ChipButton label={bucket.label} size="small" compact={true} active={maxTravelBucket === bucket.value} onclick={() => (maxTravelBucket = bucket.value)} />
									{/each}
								</div>
								<p class="sheet-subtitle">Filtros de climatologia</p>
								<div class="sheet-slider-grid">
									<div class="sheet-score-item">
										<label for="sheet-min-precip">Precipitacion minima anual: {minPrecipAnnual} mm</label>
										<input id="sheet-min-precip" type="range" min="0" max="1800" step="10" value={minPrecipAnnual} oninput={(e) => (minPrecipAnnual = toNumber(e))} />
									</div>
									<div class="sheet-score-item">
										<label for="sheet-min-winter">Temp. invierno minima: {minWinterTemp} C</label>
										<input id="sheet-min-winter" type="range" min="-15" max="15" step="0.5" value={minWinterTemp} oninput={(e) => (minWinterTemp = toNumber(e))} />
									</div>
									<div class="sheet-score-item">
										<label for="sheet-max-summer">Temp. verano maxima: {maxSummerTemp} C</label>
										<input id="sheet-max-summer" type="range" min="15" max="40" step="0.5" value={maxSummerTemp} oninput={(e) => (maxSummerTemp = toNumber(e))} />
									</div>
									<div class="sheet-score-item">
										<label for="sheet-max-amplitude">Amplitud termica maxima: {maxThermalAmplitude.toFixed(1)} C</label>
										<input id="sheet-max-amplitude" type="range" min="12" max="21" step="0.1" value={maxThermalAmplitude} oninput={(e) => (maxThermalAmplitude = toNumber(e))} />
									</div>
								</div>
								{#if viewMode === 'evaluacion'}
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
											<label for="sheet-min-score">Score minimo visible: {minCompositeScore.toFixed(2)}</label>
											<input id="sheet-min-score" type="range" min="0" max="1" step="0.01" value={minCompositeScore} oninput={(e) => (minCompositeScore = toNumber(e))} />
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
									<p class="sheet-meta">Robustez top-10: {sensitivityOverlap}/10</p>
								{/if}
								<button class="sheet-clear" onclick={handleClearFilters}>Limpiar filtros</button>
							</div>
						{:else if activeSheetTab === 'capas'}
							<div class="sheet-block">
								<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={handleLayerOrderChange} />
								<div class="chips-row">
									<ChipButton label="Puntuacion global" active={mapColorMetric === 'mixed_score'} onclick={() => (mapColorMetric = 'mixed_score')} />
									<ChipButton label="Precipitacion" active={mapColorMetric === 'precip_annual_mm'} onclick={() => (mapColorMetric = 'precip_annual_mm')} />
								</div>
								<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => (showIgnWmsBase = (e.currentTarget as HTMLInputElement).checked)} /> Base IGN</label>
								<label><input type="checkbox" checked={showIgnSatellite} onchange={(e) => (showIgnSatellite = (e.currentTarget as HTMLInputElement).checked)} /> Satelite IGN</label>
							</div>
						{:else if activeSheetTab === 'rank'}
							<div class="sheet-rank">
								{#if viewMode === 'evaluacion'}
									<p class="sheet-meta">Top 25 en base a score mixto actual.</p>
									<RankingList rows={tableRows} limit={25} compact={true} onSelect={handleSelectMunicipio} />
								{:else}
									<p class="sheet-meta">El ranking se utiliza en modo evaluacion.</p>
									<button class="sheet-clear" onclick={() => { viewMode = 'evaluacion'; handleSelectSheetTab('rank'); }}>Cambiar a evaluacion</button>
								{/if}
							</div>
						{:else}
							<section class="sheet-meta-panel" aria-label="Metodologia y metadatos">
								<h3>Datos y metodologia</h3>
								{#if data.datasetMetadata}
									<ul>
										<li><strong>Version:</strong> {data.datasetMetadata.dataset_version}</li>
										<li><strong>Generado:</strong> {new Date(data.datasetMetadata.generated_at_utc).toLocaleDateString('es-ES')}</li>
										<li><strong>Periodo clima:</strong> {data.datasetMetadata.climate_period}</li>
										<li><strong>Fuente clima:</strong> {data.datasetMetadata.climate_source}</li>
										<li><strong>Scope:</strong> {data.datasetMetadata.analysis_scope}</li>
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
					<h2>Evaluacion</h2>
					<p>Selecciona un municipio para ver su ficha o usa este ranking para comparar.</p>
					<div class="desktop-toggle" role="tablist" aria-label="Vista de evaluacion">
						<button
							type="button"
							class:active={desktopEvalPanel === 'top'}
							onclick={() => (desktopEvalPanel = 'top')}
						>
							Top 25
						</button>
						<button
							type="button"
							class:active={desktopEvalPanel === 'shortlist'}
							onclick={() => (desktopEvalPanel = 'shortlist')}
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
							<p class="muted">Tu shortlist esta vacia. Abre un municipio y pulsa "Guardar shortlist".</p>
						{/if}
					{/if}

					<section class="desktop-score-panel">
						<h3>Ajuste del score</h3>
						<p class="muted">Estos pesos cambian el score y el ranking; el filtro de score minimo del panel izquierdo decide que municipios se muestran en mapa y tabla.</p>
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
					<h2>Exploracion</h2>
					<p>Explora el mapa, capas y filtros. Al seleccionar un municipio veras la ficha completa aqui.</p>
					<p class="muted">En este modo ocultamos el ranking para reducir ruido.</p>
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
		display: grid;
		grid-template-rows: minmax(0, 1fr) minmax(180px, 34%);
	}
	.map-desktop-zone {
		min-height: 0;
	}
	.desktop-table {
		border-top: 1px solid rgba(21, 32, 33, 0.14);
		background: rgba(255, 251, 243, 0.9);
		min-height: 0;
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
			display: flex;
			flex-wrap: wrap;
			gap: 0.25rem;
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

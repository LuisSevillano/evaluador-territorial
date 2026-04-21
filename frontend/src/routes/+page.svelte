<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import InspectorPanel from '$lib/components/InspectorPanel.svelte';
	import BottomSheet from '$lib/components/ui/BottomSheet.svelte';
	import ModeToggle from '$lib/components/ui/ModeToggle.svelte';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import { MapPin, SlidersHorizontal, Layers, BarChart3 } from 'lucide-svelte';
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
	let activeSheetTab = $state<'sel' | 'filtr' | 'capas' | 'rank'>('filtr');
	let hasNewSelection = $state(false);
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
	let sortBy = $state<'nombre' | 'provincia' | 'travel_bucket' | 'precip_annual_mm' | 'temp_winter_mean_c' | 'temp_summer_mean_c' | 'mixed_score'>('mixed_score');
	let sortDirection = $state<'asc' | 'desc'>('desc');

	let maxTravelBucket = $state<'<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00'>(
		'>4h00'
	);
	let minPrecipAnnual = $state(0);
	let minWinterTemp = $state(-10);
	let maxSummerTemp = $state(40);
	let climateWeight = $state(40);
	let accessWeight = $state(30);
	let natureWeight = $state(30);

	const bucketOrder: Record<string, number> = {
		'<=1h30': 1,
		'<=2h00': 2,
		'<=2h30': 3,
		'<=3h30': 4,
		'<=4h00': 5,
		'>4h00': 6
	};

	const isPlausibleTemp = (value: number) => Number.isFinite(value) && value > -60 && value < 60;
	const isPlausiblePrecipAnnual = (value: number) =>
		Number.isFinite(value) && value >= 0 && value < 20000;

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
		(() => {
			const total = climateWeight + accessWeight + natureWeight;
			if (!total) return { climate: 0.4, access: 0.3, nature: 0.3 };
			return {
				climate: climateWeight / total,
				access: accessWeight / total,
				nature: natureWeight / total
			};
		})()
	);

	const scoreFor = (m: Municipio, weights: { climate: number; access: number; nature: number }) => {
		const climate = m.climate_block_score ?? m.precip_norm ?? 0.5;
		const access = m.access_block_score ?? m.accesibilidad_norm ?? 0.5;
		const nature = m.nature_block_score ?? m.naturality_norm ?? 0.5;
		return weights.climate * climate + weights.access * access + weights.nature * nature;
	};

	const municipiosScoredForView = $derived(
		municipios.map((m) => ({
			...m,
			mixed_score: Number(scoreFor(m, normalizedWeights).toFixed(4))
		}))
	);

	const municipiosFiltradosBase = $derived(
		municipiosScoredForView.filter((m) => {
			const provinceOk = provinceFilter === 'Todas' || m.provincia === provinceFilter;
			const bucketOk = bucketOrder[m.travel_bucket] <= bucketOrder[maxTravelBucket];
			const precipOk = isPlausiblePrecipAnnual(m.precip_annual_mm)
				? m.precip_annual_mm >= minPrecipAnnual
				: true;
			const winterOk = isPlausibleTemp(m.temp_winter_mean_c)
				? m.temp_winter_mean_c >= minWinterTemp
				: true;
			const summerOk = isPlausibleTemp(m.temp_summer_mean_c)
				? m.temp_summer_mean_c <= maxSummerTemp
				: true;
			const scoreOk = Number.isFinite(m.mixed_score)
				? m.mixed_score >= minCompositeScore
				: true;
			return provinceOk && bucketOk && precipOk && winterOk && summerOk && scoreOk;
		})
	);

	const municipiosFiltrados = $derived(municipiosFiltradosBase);

	const baselineWeights = { climate: 0.4, access: 0.3, nature: 0.3 };
	const baselineTopIds = $derived(
		[...municipiosFiltrados]
			.sort((a, b) => scoreFor(b, baselineWeights) - scoreFor(a, baselineWeights))
			.slice(0, 10)
			.map((m) => m.id)
	);

	const tableRows = $derived(
		[...municipiosFiltrados].sort((a, b) => {
			let cmp = 0;
			if (sortBy === 'travel_bucket') cmp = bucketOrder[a.travel_bucket] - bucketOrder[b.travel_bucket];
			else if (sortBy === 'nombre' || sortBy === 'provincia') cmp = a[sortBy].localeCompare(b[sortBy], 'es');
			else if (sortBy === 'mixed_score') cmp = scoreFor(a, normalizedWeights) - scoreFor(b, normalizedWeights);
			else cmp = (a[sortBy] ?? 0) - (b[sortBy] ?? 0);
			return sortDirection === 'asc' ? cmp : -cmp;
		})
	);

	const sensitivityOverlap = $derived(
		(() => {
			const currentTop = tableRows.slice(0, 10).map((m) => m.id);
			return currentTop.filter((id) => baselineTopIds.includes(id)).length;
		})()
	);

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
			minCompositeScore > 0 ? `score>=${minCompositeScore.toFixed(2)}` : null
		].filter(Boolean) as string[]
	);

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);

	const travelBuckets: Array<{
		value: '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';
		label: string;
	}> = [
		{ value: '<=1h30', label: '1,5h' },
		{ value: '<=2h00', label: '2h' },
		{ value: '<=2h30', label: '2,5h' },
		{ value: '<=3h30', label: '3,5h' },
		{ value: '<=4h00', label: '4h' },
		{ value: '>4h00', label: '>4h' }
	];

	const activePreset = $derived.by(() => {
		const c = climateWeight;
		const a = accessWeight;
		const n = natureWeight;
		if (c === 40 && a === 30 && n === 30) return 'equilibrado';
		if (c === 25 && a === 20 && n === 55) return 'naturaleza';
		if (c === 25 && a === 55 && n === 20) return 'accesibilidad';
		if (c === 55 && a === 20 && n === 25) return 'clima';
		return null;
	});

	const layerLabels: Record<string, string> = {
		municipios: 'Municipios',
		landuse: 'Usos del suelo',
		vegetation: 'Cobertura vegetal',
		forest: 'Masa forestal',
		reservoirs: 'Embalses IGN',
		rivers: 'Rios IGN'
	};

	const isLayerVisible = (layerKey: string) => {
		if (layerKey === 'municipios') return showMunicipioPolygons;
		if (layerKey === 'landuse') return showLandUseLayer;
		if (layerKey === 'vegetation') return showVegetationLayer;
		if (layerKey === 'forest') return showForestLayer;
		if (layerKey === 'reservoirs') return showIgnReservoirs;
		if (layerKey === 'rivers') return showIgnRivers;
		return false;
	};

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
			visible: isLayerVisible(layerKey)
		}))
	);

	const visibleMunicipioIds = $derived(municipiosFiltrados.map((m) => m.id));

	const selectedClimateSeries = $derived(
		(() => {
			const selected = selectedMunicipio;
			if (!selected) return [];
			return climateMonthly.filter((r) => r.id === selected.id).sort((a, b) => a.month - b.month);
		})()
	);

	const selectedProvinceClimateSeries = $derived(
		(() => {
			const selected = selectedMunicipio;
			if (!selected) return [];
			const byMonth = new Map<number, { sumTemp: number; count: number }>();
			for (const row of climateMonthly) {
				if (row.provincia !== selected.provincia) continue;
				const bucket = byMonth.get(row.month) ?? { sumTemp: 0, count: 0 };
				bucket.sumTemp += row.temp_mean_c;
				bucket.count += 1;
				byMonth.set(row.month, bucket);
			}
			return Array.from(byMonth.entries())
				.map(([month, values]) => ({ month, temp_mean_c: values.count ? values.sumTemp / values.count : 0 }))
				.sort((a, b) => a.month - b.month);
		})()
	);

	const selectedCcaaClimateSeries = $derived(
		(() => {
			if (climateMonthly.length === 0) return [];
			const byMonth = new Map<number, { sumTemp: number; count: number }>();
			for (const row of climateMonthly) {
				const bucket = byMonth.get(row.month) ?? { sumTemp: 0, count: 0 };
				bucket.sumTemp += row.temp_mean_c;
				bucket.count += 1;
				byMonth.set(row.month, bucket);
			}
			return Array.from(byMonth.entries())
				.map(([month, values]) => ({ month, temp_mean_c: values.count ? values.sumTemp / values.count : 0 }))
				.sort((a, b) => a.month - b.month);
		})()
	);

	const handleSelectMunicipio = (municipio: Municipio | null) => {
		if (!municipio) {
			selectedMunicipio = null;
			return;
		}
		selectedMunicipio = municipio;
		hasNewSelection = true;
		if (activeSheetTab === 'sel') {
			isBottomSheetOpen = true;
		}
	};

	const handleClearSelectedMunicipio = () => {
		selectedMunicipio = null;
		hasNewSelection = false;
		activeSheetTab = 'rank';
	};

	const handleClearFilters = () => {
		provinceFilter = 'Todas';
		maxTravelBucket = '>4h00';
		minPrecipAnnual = 0;
		minWinterTemp = -10;
		maxSummerTemp = 40;
		minCompositeScore = 0;
	};

	const handleToggleShortlist = (municipioId: string) => {
		shortlistedIds = shortlistedIds.includes(municipioId)
			? shortlistedIds.filter((id) => id !== municipioId)
			: [...shortlistedIds, municipioId];
	};

	const handleChangeSort = (newSortBy: typeof sortBy) => {
		if (sortBy === newSortBy) {
			sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
			return;
		}
		sortBy = newSortBy;
		sortDirection = newSortBy === 'nombre' || newSortBy === 'provincia' || newSortBy === 'travel_bucket' ? 'asc' : 'desc';
	};

	const handleLayerOrderChange = (nextOrder: string[]) => {
		layerOrder = nextOrder;
	};

	const handlePresetWeights = (preset: 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima') => {
		mapColorMetric = 'mixed_score';
		if (preset === 'equilibrado') {
			climateWeight = 40;
			accessWeight = 30;
			natureWeight = 30;
		} else if (preset === 'naturaleza') {
			climateWeight = 25;
			accessWeight = 20;
			natureWeight = 55;
		} else if (preset === 'accesibilidad') {
			climateWeight = 25;
			accessWeight = 55;
			natureWeight = 20;
		} else {
			climateWeight = 55;
			accessWeight = 20;
			natureWeight = 25;
		}
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
		if (selectedMunicipio && !municipiosScoredForView.some((m) => m.id === selectedMunicipio?.id)) {
			selectedMunicipio = null;
		}
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
		if (typeof localStorage === 'undefined') return;
		const raw = localStorage.getItem('ebv-shortlist-v1');
		if (!raw) return;
		try {
			const parsed = JSON.parse(raw) as string[];
			if (Array.isArray(parsed)) shortlistedIds = parsed;
		} catch (_error) {
			shortlistedIds = [];
		}
	});

	$effect(() => {
		if (typeof localStorage === 'undefined') return;
		localStorage.setItem('ebv-shortlist-v1', JSON.stringify(shortlistedIds));
	});

	$effect(() => {
		if (viewMode === 'evaluacion') {
			mapColorMetric = 'mixed_score';
		}
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
		<small>{viewMode === 'exploracion' ? 'Exploracion: filtros y capas' : 'Evaluacion: score y ranking'} · {municipiosFiltrados.length}/{municipios.length}</small>
	</div>
	<div class="topbar-mode">
		<ModeToggle mode={viewMode} onChange={(nextMode) => (viewMode = nextMode)} />
	</div>
</header>

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
				{minCompositeScore}
				{layerOrder}
				activeFiltersSummary={activeFiltersSummary}
				shortlistMunicipios={shortlistMunicipios}
				shortlistedIds={shortlistedIds}
				tableRows={tableRows}
				{sortBy}
				{sortDirection}
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
				onMinCompositeScoreChange={(value: number) => (minCompositeScore = value)}
				onClearFilters={handleClearFilters}
				onLayerOrderChange={handleLayerOrderChange}
				onToggleShortlist={handleToggleShortlist}
				onChangeSort={handleChangeSort}
				onClimateWeightChange={handleClimateWeightChange}
				onAccessWeightChange={handleAccessWeightChange}
				onNatureWeightChange={handleNatureWeightChange}
				onPresetWeights={handlePresetWeights}
			/>
		</div>

		<section class="map-wrap">
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
				pmtilesUrl={municipiosPmtilesUrl}
				onMapSelection={handleSelectMunicipio}
			/>
			<BottomSheet initialHeight="20vh" expandedHeight="62vh" peekHeight="5.2rem" bind:isOpen={isBottomSheetOpen}>
				{#snippet children()}
					<div class="sheet-tabs" role="tablist" aria-label="Panel movil">
						<button class:active={activeSheetTab === 'sel'} onclick={() => { activeSheetTab = 'sel'; isBottomSheetOpen = true; }}><MapPin size={16} />Sel</button>
						<button class:active={activeSheetTab === 'filtr'} onclick={() => { activeSheetTab = 'filtr'; isBottomSheetOpen = true; }}><SlidersHorizontal size={16} />Filtr</button>
						<button class:active={activeSheetTab === 'capas'} onclick={() => { activeSheetTab = 'capas'; isBottomSheetOpen = true; }}><Layers size={16} />Capas</button>
						<button class:active={activeSheetTab === 'rank'} onclick={() => { activeSheetTab = 'rank'; isBottomSheetOpen = true; }}><BarChart3 size={16} />Rank</button>
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
								<button class="sheet-clear" onclick={() => (activeSheetTab = 'rank')}>Ir al ranking</button>
							{/if}
						{:else if activeSheetTab === 'filtr'}
							<div class="sheet-block">
								<ModeToggle mode={viewMode} onChange={(nextMode) => (viewMode = nextMode)} />
								<p class="sheet-meta">{viewMode === 'exploracion' ? 'Ajusta filtros territoriales y explora el mapa.' : 'Ajusta score, pesos y ranking para comparar municipios.'}</p>
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
								<label for="sheet-min-precip">Precipitacion minima anual: {minPrecipAnnual} mm</label>
								<input id="sheet-min-precip" type="range" min="0" max="1800" step="10" value={minPrecipAnnual} oninput={(e) => (minPrecipAnnual = toNumber(e))} />
								<label for="sheet-min-winter">Temp. invierno minima: {minWinterTemp} C</label>
								<input id="sheet-min-winter" type="range" min="-15" max="15" step="0.5" value={minWinterTemp} oninput={(e) => (minWinterTemp = toNumber(e))} />
								<label for="sheet-max-summer">Temp. verano maxima: {maxSummerTemp} C</label>
								<input id="sheet-max-summer" type="range" min="15" max="40" step="0.5" value={maxSummerTemp} oninput={(e) => (maxSummerTemp = toNumber(e))} />
								{#if viewMode === 'evaluacion'}
									<label for="sheet-min-score">Score minimo visible: {minCompositeScore.toFixed(2)}</label>
									<input id="sheet-min-score" type="range" min="0" max="1" step="0.01" value={minCompositeScore} oninput={(e) => (minCompositeScore = toNumber(e))} />
									<label for="sheet-w-clima">Peso clima: {climateWeight}</label>
									<input id="sheet-w-clima" type="range" min="0" max="100" step="1" value={climateWeight} oninput={(e) => handleClimateWeightChange(toNumber(e))} />
									<label for="sheet-w-acceso">Peso accesibilidad: {accessWeight}</label>
									<input id="sheet-w-acceso" type="range" min="0" max="100" step="1" value={accessWeight} oninput={(e) => handleAccessWeightChange(toNumber(e))} />
									<label for="sheet-w-nat">Peso naturaleza: {natureWeight}</label>
									<input id="sheet-w-nat" type="range" min="0" max="100" step="1" value={natureWeight} oninput={(e) => handleNatureWeightChange(toNumber(e))} />
									<div class="chips-row">
										<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => handlePresetWeights('equilibrado')} />
										<ChipButton label="Naturaleza" active={activePreset === 'naturaleza'} onclick={() => handlePresetWeights('naturaleza')} />
										<ChipButton label="Accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => handlePresetWeights('accesibilidad')} />
										<ChipButton label="Clima" active={activePreset === 'clima'} onclick={() => handlePresetWeights('clima')} />
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
						{:else}
							<div class="sheet-rank">
								{#if viewMode === 'evaluacion'}
									<p class="sheet-meta">Top 25 en base a score mixto actual.</p>
									{#each tableRows.slice(0, 25) as municipio, idx (municipio.id)}
										<button class="rank-row" onclick={() => handleSelectMunicipio(municipio)}>
											<span class="idx">#{idx + 1}</span>
											<span>{municipio.nombre}</span>
											<small>{municipio.provincia}</small>
											<strong>{municipio.mixed_score?.toFixed(3) ?? '-'}</strong>
										</button>
									{/each}
								{:else}
									<p class="sheet-meta">El ranking se utiliza en modo evaluacion.</p>
									<button class="sheet-clear" onclick={() => (viewMode = 'evaluacion')}>Cambiar a evaluacion</button>
								{/if}
							</div>
						{/if}
					</div>
				{/snippet}
			</BottomSheet>
		</section>

		<div class="inspector-desktop">
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
	.topbar-mode {
		display: block;
	}
	main {
		height: calc(100dvh - 56px);
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
	.sheet-tabs,
	.sheet-content {
		display: none;
	}
	@media (max-width: 900px) {
		.topbar {
			height: 52px;
			padding: 0.5rem 0.6rem;
		}
		.topbar-mode {
			display: none;
		}
		.topbar-brand strong {
			font-size: 1.1rem;
		}
		.topbar-brand small {
			font-size: 0.65rem;
		}
		main {
			height: auto;
			min-height: calc(100dvh - 52px);
			grid-template-columns: 1fr;
			grid-template-rows: 1fr;
			padding: 0;
			gap: 0;
			overflow: hidden;
		}
		.map-wrap {
			display: block;
			min-height: calc(100dvh - 52px);
			height: calc(100dvh - 52px);
			border-radius: 0;
			box-shadow: none;
		}
		.map-wrap :global(.map-shell) {
			height: 100%;
		}
		.panel-wrapper {
			display: none;
		}
		.sheet-tabs {
			display: grid;
			grid-template-columns: repeat(4, minmax(0, 1fr));
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
		.sheet-block label {
			font-size: 0.75rem;
			color: #3f5753;
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
		.sheet-meta {
			margin: 0.1rem 0 0.2rem;
			font-size: 0.72rem;
			color: #48605c;
		}
		.rank-row {
			display: grid;
			grid-template-columns: auto 1fr auto;
			gap: 0.2rem 0.45rem;
			align-items: center;
			text-align: left;
			border: 1px solid rgba(21, 32, 33, 0.12);
			border-radius: 8px;
			background: rgba(255, 255, 255, 0.7);
			padding: 0.36rem 0.45rem;
		}
		.rank-row .idx {
			font-size: 0.68rem;
			color: #4a605c;
		}
		.rank-row span {
			font-size: 0.78rem;
			font-weight: 600;
			line-height: 1.1;
		}
		.rank-row small {
			grid-column: 2;
			font-size: 0.68rem;
			color: #4a615d;
		}
		.rank-row strong {
			font-size: 0.75rem;
		}
		.inspector-desktop {
			display: none;
		}
	}
</style>

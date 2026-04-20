<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import InspectorPanel from '$lib/components/InspectorPanel.svelte';
	import { Filter, Map as MapIcon, Info } from 'lucide-svelte';
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
	let query = $state('');
	let showMunicipioPolygons = $state(true);
	let showMunicipioPoints = $state(false);
	let showIgnWmsBase = $state(true);
	let showIgnSatellite = $state(false);
	let showIgnRivers = $state(false);
	let showIgnReservoirs = $state(false);
	let mapColorMetric = $state<'precip_annual_mm' | 'mixed_score'>('mixed_score');
	let activeMobileTab = $state<'filters' | 'map' | 'inspector'>('map');
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
	};

	const handleClearSelectedMunicipio = () => {
		selectedMunicipio = null;
		hasNewSelection = false;
		activeMobileTab = 'map';
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
</script>

<svelte:head>
	<title>El Buen Vivir | Visor Territorial de Municipios</title>
	<meta name="description" content="Herramienta analítica para evaluar municipios según climatología, accesibilidad y naturaleza. Explora datos, compara territorios y toma decisiones informadas." />
	<meta name="keywords" content="municipios, análisis territorial, Castilla y León, climatología, accesibilidad, naturaleza, score municipal, visor geográfico" />
	<meta name="author" content="El Buen Vivir" />
	<meta name="robots" content="index, follow" />

	<!-- Open Graph / Facebook -->
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://el-buen-vivir.netlify.app/" />
	<meta property="og:title" content="El Buen Vivir | Visor Territorial de Municipios" />
	<meta property="og:description" content="Herramienta analítica para evaluar municipios según climatología, accesibilidad y naturaleza. Explora datos, compara territorios y toma decisiones informadas." />
	<meta property="og:site_name" content="El Buen Vivir" />
	<meta property="og:locale" content="es_ES" />

	<!-- Twitter -->
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:url" content="https://el-buen-vivir.netlify.app/" />
	<meta name="twitter:title" content="El Buen Vivir | Visor Territorial de Municipios" />
	<meta name="twitter:description" content="Herramienta analítica para evaluar municipios según climatología, accesibilidad y naturaleza." />

	<!-- Canonical -->
	<link rel="canonical" href="https://el-buen-vivir.netlify.app/" />
</svelte:head>

<nav class="mobile-tabs">
		<button class="tab-btn" class:active={activeMobileTab === 'filters'} onclick={() => activeMobileTab = 'filters'}>
			<Filter size={20} />
			<span class="tab-label">Filtros</span>
		</button>
		<button class="tab-btn" class:active={activeMobileTab === 'map'} onclick={() => activeMobileTab = 'map'}>
			<MapIcon size={20} />
			<span class="tab-label">Mapa</span>
		</button>
		<button class="tab-btn" class:active={activeMobileTab === 'inspector'} onclick={() => { activeMobileTab = 'inspector'; hasNewSelection = false; }}>
			<span class="tab-icon-wrap">
				<Info size={20} />
				{#if hasNewSelection}<span class="notification-dot"></span>{/if}
			</span>
			<span class="tab-label">Info</span>
		</button>
	</nav>

	<main>
		<div class="panel-wrapper" class:visible={activeMobileTab === 'filters'}>
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

		<section class="map-wrap" class:visible={activeMobileTab === 'map'}>
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
				polygonDataUrl="/data/municipios_v2.geojson"
				pmtilesUrl={municipiosPmtilesUrl}
				onMapSelection={handleSelectMunicipio}
			/>
		</section>

		<div class="panel-wrapper" class:visible={activeMobileTab === 'inspector'}>
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
	.mobile-tabs {
		display: none;
	}
	main {
		height: 100dvh;
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
	}
	.panel-wrapper {
		display: contents;
	}
	@media (max-width: 900px) {
		.mobile-tabs {
			display: flex;
			position: fixed;
			bottom: 0;
			left: 0;
			right: 0;
			z-index: 9999;
			background: linear-gradient(180deg, rgba(255, 252, 245, 0.98), rgba(245, 238, 224, 0.98));
			border-top: 1px solid rgba(21, 32, 33, 0.18);
			padding: 0.5rem 0.25rem;
			gap: 0.25rem;
			box-shadow: 0 -4px 20px rgba(21, 32, 33, 0.1);
		}
		.tab-btn {
			position: relative;
			flex: 1;
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;
			gap: 0.15rem;
			padding: 0.4rem 0.25rem;
			border: none;
			border-radius: 6px;
			background: transparent;
			cursor: pointer;
			transition: background 160ms ease;
			color: #354845;
		}
		.tab-btn:hover {
			background: rgba(47, 125, 133, 0.08);
		}
		.tab-btn.active {
			background: rgba(47, 125, 133, 0.15);
			color: #2f7d85;
		}
		.tab-icon-wrap {
			position: relative;
			display: inline-flex;
			align-items: center;
			justify-content: center;
		}
		.notification-dot {
			position: absolute;
			top: -2px;
			right: -6px;
			width: 12px;
			height: 12px;
			background: #22c55e;
			border-radius: 50%;
			border: 1px solid rgba(255, 255, 255, 0.95);
		}
		.tab-label {
			font-size: 0.65rem;
			color: inherit;
		}
		main {
			height: auto;
			min-height: 100dvh;
			grid-template-columns: 1fr;
			grid-template-rows: 1fr;
			padding: 0;
			gap: 0;
			overflow: hidden;
			padding-bottom: 60px;
		}
		.map-wrap {
			display: none;
			min-height: calc(100dvh - 60px);
			height: calc(100dvh - 60px);
			border-radius: 0;
			box-shadow: none;
		}
		.map-wrap.visible,
		.panel-wrapper.visible {
			display: block;
		}
		.panel-wrapper {
			display: none;
			overflow-y: auto;
			max-height: calc(100dvh - 60px);
		}
		.panel-wrapper.visible {
			display: block;
		}
	}
</style>

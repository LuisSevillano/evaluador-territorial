<script lang="ts">
	import MapView from '$lib/components/MapView.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
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
	let showIgnWmsBase = $state(false);
	let mapColorMetric = $state<'precip_annual_mm' | 'mixed_score'>('mixed_score');
	let showForestLayer = $state(false);
	let showLandUseLayer = $state(false);
	let showVegetationLayer = $state(false);
	const municipiosPmtilesUrl = '/tiles/municipios.pmtiles';
let provinceFilter = $state('Todas');
let shortlistedIds = $state<string[]>([]);
	let sortBy = $state<'nombre' | 'provincia' | 'travel_bucket' | 'precip_annual_mm' | 'temp_winter_mean_c' | 'temp_summer_mean_c'>('precip_annual_mm');
	let sortDirection = $state<'asc' | 'desc'>('desc');

	let maxTravelBucket = $state<'<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00'>(
		'>4h00'
	);
	let minPrecipAnnual = $state(0);
	let minWinterTemp = $state(-10);
	let maxSummerTemp = $state(40);

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
	const isExcludedProvince = (value: string) => /^\s*53\s*$/.test(value);

	const provinciasDisponibles = $derived([
		'Todas',
		...Array.from(new Set(municipios.map((m) => m.provincia)))
			.filter((provincia) => provincia && !isExcludedProvince(provincia))
			.sort((a, b) => a.localeCompare(b, 'es'))
	]);

	const municipiosFiltradosBase = $derived(
		municipios.filter((m) => {
			if (isExcludedProvince(m.provincia)) return false;
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
			return provinceOk && bucketOk && precipOk && winterOk && summerOk;
		})
	);

	const queryNormalized = $derived(query.trim().toLowerCase());

	const municipiosFiltrados = $derived(
		municipiosFiltradosBase.filter((m) => {
			if (!queryNormalized) return true;
			return `${m.nombre} ${m.provincia}`.toLowerCase().includes(queryNormalized);
		})
	);

	const labelAccesibilidad = (bucket: string) => {
		if (bucket === '<=1h30' || bucket === '<=2h00') return 'alta';
		if (bucket === '<=2h30' || bucket === '<=3h30') return 'media';
		return 'baja';
	};

	const tableRows = $derived(
		[...municipiosFiltrados].sort((a, b) => {
			let cmp = 0;
			if (sortBy === 'travel_bucket') cmp = bucketOrder[a.travel_bucket] - bucketOrder[b.travel_bucket];
			else if (sortBy === 'nombre' || sortBy === 'provincia') cmp = a[sortBy].localeCompare(b[sortBy], 'es');
			else cmp = (a[sortBy] ?? 0) - (b[sortBy] ?? 0);
			return sortDirection === 'asc' ? cmp : -cmp;
		})
	);

	const shortlistMunicipios = $derived(
		municipios.filter((m) => shortlistedIds.includes(m.id)).sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
	);

	const activeFiltersSummary = $derived(
		[
			provinceFilter !== 'Todas' ? `provincia=${provinceFilter}` : null,
			maxTravelBucket !== '>4h00' ? `acc<=${maxTravelBucket}` : null,
			minPrecipAnnual !== 0 ? `ppt>=${minPrecipAnnual}` : null,
			minWinterTemp !== -10 ? `t_inv>=${minWinterTemp}` : null,
			maxSummerTemp !== 40 ? `t_ver<=${maxSummerTemp}` : null,
			queryNormalized ? `busqueda=${query.trim()}` : null
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

	const handleSelectMunicipio = (municipio: Municipio) => {
		selectedMunicipio = municipio;
	};

	const handleClearFilters = () => {
		provinceFilter = 'Todas';
		maxTravelBucket = '>4h00';
		minPrecipAnnual = 0;
		minWinterTemp = -10;
		maxSummerTemp = 40;
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

	$effect(() => {
		municipios = data.municipios ?? [];
		climateMonthly = data.climateMonthly ?? [];
	});

	$effect(() => {
		if (selectedMunicipio && !municipiosFiltrados.some((m) => m.id === selectedMunicipio?.id)) {
			selectedMunicipio = null;
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
	<title>El Buen Vivir - Visor Territorial (Fase 3)</title>
	<meta
		name="description"
		content="Fase 3: analitica de decision, filtros duros, trazabilidad y shortlist municipal."
	/>
</svelte:head>

<main>
	<Sidebar
		{query}
		municipios={municipiosFiltrados}
		allMunicipiosCount={municipios.length}
		{selectedMunicipio}
		{showMunicipioPolygons}
		{showIgnWmsBase}
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
		activeFiltersSummary={activeFiltersSummary}
		shortlistMunicipios={shortlistMunicipios}
		shortlistedIds={shortlistedIds}
		tableRows={tableRows}
		{sortBy}
		{sortDirection}
		datasetMetadata={data.datasetMetadata}
		labelAccesibilidad={labelAccesibilidad}
		climateSeries={selectedClimateSeries}
		onQueryChange={(value) => (query = value)}
		onSelectMunicipio={handleSelectMunicipio}
		onToggleMunicipioPolygons={(value) => (showMunicipioPolygons = value)}
		onToggleIgnWmsBase={(value) => (showIgnWmsBase = value)}
		onMapColorMetricChange={(value) => (mapColorMetric = value)}
		onToggleForestLayer={(value) => (showForestLayer = value)}
		onToggleLandUseLayer={(value) => (showLandUseLayer = value)}
		onToggleVegetationLayer={(value) => (showVegetationLayer = value)}
		onProvinceFilterChange={(value) => (provinceFilter = value)}
		onMaxTravelBucketChange={(value) => (maxTravelBucket = value)}
		onMinPrecipAnnualChange={(value) => (minPrecipAnnual = value)}
		onMinWinterTempChange={(value) => (minWinterTemp = value)}
		onMaxSummerTempChange={(value) => (maxSummerTemp = value)}
		onClearFilters={handleClearFilters}
		onToggleShortlist={handleToggleShortlist}
		onChangeSort={handleChangeSort}
	/>

	<section class="map-wrap">
		<MapView
			{municipios}
			{selectedMunicipio}
			{showMunicipioPolygons}
			{showMunicipioPoints}
			{showIgnWmsBase}
			{mapColorMetric}
			{showForestLayer}
			{showLandUseLayer}
			{showVegetationLayer}
			{visibleMunicipioIds}
			polygonDataUrl="/data/municipios_v2.geojson"
			pmtilesUrl={municipiosPmtilesUrl}
			onMapSelection={handleSelectMunicipio}
		/>
	</section>
</main>

<style>
	main {
		height: 100dvh;
		display: grid;
		grid-template-columns: minmax(340px, 390px) minmax(0, 1fr);
		grid-template-rows: minmax(0, 1fr);
		gap: 0.35rem;
		padding: 0.35rem;
		overflow: hidden;
	}
	.map-wrap {
		min-width: 0;
		min-height: 0;
		height: 100%;
		border-radius: 18px;
		overflow: hidden;
		background: rgba(251, 246, 236, 0.72);
		border: 1px solid rgba(21, 32, 33, 0.18);
		box-shadow: 0 18px 42px rgba(21, 32, 33, 0.13);
	}
	@media (max-width: 900px) {
		main {
			height: auto;
			min-height: 100dvh;
			grid-template-columns: 1fr;
			grid-template-rows: auto minmax(52dvh, 1fr);
			padding: 0;
			gap: 0;
			overflow: visible;
		}
		.map-wrap {
			min-height: 52dvh;
			border-radius: 0;
			border: 0;
			box-shadow: none;
		}
	}
</style>

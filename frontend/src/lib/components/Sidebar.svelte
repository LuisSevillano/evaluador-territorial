<script lang="ts">
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import SidebarScorePanel from '$lib/components/sidebar/SidebarScorePanel.svelte';
	import SidebarFilters from '$lib/components/sidebar/SidebarFilters.svelte';
	import SidebarLayers from '$lib/components/sidebar/SidebarLayers.svelte';
	import SidebarMethodology from '$lib/components/sidebar/SidebarMethodology.svelte';
	import { DEFAULT_WEIGHTS_NORMALIZED, DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';
	import type { MapColorMetric } from '$lib/components/map/coloring';
	import type { TravelBucketFilter } from '$lib/state/filters';
	import { travelBuckets } from '$lib/state/filters';
	import { formatScorePercent } from '$lib/utils/numberFormat';

	type Props = {
		query?: string;
		municipios?: Municipio[];
		searchMunicipios?: Municipio[];
		allMunicipiosCount?: number;
		selectedMunicipio?: Municipio | null;
		showMunicipioPolygons?: boolean;
		showIsochronesLayer?: boolean;
		showOsmBasemap?: boolean;
		showIgnWmsBase?: boolean;
		showIgnSatellite?: boolean;
		showIgnRivers?: boolean;
		showIgnReservoirs?: boolean;
		mapColorMetric?: MapColorMetric;
		showForestLayer?: boolean;
		showLandUseLayer?: boolean;
		showVegetationLayer?: boolean;
		provinceFilter?: string[];
		provinciasDisponibles?: string[];
		maxTravelBucket?: TravelBucketFilter;
		minPrecipAnnual?: number;
		minWinterTemp?: number;
		maxSummerTemp?: number;
		maxThermalAmplitude?: number;
		maxThermalAmplitudeLimit?: number;
		minCompositeScore?: number;
		layerOrder?: string[];
		activeFiltersSummary?: string[];
		shortlistedIds?: string[];
		shortlistMunicipios?: Municipio[];
		weights?: { climate: number; access: number; nature: number };
		weightsRaw?: { climateWeight: number; accessWeight: number; natureWeight: number };
		sensitivityOverlap?: number;
		datasetMetadata?: DatasetMetadata | null;
		labelAccesibilidad?: (bucket: string) => string;
		climateSeries?: MunicipioClimateMonthly[];
		onQueryChange?: (value: string) => void;
		onSelectMunicipio?: (municipio: Municipio) => void;
		onCoordinateSearch?: (payload: { lat: number; lon: number; label: string }) => void;
		onToggleMunicipioPolygons?: (value: boolean) => void;
		onToggleIsochronesLayer?: (value: boolean) => void;
		onToggleOsmBasemap?: (value: boolean) => void;
		onToggleIgnWmsBase?: (value: boolean) => void;
		onToggleIgnSatellite?: (value: boolean) => void;
		onToggleIgnRivers?: (value: boolean) => void;
		onToggleIgnReservoirs?: (value: boolean) => void;
		onMapColorMetricChange?: (value: MapColorMetric) => void;
		onToggleForestLayer?: (value: boolean) => void;
		onToggleLandUseLayer?: (value: boolean) => void;
		onToggleVegetationLayer?: (value: boolean) => void;
		onProvinceToggle?: (value: string) => void;
		onProvinceClear?: () => void;
		onMaxTravelBucketChange?: (value: TravelBucketFilter) => void;
		onMinPrecipAnnualChange?: (value: number) => void;
		onMinWinterTempChange?: (value: number) => void;
		onMaxSummerTempChange?: (value: number) => void;
		onMaxThermalAmplitudeChange?: (value: number) => void;
		onMinCompositeScoreChange?: (value: number) => void;
		onClearFilters?: () => void;
		onLayerOrderChange?: (value: string[]) => void;
		onToggleShortlist?: (municipioId: string) => void;
		onClimateWeightChange?: (value: number) => void;
		onAccessWeightChange?: (value: number) => void;
		onNatureWeightChange?: (value: number) => void;
		onPresetWeights?: (
			preset: 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto'
		) => void;
	};

	let {
		query = '',
		municipios = [],
		searchMunicipios = [],
		allMunicipiosCount = 0,
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showIsochronesLayer = false,
		showOsmBasemap = false,
		showIgnWmsBase = false,
		showIgnSatellite = false,
		showIgnRivers = false,
		showIgnReservoirs = false,
		mapColorMetric = 'mixed_score',
		showForestLayer = false,
		showLandUseLayer = false,
		showVegetationLayer = false,
		provinceFilter = [],
		provinciasDisponibles = [],
		maxTravelBucket = null,
		minPrecipAnnual = 0,
		minWinterTemp = -10,
		maxSummerTemp = 40,
		maxThermalAmplitude = 21,
		maxThermalAmplitudeLimit = 21,
		minCompositeScore = 0,
		layerOrder = ['municipios', 'isochrones', 'reservoirs', 'rivers'],
		activeFiltersSummary = [],
		shortlistedIds = [],
		shortlistMunicipios = [],
		weights = DEFAULT_WEIGHTS_NORMALIZED,
		weightsRaw = DEFAULT_WEIGHTS_RAW,
		sensitivityOverlap = 0,
		datasetMetadata = null,
		labelAccesibilidad = (bucket: string) => bucket,
		climateSeries = [],
		onQueryChange = () => undefined,
		onSelectMunicipio = () => undefined,
		onCoordinateSearch = () => undefined,
		onToggleMunicipioPolygons = () => undefined,
		onToggleIsochronesLayer = () => undefined,
		onToggleOsmBasemap = () => undefined,
		onToggleIgnWmsBase = () => undefined,
		onToggleIgnSatellite = () => undefined,
		onToggleIgnRivers = () => undefined,
		onToggleIgnReservoirs = () => undefined,
		onMapColorMetricChange = () => undefined,
		onToggleForestLayer = () => undefined,
		onToggleLandUseLayer = () => undefined,
		onToggleVegetationLayer = () => undefined,
		onProvinceToggle = () => undefined,
		onProvinceClear = () => undefined,
		onMaxTravelBucketChange = () => undefined,
		onMinPrecipAnnualChange = () => undefined,
		onMinWinterTempChange = () => undefined,
		onMaxSummerTempChange = () => undefined,
		onMaxThermalAmplitudeChange = () => undefined,
		onMinCompositeScoreChange = () => undefined,
		onClearFilters = () => undefined,
		onLayerOrderChange = () => undefined,
		onToggleShortlist = () => undefined,
		onClimateWeightChange = () => undefined,
		onAccessWeightChange = () => undefined,
		onNatureWeightChange = () => undefined,
		onPresetWeights = () => undefined
	}: Props = $props();

	const scoringActiveText = $derived(
		`clima ${formatScorePercent(weights.climate)}% · accesibilidad ${formatScorePercent(weights.access)}% · naturaleza ${formatScorePercent(weights.nature)}%`
	);

	const totalMunicipios = $derived(municipios.length);
	const within2h = $derived(municipios.filter((m) => m.iso_02h00m).length);

	const activePreset = $derived.by(() => {
		const c = weightsRaw.climateWeight;
		const a = weightsRaw.accessWeight;
		const n = weightsRaw.natureWeight;
		if (
			c === DEFAULT_WEIGHTS_RAW.climateWeight &&
			a === DEFAULT_WEIGHTS_RAW.accessWeight &&
			n === DEFAULT_WEIGHTS_RAW.natureWeight
		)
			return 'equilibrado';
		if (c === 25 && a === 20 && n === 55) return 'naturaleza';
		if (c === 25 && a === 55 && n === 20) return 'accesibilidad';
		if (c === 55 && a === 20 && n === 25) return 'clima';
		if (c === 70 && a === 15 && n === 15) return 'clima_estricto';
		return null;
	});

	const layerLabels: Record<string, string> = {
		municipios: 'Municipios',
		isochrones: 'Isocronas (overlay)',
		reservoirs: 'Embalses IGN',
		rivers: 'Rios IGN'
	};

	const isLayerVisible = (layerKey: string) => {
		if (layerKey === 'municipios') return showMunicipioPolygons;
		if (layerKey === 'isochrones') return showIsochronesLayer;
		if (layerKey === 'landuse') return showLandUseLayer;
		if (layerKey === 'vegetation') return showVegetationLayer;
		if (layerKey === 'forest') return showForestLayer;
		if (layerKey === 'reservoirs') return showIgnReservoirs;
		if (layerKey === 'rivers') return showIgnRivers;
		return false;
	};

	const toggleLayerVisibility = (layerKey: string, checked: boolean) => {
		if (layerKey === 'municipios') onToggleMunicipioPolygons(checked);
		else if (layerKey === 'isochrones') onToggleIsochronesLayer(checked);
		else if (layerKey === 'landuse') onToggleLandUseLayer(checked);
		else if (layerKey === 'vegetation') onToggleVegetationLayer(checked);
		else if (layerKey === 'forest') onToggleForestLayer(checked);
		else if (layerKey === 'reservoirs') onToggleIgnReservoirs(checked);
		else if (layerKey === 'rivers') onToggleIgnRivers(checked);
	};

	const layerItems = $derived(
		layerOrder.filter((layerKey) => layerKey !== 'landuse').map((layerKey) => ({
			key: layerKey,
			label: layerLabels[layerKey] ?? layerKey,
			visible: isLayerVisible(layerKey)
		}))
	);
</script>

<aside class="sidebar">
	<SidebarFilters
		{query}
		{municipios}
		{searchMunicipios}
		{provinceFilter}
		{provinciasDisponibles}
		{maxTravelBucket}
		{minPrecipAnnual}
		{minWinterTemp}
		{maxSummerTemp}
		{maxThermalAmplitude}
		{maxThermalAmplitudeLimit}
		{minCompositeScore}
		{activeFiltersSummary}
		{onQueryChange}
		{onSelectMunicipio}
		{onCoordinateSearch}
		{onProvinceToggle}
		{onProvinceClear}
		{onMaxTravelBucketChange}
		{onMinPrecipAnnualChange}
		{onMinWinterTempChange}
		{onMaxSummerTempChange}
		{onMaxThermalAmplitudeChange}
		{onMinCompositeScoreChange}
		{onClearFilters}
	/>

	<SidebarScorePanel
		{weights}
		{weightsRaw}
		{sensitivityOverlap}
		{activePreset}
		{onPresetWeights}
		{onClimateWeightChange}
		{onAccessWeightChange}
		{onNatureWeightChange}
	/>

	<SidebarLayers
		{mapColorMetric}
		{layerItems}
		{showOsmBasemap}
		{showIgnWmsBase}
		{showIgnSatellite}
		{onMapColorMetricChange}
		{onLayerOrderChange}
		onToggleLayerVisibility={toggleLayerVisibility}
		{onToggleOsmBasemap}
		{onToggleIgnWmsBase}
		{onToggleIgnSatellite}
	/>

	<SidebarMethodology {datasetMetadata} {scoringActiveText} />
</aside>

<style>
	.sidebar {
		width: 100%;
		max-width: 440px;
		height: 100%;
		max-height: 100%;
		min-height: 0;
		overflow-y: auto;
		overflow-x: hidden;
		overscroll-behavior: contain;
		scrollbar-gutter: stable;
		background: var(--sidebar-bg);
		border-right: 1px solid var(--divider-border);
		padding: var(--space-panel-lg);
		display: grid;
		gap: 0.85rem;
		box-sizing: border-box;
	}
	@media (max-width: 900px) {
		.sidebar {
			max-width: 100%;
			height: auto;
			min-height: 0;
			border-right: 0;
			max-height: none;
			overflow: visible;
			scrollbar-gutter: auto;
			padding: 1rem 1rem 1.15rem;
		}
	}
</style>

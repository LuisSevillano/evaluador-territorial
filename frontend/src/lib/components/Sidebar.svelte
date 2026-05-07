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
		showIgnWmsBase?: boolean;
		showIgnSatellite?: boolean;
		showIgnRivers?: boolean;
		showIgnReservoirs?: boolean;
		mapColorMetric?: MapColorMetric;
		showForestLayer?: boolean;
		showLandUseLayer?: boolean;
		showVegetationLayer?: boolean;
		provinceFilter?: string;
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
		onToggleIgnWmsBase?: (value: boolean) => void;
		onToggleIgnSatellite?: (value: boolean) => void;
		onToggleIgnRivers?: (value: boolean) => void;
		onToggleIgnReservoirs?: (value: boolean) => void;
		onMapColorMetricChange?: (value: MapColorMetric) => void;
		onToggleForestLayer?: (value: boolean) => void;
		onToggleLandUseLayer?: (value: boolean) => void;
		onToggleVegetationLayer?: (value: boolean) => void;
		onProvinceFilterChange?: (value: string) => void;
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
		onPresetWeights?: (preset: 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto') => void;
	};

	let {
		query = '',
		municipios = [],
		searchMunicipios = [],
		allMunicipiosCount = 0,
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showIsochronesLayer = false,
		showIgnWmsBase = false,
		showIgnSatellite = false,
		showIgnRivers = false,
		showIgnReservoirs = false,
		mapColorMetric = 'mixed_score',
		showForestLayer = false,
		showLandUseLayer = false,
		showVegetationLayer = false,
		provinceFilter = 'Todas',
		provinciasDisponibles = ['Todas'],
		maxTravelBucket = null,
		minPrecipAnnual = 0,
		minWinterTemp = -10,
		maxSummerTemp = 40,
		maxThermalAmplitude = 21,
		maxThermalAmplitudeLimit = 21,
		minCompositeScore = 0,
		layerOrder = ['municipios', 'isochrones', 'landuse', 'reservoirs', 'rivers'],
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
		onToggleIgnWmsBase = () => undefined,
		onToggleIgnSatellite = () => undefined,
		onToggleIgnRivers = () => undefined,
		onToggleIgnReservoirs = () => undefined,
		onMapColorMetricChange = () => undefined,
		onToggleForestLayer = () => undefined,
		onToggleLandUseLayer = () => undefined,
		onToggleVegetationLayer = () => undefined,
		onProvinceFilterChange = () => undefined,
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
		landuse: 'Usos del suelo',
		vegetation: 'Cobertura vegetal',
		forest: 'Masa forestal',
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
		layerOrder.map((layerKey) => ({
			key: layerKey,
			label: layerLabels[layerKey] ?? layerKey,
			visible: isLayerVisible(layerKey)
		}))
	);
</script>

<aside class="sidebar">
	<header class="hero hero-stats">
		<p class="kicker">Resumen operativo</p>
		<div class="stats">
			<div>
				<span>Resultados</span>
				<strong>{totalMunicipios} / {allMunicipiosCount}</strong>
			</div>
			<div>
				<span>Dentro de 2h</span>
				<strong>{within2h}</strong>
			</div>
		</div>
	</header>

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
		onQueryChange={onQueryChange}
		onSelectMunicipio={onSelectMunicipio}
		onCoordinateSearch={onCoordinateSearch}
		onProvinceFilterChange={onProvinceFilterChange}
		onMaxTravelBucketChange={onMaxTravelBucketChange}
		onMinPrecipAnnualChange={onMinPrecipAnnualChange}
		onMinWinterTempChange={onMinWinterTempChange}
		onMaxSummerTempChange={onMaxSummerTempChange}
		onMaxThermalAmplitudeChange={onMaxThermalAmplitudeChange}
		onMinCompositeScoreChange={onMinCompositeScoreChange}
		onClearFilters={onClearFilters}
	/>

	<SidebarScorePanel
		{weights}
		{weightsRaw}
		{sensitivityOverlap}
		activePreset={activePreset}
		onPresetWeights={onPresetWeights}
		onClimateWeightChange={onClimateWeightChange}
		onAccessWeightChange={onAccessWeightChange}
		onNatureWeightChange={onNatureWeightChange}
	/>

	<SidebarLayers
		{mapColorMetric}
		{layerItems}
		{showIgnWmsBase}
		{showIgnSatellite}
		onMapColorMetricChange={onMapColorMetricChange}
		onLayerOrderChange={onLayerOrderChange}
		onToggleLayerVisibility={toggleLayerVisibility}
		onToggleIgnWmsBase={onToggleIgnWmsBase}
		onToggleIgnSatellite={onToggleIgnSatellite}
	/>

	<SidebarMethodology
		{datasetMetadata}
		{scoringActiveText}
	/>
</aside>

<style>
	.sidebar { width: 100%; max-width: 440px; height: 100%; max-height: 100%; min-height: 0; overflow-y: auto; overflow-x: hidden; overscroll-behavior: contain; scrollbar-gutter: stable; background: linear-gradient(170deg, rgba(245, 238, 224, 0.86), rgba(232, 220, 196, 0.94)); border-right: 1px solid rgba(21, 32, 33, 0.18); padding: 0.9rem; display: grid; gap: 0.8rem; box-sizing: border-box; }
	.sidebar > * { min-width: 0; }
	.hero { padding: 0.95rem; border: 1px solid rgba(21, 32, 33, 0.22); border-radius: 14px; background: linear-gradient(135deg, rgba(255, 252, 245, 0.85), rgba(238, 225, 198, 0.78)); box-shadow: 0 8px 20px rgba(21, 32, 33, 0.12); }
	.hero-stats { padding: 0.75rem 0.85rem; }
	.kicker { margin: 0; font-size: 0.72rem; letter-spacing: 0.14em; text-transform: uppercase; color: #41534f; }
	.stats { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.55rem; margin-top: 0.45rem; }
	.stats div { min-width: 0; padding: 0.5rem; border-radius: 10px; background: rgba(255, 255, 255, 0.6); border: 1px solid rgba(21, 32, 33, 0.14); }
	.stats span { display: block; font-size: 0.69rem; text-transform: uppercase; letter-spacing: 0.08em; color: #4d5f5a; }
	.stats strong { display: block; font-family: 'Fraunces', serif; font-size: clamp(1rem, 2.3vw, 1.2rem); line-height: 1.06; overflow-wrap: anywhere; }
	@media (max-width: 900px) {
		.sidebar { max-width: 100%; height: auto; min-height: 0; border-right: 0; max-height: none; overflow: visible; scrollbar-gutter: auto; padding: 1rem 1rem 1.15rem; }
	}
</style>

<script lang="ts">
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import MunicipioSearch from '$lib/components/ui/MunicipioSearch.svelte';
	import ClimateFilters from '$lib/components/filters/ClimateFilters.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';
	import { DEFAULT_WEIGHTS_NORMALIZED, DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';
	import type { MapColorMetric } from '$lib/components/map/coloring';
	import type { TravelBucketFilter } from '$lib/state/filters';

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
		`clima ${(weights.climate * 100).toFixed(0)}% · accesibilidad ${(weights.access * 100).toFixed(0)}% · naturaleza ${(weights.nature * 100).toFixed(0)}%`
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

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);

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

	import { travelBuckets } from '$lib/state/filters';
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

	<section class="panel">
		<h2>Filtros</h2>
		<div class="control search-control">
			<div class="label-help-row">
				<label for="search">Buscar municipio</label>
				<FilterHelp text={FILTER_HELP.search} />
			</div>
			<MunicipioSearch
				query={query}
				{municipios}
				{searchMunicipios}
				inputId="search"
				onQueryChange={onQueryChange}
				onSelectMunicipio={onSelectMunicipio}
			/>
		</div>
		<div class="control">
			<p class="control-title control-title-help">Provincia <FilterHelp text={FILTER_HELP.province} /></p>
			<div class="chips-wrap compact province-chips">
				{#each provinciasDisponibles as provincia}
					<ChipButton
						label={provincia}
						size="small"
						active={provinceFilter === provincia}
						onclick={() => onProvinceFilterChange(provincia)}
					/>
				{/each}
			</div>
		</div>
		<div class="control">
			<p class="control-title control-title-help">Accesibilidad máxima <FilterHelp text={FILTER_HELP.accessibility} /></p>
			<div class="chips-wrap compact">
				{#each travelBuckets as bucket}
					<ChipButton
						label={bucket.label}
						size="small"
						active={maxTravelBucket === bucket.value}
						compact={true}
						onclick={() => onMaxTravelBucketChange(bucket.value)}
					/>
				{/each}
			</div>
		</div>
		<div class="control">
			<ClimateFilters
				variant="desktop"
				idPrefix="desktop"
				{minPrecipAnnual}
				{minWinterTemp}
				{maxSummerTemp}
				{maxThermalAmplitude}
				{maxThermalAmplitudeLimit}
				{minCompositeScore}
				onMinPrecipAnnualChange={onMinPrecipAnnualChange}
				onMinWinterTempChange={onMinWinterTempChange}
				onMaxSummerTempChange={onMaxSummerTempChange}
				onMaxThermalAmplitudeChange={onMaxThermalAmplitudeChange}
				onMinCompositeScoreChange={onMinCompositeScoreChange}
			/>
		</div>

		<div class="filter-foot">
			<p>Activos: {activeFiltersSummary.length > 0 ? activeFiltersSummary.join(' · ') : 'sin filtros activos'}</p>
			<button class="clear" onclick={onClearFilters}>Limpiar filtros</button>
		</div>
	</section>

	<section class="panel score-panel">
		<h2>Ajuste del score</h2>
		<p class="muted">Estos pesos cambian el score y el ranking; el filtro de score mínimo decide qué municipios se muestran en mapa y tabla.</p>
		<div class="chips-wrap compact preset-wrap">
			<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => onPresetWeights('equilibrado')} />
			<ChipButton label="Priorizar naturaleza" active={activePreset === 'naturaleza'} onclick={() => onPresetWeights('naturaleza')} />
			<ChipButton label="Priorizar accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => onPresetWeights('accesibilidad')} />
			<ChipButton label="Priorizar clima" active={activePreset === 'clima'} onclick={() => onPresetWeights('clima')} />
			<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => onPresetWeights('clima_estricto')} />
		</div>
		<div class="desktop-grid">
			<div class="item">
				<div class="label-help-row">
					<label for="m-rw-climate">Peso clima: {weightsRaw.climateWeight}</label>
				</div>
				<input id="m-rw-climate" name="m-rw-climate" type="range" min="0" max="100" step="1" value={weightsRaw.climateWeight} oninput={(e) => onClimateWeightChange(toNumber(e))} />
			</div>
			<div class="item">
				<div class="label-help-row">
					<label for="m-rw-access">Peso accesibilidad: {weightsRaw.accessWeight}</label>
				</div>
				<input id="m-rw-access" name="m-rw-access" type="range" min="0" max="100" step="1" value={weightsRaw.accessWeight} oninput={(e) => onAccessWeightChange(toNumber(e))} />
			</div>
			<div class="item">
				<div class="label-help-row">
					<label for="m-rw-nature">Peso naturaleza: {weightsRaw.natureWeight}</label>
				</div>
				<input id="m-rw-nature" name="m-rw-nature" type="range" min="0" max="100" step="1" value={weightsRaw.natureWeight} oninput={(e) => onNatureWeightChange(toNumber(e))} />
			</div>
		</div>
		<p class="muted">Normalizados: clima {(weights.climate * 100).toFixed(0)}% · accesibilidad {(weights.access * 100).toFixed(0)}% · naturaleza {(weights.nature * 100).toFixed(0)}%</p>
		<p class="muted">Robustez top-10 vs base equilibrada: {sensitivityOverlap}/10</p>
	</section>


	<section class="panel">
		<h2>Capas</h2>
		<div class="layers">
			<p class="control-title control-title-help">Color municipal <FilterHelp text={FILTER_HELP.mapColor} /></p>
			<div class="chips-wrap compact">
				<ChipButton label="Puntuación global" active={mapColorMetric === 'mixed_score'} onclick={() => onMapColorMetricChange('mixed_score')} />
				<ChipButton label="Precipitación" active={mapColorMetric === 'precip_annual_mm'} onclick={() => onMapColorMetricChange('precip_annual_mm')} />
				<ChipButton label="Tiempo de desplazamiento" active={mapColorMetric === 'travel_bucket'} onclick={() => onMapColorMetricChange('travel_bucket')} />
				<ChipButton label="Transporte OSM" active={mapColorMetric === 'transporte_norm'} onclick={() => onMapColorMetricChange('transporte_norm')} />
				<ChipButton label="Servicio Renfe" active={mapColorMetric === 'servicio_renfe_norm'} onclick={() => onMapColorMetricChange('servicio_renfe_norm')} />
				<ChipButton label="Acceso a baño" active={mapColorMetric === 'river_access_score'} onclick={() => onMapColorMetricChange('river_access_score')} />
			</div>
			<p class="muted">Arrastra para cambiar el orden de pintado (arriba = se pinta encima).</p>
			<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={onLayerOrderChange} />
			<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => onToggleIgnWmsBase((e.currentTarget as HTMLInputElement).checked)} /><span>Base IGN WMS</span></label>
			<label><input type="checkbox" checked={showIgnSatellite} onchange={(e) => onToggleIgnSatellite((e.currentTarget as HTMLInputElement).checked)} /><span>Satélite IGN (PNOA)</span></label>
		</div>
	</section>

	<section class="panel methodology">
		<details>
			<summary>Metodología y trazabilidad</summary>
			<div class="method-body">
				{#if datasetMetadata}
					<p><strong>Fuente climática:</strong> {datasetMetadata.climate_source}</p>
					<p><strong>Período:</strong> {datasetMetadata.climate_period}</p>
					<p><strong>Agregación municipal:</strong> {datasetMetadata.aggregation_method}</p>
					<p><strong>Isocronas:</strong> {datasetMetadata.isochrones_definition}</p>
					<p><strong>Fecha de generación:</strong> {datasetMetadata.generated_at_utc}</p>
					<p><strong>Versión dataset:</strong> {datasetMetadata.dataset_version}</p>
					<p><strong>Scoring base dataset:</strong> {datasetMetadata.scoring_method ?? 'No definido'}</p>
					<p><strong>Scoring activo:</strong> {scoringActiveText}</p>
					{#if typeof datasetMetadata.accessibility_normalization_floor === 'number'}
						<p><strong>Suelo accesibilidad:</strong> {(datasetMetadata.accessibility_normalization_floor * 100).toFixed(0)}%</p>
					{/if}
				{:else}
					<p class="muted">Sin metadata disponible en este build.</p>
				{/if}
			</div>
		</details>
	</section>
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
	.panel { border: 1px solid rgba(21, 32, 33, 0.16); border-radius: 12px; padding: 0.8rem; background: rgba(255, 255, 255, 0.62); }
	h2,p { margin: 0; }
	h2 { font-family: 'Fraunces', serif; font-size: 1rem; margin-bottom: 0.5rem; }
	.control-title { margin: 0; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; color: #405753; }
	.label-help-row { display: inline-flex; align-items: center; gap: 0.32rem; flex-wrap: wrap; }
	.control-title-help { display: inline-flex; align-items: center; gap: 0.32rem; flex-wrap: wrap; }
	.search-control { position: relative; z-index: 24; }
	.chips-wrap { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.25rem; }
	.chips-wrap.compact { gap: 0.3rem; }
	.preset-wrap { margin-top: 0.35rem; }
	
	.score-panel :global(.chips-wrap .chip-btn) { width: auto; }
	.score-panel .desktop-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		row-gap: 0.35rem;
		column-gap: 0.5rem;
	}
	.score-panel .desktop-grid .item:last-child { grid-column: 1 / -1; }
	.score-panel .desktop-grid .label-help-row { gap: 0.32rem; }
	.score-panel .desktop-grid .label-help-row label { font-size: 0.74rem; color: #3f5753; }
	.score-panel .desktop-grid input[type='range'] { width: 100%; }
	.province-chips { flex-wrap: wrap;  }

	:global(.chips-wrap.compact .chip-btn.compact) { width: 44px; padding-left: 0; padding-right: 0; }
	:global(.chips-wrap.compact .chip-btn.compact:first-child) { width: 58px; }
	.filter-foot .clear { cursor: pointer; border: 1px solid rgba(21, 32, 33, 0.22); border-radius: 999px; background: rgba(255, 255, 255, 0.8); padding: 0.3rem 0.6rem; color: #2f4743; font-size: 0.75rem; transition: background-color 120ms ease, transform 120ms ease; }
	.filter-foot .clear:hover { background: rgba(255, 255, 255, 0.94); transform: translateY(-0.5px); }
	.layers,.control { display: grid; gap: 0rem; margin-bottom: 0.75rem; }
	.layers { gap: 0.45rem; }
	.layers label { display: flex; gap: 0.45rem; align-items: center; font-size: 0.8rem; }
	.filter-foot { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin: 0.35rem 0; }
	.filter-foot p { font-size: 0.76rem; color: #3f5653; }
	.filter-foot .clear { width: auto; }
	.muted { color: #48615d; font-size: 0.76rem; line-height: 1.35; }
	.methodology details { border: 1px dashed rgba(21, 32, 33, 0.22); border-radius: 10px; background: rgba(255, 255, 255, 0.5); }
	.methodology summary { cursor: pointer; padding: 0.55rem 0.65rem; font-family: 'Fraunces', serif; font-size: 0.86rem; }
	.method-body { display: grid; gap: 0.35rem; padding: 0 0.65rem 0.65rem; font-size: 0.78rem; }
	@media (max-width: 900px) {
		.sidebar { max-width: 100%; height: auto; min-height: 0; border-right: 0; max-height: none; overflow: visible; scrollbar-gutter: auto; padding: 1rem 1rem 1.15rem; }
		h2 { font-size: 1.02rem; }
		.score-panel .desktop-grid .label-help-row label,
		.layers label { font-size: 0.8rem; }
		.methodology summary { font-size: 0.9rem; }
		.method-body { font-size: 0.8rem; }
		.muted { font-size: 0.8rem; }
		.score-panel { display: block; }
	}
</style>

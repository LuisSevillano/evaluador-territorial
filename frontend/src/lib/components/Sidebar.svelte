<script lang="ts">
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import { DEFAULT_WEIGHTS_NORMALIZED, DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';

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
		mapColorMetric?: 'precip_annual_mm' | 'mixed_score';
		showForestLayer?: boolean;
		showLandUseLayer?: boolean;
		showVegetationLayer?: boolean;
		provinceFilter?: string;
		provinciasDisponibles?: string[];
		maxTravelBucket?: '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';
		minPrecipAnnual?: number;
		minWinterTemp?: number;
		maxSummerTemp?: number;
		maxThermalAmplitude?: number;
		minCompositeScore?: number;
		layerOrder?: string[];
		activeFiltersSummary?: string[];
		shortlistedIds?: string[];
		shortlistMunicipios?: Municipio[];
		isEvaluationMode?: boolean;
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
		onMapColorMetricChange?: (value: 'precip_annual_mm' | 'mixed_score') => void;
		onToggleForestLayer?: (value: boolean) => void;
		onToggleLandUseLayer?: (value: boolean) => void;
		onToggleVegetationLayer?: (value: boolean) => void;
		onProvinceFilterChange?: (value: string) => void;
		onMaxTravelBucketChange?: (
			value: '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00'
		) => void;
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
		maxTravelBucket = '>4h00',
		minPrecipAnnual = 0,
		minWinterTemp = -10,
		maxSummerTemp = 40,
		maxThermalAmplitude = 21,
		minCompositeScore = 0,
		layerOrder = ['municipios', 'isochrones', 'landuse', 'reservoirs', 'rivers'],
		activeFiltersSummary = [],
		shortlistedIds = [],
		shortlistMunicipios = [],
		isEvaluationMode = false,
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

	let isSearchFocused = $state(false);

	const searchSuggestions = $derived.by(() => {
		const source = searchMunicipios.length > 0 ? searchMunicipios : municipios;
		const normalized = query.trim().toLowerCase();

		if (!normalized) {
			return [...source]
				.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
				.slice(0, 10);
		}

		return source
			.map((municipio) => {
				const nombre = municipio.nombre.toLowerCase();
				const haystack = `${municipio.nombre} ${municipio.provincia}`.toLowerCase();
				const starts = nombre.startsWith(normalized);
				const includes = haystack.includes(normalized);
				if (!includes) return null;
				return { municipio, starts };
			})
			.filter((item): item is { municipio: Municipio; starts: boolean } => item !== null)
			.sort((a, b) => {
				if (a.starts !== b.starts) return a.starts ? -1 : 1;
				return a.municipio.nombre.localeCompare(b.municipio.nombre, 'es');
			})
			.map((item) => item.municipio)
			.slice(0, 10);
	});

	const showSearchSuggestions = $derived(isSearchFocused && searchSuggestions.length > 0);

	const handleSearchBlur = () => {
		setTimeout(() => {
			isSearchFocused = false;
		}, 90);
	};

	const handleSearchKeydown = (event: KeyboardEvent) => {
		if (event.key === 'Escape') {
			isSearchFocused = false;
			return;
		}

		if (event.key === 'Enter' && searchSuggestions.length > 0) {
			event.preventDefault();
			handleSelectSuggestion(searchSuggestions[0]);
		}
	};

	const handleSelectSuggestion = (municipio: Municipio) => {
		onSelectMunicipio(municipio);
		onQueryChange(municipio.nombre);
		isSearchFocused = false;
	};

	const handleSuggestionPointerDown = (event: PointerEvent, municipio: Municipio) => {
		event.preventDefault();
		handleSelectSuggestion(municipio);
	};

	const handleSuggestionClick = (event: MouseEvent, municipio: Municipio) => {
		if (event.detail === 0) handleSelectSuggestion(municipio);
	};

	const totalMunicipios = $derived(municipios.length);
	const within2h = $derived(municipios.filter((m) => m.iso_02h00m).length);

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);

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

	const travelBuckets: Array<{
		value: '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';
		label: string;
	}> = [
		{ value: '<=1h30', label: '1,5horas' },
		{ value: '<=2h00', label: '2h' },
		{ value: '<=2h30', label: '2,5h' },
		{ value: '<=3h30', label: '3,5h' },
		{ value: '<=4h00', label: '4h' },
		{ value: '>4h00', label: '>4h' }
	];
</script>

<aside class="sidebar">
	<header class="hero">
		<p class="kicker">Observatorio Territorial</p>
		<h1>El Buen Vivir</h1>
		<p class="phase">Fase 3 · analítica de decisión</p>
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

	<section class="panel mode-context">
		<h2>{isEvaluationMode ? 'Modo evaluación' : 'Modo exploración'}</h2>
		<p>
			{#if isEvaluationMode}
				Ajusta pesos y score para comparar municipios de forma cuantitativa.
			{:else}
				Ajusta filtros y capas para explorar el territorio sin sesgo por ranking.
			{/if}
		</p>
	</section>

	<section class="panel">
		<h2>{isEvaluationMode ? 'Filtros de evaluación' : 'Filtros de exploración'}</h2>
		<div class="control search-control">
			<label for="search">Buscar municipio</label>
			<div
				class="search-shell"
				role="combobox"
				aria-expanded={showSearchSuggestions}
				aria-controls="municipio-search-suggestions"
			>
				<input
					id="search"
					name="municipio-search"
					autocomplete="off"
					type="search"
					placeholder="Ej. Soria…"
					value={query}
					onfocus={() => (isSearchFocused = true)}
					onblur={handleSearchBlur}
					onkeydown={handleSearchKeydown}
					oninput={(e) => onQueryChange((e.currentTarget as HTMLInputElement).value)}
				/>
				{#if showSearchSuggestions}
					<div class="search-dropdown">
						<ul class="search-suggestions" id="municipio-search-suggestions" role="listbox">
							{#each searchSuggestions as municipio (municipio.id)}
								<li>
									<button
										class="suggestion-btn"
										onpointerdown={(event) => handleSuggestionPointerDown(event, municipio)}
										onclick={(event) => handleSuggestionClick(event, municipio)}
									>
										<span>{municipio.nombre}</span>
										<small>{municipio.provincia}</small>
									</button>
								</li>
							{/each}
						</ul>
					</div>
				{/if}
			</div>
		</div>
		<div class="control">
			<p class="control-title">Provincia</p>
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
			<p class="control-title">Accesibilidad máxima</p>
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
		<div class="control compact-slider-grid">
			<label for="min-precip">Precipitación mínima anual: {minPrecipAnnual} mm</label>
			<input id="min-precip" name="min-precip" type="range" min="0" max="1800" step="10" value={minPrecipAnnual} oninput={(e) => onMinPrecipAnnualChange(toNumber(e))} />
			<label for="min-winter-temp">Temp. invierno mínima: {minWinterTemp} C</label>
			<input id="min-winter-temp" name="min-winter-temp" type="range" min="-15" max="15" step="0.5" value={minWinterTemp} oninput={(e) => onMinWinterTempChange(toNumber(e))} />
			<label for="max-summer-temp">Temp. verano máxima: {maxSummerTemp} C</label>
			<input id="max-summer-temp" name="max-summer-temp" type="range" min="15" max="40" step="0.5" value={maxSummerTemp} oninput={(e) => onMaxSummerTempChange(toNumber(e))} />
			<label for="max-thermal-amplitude">Amplitud térmica máxima: {maxThermalAmplitude.toFixed(1)} C</label>
			<input id="max-thermal-amplitude" name="max-thermal-amplitude" type="range" min="12" max="21" step="0.1" value={maxThermalAmplitude} oninput={(e) => onMaxThermalAmplitudeChange(toNumber(e))} />
			{#if isEvaluationMode}
				<label for="min-score">Score mínimo visible: {minCompositeScore.toFixed(2)}</label>
				<input id="min-score" name="min-score" type="range" min="0" max="1" step="0.01" value={minCompositeScore} oninput={(e) => onMinCompositeScoreChange(toNumber(e))} />
			{/if}
		</div>

		<div class="filter-foot">
			<p>Activos: {activeFiltersSummary.length > 0 ? activeFiltersSummary.join(' · ') : 'sin filtros activos'}</p>
			<button class="clear" onclick={onClearFilters}>Limpiar filtros</button>
		</div>
	</section>

	{#if isEvaluationMode}
		<section class="panel mobile-score-panel">
			<h2>Ajuste del score</h2>
			<p class="muted">Estos pesos cambian el score y el ranking; el filtro de score mínimo decide qué municipios se muestran en mapa y tabla.</p>
			<div class="chips-wrap compact preset-wrap">
				<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => onPresetWeights('equilibrado')} />
				<ChipButton label="Priorizar naturaleza" active={activePreset === 'naturaleza'} onclick={() => onPresetWeights('naturaleza')} />
				<ChipButton label="Priorizar accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => onPresetWeights('accesibilidad')} />
				<ChipButton label="Priorizar clima" active={activePreset === 'clima'} onclick={() => onPresetWeights('clima')} />
				<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => onPresetWeights('clima_estricto')} />
			</div>
			<div class="control score-control">
				<label for="m-rw-climate">Peso clima: {weightsRaw.climateWeight}</label>
				<input id="m-rw-climate" name="m-rw-climate" type="range" min="0" max="100" step="1" value={weightsRaw.climateWeight} oninput={(e) => onClimateWeightChange(toNumber(e))} />
			</div>
			<div class="control score-control">
				<label for="m-rw-access">Peso accesibilidad: {weightsRaw.accessWeight}</label>
				<input id="m-rw-access" name="m-rw-access" type="range" min="0" max="100" step="1" value={weightsRaw.accessWeight} oninput={(e) => onAccessWeightChange(toNumber(e))} />
			</div>
			<div class="control score-control">
				<label for="m-rw-nature">Peso naturaleza: {weightsRaw.natureWeight}</label>
				<input id="m-rw-nature" name="m-rw-nature" type="range" min="0" max="100" step="1" value={weightsRaw.natureWeight} oninput={(e) => onNatureWeightChange(toNumber(e))} />
			</div>
			<p class="muted">Normalizados: clima {(weights.climate * 100).toFixed(0)}% · acces {(weights.access * 100).toFixed(0)}% · nat {(weights.nature * 100).toFixed(0)}%</p>
			<p class="muted">Robustez top-10 vs base equilibrada: {sensitivityOverlap}/10</p>
		</section>
	{/if}


	{#if isEvaluationMode}
		<section class="panel">
			<h2>Ranking y decisión</h2>
			<p class="muted">El ranking top 25 aparece en el panel derecho. Selecciona un municipio para revisar su ficha y ajustar pesos con contexto.</p>
		</section>
	{/if}


	<section class="panel">
		<h2>Capas</h2>
		<div class="layers">
			<p class="muted">Arrastra para cambiar el orden de pintado (arriba = se pinta encima).</p>
			<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={onLayerOrderChange} />
			<p class="control-title">Color municipal</p>
			<div class="chips-wrap compact">
				<ChipButton label="Puntuación global" active={mapColorMetric === 'mixed_score'} onclick={() => onMapColorMetricChange('mixed_score')} />
				<ChipButton label="Precipitación" active={mapColorMetric === 'precip_annual_mm'} onclick={() => onMapColorMetricChange('precip_annual_mm')} />
			</div>
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
					<p><strong>Scoring:</strong> {datasetMetadata.scoring_method ?? 'No definido'}</p>
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
	.kicker { margin: 0; font-size: 0.72rem; letter-spacing: 0.14em; text-transform: uppercase; color: #41534f; }
	h1 { margin: 0.35rem 0 0; font-family: 'Fraunces', serif; font-size: 1.72rem; line-height: 1.03; }
	.phase { margin: 0.4rem 0 0; font-size: 0.84rem; color: #354845; }
	.stats { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.55rem; margin-top: 0.85rem; }
	.stats div { min-width: 0; padding: 0.5rem; border-radius: 10px; background: rgba(255, 255, 255, 0.6); border: 1px solid rgba(21, 32, 33, 0.14); }
	.stats span { display: block; font-size: 0.69rem; text-transform: uppercase; letter-spacing: 0.08em; color: #4d5f5a; }
	.stats strong { display: block; font-family: 'Fraunces', serif; font-size: clamp(1rem, 2.3vw, 1.2rem); line-height: 1.06; overflow-wrap: anywhere; }
	.panel { border: 1px solid rgba(21, 32, 33, 0.16); border-radius: 12px; padding: 0.8rem; background: rgba(255, 255, 255, 0.62); }
	h2,p { margin: 0; }
	h2 { font-family: 'Fraunces', serif; font-size: 1rem; margin-bottom: 0.5rem; }
	.mode-context p { font-size: 0.78rem; line-height: 1.35; color: #48615d; }
	.control-title { margin: 0; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; color: #405753; }
	.control > label { font-size: 0.78rem; letter-spacing: 0.02em; color: #425955; }
	.search-control { position: relative; z-index: 24; }
	.search-shell { position: relative; margin-top: 0.1rem; }
	input[type='search'] { width: 100%; margin-top: 0.35rem; padding: 0.62rem 0.7rem; border: 1px solid rgba(21, 32, 33, 0.2); border-radius: 10px; background: rgba(255, 255, 255, 0.78); }
	.search-dropdown {
		position: absolute;
		top: calc(100% + 0.32rem);
		left: 0;
		right: 0;
		background: rgba(255, 252, 246, 0.98);
		border: 1px solid rgba(21, 32, 33, 0.24);
		border-radius: 12px;
		box-shadow: 0 12px 24px rgba(21, 32, 33, 0.16);
		backdrop-filter: blur(2px);
		overflow: hidden;
		z-index: 30;
	}
	.chips-wrap { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.25rem; }
	.chips-wrap.compact { gap: 0.3rem; }
	.preset-wrap { margin-top: 0.35rem; }
	.mobile-score-panel { display: none; }
	.mobile-score-panel :global(.chips-wrap .chip-btn) { width: auto; }
	.mobile-score-panel .score-control { max-width: 280px; }
	.mobile-score-panel .score-control label { font-size: 0.78rem; letter-spacing: 0.02em; color: #415954; }
	.mobile-score-panel .score-control input[type='range'] { height: 10px; }
	.province-chips { flex-wrap: wrap;  }

	:global(.chips-wrap.compact .chip-btn.compact) { width: 44px; padding-left: 0; padding-right: 0; }
	:global(.chips-wrap.compact .chip-btn.compact:first-child) { width: 58px; }
	.search-suggestions { list-style: none; padding: 0.24rem; margin: 0; display: grid; gap: 0.2rem; max-height: 248px; overflow-y: auto; }
	.suggestion-btn {
		width: 100%;
		text-align: left;
		border: 0;
		border-radius: 8px;
		background: transparent;
		padding: 0.42rem 0.5rem;
		display: grid;
		cursor: pointer;
		transition: background-color 140ms ease, transform 140ms ease;
		font-size: 0.8rem;
		line-height: 1.2;
	}
	.suggestion-btn:hover { background: rgba(47, 125, 133, 0.12); transform: translateX(1px); }
	.suggestion-btn:focus-visible { outline: 2px solid #2f7d85; outline-offset: 2px; }
	.filter-foot .clear { cursor: pointer; }
	small { color: #48615d; font-size: 0.72rem; }
	.layers,.control { display: grid; gap: 0.45rem; margin-bottom: 0.55rem; }
	.compact-slider-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 0.55rem; row-gap: 0.2rem; align-items: center; }
	.compact-slider-grid label { font-size: 0.74rem; }
	.compact-slider-grid input[type='range'] { margin-bottom: 0.1rem; }
	.layers label { display: flex; gap: 0.45rem; align-items: center; font-size: 0.8rem; }
	.filter-foot { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin: 0.35rem 0; }
	.filter-foot p { font-size: 0.76rem; color: #3f5653; }
	.filter-foot .clear { width: auto; font-size: 0.74rem; }
	.muted { color: #48615d; font-size: 0.76rem; line-height: 1.35; }
	.methodology details { border: 1px dashed rgba(21, 32, 33, 0.22); border-radius: 10px; background: rgba(255, 255, 255, 0.5); }
	.methodology summary { cursor: pointer; padding: 0.55rem 0.65rem; font-family: 'Fraunces', serif; font-size: 0.86rem; }
	.method-body { display: grid; gap: 0.35rem; padding: 0 0.65rem 0.65rem; font-size: 0.78rem; }
	@media (max-width: 900px) {
		.sidebar { max-width: 100%; height: auto; min-height: 0; border-right: 0; max-height: none; overflow: visible; scrollbar-gutter: auto; padding: 1rem 1rem 1.15rem; }
		h2 { font-size: 1.02rem; }
		.control > label,
		.mobile-score-panel .score-control label,
		.compact-slider-grid label,
		.layers label { font-size: 0.8rem; }
		.methodology summary { font-size: 0.9rem; }
		.method-body { font-size: 0.8rem; }
		.muted { font-size: 0.8rem; }
		.mobile-score-panel { display: block; }
	}
</style>

<script lang="ts">
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import ClimateTempLineChart from '$lib/components/charts/ClimateTempLineChart.svelte';
	import ClimatePrecipBarsChart from '$lib/components/charts/ClimatePrecipBarsChart.svelte';

	type SortField =
		| 'nombre'
		| 'provincia'
		| 'travel_bucket'
		| 'precip_annual_mm'
		| 'temp_winter_mean_c'
		| 'temp_summer_mean_c';

	type Props = {
		query?: string;
		municipios?: Municipio[];
		allMunicipiosCount?: number;
		selectedMunicipio?: Municipio | null;
		showMunicipioPolygons?: boolean;
		showIgnWmsBase?: boolean;
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
		activeFiltersSummary?: string[];
		shortlistedIds?: string[];
		shortlistMunicipios?: Municipio[];
		tableRows?: Municipio[];
		sortBy?: SortField;
		sortDirection?: 'asc' | 'desc';
		datasetMetadata?: DatasetMetadata | null;
		labelAccesibilidad?: (bucket: string) => string;
		climateSeries?: MunicipioClimateMonthly[];
		onQueryChange?: (value: string) => void;
		onSelectMunicipio?: (municipio: Municipio) => void;
		onToggleMunicipioPolygons?: (value: boolean) => void;
		onToggleIgnWmsBase?: (value: boolean) => void;
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
		onClearFilters?: () => void;
		onToggleShortlist?: (municipioId: string) => void;
		onChangeSort?: (field: SortField) => void;
	};

	let {
		query = '',
		municipios = [],
		allMunicipiosCount = 0,
		selectedMunicipio = null,
		showMunicipioPolygons = true,
		showIgnWmsBase = false,
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
		activeFiltersSummary = [],
		shortlistedIds = [],
		shortlistMunicipios = [],
		tableRows = [],
		sortBy = 'precip_annual_mm',
		sortDirection = 'desc',
		datasetMetadata = null,
		labelAccesibilidad = (bucket: string) => bucket,
		climateSeries = [],
		onQueryChange = () => undefined,
		onSelectMunicipio = () => undefined,
		onToggleMunicipioPolygons = () => undefined,
		onToggleIgnWmsBase = () => undefined,
		onMapColorMetricChange = () => undefined,
		onToggleForestLayer = () => undefined,
		onToggleLandUseLayer = () => undefined,
		onToggleVegetationLayer = () => undefined,
		onProvinceFilterChange = () => undefined,
		onMaxTravelBucketChange = () => undefined,
		onMinPrecipAnnualChange = () => undefined,
		onMinWinterTempChange = () => undefined,
		onMaxSummerTempChange = () => undefined,
		onClearFilters = () => undefined,
		onToggleShortlist = () => undefined,
		onChangeSort = () => undefined
	}: Props = $props();

	const filteredMunicipios = $derived(
		municipios
			.filter((m) => `${m.nombre} ${m.provincia}`.toLowerCase().includes(query.trim().toLowerCase()))
			.slice(0, 10)
	);

	const totalMunicipios = $derived(municipios.length);
	const within2h = $derived(municipios.filter((m) => m.iso_02h00m).length);

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);

	const climateTag = (m: Municipio) => {
		if (m.precip_annual_mm >= 950) return 'humedo';
		if (m.precip_annual_mm <= 550) return 'seco';
		return 'medio';
	};

	const summerTag = (m: Municipio) => {
		if (m.temp_summer_mean_c <= 20) return 'verano suave';
		if (m.temp_summer_mean_c >= 25) return 'verano caluroso';
		return 'verano templado';
	};

	const sortLabel = (field: SortField) => (sortBy === field ? ` ${sortDirection === 'asc' ? '↑' : '↓'}` : '');

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
		<p class="phase">Fase 3 · analitica de decision</p>
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
		<h2>Filtros duros</h2>
		<div class="control">
			<label for="search">Buscar municipio</label>
			<input
				id="search"
				type="search"
				placeholder="Ej. Soria"
				value={query}
				oninput={(e) => onQueryChange((e.currentTarget as HTMLInputElement).value)}
			/>
		</div>
		<div class="control">
			<p class="control-title">Provincia</p>
			<div class="chips-wrap">
				{#each provinciasDisponibles as provincia}
					<button
						type="button"
						class={`chip ${provinceFilter === provincia ? 'active' : ''}`}
						onclick={() => onProvinceFilterChange(provincia)}
						aria-pressed={provinceFilter === provincia}
					>
						{provincia}
					</button>
				{/each}
			</div>
		</div>
		<div class="control">
			<p class="control-title">Accesibilidad maxima</p>
			<div class="chips-wrap compact">
				{#each travelBuckets as bucket}
					<button
						type="button"
						class={`chip ${maxTravelBucket === bucket.value ? 'active' : ''}`}
						onclick={() => onMaxTravelBucketChange(bucket.value)}
						aria-pressed={maxTravelBucket === bucket.value}
					>
						{bucket.label}
					</button>
				{/each}
			</div>
		</div>
		<div class="control">
			<label for="min-precip">Precipitacion minima anual: {minPrecipAnnual} mm</label>
			<input id="min-precip" type="range" min="0" max="1800" step="10" value={minPrecipAnnual} oninput={(e) => onMinPrecipAnnualChange(toNumber(e))} />
		</div>
		<div class="control">
			<label for="min-winter-temp">Temp. invierno minima: {minWinterTemp} C</label>
			<input id="min-winter-temp" type="range" min="-15" max="15" step="0.5" value={minWinterTemp} oninput={(e) => onMinWinterTempChange(toNumber(e))} />
		</div>
		<div class="control">
			<label for="max-summer-temp">Temp. verano maxima: {maxSummerTemp} C</label>
			<input id="max-summer-temp" type="range" min="15" max="40" step="0.5" value={maxSummerTemp} oninput={(e) => onMaxSummerTempChange(toNumber(e))} />
		</div>
		<div class="filter-foot">
			<p>Activos: {activeFiltersSummary.length > 0 ? activeFiltersSummary.join(' · ') : 'sin filtros activos'}</p>
			<button class="clear" onclick={onClearFilters}>Limpiar filtros</button>
		</div>
		{#if query.trim().length > 0}
			<ul>
				{#each filteredMunicipios as municipio (municipio.id)}
					<li>
						<button onclick={() => onSelectMunicipio(municipio)}>
							<span>{municipio.nombre}</span>
							<small>{municipio.provincia}</small>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</section>

	<section class="panel ficha">
		<h2>Ficha municipal rica</h2>
		{#if selectedMunicipio}
			<h3>{selectedMunicipio.nombre}</h3>
			<p>{selectedMunicipio.provincia} · {selectedMunicipio.codigo}</p>
			<div class="tags">
				<span>{climateTag(selectedMunicipio)}</span>
				<span>{summerTag(selectedMunicipio)}</span>
				<span>accesibilidad {labelAccesibilidad(selectedMunicipio.travel_bucket)}</span>
			</div>
			<div class="metric-grid">
				<div><span>Bucket accesibilidad</span><strong>{selectedMunicipio.travel_bucket}</strong></div>
				<div><span>Precipitacion anual</span><strong>{selectedMunicipio.precip_annual_mm} mm</strong></div>
				<div><span>Invierno medio</span><strong>{selectedMunicipio.temp_winter_mean_c} C</strong></div>
				<div><span>Verano medio</span><strong>{selectedMunicipio.temp_summer_mean_c} C</strong></div>
				<div><span>Enero / Julio</span><strong>{selectedMunicipio.temp_jan_mean_c} / {selectedMunicipio.temp_jul_mean_c} C</strong></div>
				<div><span>Norma futura</span><strong>{selectedMunicipio.precip_norm ?? '-'} / {selectedMunicipio.accesibilidad_norm ?? '-'}</strong></div>
			</div>
			<div class="charts">
				<div class="chart-card">
					<p>Temperatura mensual (C)</p>
					<ClimateTempLineChart data={climateSeries} />
				</div>
				<div class="chart-card">
					<p>Precipitacion mensual (mm)</p>
					<ClimatePrecipBarsChart data={climateSeries} />
				</div>
			</div>
			<button class="shortlist-btn" onclick={() => onToggleShortlist(selectedMunicipio.id)}>
				{shortlistedIds.includes(selectedMunicipio.id) ? 'Quitar de shortlist' : 'Anadir a shortlist'}
			</button>
		{:else}
			<p class="muted">Selecciona un municipio desde el buscador, listado o mapa.</p>
		{/if}
	</section>

	<section class="panel table-panel">
		<h2>Vista analitica</h2>
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th><button onclick={() => onChangeSort('nombre')}>Municipio{sortLabel('nombre')}</button></th>
						<th><button onclick={() => onChangeSort('provincia')}>Provincia{sortLabel('provincia')}</button></th>
						<th><button onclick={() => onChangeSort('travel_bucket')}>Isocrona{sortLabel('travel_bucket')}</button></th>
						<th><button onclick={() => onChangeSort('precip_annual_mm')}>PPT{sortLabel('precip_annual_mm')}</button></th>
						<th><button onclick={() => onChangeSort('temp_winter_mean_c')}>Invierno{sortLabel('temp_winter_mean_c')}</button></th>
						<th><button onclick={() => onChangeSort('temp_summer_mean_c')}>Verano{sortLabel('temp_summer_mean_c')}</button></th>
					</tr>
				</thead>
				<tbody>
					{#each tableRows.slice(0, 80) as municipio (municipio.id)}
						<tr onclick={() => onSelectMunicipio(municipio)}>
							<td>{municipio.nombre}</td>
							<td>{municipio.provincia}</td>
							<td>{municipio.travel_bucket}</td>
							<td>{municipio.precip_annual_mm}</td>
							<td>{municipio.temp_winter_mean_c}</td>
							<td>{municipio.temp_summer_mean_c}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</section>

	<section class="panel">
		<h2>Shortlist</h2>
		{#if shortlistMunicipios.length === 0}
			<p class="muted">Todavia no hay municipios guardados.</p>
		{:else}
			<ul>
				{#each shortlistMunicipios as municipio (municipio.id)}
					<li>
						<button onclick={() => onSelectMunicipio(municipio)}>
							<span>{municipio.nombre}</span>
							<small>{municipio.provincia}</small>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</section>

	<section class="panel methodology">
		<details>
			<summary>Metodologia y trazabilidad</summary>
			<div class="method-body">
				{#if datasetMetadata}
					<p><strong>Fuente climatica:</strong> {datasetMetadata.climate_source}</p>
					<p><strong>Periodo:</strong> {datasetMetadata.climate_period}</p>
					<p><strong>Agregacion municipal:</strong> {datasetMetadata.aggregation_method}</p>
					<p><strong>Isocronas:</strong> {datasetMetadata.isochrones_definition}</p>
					<p><strong>Fecha generacion:</strong> {datasetMetadata.generated_at_utc}</p>
					<p><strong>Version dataset:</strong> {datasetMetadata.dataset_version}</p>
				{:else}
					<p class="muted">Sin metadata disponible en este build.</p>
				{/if}
			</div>
		</details>
	</section>

	<section class="panel">
		<h2>Capas</h2>
		<div class="layers">
			<p class="control-title">Color municipal</p>
			<div class="chips-wrap compact">
				<button type="button" class={`chip ${mapColorMetric === 'mixed_score' ? 'active' : ''}`} onclick={() => onMapColorMetricChange('mixed_score')} aria-pressed={mapColorMetric === 'mixed_score'}>Score</button>
				<button type="button" class={`chip ${mapColorMetric === 'precip_annual_mm' ? 'active' : ''}`} onclick={() => onMapColorMetricChange('precip_annual_mm')} aria-pressed={mapColorMetric === 'precip_annual_mm'}>PPT</button>
			</div>
			<label><input type="checkbox" checked={showMunicipioPolygons} onchange={(e) => onToggleMunicipioPolygons((e.currentTarget as HTMLInputElement).checked)} /><span>Poligonos municipales</span></label>
			<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => onToggleIgnWmsBase((e.currentTarget as HTMLInputElement).checked)} /><span>Base IGN WMS</span></label>
			<label><input type="checkbox" checked={showForestLayer} onchange={(e) => onToggleForestLayer((e.currentTarget as HTMLInputElement).checked)} /><span>Masa forestal</span></label>
			<label><input type="checkbox" checked={showLandUseLayer} onchange={(e) => onToggleLandUseLayer((e.currentTarget as HTMLInputElement).checked)} /><span>Usos del suelo</span></label>
			<label><input type="checkbox" checked={showVegetationLayer} onchange={(e) => onToggleVegetationLayer((e.currentTarget as HTMLInputElement).checked)} /><span>Cobertura vegetal</span></label>
		</div>
	</section>
</aside>

<style>
	.sidebar { width: 100%; max-width: 440px; height: 100%; max-height: 100%; min-height: 0; overflow-y: auto; overflow-x: hidden; overscroll-behavior: contain; scrollbar-gutter: stable; background: linear-gradient(170deg, rgba(245, 238, 224, 0.86), rgba(232, 220, 196, 0.94)); border-right: 1px solid rgba(21, 32, 33, 0.18); padding: 1rem 0.9rem 1.35rem; display: grid; gap: 0.8rem; }
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
	h2,h3,p { margin: 0; }
	h2 { font-family: 'Fraunces', serif; font-size: 1rem; margin-bottom: 0.5rem; }
	h3 { font-family: 'Fraunces', serif; font-size: 1.1rem; }
	.control-title { margin: 0; font-size: 0.95rem; }
	input[type='search'] { width: 100%; margin-top: 0.35rem; padding: 0.62rem 0.7rem; border: 1px solid rgba(21, 32, 33, 0.2); border-radius: 10px; background: rgba(255, 255, 255, 0.78); }
	.chips-wrap { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.25rem; }
	.chips-wrap.compact { gap: 0.3rem; }
	.chip { width: auto; padding: 0.28rem 0.5rem; border-radius: 999px; border: 1px solid rgba(21, 32, 33, 0.2); background: rgba(255, 255, 255, 0.72); font-size: 0.72rem; line-height: 1.1; text-transform: none; letter-spacing: 0.01em; }
	.chips-wrap.compact .chip:nth-child(n + 2) { width: 41px; padding-left: 0; padding-right: 0; justify-content: center; text-align: center; }
	.chip:hover { transform: translateY(-1px); border-color: #2f7d85; }
	.chip.active { background: #2f7d85; color: #f5f4ef; border-color: #1f5f66; }
	ul { list-style: none; padding: 0; margin: 0.6rem 0 0; display: grid; gap: 0.4rem; }
	button { width: 100%; text-align: left; border: 1px solid rgba(47, 125, 133, 0.28); border-radius: 10px; background: rgba(255, 255, 255, 0.92); padding: 0.45rem 0.6rem; display: grid; cursor: pointer; }
	button:hover { border-color: #bb5b31; transform: translateX(2px); transition: 160ms ease; }
	small { color: #48615d; }
	.tags { display: flex; gap: 0.4rem; flex-wrap: wrap; margin-top: 0.4rem; }
	.tags span { font-size: 0.74rem; padding: 0.2rem 0.45rem; border-radius: 999px; background: rgba(16, 88, 96, 0.12); color: #1f4f56; }
	.metric-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.45rem; margin-top: 0.55rem; }
	.metric-grid div { padding: 0.45rem; border-radius: 8px; background: rgba(238, 248, 245, 0.64); border: 1px solid rgba(19, 63, 70, 0.16); }
	.metric-grid span { display: block; font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.08em; color: #4b5d5a; }
	.metric-grid strong { font-size: 0.9rem; }
	.charts { display: grid; gap: 0.55rem; margin-top: 0.6rem; }
	.chart-card { border: 1px solid rgba(19, 63, 70, 0.16); border-radius: 8px; background: rgba(255, 255, 255, 0.66); padding: 0.4rem; }
	.chart-card p { font-size: 0.72rem; letter-spacing: 0.03em; text-transform: uppercase; color: #3d5552; margin-bottom: 0.22rem; }
	.shortlist-btn { margin-top: 0.6rem; }
	.layers,.control { display: grid; gap: 0.45rem; margin-bottom: 0.55rem; }
	.layers label { display: flex; gap: 0.45rem; align-items: center; font-size: 0.92rem; }
	.filter-foot { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin: 0.35rem 0; }
	.filter-foot p { font-size: 0.76rem; color: #3f5653; }
	.filter-foot .clear { width: auto; }
	.table-wrap { overflow: auto; max-height: 320px; }
	table { width: 100%; border-collapse: collapse; font-size: 0.8rem; }
	th, td { border-bottom: 1px solid rgba(21, 32, 33, 0.12); padding: 0.25rem 0.35rem; white-space: nowrap; }
	th button { width: auto; border: 0; padding: 0; background: transparent; font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.04em; }
	tbody tr { cursor: pointer; }
	tbody tr:hover { background: rgba(33, 102, 109, 0.08); }
	.muted { color: #48615d; }
	.methodology details { border: 1px dashed rgba(21, 32, 33, 0.22); border-radius: 10px; background: rgba(255, 255, 255, 0.5); }
	.methodology summary { cursor: pointer; padding: 0.55rem 0.65rem; font-family: 'Fraunces', serif; font-size: 0.95rem; }
	.method-body { display: grid; gap: 0.35rem; padding: 0 0.65rem 0.65rem; font-size: 0.84rem; }
	@media (max-width: 900px) { .sidebar { max-width: 100%; height: auto; min-height: 0; border-right: 0; border-bottom: 1px solid rgba(21, 32, 33, 0.18); max-height: none; overflow: visible; scrollbar-gutter: auto; padding: 1rem 1rem 1.15rem; } }
</style>

<script lang="ts">
	import type { DatasetMetadata, Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import MunicipioSearch from '$lib/components/ui/MunicipioSearch.svelte';
	import ClimateFilters from '$lib/components/filters/ClimateFilters.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';
	import type { TravelBucketFilter } from '$lib/state/filters';
	import { travelBuckets } from '$lib/state/filters';

	type Props = {
		query?: string;
		municipios?: Municipio[];
		searchMunicipios?: Municipio[];
		selectedMunicipio?: Municipio | null;
		provinceFilter?: string;
		provinciasDisponibles?: string[];
		maxTravelBucket?: TravelBucketFilter;
		minPrecipAnnual?: number;
		minWinterTemp?: number;
		maxSummerTemp?: number;
		maxThermalAmplitude?: number;
		maxThermalAmplitudeLimit?: number;
		minCompositeScore?: number;
		activeFiltersSummary?: string[];
		onQueryChange?: (value: string) => void;
		onSelectMunicipio?: (municipio: Municipio) => void;
		onProvinceFilterChange?: (value: string) => void;
		onMaxTravelBucketChange?: (value: TravelBucketFilter) => void;
		onMinPrecipAnnualChange?: (value: number) => void;
		onMinWinterTempChange?: (value: number) => void;
		onMaxSummerTempChange?: (value: number) => void;
		onMaxThermalAmplitudeChange?: (value: number) => void;
		onMinCompositeScoreChange?: (value: number) => void;
		onClearFilters?: () => void;
	};

	let {
		query = '',
		municipios = [],
		searchMunicipios = [],
		provinceFilter = 'Todas',
		provinciasDisponibles = ['Todas'],
		maxTravelBucket = null,
		minPrecipAnnual = 0,
		minWinterTemp = -10,
		maxSummerTemp = 40,
		maxThermalAmplitude = 21,
		maxThermalAmplitudeLimit = 21,
		minCompositeScore = 0,
		activeFiltersSummary = [],
		onQueryChange = () => undefined,
		onSelectMunicipio = () => undefined,
		onProvinceFilterChange = () => undefined,
		onMaxTravelBucketChange = () => undefined,
		onMinPrecipAnnualChange = () => undefined,
		onMinWinterTempChange = () => undefined,
		onMaxSummerTempChange = () => undefined,
		onMaxThermalAmplitudeChange = () => undefined,
		onMinCompositeScoreChange = () => undefined,
		onClearFilters = () => undefined
	}: Props = $props();
</script>

<section class="panel">
	<h2>Filtros</h2>
	<div class="control search-control">
		<div class="label-help-row">
			<label class="control-title" for="search">Buscar municipio</label>
			<FilterHelp text={FILTER_HELP.search} />
		</div>
		<MunicipioSearch
			{query}
			{municipios}
			{searchMunicipios}
			inputId="search"
			{onQueryChange}
			{onSelectMunicipio}
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
		<p class="control-title control-title-help">Accesibilidad maxima <FilterHelp text={FILTER_HELP.accessibility} /></p>
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

<style>
	section.panel {
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		padding: 0.8rem;
		background: rgba(255, 255, 255, 0.62);
	}
	h2 {
		font-family: 'Fraunces', serif;
		font-size: 1rem;
		margin: 0 0 0.5rem 0;
	}
	h2, p {
		margin: 0;
	}
	.control-title {
		margin: 0;
		font-size: 0.78rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #405753;
	}
	.label-help-row {
		display: inline-flex;
		align-items: center;
		gap: 0.32rem;
		flex-wrap: wrap;
		margin-top: 0.4rem;
	}
	.control-title-help {
		display: inline-flex;
		align-items: center;
		gap: 0.32rem;
		flex-wrap: wrap;
	}
	.search-control {
		position: relative;
		z-index: 24;
	}
	.chips-wrap {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		margin-top: 0.25rem;
	}
	.chips-wrap.compact {
		gap: 0.3rem;
	}
	.province-chips {
		flex-wrap: wrap;
	}
	.control {
		display: grid;
		gap: 0rem;
		margin-bottom: 0.75rem;
	}
	.filter-foot {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin: 0.35rem 0;
	}
	.filter-foot p {
		font-size: 0.76rem;
		color: #3f5653;
		margin: 0;
	}
	.filter-foot .clear {
		cursor: pointer;
		border: 1px solid rgba(21, 32, 33, 0.22);
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.8);
		padding: 0.3rem 0.6rem;
		color: #2f4743;
		font-size: 0.75rem;
		transition: background-color 120ms ease, transform 120ms ease;
	}
	.filter-foot .clear:hover {
		background: rgba(255, 255, 255, 0.94);
		transform: translateY(-0.5px);
	}
</style>

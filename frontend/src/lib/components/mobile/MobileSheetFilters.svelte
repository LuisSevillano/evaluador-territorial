<script lang="ts">
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import MunicipioSearch from '$lib/components/ui/MunicipioSearch.svelte';
	import ClimateFilters from '$lib/components/filters/ClimateFilters.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';
	import { travelBuckets, type TravelBucket } from '$lib/state/filters';
	import type { Municipio } from '$lib/types/municipio';
	import type { Preset } from '$lib/state/scoring';

	type Props = {
		query: string;
		municipiosScoredForView: Municipio[];
		municipiosFiltradosBase: Municipio[];
		provinciasDisponibles: string[];
		provinceFilter: string;
		maxTravelBucket: TravelBucket | null;
		minPrecipAnnual: number;
		minWinterTemp: number;
		maxSummerTemp: number;
		maxThermalAmplitude: number;
		maxThermalAmplitudeLimit: number;
		minCompositeScore: number;
		climateWeight: number;
		accessWeight: number;
		natureWeight: number;
		sensitivityOverlap: number;
		activePreset: Preset | null;
		onQueryChange: (value: string) => void;
		onSelectMunicipio: (municipio: Municipio | null) => void;
		onProvinceFilterChange: (value: string) => void;
		onMaxTravelBucketChange: (value: TravelBucket | null) => void;
		onMinPrecipAnnualChange: (value: number) => void;
		onMinWinterTempChange: (value: number) => void;
		onMaxSummerTempChange: (value: number) => void;
		onMaxThermalAmplitudeChange: (value: number) => void;
		onMinCompositeScoreChange: (value: number) => void;
		onPresetWeights: (preset: Preset) => void;
		onClimateWeightChange: (value: number) => void;
		onAccessWeightChange: (value: number) => void;
		onNatureWeightChange: (value: number) => void;
		onClearFilters: () => void;
		onGoToRank: () => void;
	};

	let props: Props = $props();
	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);
</script>

<div class="sheet-block">
	<p class="sheet-meta">Ajusta filtros y criterios para encontrar el municipio ideal.</p>
	<section class="sheet-section">
		<p class="sheet-subtitle">Filtros base</p>
		<div class="sheet-score-item">
			<label for="sheet-search">Buscar municipio</label>
			<MunicipioSearch
				query={props.query}
				municipios={props.municipiosScoredForView}
				searchMunicipios={props.municipiosFiltradosBase}
				inputId="sheet-search"
				variant="sheet"
				onQueryChange={props.onQueryChange}
				onSelectMunicipio={props.onSelectMunicipio}
			/>
		</div>
		<div class="sheet-label-help-row sheet-label-help-row-nowrap">
			<label for="sheet-province">Provincia</label>
			<FilterHelp text={FILTER_HELP.province} />
		</div>
		<select id="sheet-province" value={props.provinceFilter} onchange={(e) => props.onProvinceFilterChange((e.currentTarget as HTMLSelectElement).value)}>
			{#each props.provinciasDisponibles as provincia}
				<option value={provincia}>{provincia}</option>
			{/each}
		</select>
		<p class="sheet-subtitle sheet-subtitle-help">Accesibilidad maxima <FilterHelp text={FILTER_HELP.accessibility} /></p>
		<div class="chips-row">
			{#each travelBuckets as bucket}
				<ChipButton label={bucket.label} size="small" compact={true} active={props.maxTravelBucket === bucket.value} onclick={() => props.onMaxTravelBucketChange(bucket.value)} />
			{/each}
		</div>
		<p class="sheet-subtitle">Filtros de climatologia</p>
		<ClimateFilters
			variant="sheet"
			idPrefix="sheet"
			minPrecipAnnual={props.minPrecipAnnual}
			minWinterTemp={props.minWinterTemp}
			maxSummerTemp={props.maxSummerTemp}
			maxThermalAmplitude={props.maxThermalAmplitude}
			maxThermalAmplitudeLimit={props.maxThermalAmplitudeLimit}
			minCompositeScore={props.minCompositeScore}
			onMinPrecipAnnualChange={props.onMinPrecipAnnualChange}
			onMinWinterTempChange={props.onMinWinterTempChange}
			onMaxSummerTempChange={props.onMaxSummerTempChange}
			onMaxThermalAmplitudeChange={props.onMaxThermalAmplitudeChange}
			onMinCompositeScoreChange={props.onMinCompositeScoreChange}
		/>
	</section>
	<section class="sheet-section sheet-section-score">
		<div class="sheet-score-summary">
			<span>Clima: {props.climateWeight} · Accesibilidad: {props.accessWeight} · Naturaleza: {props.natureWeight}</span>
			<span>Robustez top-10: {props.sensitivityOverlap}/10</span>
		</div>
		<p class="sheet-subtitle">Ajuste del score</p>
		<div class="chips-row">
			<ChipButton label="Equilibrado" active={props.activePreset === 'equilibrado'} onclick={() => props.onPresetWeights('equilibrado')} />
			<ChipButton label="Naturaleza" active={props.activePreset === 'naturaleza'} onclick={() => props.onPresetWeights('naturaleza')} />
			<ChipButton label="Accesibilidad" active={props.activePreset === 'accesibilidad'} onclick={() => props.onPresetWeights('accesibilidad')} />
			<ChipButton label="Clima" active={props.activePreset === 'clima'} onclick={() => props.onPresetWeights('clima')} />
			<ChipButton label="Clima estricto" active={props.activePreset === 'clima_estricto'} onclick={() => props.onPresetWeights('clima_estricto')} />
		</div>
		<div class="sheet-slider-grid">
			<div class="sheet-score-item">
				<label for="sheet-w-clima">Peso clima: {props.climateWeight}</label>
				<input id="sheet-w-clima" type="range" min="0" max="100" step="1" value={props.climateWeight} oninput={(e) => props.onClimateWeightChange(toNumber(e))} />
			</div>
			<div class="sheet-score-item">
				<label for="sheet-w-acceso">Peso accesibilidad: {props.accessWeight}</label>
				<input id="sheet-w-acceso" type="range" min="0" max="100" step="1" value={props.accessWeight} oninput={(e) => props.onAccessWeightChange(toNumber(e))} />
			</div>
			<div class="sheet-score-item">
				<label for="sheet-w-nat">Peso naturaleza: {props.natureWeight}</label>
				<input id="sheet-w-nat" type="range" min="0" max="100" step="1" value={props.natureWeight} oninput={(e) => props.onNatureWeightChange(toNumber(e))} />
			</div>
		</div>
	</section>
	<div class="sheet-actions">
		<button class="sheet-clear" onclick={props.onClearFilters}>Limpiar filtros</button>
		<button class="sheet-clear" onclick={props.onGoToRank}>Ir a ranking</button>
	</div>
</div>

<style>
	.sheet-block {
		display: grid;
		gap: 0.45rem;
	}
	.sheet-section {
		display: grid;
		gap: 0.4rem;
		padding: 0.5rem;
		border: 1px solid rgba(21, 32, 33, 0.13);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.45);
	}
	.sheet-section-score {
		padding-top: 0.45rem;
	}
	.sheet-score-summary {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}
	.sheet-score-summary span {
		font-size: 0.68rem;
		padding: 0.16rem 0.45rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.16);
		background: rgba(255, 255, 255, 0.6);
		color: #3d5652;
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
	.sheet-label-help-row {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		flex-wrap: nowrap;
	}
	.sheet-label-help-row label {
		display: inline;
		min-width: 0;
		line-height: 1.15;
	}
	.sheet-label-help-row :global(.help-wrap) {
		flex: 0 0 auto;
		margin-top: 0;
	}
	.sheet-label-help-row-nowrap label {
		white-space: nowrap;
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
	.sheet-subtitle-help {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		white-space: nowrap;
	}
	.sheet-subtitle-help :global(.help-wrap) {
		flex: 0 0 auto;
	}
	@media (max-width: 435px) {
		.sheet-label-help-row label,
		.sheet-subtitle-help {
			font-size: 0.68rem;
		}
	}
	.sheet-block select {
		border: 1px solid rgba(21, 32, 33, 0.2);
		border-radius: 8px;
		height: 30px;
		padding: 0 0.5rem;
		font-size: 0.8rem;
		line-height: 1.2;
		background: rgba(255, 255, 255, 0.86);
	}
	.chips-row {
		column-gap: 0.25rem;
		row-gap: 0.25rem;
	}
	.sheet-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		padding: 0.15rem 0 calc(env(safe-area-inset-bottom) + 0.1rem);
	}
	.sheet-meta {
		margin: 0.1rem 0 0.2rem;
		font-size: 0.72rem;
		color: #48605c;
	}
</style>

<script lang="ts">
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import MunicipioSearch from '$lib/components/ui/MunicipioSearch.svelte';
	import ClimateFilters from '$lib/components/filters/ClimateFilters.svelte';
	import ScoreControls from '$lib/components/scoring/ScoreControls.svelte';
	import AppButton from '$lib/components/ui/AppButton.svelte';
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
		onCoordinateSearch: (payload: { lat: number; lon: number; label: string }) => void;
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

	const normalizedWeights = $derived.by(() => {
		const total = props.climateWeight + props.accessWeight + props.natureWeight;
		if (total <= 0) {
			return { climate: 0, access: 0, nature: 0 };
		}
		return {
			climate: props.climateWeight / total,
			access: props.accessWeight / total,
			nature: props.natureWeight / total
		};
	});
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
				onCoordinateSearch={props.onCoordinateSearch}
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
	<div class="sheet-section sheet-section-score">
		<ScoreControls
			weights={normalizedWeights}
			weightsRaw={{
				climateWeight: props.climateWeight,
				accessWeight: props.accessWeight,
				natureWeight: props.natureWeight
			}}
			sensitivityOverlap={props.sensitivityOverlap}
			activePreset={props.activePreset}
			onPresetWeights={props.onPresetWeights}
			onClimateWeightChange={props.onClimateWeightChange}
			onAccessWeightChange={props.onAccessWeightChange}
			onNatureWeightChange={props.onNatureWeightChange}
			idPrefix="sheet"
			layout="stack"
			containerTag="div"
			compactPresetLabels={true}
			subtitle="Estos pesos cambian el score y el ranking del atlas en tiempo real."
		/>
	</div>
	<div class="sheet-actions">
		<AppButton label="Limpiar filtros" onclick={props.onClearFilters} />
		<AppButton label="Ir a ranking" onclick={props.onGoToRank} variant="solid" />
	</div>
</div>

<style>
	.sheet-block {
		display: grid;
		gap: 0.45rem;
		min-width: 0;
		overflow-x: clip;
	}
	.sheet-section {
		display: grid;
		gap: 0.4rem;
		width: 100%;
		min-width: 0;
		box-sizing: border-box;
		padding: 0.5rem;
		border: 1px solid rgba(21, 32, 33, 0.13);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.45);
	}
	.sheet-section-score {
		padding-top: 0.45rem;
		min-width: 0;
	}
	:global(.sheet-section-score .score-panel) {
		border: 0;
		border-radius: 0;
		padding: 0;
		background: transparent;
		width: 100%;
		min-width: 0;
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
		display: flex;
		flex-wrap: wrap;
		min-width: 0;
		column-gap: 0.25rem;
		row-gap: 0.25rem;
	}
	.sheet-actions {
		display: flex;
		flex-wrap: wrap;
		min-width: 0;
		gap: 0.35rem;
		padding: 0.15rem 0 calc(env(safe-area-inset-bottom) + 0.1rem);
	}
	:global(.sheet-actions .app-btn) {
		font-size: 0.72rem;
	}
	.sheet-meta {
		margin: 0.1rem 0 0.2rem;
		font-size: 0.72rem;
		color: #48605c;
	}
</style>

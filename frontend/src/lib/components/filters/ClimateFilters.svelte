<script lang="ts">
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';

	type Props = {
		variant?: 'desktop' | 'sheet';
		idPrefix?: string;
		minPrecipAnnual: number;
		minWinterTemp: number;
		maxSummerTemp: number;
		maxThermalAmplitude: number;
		maxThermalAmplitudeLimit: number;
		minCompositeScore?: number;
		onMinPrecipAnnualChange: (value: number) => void;
		onMinWinterTempChange: (value: number) => void;
		onMaxSummerTempChange: (value: number) => void;
		onMaxThermalAmplitudeChange: (value: number) => void;
		onMinCompositeScoreChange?: (value: number) => void;
	};

	let {
		variant = 'desktop',
		idPrefix = 'climate',
		minPrecipAnnual,
		minWinterTemp,
		maxSummerTemp,
		maxThermalAmplitude,
		maxThermalAmplitudeLimit,
		minCompositeScore = 0,
		onMinPrecipAnnualChange,
		onMinWinterTempChange,
		onMaxSummerTempChange,
		onMaxThermalAmplitudeChange,
		onMinCompositeScoreChange = () => undefined
	}: Props = $props();

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);
</script>

<div class:desktop-grid={variant === 'desktop'} class:sheet-grid={variant === 'sheet'}>
	<div class="item">
		<div class="label-help-row">
			<label for={`${idPrefix}-min-precip`}>Precipitación mínima anual: {minPrecipAnnual} mm</label>
			<FilterHelp text={FILTER_HELP.precip} />
		</div>
		<input
			id={`${idPrefix}-min-precip`}
			type="range"
			min="0"
			max="1800"
			step="10"
			value={minPrecipAnnual}
			oninput={(e) => onMinPrecipAnnualChange(toNumber(e))}
		/>
	</div>

	<div class="item">
		<div class="label-help-row">
			<label for={`${idPrefix}-min-winter`}>Temp. invierno mínima: {minWinterTemp} C</label>
			<FilterHelp text={FILTER_HELP.winter} />
		</div>
		<input
			id={`${idPrefix}-min-winter`}
			type="range"
			min="-15"
			max="15"
			step="0.5"
			value={minWinterTemp}
			oninput={(e) => onMinWinterTempChange(toNumber(e))}
		/>
	</div>

	<div class="item">
		<div class="label-help-row">
			<label for={`${idPrefix}-max-summer`}>Temp. verano máxima: {maxSummerTemp} C</label>
			<FilterHelp text={FILTER_HELP.summer} />
		</div>
		<input
			id={`${idPrefix}-max-summer`}
			type="range"
			min="15"
			max="40"
			step="0.5"
			value={maxSummerTemp}
			oninput={(e) => onMaxSummerTempChange(toNumber(e))}
		/>
	</div>

	<div class="item">
		<div class="label-help-row">
			<label for={`${idPrefix}-max-amplitude`}
				>Amplitud térmica máxima: {maxThermalAmplitude.toFixed(1)} C</label
			>
			<FilterHelp text={FILTER_HELP.amplitude} />
		</div>
		<input
			id={`${idPrefix}-max-amplitude`}
			type="range"
			min="12"
			max={maxThermalAmplitudeLimit}
			step="0.1"
			value={maxThermalAmplitude}
			oninput={(e) => onMaxThermalAmplitudeChange(toNumber(e))}
		/>
	</div>

	<div class="item" class:full-width={variant === 'sheet'}>
		<div class="label-help-row">
			<label for={`${idPrefix}-min-score`}
				>Score mínimo visible: {minCompositeScore.toFixed(2)}</label
			>
			<FilterHelp text={FILTER_HELP.minScore} />
		</div>
		<input
			id={`${idPrefix}-min-score`}
			type="range"
			min="0"
			max="1"
			step="0.01"
			value={minCompositeScore}
			oninput={(e) => onMinCompositeScoreChange(toNumber(e))}
		/>
	</div>
</div>

<style>
	.desktop-grid {
		display: grid;
		grid-template-columns: minmax(0, 1.4fr) minmax(110px, 0.8fr);
		column-gap: 0.55rem;
		row-gap: 0.2rem;
		align-items: center;
	}

	.sheet-grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 0.45rem 0.5rem;
	}

	.item {
		display: grid;
		gap: 0.2rem;
	}

	.desktop-grid .item {
		display: contents;
	}

	.full-width {
		grid-column: 1 / -1;
	}

	.label-help-row {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		flex-wrap: nowrap;
	}

	.label-help-row label {
		display: inline;
		min-width: 0;
		line-height: 1.15;
		font-size: 0.74rem;
		color: #3f5753;
	}

	.label-help-row :global(.help-wrap) {
		flex: 0 0 auto;
	}

	input[type='range'] {
		margin-bottom: 0.1rem;
		width: 100%;
	}

	.desktop-grid input[type='range'] {
		max-width: 150px;
		justify-self: end;
		align-self: center;
	}

	.desktop-grid .label-help-row {
		gap: 0.32rem;
	}

	.desktop-grid .label-help-row label {
		font-size: 0.74rem;
	}

	@media (max-width: 435px) {
		.label-help-row label {
			font-size: 0.6rem;
		}
	}
</style>

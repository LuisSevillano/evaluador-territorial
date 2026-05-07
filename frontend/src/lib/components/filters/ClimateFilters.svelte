<script lang="ts">
	import RangeControl from '$lib/components/ui/RangeControl.svelte';
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

</script>

<div class:desktop-grid={variant === 'desktop'} class:sheet-grid={variant === 'sheet'}>
	<RangeControl
		id={`${idPrefix}-min-precip`}
		label={`Precipitación mínima anual: ${minPrecipAnnual} mm`}
		value={minPrecipAnnual}
		min={0}
		max={1800}
		step={10}
		helpText={FILTER_HELP.precip}
		onChange={onMinPrecipAnnualChange}
		variant={variant}
	/>

	<RangeControl
		id={`${idPrefix}-min-winter`}
		label={`Temp. invierno mínima: ${minWinterTemp} C`}
		value={minWinterTemp}
		min={-15}
		max={15}
		step={0.5}
		helpText={FILTER_HELP.winter}
		onChange={onMinWinterTempChange}
		variant={variant}
	/>

	<RangeControl
		id={`${idPrefix}-max-summer`}
		label={`Temp. verano máxima: ${maxSummerTemp} C`}
		value={maxSummerTemp}
		min={15}
		max={40}
		step={0.5}
		helpText={FILTER_HELP.summer}
		onChange={onMaxSummerTempChange}
		variant={variant}
	/>

	<RangeControl
		id={`${idPrefix}-max-amplitude`}
		label={`Amplitud térmica máxima: ${maxThermalAmplitude.toFixed(1)} C`}
		value={maxThermalAmplitude}
		min={12}
		max={maxThermalAmplitudeLimit}
		step={0.1}
		helpText={FILTER_HELP.amplitude}
		onChange={onMaxThermalAmplitudeChange}
		variant={variant}
	/>

	<RangeControl
		id={`${idPrefix}-min-score`}
		label={`Score mínimo visible: ${minCompositeScore.toFixed(2)}`}
		value={minCompositeScore}
		min={0}
		max={1}
		step={0.01}
		helpText={FILTER_HELP.minScore}
		onChange={onMinCompositeScoreChange}
		variant={variant}
	/>
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

	:global(.desktop-grid .range-control.desktop) {
		display: contents;
	}

	:global(.desktop-grid .range-control.desktop .label-help-row label) {
		font-size: 0.74rem;
	}

	@media (max-width: 435px) {
		:global(.sheet-grid .range-control.sheet .label-help-row label) {
			font-size: 0.6rem;
		}
	}
</style>

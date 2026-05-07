<script lang="ts">
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
 	import RangeControl from '$lib/components/ui/RangeControl.svelte';

	type Preset = 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto';
	type Layout = 'stack' | 'grid';

	type Props = {
		weights: { climate: number; access: number; nature: number };
		weightsRaw: { climateWeight: number; accessWeight: number; natureWeight: number };
		sensitivityOverlap: number;
		activePreset: Preset | null;
		onPresetWeights: (preset: Preset) => void;
		onClimateWeightChange: (value: number) => void;
		onAccessWeightChange: (value: number) => void;
		onNatureWeightChange: (value: number) => void;
		idPrefix?: string;
		layout?: Layout;
		subtitle?: string;
		hideOnMobile?: boolean;
		containerTag?: 'section' | 'div';
		compactPresetLabels?: boolean;
	};

	let {
		weights,
		weightsRaw,
		sensitivityOverlap,
		activePreset,
		onPresetWeights,
		onClimateWeightChange,
		onAccessWeightChange,
		onNatureWeightChange,
		idPrefix = 'score',
		layout = 'grid',
		subtitle = 'Estos pesos cambian el score y el ranking; el filtro de score minimo decide que municipios se muestran en mapa y tabla.',
		hideOnMobile = false,
		containerTag = 'section',
		compactPresetLabels = false
	}: Props = $props();

</script>

<svelte:element this={containerTag} class={`panel score-panel ${hideOnMobile ? 'hide-mobile' : ''}`}>
	<h2>Ajuste del score</h2>
	<p class="muted">{subtitle}</p>
	<div class="chips-wrap compact preset-wrap">
		<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => onPresetWeights('equilibrado')} size="small" />
		<ChipButton label={compactPresetLabels ? 'Naturaleza' : 'Priorizar naturaleza'} active={activePreset === 'naturaleza'} onclick={() => onPresetWeights('naturaleza')} size="small" />
		<ChipButton label={compactPresetLabels ? 'Accesibilidad' : 'Priorizar accesibilidad'} active={activePreset === 'accesibilidad'} onclick={() => onPresetWeights('accesibilidad')} size="small" />
		<ChipButton label={compactPresetLabels ? 'Clima' : 'Priorizar clima'} active={activePreset === 'clima'} onclick={() => onPresetWeights('clima')} size="small" />
		<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => onPresetWeights('clima_estricto')} size="small" />
	</div>
	<div class="desktop-grid" class:stack-layout={layout === 'stack'}>
		<RangeControl
			id={`${idPrefix}-rw-climate`}
			name={`${idPrefix}-rw-climate`}
			label={`Peso clima: ${weightsRaw.climateWeight}`}
			value={weightsRaw.climateWeight}
			min={0}
			max={100}
			step={1}
			onChange={onClimateWeightChange}
			variant={layout === 'stack' ? 'sheet' : 'desktop'}
		/>
		<RangeControl
			id={`${idPrefix}-rw-access`}
			name={`${idPrefix}-rw-access`}
			label={`Peso accesibilidad: ${weightsRaw.accessWeight}`}
			value={weightsRaw.accessWeight}
			min={0}
			max={100}
			step={1}
			onChange={onAccessWeightChange}
			variant={layout === 'stack' ? 'sheet' : 'desktop'}
		/>
		<RangeControl
			id={`${idPrefix}-rw-nature`}
			name={`${idPrefix}-rw-nature`}
			label={`Peso naturaleza: ${weightsRaw.natureWeight}`}
			value={weightsRaw.natureWeight}
			min={0}
			max={100}
			step={1}
			onChange={onNatureWeightChange}
			variant={layout === 'stack' ? 'sheet' : 'desktop'}
		/>
	</div>
	<p class="muted">Normalizados: clima {(weights.climate * 100).toFixed(0)}% · accesibilidad {(weights.access * 100).toFixed(0)}% · naturaleza {(weights.nature * 100).toFixed(0)}%</p>
</svelte:element>

<style>
	section.panel {
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		padding: 0.8rem;
		background: rgba(255, 255, 255, 0.62);
	}
	.score-panel {
		min-width: 0;
		overflow-x: clip;
	}
	h2 {
		font-family: 'Fraunces', serif;
		font-size: 1rem;
		margin: 0 0 0.5rem 0;
	}
	h2, p {
		margin: 0;
	}
	.chips-wrap {
		display: flex;
		flex-wrap: wrap;
		min-width: 0;
		gap: 0.35rem;
		margin-top: 0.25rem;
	}
	.chips-wrap.compact {
		gap: 0.3rem;
	}
	.preset-wrap {
		margin-top: 0.35rem;
	}
	:global(.chips-wrap .chip-btn) {
		width: auto;
	}
	.desktop-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		column-gap: 0.5rem;
		row-gap: 0.45rem;
		margin-top: 0.5rem;
	}
	:global(.desktop-grid .range-control.desktop) {
		display: contents;
	}

	:global(.desktop-grid .range-control.desktop .label-help-row label) {
		font-size: 0.74rem;
	}

	.stack-layout {
		grid-template-columns: repeat(2, minmax(0, 1fr));
	}
	.muted {
		color: #48615d;
		font-size: 0.76rem;
		line-height: 1.35;
		margin-top: 0.4rem;
	}
	@media (max-width: 900px) {
		.hide-mobile {
			display: none;
		}
		.muted,
		:global(.desktop-grid .range-control .label-help-row label) {
			font-size: 0.8rem;
		}
	}
</style>

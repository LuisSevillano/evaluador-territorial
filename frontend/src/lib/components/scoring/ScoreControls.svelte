<script lang="ts">
	import ChipButton from '$lib/components/ui/ChipButton.svelte';

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
		layout = 'stack',
		subtitle = 'Estos pesos cambian el score y el ranking; el filtro de score minimo decide que municipios se muestran en mapa y tabla.',
		hideOnMobile = false
	}: Props = $props();

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);
</script>

<section class={`panel score-panel ${hideOnMobile ? 'hide-mobile' : ''}`}>
	<h2>Ajuste del score</h2>
	<p class="muted">{subtitle}</p>
	<div class="chips-wrap compact preset-wrap">
		<ChipButton label="Equilibrado" active={activePreset === 'equilibrado'} onclick={() => onPresetWeights('equilibrado')} size="small" />
		<ChipButton label="Priorizar naturaleza" active={activePreset === 'naturaleza'} onclick={() => onPresetWeights('naturaleza')} size="small" />
		<ChipButton label="Priorizar accesibilidad" active={activePreset === 'accesibilidad'} onclick={() => onPresetWeights('accesibilidad')} size="small" />
		<ChipButton label="Priorizar clima" active={activePreset === 'clima'} onclick={() => onPresetWeights('clima')} size="small" />
		<ChipButton label="Clima estricto" active={activePreset === 'clima_estricto'} onclick={() => onPresetWeights('clima_estricto')} size="small" />
	</div>
	<div class="desktop-grid">
		<div class="item">
			<label for={`${idPrefix}-rw-climate`}>Peso clima: {weightsRaw.climateWeight}</label>
			<input id={`${idPrefix}-rw-climate`} name={`${idPrefix}-rw-climate`} type="range" min="0" max="100" step="1" value={weightsRaw.climateWeight} oninput={(e) => onClimateWeightChange(toNumber(e))} />
		</div>
		<div class="item">
			<label for={`${idPrefix}-rw-access`}>Peso accesibilidad: {weightsRaw.accessWeight}</label>
			<input id={`${idPrefix}-rw-access`} name={`${idPrefix}-rw-access`} type="range" min="0" max="100" step="1" value={weightsRaw.accessWeight} oninput={(e) => onAccessWeightChange(toNumber(e))} />
		</div>
		<div class="item full-width">
			<label for={`${idPrefix}-rw-nature`}>Peso naturaleza: {weightsRaw.natureWeight}</label>
			<input id={`${idPrefix}-rw-nature`} name={`${idPrefix}-rw-nature`} type="range" min="0" max="100" step="1" value={weightsRaw.natureWeight} oninput={(e) => onNatureWeightChange(toNumber(e))} />
		</div>
	</div>
	<p class="muted">Normalizados: clima {(weights.climate * 100).toFixed(0)}% · accesibilidad {(weights.access * 100).toFixed(0)}% · naturaleza {(weights.nature * 100).toFixed(0)}%</p>
	<p class="muted">Robustez top-10 vs base equilibrada: {sensitivityOverlap}/10</p>
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
	.chips-wrap {
		display: flex;
		flex-wrap: wrap;
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
	.desktop-grid .item {
		display: contents;
	}
	.desktop-grid .item.full-width {
		grid-column: 1 / -1;
	}
	.desktop-grid label {
		font-size: 0.74rem;
		color: #3f5753;
		align-self: center;
	}
	.desktop-grid input[type='range'] {
		max-width: 150px;
		justify-self: end;
		align-self: center;
		height: 10px;
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
		.desktop-grid {
			grid-template-columns: 1fr;
		}
		.desktop-grid .item.full-width {
			grid-column: 1;
		}
		.desktop-grid label {
			display: block;
			margin-bottom: 0.2rem;
		}
		.desktop-grid input[type='range'] {
			max-width: 100%;
			width: 100%;
		}
		.muted,
		.desktop-grid label {
			font-size: 0.8rem;
		}
	}
</style>

<script lang="ts">
	import type { Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import ClimateTempLineChart from '$lib/components/charts/ClimateTempLineChart.svelte';
	import ClimatePrecipBarsChart from '$lib/components/charts/ClimatePrecipBarsChart.svelte';
	import MunicipioContextCard from '$lib/components/inspector/MunicipioContextCard.svelte';
	import { buildMunicipioContext } from '$lib/components/inspector/context';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { classifyMixedScore, labelForScoreBand } from '$lib/components/map/scoreClassification';
	import { accessToneFromBucket, climateToneFromPrecip } from '$lib/state/metricSemantics';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import ReliefIndicator from '$lib/components/inspector/ReliefIndicator.svelte';
	import { DEFAULT_WEIGHTS_NORMALIZED, DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';

	type Props = {
		selectedMunicipio?: Municipio | null;
		municipios?: Municipio[];
		shortlistedIds?: string[];
		weights?: { climate: number; access: number; nature: number };
		weightsRaw?: { climateWeight: number; accessWeight: number; natureWeight: number };
		sensitivityOverlap?: number;
		isEvaluationMode?: boolean;
		climateSeries?: MunicipioClimateMonthly[];
		provinceClimateSeries?: Array<{ month: number; temp_mean_c: number }>;
		ccaaClimateSeries?: Array<{ month: number; temp_mean_c: number }>;
		onToggleShortlist?: (municipioId: string) => void;
		onClimateWeightChange?: (value: number) => void;
		onAccessWeightChange?: (value: number) => void;
		onNatureWeightChange?: (value: number) => void;
		onPresetWeights?: (
			preset: 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto'
		) => void;
		onClearMunicipio?: () => void;
	};

	let {
		selectedMunicipio = null,
		municipios = [],
		shortlistedIds = [],
		weights = DEFAULT_WEIGHTS_NORMALIZED,
		weightsRaw = DEFAULT_WEIGHTS_RAW,
		sensitivityOverlap = 0,
		isEvaluationMode = false,
		climateSeries = [],
		provinceClimateSeries = [],
		ccaaClimateSeries = [],
		onToggleShortlist = () => undefined,
		onClimateWeightChange = () => undefined,
		onAccessWeightChange = () => undefined,
		onNatureWeightChange = () => undefined,
		onPresetWeights = () => undefined,
		onClearMunicipio = () => undefined
	}: Props = $props();

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

	const transportRows = $derived([
		{ label: 'Dist. tren (OSM)', value: `${selectedMunicipio?.dist_estacion_tren_km ?? '-'} km` },
		{ label: 'Dist. bus (OSM)', value: `${selectedMunicipio?.dist_parada_bus_km ?? '-'} km` },
		{ label: 'Dist. Renfe', value: `${selectedMunicipio?.dist_renfe_km ?? '-'} km` },
		{
			label: 'Servicio Renfe',
			value: `${selectedMunicipio?.renfe_tipo_servicio ?? '-'} (${selectedMunicipio?.renfe_salidas_dia ?? 0}/dia)`
		}
	]);

	const context = $derived.by(() => {
		return buildMunicipioContext({
			selectedMunicipio,
			municipios,
			climateSeries,
			weights
		});
	});

	const mixedLegendThresholds = $derived(getLegendConfig('mixed_score', municipios).thresholds as number[]);
	const scoreLabelWithValue = $derived.by(() => {
		if (!selectedMunicipio || !Number.isFinite(selectedMunicipio.mixed_score)) return '-';
		const score = selectedMunicipio.mixed_score as number;
		const band = classifyMixedScore(score, mixedLegendThresholds);
		return `${labelForScoreBand(band)} (${score.toFixed(3)})`;
	});
</script>

<aside class="inspector">
	<section class="panel">
		{#if selectedMunicipio}
			<div class="title-row">
				<h3>{selectedMunicipio.nombre}</h3>
				<button class="ghost-btn" onclick={onClearMunicipio}>Cerrar</button>
			</div>
			<p>
				{selectedMunicipio.provincia} · {selectedMunicipio.codigo}{selectedMunicipio.population
					? ` · ${selectedMunicipio.population.toLocaleString('es-ES')} hab.`
					: ''}
			</p>
			<MunicipioContextCard {context} scoreThresholds={mixedLegendThresholds} relieveNorm={selectedMunicipio.relieve_norm} />
			<div class="metric-grid">
				<div class="metric score">
					<span>Score mixto</span><strong>{scoreLabelWithValue}</strong>
				</div>
				<div class={`metric ${accessToneFromBucket(selectedMunicipio.travel_bucket)}`}>
					<span>Accesibilidad</span><strong>{selectedMunicipio.travel_bucket}</strong>
				</div>
				<div class={`metric ${climateToneFromPrecip(selectedMunicipio.precip_annual_mm)}`}>
					<span>Precipitación</span><strong>{selectedMunicipio.precip_annual_mm} mm</strong>
				</div>
				<div class="metric">
					<span>Invierno / Verano</span><strong
						>{selectedMunicipio.temp_winter_mean_c} / {selectedMunicipio.temp_summer_mean_c} C</strong
					>
				</div>
				<div class="metric">
					<span>Enero / Julio</span><strong
						>{selectedMunicipio.temp_jan_mean_c} / {selectedMunicipio.temp_jul_mean_c} C</strong
					>
				</div>
				<div class="metric">
					<span>% forestal / agua</span><strong
						>{selectedMunicipio.forest_pct ?? '-'} / {selectedMunicipio.water_pct ?? '-'}</strong
					>
				</div>
			<div class="metric">
				<span>Acceso a baño</span><strong>{selectedMunicipio.river_access_class ?? '-'} ({selectedMunicipio.river_access_score ?? '-'} )</strong>
			</div>
			<div class="metric">
				<span>Río más cercano</span><strong>{selectedMunicipio.river_nearest_name ?? '-'} ({selectedMunicipio.river_nearest_distance_km ?? '-'} km)</strong>
			</div>
		</div>
			<div class="transport-mini">
				<strong>Transporte de referencia</strong>
				<table>
					<tbody>
						{#each transportRows as row}
							<tr>
								<td>{row.label}</td>
								<td>{row.value}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			<div class="charts">
				<div class="chart-card">
					<p>Temperatura mensual (media + rango)</p>
					<ClimateTempLineChart
						data={climateSeries}
						provinceData={provinceClimateSeries}
						ccaaData={ccaaClimateSeries}
					/>
					{#if context?.tempAmplitude !== null}
						<small
							>Amplitud anual: {context?.tempAmplitude?.toFixed(1)} C (más alto = estacionalidad más marcada).</small
						>
					{/if}
				</div>
				<div class="chart-card">
					<p>Precipitación mensual</p>
					<ClimatePrecipBarsChart data={climateSeries} />
					{#if context?.wettest && context?.driest}
						<small
							>Pico humedo mes {context.wettest.month} ({context.wettest.precip_mm.toFixed(0)} mm) · valle
							seco mes {context.driest.month} ({context.driest.precip_mm.toFixed(0)} mm).</small
						>
					{/if}
				</div>
			</div>
			<button class="shortlist-btn" onclick={() => onToggleShortlist(selectedMunicipio.id)}>
				{shortlistedIds.includes(selectedMunicipio.id)
					? 'Quitar de shortlist'
					: 'Añadir a shortlist'}
			</button>
		{:else}
			<p class="muted">Selecciona un municipio para ver detalle avanzado.</p>
		{/if}
	</section>

	{#if isEvaluationMode}
		<section class="panel score-panel">
			<h2>Ajuste del score</h2>
			<p class="muted">
				Estos pesos cambian el score y el ranking; el filtro de score mínimo del panel izquierdo
				decide qué municipios se muestran en mapa y tabla.
			</p>
			<div class="chips-wrap compact preset-wrap">
				<ChipButton
					label="Equilibrado"
					active={activePreset === 'equilibrado'}
					onclick={() => onPresetWeights('equilibrado')}
				/>
				<ChipButton
					label="Priorizar naturaleza"
					active={activePreset === 'naturaleza'}
					onclick={() => onPresetWeights('naturaleza')}
				/>
				<ChipButton
					label="Priorizar accesibilidad"
					active={activePreset === 'accesibilidad'}
					onclick={() => onPresetWeights('accesibilidad')}
				/>
				<ChipButton
					label="Priorizar clima"
					active={activePreset === 'clima'}
					onclick={() => onPresetWeights('clima')}
				/>
				<ChipButton
					label="Clima estricto"
					active={activePreset === 'clima_estricto'}
					onclick={() => onPresetWeights('clima_estricto')}
				/>
			</div>
			<div class="control score-control">
				<label for="rw-climate">Peso clima: {weightsRaw.climateWeight}</label>
				<input
					id="rw-climate"
					name="rw-climate"
					type="range"
					min="0"
					max="100"
					step="1"
					value={weightsRaw.climateWeight}
					oninput={(e) => onClimateWeightChange(toNumber(e))}
				/>
			</div>
			<div class="control score-control">
				<label for="rw-access">Peso accesibilidad: {weightsRaw.accessWeight}</label>
				<input
					id="rw-access"
					name="rw-access"
					type="range"
					min="0"
					max="100"
					step="1"
					value={weightsRaw.accessWeight}
					oninput={(e) => onAccessWeightChange(toNumber(e))}
				/>
			</div>
			<div class="control score-control">
				<label for="rw-nature">Peso naturaleza: {weightsRaw.natureWeight}</label>
				<input
					id="rw-nature"
					name="rw-nature"
					type="range"
					min="0"
					max="100"
					step="1"
					value={weightsRaw.natureWeight}
					oninput={(e) => onNatureWeightChange(toNumber(e))}
				/>
			</div>
			<p class="muted">
				Normalizados: clima {(weights.climate * 100).toFixed(0)}% · accesibilidad {(
					weights.access * 100
				).toFixed(0)}% · naturaleza {(weights.nature * 100).toFixed(0)}%
			</p>
			<p class="muted">Robustez top-10 vs base equilibrada: {sensitivityOverlap}/10</p>
		</section>
	{/if}
</aside>

<style>
	.inspector {
		width: 100%;
		max-width: 360px;
		height: 100%;
		min-height: 0;
		overflow-y: auto;
		background: linear-gradient(180deg, rgba(246, 239, 227, 0.9), rgba(234, 222, 198, 0.92));
		border-left: 1px solid rgba(21, 32, 33, 0.18);
		padding: 0.9rem;
		display: grid;
		gap: 0.8rem;
		box-sizing: border-box;
	}
	.panel {
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		padding: 0.95rem;
		background: rgba(255, 255, 255, 0.72);
	}
	h2,
	h3,
	p {
		margin: 0;
	}
	h2 {
		font-family: 'Fraunces', serif;
		font-size: 1rem;
		margin-bottom: 0.5rem;
	}
	h3 {
		font-family: 'Fraunces', serif;
		font-size: 1.1rem;
	}
	p {
		font-size: 0.82rem;
		line-height: 1.35;
		color: #3f5652;
	}
	.title-row + p {
		margin-top: 0.12rem;
		font-size: 0.78rem;
	}
	.title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.4rem;
	}
	.ghost-btn {
		width: auto;
		border: 1px solid rgba(19, 63, 70, 0.24);
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.78);
		padding: 0.2rem 0.5rem;
		font-size: 0.74rem;
	}
	.metric-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.6rem;
		margin-top: 0.7rem;
	}
	.metric-grid div {
		padding: 0.55rem;
		border-radius: 10px;
		background: rgba(238, 248, 245, 0.64);
		border: 1px solid rgba(19, 63, 70, 0.16);
	}
	.metric.score {
		border-color: rgba(35, 98, 108, 0.45);
		background: rgba(224, 244, 247, 0.72);
	}
	.metric.good {
		border-color: rgba(15, 118, 110, 0.42);
		background: rgba(220, 248, 241, 0.72);
	}
	.metric.mid {
		border-color: rgba(180, 111, 36, 0.38);
		background: rgba(252, 242, 222, 0.74);
	}
	.metric.bad {
		border-color: rgba(170, 45, 45, 0.38);
		background: rgba(252, 234, 234, 0.74);
	}
	.metric-grid span {
		display: block;
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #4b5d5a;
	}
	.metric-grid strong {
		font-size: 0.9rem;
	}
	.charts {
		display: grid;
		gap: 0.7rem;
		margin-top: 0.75rem;
	}
	.chart-card {
		border: 1px solid rgba(19, 63, 70, 0.16);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.68);
		padding: 0.55rem;
	}
	.chart-card p {
		font-size: 0.72rem;
		letter-spacing: 0.03em;
		text-transform: uppercase;
		color: #3d5552;
		margin-bottom: 0.22rem;
	}
	.chart-card small {
		display: block;
		margin-top: 0.25rem;
		font-size: 0.7rem;
		color: #3b5250;
	}
	.shortlist-btn {
		margin-top: 0.6rem;
		cursor: pointer;
		border: 1px solid rgba(21, 32, 33, 0.22);
		border-radius: 999px;
		background: linear-gradient(120deg, #2f7d85, #245f66);
		color: #f7f4ec;
		padding: 0.45rem 0.72rem;
		font-size: 0.78rem;
		transition:
			transform 160ms ease,
			filter 160ms ease;
	}
	.shortlist-btn:hover {
		transform: translateY(-1px);
		filter: brightness(1.05);
	}
	.shortlist-btn:focus-visible {
		outline: 2px solid #2f7d85;
		outline-offset: 2px;
	}
	.chips-wrap {
		display: grid;
		gap: 0.35rem;
	}
	.preset-wrap {
		margin-top: 0.35rem;
	}
	.inspector :global(.chips-wrap .chip-btn) {
		width: auto;
	}
	.control {
		display: grid;
		gap: 0.3rem;
		margin-top: 0.55rem;
	}
	.control label {
		font-size: 0.76rem;
		letter-spacing: 0.02em;
		color: #3f5853;
	}
	.score-control {
		max-width: 230px;
	}
	.score-control input[type='range'] {
		height: 10px;
	}
	.transport-mini {
		margin-top: 0.45rem;
		padding: 0.45rem 0.55rem;
		border: 1px solid rgba(21, 32, 33, 0.12);
		border-radius: 9px;
		background: rgba(255, 255, 255, 0.66);
	}
	.transport-mini strong {
		display: block;
		font-size: 0.72rem;
		margin-bottom: 0.3rem;
		color: #3c5652;
	}
	.transport-mini table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.72rem;
	}
	.transport-mini td {
		padding: 0.14rem 0;
		vertical-align: top;
	}
	.transport-mini td:last-child {
		text-align: right;
		color: #3d5552;
	}
	.muted {
		color: #48615d;
		font-size: 0.76rem;
		margin-top: 0.4rem;
		line-height: 1.35;
	}
	@media (max-width: 1180px) {
		.inspector {
			max-width: 100%;
			border-left: 0;
		}
	}
	@media (max-width: 900px) {
		.inspector {
			padding: 0.5rem;
			gap: 0.5rem;
		}
		h2 {
			font-size: 0.9rem;
			margin-bottom: 0.35rem;
		}
		h3 {
			font-size: 1rem;
		}
		p {
			font-size: 0.78rem;
		}
		.title-row + p {
			font-size: 0.72rem;
		}
		.metric-grid {
			gap: 0.35rem;
			margin-top: 0.45rem;
		}
		.metric-grid div {
			padding: 0.35rem;
			border-radius: 6px;
		}
		.metric-grid span {
			font-size: 0.6rem;
		}
		.metric-grid strong {
			font-size: 0.8rem;
		}
		.charts {
			gap: 0.4rem;
			margin-top: 0.45rem;
		}
		.chart-card {
			padding: 0.35rem;
			border-radius: 6px;
		}
		.chart-card p {
			font-size: 0.64rem;
		}
		.shortlist-btn {
			padding: 0.35rem 0.5rem;
			font-size: 0.72rem;
		}
		.score-panel {
			display: none;
		}
	}
</style>

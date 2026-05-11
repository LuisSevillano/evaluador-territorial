<script lang="ts">
	import type { Municipio, MunicipioClimateMonthly } from '$lib/types/municipio';
	import ClimateTempLineChart from '$lib/components/charts/ClimateTempLineChart.svelte';
	import ClimatePrecipBarsChart from '$lib/components/charts/ClimatePrecipBarsChart.svelte';
	import WaterDropIcon from '$lib/components/ui/WaterDropIcon.svelte';
	import MunicipioContextCard from '$lib/components/inspector/MunicipioContextCard.svelte';
	import { buildMunicipioContext } from '$lib/components/inspector/context';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { classifyMixedScore, labelForScoreBand } from '$lib/components/map/scoreClassification';
	import {
		accessToneFromBucket,
		climateToneFromMoistureScore,
		renfeMadridToneFromScore
	} from '$lib/state/metricSemantics';
	import ReliefIndicator from '$lib/components/inspector/ReliefIndicator.svelte';
	import { DEFAULT_WEIGHTS_NORMALIZED, DEFAULT_WEIGHTS_RAW } from '$lib/state/scoring';
	import { formatScorePercent, formatSmartNumber } from '$lib/utils/numberFormat';

	type Props = {
		selectedMunicipio?: Municipio | null;
		municipios?: Municipio[];
		shortlistedIds?: string[];
		weights?: { climate: number; access: number; nature: number };
		weightsRaw?: { climateWeight: number; accessWeight: number; natureWeight: number };
		sensitivityOverlap?: number;
		climateSeries?: MunicipioClimateMonthly[];
		provinceClimateSeries?: Array<{ month: number; temp_mean_c: number }>;
		ccaaClimateSeries?: Array<{ month: number; temp_mean_c: number }>;
		isGridCell?: boolean;
		gridClimateLoading?: boolean;
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
		isGridCell = false,
		weights = DEFAULT_WEIGHTS_NORMALIZED,
		weightsRaw = DEFAULT_WEIGHTS_RAW,
		sensitivityOverlap = 0,
		climateSeries = [],
		provinceClimateSeries = [],
		ccaaClimateSeries = [],
		gridClimateLoading = false,
		onToggleShortlist = () => undefined,
		onClimateWeightChange = () => undefined,
		onAccessWeightChange = () => undefined,
		onNatureWeightChange = () => undefined,
		onPresetWeights = () => undefined,
		onClearMunicipio = () => undefined
	}: Props = $props();

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

	const renfeIsDirect = $derived(
		selectedMunicipio?.has_direct_madrid_service ??
			selectedMunicipio?.renfe_tipo_servicio === 'direct'
	);
	const renfeDist = $derived(
		selectedMunicipio?.dist_renfe_madrid_km ?? selectedMunicipio?.dist_renfe_km
	);
	const renfeDepartures = $derived(
		selectedMunicipio?.renfe_madrid_departures_avg_day ?? selectedMunicipio?.renfe_salidas_dia
	);
	const renfeScore = $derived(
		selectedMunicipio?.renfe_madrid_service_norm ?? selectedMunicipio?.servicio_renfe_norm
	);
	const renfeStatus = $derived.by(() => {
		if (selectedMunicipio?.transport_status) return selectedMunicipio.transport_status;
		if (renfeIsDirect) return 'direct_madrid';
		if (renfeDist !== undefined && renfeDist !== null && renfeDist <= 15) return 'station_nearby';
		return 'no_station';
	});
	const renfeTone = $derived(
		renfeStatus === 'direct_madrid' ? 'good' : renfeStatus === 'station_nearby' ? 'mid' : 'bad'
	);
	const renfeStatusText = $derived(
		renfeStatus === 'direct_madrid'
			? 'Tren directo a Madrid'
			: renfeStatus === 'station_nearby'
				? 'Estación de tren cercana'
				: `Estación a ${formatSmartNumber(renfeDist ?? 0)} km`
	);
	const renfeDistLabel = $derived(
		Number.isFinite(renfeDist) ? formatSmartNumber(renfeDist as number) : '-'
	);
	const renfeDeparturesLabel = $derived(
		Number.isFinite(renfeDepartures)
			? Math.round(renfeDepartures as number).toLocaleString('es-ES')
			: '-'
	);
	const renfeStationName = $derived(selectedMunicipio?.renfe_madrid_stop_name ?? '-');
	const renfeStationLoc = $derived.by(() => {
		if (!selectedMunicipio?.renfe_madrid_stop_municipality) return '';
		const stopMuni = selectedMunicipio.renfe_madrid_stop_municipality;
		const stopProv = selectedMunicipio.renfe_madrid_stop_province;
		const muniProv = selectedMunicipio.provincia_nombre_geo ?? selectedMunicipio.provincia;
		if (stopProv && stopProv !== muniProv) return `, ${stopProv}`;
		return '';
	});

	const context = $derived.by(() => {
		return buildMunicipioContext({
			selectedMunicipio,
			municipios,
			climateSeries,
			weights
		});
	});

	const mixedLegendThresholds = $derived(
		getLegendConfig('mixed_score', municipios).thresholds as number[]
	);
	const scoreLabelWithValue = $derived.by(() => {
		if (!selectedMunicipio || !Number.isFinite(selectedMunicipio.mixed_score)) return '-';
		const score = selectedMunicipio.mixed_score as number;
		const band = classifyMixedScore(score, mixedLegendThresholds);
		return `${labelForScoreBand(band)} (${formatScorePercent(score)}%)`;
	});
	const formatMetricValue = (value: number | null | undefined) =>
		Number.isFinite(value) ? formatSmartNumber(value as number) : '-';
	const formatPercentMetric = (value: number | null | undefined) =>
		Number.isFinite(value) ? `${formatSmartNumber(value as number)}%` : '-';
	const formatScoreMetric = (value: number | null | undefined) =>
		Number.isFinite(value) ? formatScorePercent(value as number) : '-';
	const waterDropCount = $derived.by(() => {
		const level = selectedMunicipio?.water_drops_level;
		if (!Number.isFinite(level)) return 0;
		return Math.max(1, Math.min(3, Math.round(level as number)));
	});
	const dropColor = $derived.by(() => {
		const tone = climateToneFromMoistureScore(selectedMunicipio?.moisture_absolute_score);
		if (tone === 'good') return '#1f7a9c';
		if (tone === 'bad') return '#c56a42';
		return '#7a9e8a';
	});
</script>

<aside class="inspector">
	<section class="panel">
		{#if selectedMunicipio}
			<div class="title-row">
				<div class="title-with-badge">
					<h3>{selectedMunicipio.nombre}</h3>
				</div>
				<button class="ghost-btn" onclick={onClearMunicipio}>Cerrar</button>
			</div>
			<p>
				{selectedMunicipio.provincia} · {selectedMunicipio.codigo}{selectedMunicipio.population
					? ` · ${selectedMunicipio.population.toLocaleString('es-ES')} hab.`
					: ''}
			</p>
			{#if isGridCell}
				<p class="grid-notice">
					<span class="grid-notice-dot" aria-hidden="true"></span>Viendo estadísticas de esta celda,
					no del municipio completo.{#if gridClimateLoading}
						<span class="grid-loading">(cargando datos climáticos...)</span>{/if}
				</p>
			{/if}
			<MunicipioContextCard
				{context}
				scoreThresholds={mixedLegendThresholds}
				relieveNorm={selectedMunicipio.relieve_norm}
			/>
			<div class="metric-grid">
				<div class="metric score">
					<span>Score mixto</span><strong>{scoreLabelWithValue}</strong>
				</div>
				<div class={`metric ${accessToneFromBucket(selectedMunicipio.travel_bucket)}`}>
					<span>Accesibilidad</span><strong>{selectedMunicipio.travel_bucket}</strong>
				</div>
				<div
					class={`metric ${climateToneFromMoistureScore(selectedMunicipio.moisture_absolute_score)}`}
				>
					<span>Precipitación</span><strong
						><WaterDropIcon count={waterDropCount} size={10} color={dropColor} />
						{selectedMunicipio.water_drops_label ?? '-'}</strong
					>
					<small>{formatMetricValue(selectedMunicipio.precip_annual_mm)} mm ·
						{formatMetricValue(selectedMunicipio.precip_summer_mm)} mm verano ·
						ventaja {formatScoreMetric(selectedMunicipio.precip_relative_score)}</small>
				</div>
				<div class="metric">
					<span>Temperatura</span><strong
						>{formatMetricValue(selectedMunicipio.temp_winter_mean_c)} /
						{formatMetricValue(selectedMunicipio.temp_summer_mean_c)} °C</strong
					>
					<small>Enero: {formatMetricValue(selectedMunicipio.temp_jan_mean_c)} / Julio: {formatMetricValue(
							selectedMunicipio.temp_jul_mean_c
						)} · Amplitud {formatMetricValue(context?.tempAmplitude)} °C</small>
				</div>
				<div class="metric">
					<span>Cobertura forestal</span><strong>{formatPercentMetric(selectedMunicipio.forest_pct)}</strong>
				</div>
				<div class="metric">
					<span>Agua y ríos</span><strong
						>{formatMetricValue(selectedMunicipio.river_nearest_distance_km)} km al río · {selectedMunicipio.river_access_class ?? '-'}</strong
					>
					<small>{selectedMunicipio.river_nearest_name ?? 'Río más cercano'} · láminas de agua {formatPercentMetric(
							selectedMunicipio.water_pct
						)}</small>
				</div>
			</div>
			<div class="transport-block">
				<div class="transport-header">TRANSPORTE</div>
				<div class={`transport-content ${renfeTone}`}>
					<div class="transport-row">
						<span class="transport-type">Tren</span>
						<span class={`transport-indicator ${renfeTone}`}></span>
						<span class="transport-status">{renfeStatusText}</span>
						{#if renfeStatus === 'direct_madrid'}
							<span class="transport-score">{formatScorePercent(renfeScore ?? 0)}%</span>
						{/if}
					</div>
					{#if renfeStationName !== '-'}
						<div class="transport-info">
							<span class="transport-station">{renfeStationName}{renfeStationLoc}</span>
							<span class="transport-dist">
								{renfeDistLabel} km (línea recta)
								{#if renfeStatus === 'direct_madrid' && renfeDeparturesLabel !== '-'}
									<span class="transport-sep">·</span>{renfeDeparturesLabel}/día
								{/if}
							</span>
						</div>
					{/if}
				</div>
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
							>Amplitud anual: {formatMetricValue(context?.tempAmplitude)} °C (más alto = estacionalidad
							más marcada).</small
						>
					{/if}
				</div>
				<div class="chart-card">
					<p>Precipitación mensual</p>
					<ClimatePrecipBarsChart data={climateSeries} />
					{#if context?.wettest && context?.driest}
						<small
							>Pico humedo mes {context.wettest.month} ({formatMetricValue(
								context.wettest.precip_mm
							)} mm) · valle seco mes {context.driest.month} ({formatMetricValue(
								context.driest.precip_mm
							)} mm).</small
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
	h3,
	p {
		margin: 0;
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
	.title-with-badge {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	.title-with-badge h3 {
		margin: 0;
	}
	.grid-notice {
		display: flex;
		align-items: flex-start;
		gap: 0.45rem;
		margin-top: 0.35rem;
		padding: 0.25rem 0.3rem;
		border-radius: 8px;
		background: rgba(254, 243, 199, 0.35);
		color: #7a4a1c;
		font-size: 0.74rem;
		line-height: 1.35;
	}
	.grid-notice-dot {
		width: 0.4rem;
		height: 0.4rem;
		margin-top: 0.3rem;
		border-radius: 999px;
		background: #d97706;
		flex: 0 0 auto;
	}
	.grid-loading {
		color: #92400e;
		font-style: italic;
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
		display: flex;
		align-items: center;
	}
	.metric-grid small {
		display: block;
		margin-top: 0.22rem;
		font-size: 0.68rem;
		line-height: 1.25;
		color: #52645f;
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
	.transport-block {
		margin-top: 0.35rem;
	}
	.transport-header {
		font-size: 0.58rem;
		font-weight: 700;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: #6b7280;
		margin-bottom: 0.2rem;
	}
	.transport-content {
		padding: 0.35rem 0.45rem;
		border: 1px solid rgba(21, 32, 33, 0.12);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.58);
	}
	.transport-content.good {
		border-color: rgba(15, 118, 110, 0.24);
		background: rgba(220, 248, 241, 0.44);
	}
	.transport-content.mid {
		border-color: rgba(180, 111, 36, 0.22);
		background: rgba(254, 243, 199, 0.42);
	}
	.transport-content.bad {
		border-color: rgba(170, 45, 45, 0.22);
		background: rgba(254, 226, 226, 0.42);
	}
	.transport-row {
		display: flex;
		align-items: center;
		gap: 0.35rem;
	}
	.transport-type {
		font-size: 0.78rem;
		font-weight: 700;
		color: #1f2937;
	}
	.transport-indicator {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex-shrink: 0;
	}
	.transport-indicator.good {
		background: #059669;
	}
	.transport-indicator.mid {
		background: #d97706;
	}
	.transport-indicator.bad {
		background: #dc2626;
	}
	.transport-status {
		flex: 1;
		font-size: 0.72rem;
		font-weight: 500;
		color: #374151;
	}
	.transport-score {
		flex: 0 0 auto;
		border-radius: 999px;
		padding: 0.06rem 0.3rem;
		background: rgba(255, 255, 255, 0.7);
		font-size: 0.62rem;
		font-weight: 700;
		color: #065f46;
	}
	.transport-info {
		margin-top: 0.22rem;
		font-size: 0.66rem;
		color: #4b5563;
	}
	.transport-station {
		font-weight: 600;
		color: #1f2937;
	}
	.transport-dist {
		display: block;
		margin-top: 0.05rem;
		color: #6b7280;
	}
	.transport-sep {
		margin: 0 0.2rem;
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
		.transport-content {
			padding: 0.28rem 0.35rem;
		}
		.transport-type {
			font-size: 0.72rem;
		}
		.transport-info {
			font-size: 0.62rem;
		}
	}
</style>

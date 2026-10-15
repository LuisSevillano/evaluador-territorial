<script lang="ts">
	import type { Municipio, MunicipioClimateMonthly, ProtectedAreaRef } from '$lib/types/municipio';
	import ClimateTempLineChart from '$lib/components/charts/ClimateTempLineChart.svelte';
	import ClimatePrecipBarsChart from '$lib/components/charts/ClimatePrecipBarsChart.svelte';
	import WaterDropIcon from '$lib/components/ui/WaterDropIcon.svelte';
	import MunicipioContextCard from '$lib/components/inspector/MunicipioContextCard.svelte';
	import { buildMunicipioContext } from '$lib/components/inspector/context';
	import { getLegendConfig } from '$lib/components/map/coloring';
	import { classifyMixedScore, labelForScoreBand } from '$lib/components/map/scoreClassification';
	import {
		type MetricTone,
		accessToneFromBucket,
		climateToneFromMoistureScore,
		renfeMadridToneFromScore
	} from '$lib/state/metricSemantics';
	import { formatTravelBucketSentence } from '$lib/state/filters';
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
				: 'Sin conexión clara con Madrid'
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
	const otpScope = $derived(selectedMunicipio?.otp_madrid_query_scope);
	const otpStatus = $derived(selectedMunicipio?.otp_madrid_transit_status);
	const otpMinutes = $derived(selectedMunicipio?.otp_madrid_transit_minutes);
	const otpStopName = $derived(selectedMunicipio?.otp_madrid_stop_name);
	const otpStopDistance = $derived(selectedMunicipio?.otp_madrid_stop_distance_m);
	const otpConfidence = $derived(selectedMunicipio?.otp_madrid_transit_confidence);
	const otpTransitModes = $derived(selectedMunicipio?.otp_madrid_transit_modes);
	const otpOriginLat = $derived(selectedMunicipio?.otp_madrid_origin_lat);
	const otpOriginLon = $derived(selectedMunicipio?.otp_madrid_origin_lon);
	const otpStopLat = $derived(selectedMunicipio?.otp_madrid_stop_lat);
	const otpStopLon = $derived(selectedMunicipio?.otp_madrid_stop_lon);
	const otpHasData = $derived(!!otpScope && otpScope !== 'out_of_scope');
	const otpMapUrl = $derived.by(() => {
		if (!otpIsRouted || !Number.isFinite(otpOriginLat) || !Number.isFinite(otpOriginLon) || !Number.isFinite(otpStopLat) || !Number.isFinite(otpStopLon)) return null;
		return `https://www.google.com/maps/dir/?api=1&origin=${otpOriginLat},${otpOriginLon}&destination=${otpStopLat},${otpStopLon}&travelmode=transit`;
	});
	const mapsSearchUrl = $derived.by(() => {
		const zoom = 15;
		if (!selectedMunicipio) return null;
		if (Number.isFinite(selectedMunicipio.lat) && Number.isFinite(selectedMunicipio.lon)) {
			return `https://www.google.com/maps/@?api=1&map_action=map&center=${selectedMunicipio.lat},${selectedMunicipio.lon}&zoom=${zoom}`;
		}
		const place = [selectedMunicipio.nombre, selectedMunicipio.provincia].filter(Boolean).join(', ');
		if (!place) return null;
		return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(place)}`;
	});
	const otpIsRouted = $derived(otpStatus === 'routed');
	const otpTone = $derived.by((): MetricTone => {
		if (!otpIsRouted || !Number.isFinite(otpMinutes)) return 'bad';
		if ((otpMinutes as number) <= 180) return 'good';
		if ((otpMinutes as number) <= 360) return 'mid';
		return 'bad';
	});
	const otpStatusText = $derived.by(() => {
		if (otpIsRouted) return 'Conexión a Madrid (Bus / Tren)';
		if (otpStatus === 'no_route') return 'Sin ruta laborable';
		return 'Sin conexión';
	});
	const otpTimeLabel = $derived.by(() => {
		if (!Number.isFinite(otpMinutes)) return '-';
		const m = otpMinutes as number;
		if (m >= 60) {
			const h = Math.floor(m / 60);
			const min = Math.round(m % 60);
			return `${h}h ${min}min`;
		}
		return `${Math.round(m)} min`;
	});
	const otpStopLabel = $derived(otpStopName ?? '-');
	const otpConfidenceLabel = $derived.by(() => {
		if (otpConfidence === 'pilot_nearest_stop') return 'parada cercana';
		return '';
	});
	const otpStopDistanceLabel = $derived.by(() => {
		if (!Number.isFinite(otpStopDistance)) return '';
		const km = ((otpStopDistance as number) / 1000).toFixed(1);
		return `a ${km} km`;
	});
	const otpModesLabel = $derived.by(() => {
		if (!otpTransitModes) return 'GTFS';
		return otpTransitModes.replaceAll(',', ' + ');
	});

	const safeParseProtectedAreas = (value: string): ProtectedAreaRef[] => {
		try {
			const parsed = JSON.parse(value) as unknown;
			if (!Array.isArray(parsed)) return [];
			return parsed.flatMap((item) => {
				if (!item || typeof item !== 'object') return [];
				const area = item as Record<string, unknown>;
				const designation = typeof area.designation === 'string' ? area.designation : '';
				const name = typeof area.name === 'string' ? area.name : '';
				return designation && name ? [{ designation, name }] : [];
			});
		} catch (_error) {
			return [];
		}
	};
	const protectedAreas = $derived.by((): ProtectedAreaRef[] => {
		const raw = selectedMunicipio?.protected_areas;
		if (!raw) return [];
		const parsed = typeof raw === 'string' ? safeParseProtectedAreas(raw) : raw;
		return parsed
			.filter((area) => area?.designation && area?.name)
			.filter(
				(area, index, rows) =>
					rows.findIndex(
						(candidate) =>
							candidate.designation === area.designation && candidate.name === area.name
					) === index
			);
	});
	const visibleProtectedAreas = $derived(protectedAreas.slice(0, 4));
	const hiddenProtectedAreasCount = $derived(
		Math.max(0, protectedAreas.length - visibleProtectedAreas.length)
	);

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
				<div class="title-actions">
					{#if mapsSearchUrl}
						<a
							class="maps-btn"
							href={mapsSearchUrl}
							target="_blank"
							rel="noopener noreferrer"
							aria-label={`Abrir ${selectedMunicipio.nombre} en Google Maps`}
							title="Abrir en Google Maps"
						>
							<img src="/icons/google-maps.png" alt="" width="16" height="16" />
						</a>
					{/if}
					<button class="ghost-btn" onclick={onClearMunicipio}>Cerrar</button>
				</div>
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
					<span>Accesibilidad</span><strong>{formatTravelBucketSentence(selectedMunicipio.travel_bucket)}</strong>
				</div>
				<div
					class={`metric ${climateToneFromMoistureScore(selectedMunicipio.moisture_absolute_score)}`}
				>
					<span>Precipitación</span><strong
						><WaterDropIcon count={waterDropCount} size={10} color={dropColor} />
						{selectedMunicipio.water_drops_label ?? '-'}</strong
					>
					<small
						>{formatMetricValue(selectedMunicipio.precip_annual_mm)} mm ·
						{formatMetricValue(selectedMunicipio.precip_summer_mm)} mm verano · ventaja {formatScoreMetric(
							selectedMunicipio.precip_relative_score
						)}</small
					>
				</div>
				<div class="metric">
					<span>Temperatura</span><strong
						>{formatMetricValue(selectedMunicipio.temp_winter_mean_c)} /
						{formatMetricValue(selectedMunicipio.temp_summer_mean_c)} °C</strong
					>
					<small
						>Enero: {formatMetricValue(selectedMunicipio.temp_jan_mean_c)} / Julio: {formatMetricValue(
							selectedMunicipio.temp_jul_mean_c
						)} · Amplitud {formatMetricValue(context?.tempAmplitude)} °C</small
					>
				</div>
				<div class="metric">
					<span>Cobertura forestal</span><strong
						>{formatPercentMetric(selectedMunicipio.forest_pct)}</strong
					>
				</div>
				<div class="metric">
					<span>Agua y ríos</span><strong
						>{formatMetricValue(selectedMunicipio.river_nearest_distance_km)} km al río · {selectedMunicipio.river_access_class ??
							'-'}</strong
					>
					<small
						>{selectedMunicipio.river_nearest_name ?? 'Río más cercano'} · láminas de agua {formatPercentMetric(
							selectedMunicipio.water_pct
						)}</small
					>
				</div>
			</div>

			<div class="transport-block">
				<div class="transport-header">TRANSPORTE</div>
				<div class={`transport-content ${renfeTone}`}>
					<div class="transport-row">
						<div class="transport-title">
							<span class="transport-type">Tren</span>
							<span class={`transport-indicator ${renfeTone}`}></span>
						</div>
						<span class="transport-status">{renfeStatusText}</span>
						{#if renfeStatus === 'direct_madrid'}
							<span class="transport-score">{formatScorePercent(renfeScore ?? 0)}%</span>
						{/if}
					</div>
					{#if renfeStatus !== 'no_station' && renfeStationName !== '-'}
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
				{#if otpHasData}
					<div class="transport-content {otpTone}">
						<div class="transport-row">
							<div class="transport-title">
								<span class="transport-type">Bus / Tren</span>
								<span class="transport-indicator {otpTone}"></span>
							</div>
							<span class="transport-status">{otpStatusText}</span>
							{#if otpIsRouted}
								<span class="transport-score">{otpTimeLabel}</span>
							{/if}
						</div>
						{#if otpIsRouted}
							<div class="transport-info">
								<div class="transport-station-line">
									<span class="transport-station">{otpStopLabel}</span>
									<span class="transport-mode-chip">{otpModesLabel}</span>
								</div>
								{#if otpConfidenceLabel || otpStopDistanceLabel}
									<span class="transport-dist">
										{otpConfidenceLabel}{#if otpConfidenceLabel && otpStopDistanceLabel} · {/if}{otpStopDistanceLabel}
									</span>
								{/if}
								{#if otpMapUrl}
									<a href={otpMapUrl} target="_blank" rel="noopener noreferrer" class="transport-gmaps">Abrir en Google Maps →</a>
								{/if}
							</div>
						{/if}
					</div>
				{/if}
			</div>
			{#if protectedAreas.length > 0}
				<div class="protected-block">
					<div class="protected-header">ZONAS PROTEGIDAS</div>
					<ul class="protected-list">
						{#each visibleProtectedAreas as area}
							<li><strong>{area.designation}:</strong> {area.name}</li>
						{/each}
					</ul>
					{#if hiddenProtectedAreasCount > 0}
						<div class="protected-more">+ {hiddenProtectedAreasCount} espacios más</div>
					{/if}
				</div>
			{/if}
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
		background: var(--sidebar-bg);
		border-left: 1px solid var(--divider-border);
		padding: var(--space-panel-lg);
		display: grid;
		gap: 0.8rem;
		box-sizing: border-box;
	}
	.panel {
		border: 1px solid var(--panel-border);
		border-radius: var(--radius-panel);
		padding: var(--space-panel-lg);
		background: var(--panel-bg);
		box-shadow: var(--shadow-soft);
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
		color: var(--text-secondary);
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
		border-radius: var(--radius-card);
		background: var(--status-warn-bg);
		color: var(--status-warn);
		font-size: 0.74rem;
		line-height: 1.35;
	}
	.grid-notice-dot {
		width: 0.4rem;
		height: 0.4rem;
		margin-top: 0.3rem;
		border-radius: var(--radius-pill);
		background: var(--status-warn);
		flex: 0 0 auto;
	}
	.grid-loading {
		color: var(--status-warn);
		font-style: italic;
	}
	.ghost-btn {
		width: auto;
		border: 1px solid var(--control-border);
		border-radius: var(--radius-pill);
		background: var(--control-bg);
		padding: 0.2rem 0.5rem;
		font-size: 0.74rem;
	}
	.title-actions {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		flex: 0 0 auto;
	}
	.maps-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 1.55rem;
		height: 1.55rem;
		border: 1px solid var(--control-border);
		border-radius: var(--radius-pill);
		background: var(--control-bg);
		transition: background-color 120ms ease, transform 120ms ease;
	}
	.maps-btn:hover {
		background: var(--control-bg-hover);
		transform: translateY(-0.5px);
	}
	.maps-btn:focus-visible {
		outline: 2px solid var(--focus-ring);
		outline-offset: 2px;
	}
	.maps-btn img {
		width: 16px;
		height: 16px;
		display: block;
	}
	.metric-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.6rem;
		margin-top: 0.7rem;
	}
	.metric-grid div {
		padding: 0.55rem;
		border-radius: var(--radius-card);
		background: var(--panel-bg-subtle);
		border: 0;
	}
	.metric.score {
		background: color-mix(in srgb, var(--brand) 9%, var(--surface));
	}
	.metric.good {
		background: var(--status-good-bg);
	}
	.metric.mid {
		background: var(--status-warn-bg);
	}
	.metric.bad {
		background: var(--status-bad-bg);
	}
	.metric-grid span {
		display: block;
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--text-muted);
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
		color: var(--text-muted);
	}
	.charts {
		display: grid;
		gap: 0.7rem;
		margin-top: 0.75rem;
	}
	.chart-card {
		border: 0;
		border-radius: var(--radius-card);
		background: var(--panel-bg-subtle);
		padding: 0.55rem;
	}
	.chart-card p {
		font-size: 0.72rem;
		letter-spacing: 0.03em;
		text-transform: uppercase;
		color: var(--text-secondary);
		margin-bottom: 0.22rem;
	}
	.chart-card small {
		display: block;
		margin-top: 0.25rem;
		font-size: 0.7rem;
		color: var(--text-secondary);
	}
	.shortlist-btn {
		margin-top: 0.6rem;
		cursor: pointer;
		border: 1px solid color-mix(in srgb, var(--brand) 28%, transparent);
		border-radius: var(--radius-pill);
		background: var(--brand);
		color: var(--text-inverse);
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
		outline: 2px solid var(--focus-ring);
		outline-offset: 2px;
	}
	.transport-block {
		margin-top: 0.35rem;
	}
	.protected-block {
		margin-top: 0.5rem;
		padding: 0.45rem 0.55rem;
		border: 0;
		border-radius: var(--radius-card);
		background: transparent;
		border-top: 1px solid var(--divider-border);
		border-radius: 0;
	}
	.protected-header {
		font-size: 0.58rem;
		font-weight: 700;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: var(--brand);
		margin-bottom: 0.25rem;
	}
	.protected-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: 0.2rem;
	}
	.protected-list li {
		font-size: 0.72rem;
		line-height: 1.28;
		color: var(--text-secondary);
	}
	.protected-list strong {
		color: var(--brand);
	}
	.protected-more {
		margin-top: 0.25rem;
		font-size: 0.66rem;
		font-weight: 700;
		color: var(--text-muted);
	}
	.transport-header {
		font-size: 0.58rem;
		font-weight: 700;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: var(--text-muted);
		margin-bottom: 0.35rem;
	}
	.transport-content {
		padding: 0.6rem 0.7rem;
		border: 1px solid transparent;
		border-radius: 0.7rem;
		background: transparent;
		box-shadow: inset 0 1px 0 color-mix(in srgb, white 45%, transparent);
	}
	.transport-content + .transport-content {
		margin-top: 0.4rem;
	}
	.transport-content.good {
		background: color-mix(in srgb, var(--status-good-bg) 58%, white 22%);
		border-color: color-mix(in srgb, var(--status-good) 18%, transparent);
	}
	.transport-content.mid {
		background: color-mix(in srgb, var(--status-warn-bg) 58%, white 22%);
		border-color: color-mix(in srgb, var(--status-warn) 18%, transparent);
	}
	.transport-content.bad {
		background: color-mix(in srgb, var(--status-bad-bg) 58%, white 22%);
		border-color: color-mix(in srgb, var(--status-bad) 16%, transparent);
	}
	.transport-row {
		display: grid;
		grid-template-columns: minmax(5rem, auto) minmax(0, 1fr) auto;
		align-items: start;
		gap: 0.55rem;
	}
	.transport-title {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		min-width: 0;
	}
	.transport-type {
		font-size: 0.82rem;
		font-weight: 700;
		color: var(--text-primary);
		line-height: 1.1;
	}
	.transport-indicator {
		width: 0.5rem;
		height: 0.5rem;
		border-radius: 50%;
		flex-shrink: 0;
		box-shadow: 0 0 0 3px color-mix(in srgb, currentColor 12%, transparent);
	}
	.transport-indicator.good {
		background: var(--status-good);
	}
	.transport-indicator.mid {
		background: var(--status-warn);
	}
	.transport-indicator.bad {
		background: var(--status-bad);
	}
	.transport-status {
		min-width: 0;
		font-size: 0.76rem;
		font-weight: 650;
		line-height: 1.22;
		color: var(--text-secondary);
	}
	.transport-score {
		flex: 0 0 auto;
		border-radius: var(--radius-pill);
		padding: 0.16rem 0.45rem;
		background: color-mix(in srgb, var(--surface) 88%, white 12%);
		font-size: 0.7rem;
		font-weight: 700;
		color: var(--brand);
		line-height: 1;
		box-shadow: 0 1px 4px color-mix(in srgb, black 5%, transparent);
	}
	.transport-info {
		margin-top: 0.45rem;
		padding-left: calc(5rem + 0.55rem);
		font-size: 0.7rem;
		line-height: 1.25;
		color: var(--text-muted);
	}
	.transport-station-line {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		flex-wrap: wrap;
	}
	.transport-station {
		font-weight: 750;
		color: var(--text-primary);
	}
	.transport-mode-chip {
		border-radius: var(--radius-pill);
		padding: 0.08rem 0.35rem;
		background: color-mix(in srgb, var(--brand) 8%, transparent);
		font-size: 0.58rem;
		font-weight: 750;
		letter-spacing: 0.04em;
		text-transform: uppercase;
		color: var(--brand);
	}
	.transport-dist {
		display: block;
		margin-top: 0.12rem;
		color: var(--text-muted);
	}
	.transport-gmaps {
		display: inline-block;
		margin-top: 0.25rem;
		font-size: 0.66rem;
		font-weight: 600;
		color: var(--brand);
		text-decoration: none;
		border: 1px solid color-mix(in srgb, var(--brand) 25%, transparent);
		border-radius: var(--radius-pill);
		padding: 0.1rem 0.45rem;
		transition: background 160ms ease;
	}
	.transport-gmaps:hover {
		background: color-mix(in srgb, var(--brand) 10%, transparent);
	}
	.transport-sep {
		margin: 0 0.2rem;
	}
	.muted {
		color: var(--text-muted);
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
		.transport-row {
			grid-template-columns: 1fr auto;
			gap: 0.3rem 0.45rem;
		}
		.transport-title {
			grid-column: 1 / -1;
		}
		.transport-info {
			padding-left: 0;
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

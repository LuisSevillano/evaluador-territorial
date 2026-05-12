<script lang="ts">
	import type { MunicipioContext } from '$lib/components/inspector/context';
	import {
		classifyMixedScore,
		labelForScoreBand,
		normalizeScoreThresholds
	} from '$lib/components/map/scoreClassification';
	import ReliefIndicator from '$lib/components/inspector/ReliefIndicator.svelte';
	import { formatScorePercent } from '$lib/utils/numberFormat';

	type Props = {
		context?: MunicipioContext | null;
		scoreThresholds?: number[];
		relieveNorm?: number;
	};

	let {
		context = null,
		scoreThresholds = [0.319, 0.354, 0.3885, 0.4283],
		relieveNorm = undefined
	}: Props = $props();

	const scoreTone = (score: number) =>
		classifyMixedScore(score, normalizeScoreThresholds(scoreThresholds));

	const scoreLabel = (score: number) => labelForScoreBand(scoreTone(score));

	const blockLabel = (key: string) => {
		if (key === 'clima') return 'Lluvia';
		if (key === 'accesibilidad') return 'Acceso';
		return 'Naturaleza';
	};

	const fitLabel = (percentile: number) => {
		if (percentile >= 75) return 'Encaje alto';
		if (percentile >= 45) return 'Encaje medio';
		return 'Encaje bajo';
	};
</script>

{#if context}
	<div class="explain-card">
		<div class="score-hero {scoreTone(context.selectedScore)}">
			<div>
				<span class="hero-label">Score global</span>
				<strong>{formatScorePercent(context.selectedScore)}%</strong>
			</div>
			<div class="hero-meta">
				<span>{scoreLabel(context.selectedScore)}</span>
				<small>Rank {context.rank}/{context.total}</small>
			</div>
		</div>
		<div class="explainer">
			<p>
				<b>{fitLabel(context.percentile)}.</b>
				{context.selectedScore >= context.globalAvg
					? ' Está por encima de la media general del atlas.'
					: ' Está por debajo de la media general del atlas.'}
			</p>
			<p>
				Posición {context.rank}/{context.total} (percentil {context.percentile.toFixed(0)}).
			</p>
			<p>
				Comparativa: {context.selectedScore >= context.provinceAvg ? 'mejor' : 'peor'} que su provincia
				y {context.selectedScore >= context.bucketAvg ? 'mejor' : 'peor'} que su grupo de accesibilidad.
			</p>
		</div>
		<div class="relief-row">
			<ReliefIndicator {relieveNorm} />
		</div>
		<div class="block-grid">
			{#each context.blockBreakdown as block}
				{@const pctAbove = block.avgRaw > 0 ? ((block.raw - block.avgRaw) / block.avgRaw) * 100 : 0}
				{@const baseWidth = Math.max(0, Math.min(100, 50 + pctAbove * 2))}
				{@const barWidth = Math.abs(pctAbove) < 0.1 ? baseWidth : Math.max(6, baseWidth)}
				<div class="block-item">
					<span>{blockLabel(block.key)}</span>
					<div class="bar-track">
						<div
							class="bar-fill"
							class:positive={pctAbove >= 0}
							class:negative={pctAbove < 0}
							style="width: {barWidth}%"
						></div>
					</div>
					<em class={pctAbove >= 0 ? 'up' : 'down'}>
						{pctAbove >= 0 ? '↑' : '↓'}
						{Math.abs(pctAbove).toFixed(0)}% vs mediana del bloque
					</em>
				</div>
			{/each}
		</div>
		<div class="drivers-grid">
			<div>
				<strong>Fortalezas</strong>
				{#if context.positiveDrivers.length > 0}
					<ul class="driver-list">
						{#each context.positiveDrivers.slice(0, 2) as driver}
							<li><b>{blockLabel(driver.key)}</b>: {driver.summary}</li>
						{/each}
					</ul>
				{:else}
					<p class="empty">No destaca claramente frente al conjunto.</p>
				{/if}
			</div>
			<div>
				<strong>Riesgos</strong>
				{#if context.negativeDrivers.length > 0}
					<ul class="driver-list">
						{#each context.negativeDrivers.slice(0, 2) as driver}
							<li><b>{blockLabel(driver.key)}</b>: {driver.summary}</li>
						{/each}
					</ul>
				{:else}
					<p class="empty">No presenta riesgos claros frente al conjunto.</p>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.relief-row {
		margin-bottom: 0.2rem;
	}

	.explain-card {
		margin-top: 0.5rem;
		padding: 0.5rem 0;
		border-radius: var(--radius-card);
		border: 0;
		background: transparent;
		border-top: 1px solid var(--divider-border);
		border-radius: 0;
		display: grid;
		gap: 0.3rem;
	}
	.explain-card p {
		margin: 0;
		font-size: 0.78rem;
		line-height: 1.35;
	}
	.score-hero {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.75rem;
		padding: 0.5rem 0.6rem;
		border-radius: var(--radius-card);
		border: 0;
		background: var(--panel-bg-subtle);
	}
	.hero-label {
		display: block;
		font-size: 0.64rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--text-muted);
	}
	.score-hero strong {
		font-size: 1.2rem;
		line-height: 1;
		font-family: 'Fraunces', serif;
	}
	.hero-meta {
		display: grid;
		justify-items: end;
		gap: 0.1rem;
	}
	.hero-meta span {
		font-size: 0.72rem;
		font-weight: 700;
	}
	.hero-meta small {
		font-size: 0.68rem;
		color: var(--text-muted);
	}
	.score-hero.very-low {
		background: var(--status-bad-bg);
	}
	.score-hero.low {
		background: color-mix(in srgb, var(--status-bad-bg) 72%, var(--surface));
	}
	.score-hero.mid {
		background: var(--status-warn-bg);
	}
	.score-hero.high {
		background: color-mix(in srgb, var(--status-good-bg) 72%, var(--surface));
	}
	.score-hero.very-high {
		background: var(--status-good-bg);
	}
	.drivers-grid {
		display: grid;
		gap: 0.4rem;
		grid-template-columns: 1fr 1fr;
	}
	.drivers-grid strong {
		font-size: 0.76rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--text-primary);
	}
	.driver-list {
		margin: 0;
		padding-left: 1rem;
		display: grid;
		gap: 0.12rem;
	}
	.driver-list li {
		font-size: 0.75rem;
		line-height: 1.3;
		color: var(--text-secondary);
	}
	.driver-list li b {
		text-transform: capitalize;
	}
	.empty {
		font-size: 0.72rem;
		color: var(--text-muted);
		margin-top: 0.18rem;
	}
	.explainer p {
		margin: 0;
	}
	.explainer {
		display: grid;
		gap: 0.5rem;
	}
	.block-grid {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 0.3rem;
	}
	.block-item {
		padding: 0.3rem;
		border-radius: var(--radius-card);
		background: var(--panel-bg-subtle);
		border: 0;
		display: grid;
		gap: 0.2rem;
	}
	.block-item > span {
		display: block;
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--text-secondary);
	}
	.block-grid em {
		display: block;
		margin-top: 0;
		font-style: normal;
		font-size: 0.7rem;
	}
	.block-grid em.up {
		color: var(--status-good);
	}
	.bar-track {
		height: 6px;
		background: color-mix(in srgb, var(--paper-2) 70%, var(--surface));
		border-radius: 3px;
		margin-top: 0.08rem;
		overflow: hidden;
	}
	.bar-fill {
		height: 100%;
		border-radius: inherit;
		display: block;
		transition: width 300ms ease;
	}
	.bar-fill.positive {
		background: var(--status-good);
	}
	.bar-fill.negative {
		background: var(--status-bad);
	}
	.block-grid em.down {
		color: var(--status-bad);
	}
	@media (max-width: 760px) {
		.drivers-grid {
			grid-template-columns: 1fr;
		}
		.block-grid {
			grid-template-columns: 1fr;
		}
	}
</style>

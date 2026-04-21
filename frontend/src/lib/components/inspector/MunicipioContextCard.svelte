<script lang="ts">
	import type { MunicipioContext } from '$lib/components/inspector/context';

	type Props = {
		context?: MunicipioContext | null;
	};

	let { context = null }: Props = $props();

	const scoreTone = (score: number) => {
		if (score <= 0.24) return 'very-low';
		if (score <= 0.3) return 'low';
		if (score <= 0.36) return 'mid';
		if (score <= 0.42) return 'high';
		return 'very-high';
	};

	const scoreLabel = (score: number) => {
		if (score <= 0.24) return 'Muy bajo';
		if (score <= 0.3) return 'Bajo';
		if (score <= 0.36) return 'Intermedio';
		if (score <= 0.42) return 'Alto';
		return 'Muy alto';
	};

	const blockLabel = (key: string) => {
		if (key === 'clima') return 'Lluvia';
		if (key === 'accesibilidad') return 'Acceso';
		return 'Naturaleza';
	};
</script>

{#if context}
	<div class="explain-card">
		<div class="score-hero {scoreTone(context.selectedScore)}">
			<div>
				<span class="hero-label">Score global</span>
				<strong>{context.selectedScore.toFixed(3)}</strong>
			</div>
			<div class="hero-meta">
				<span>{scoreLabel(context.selectedScore)}</span>
				<small>Rank {context.rank}/{context.total}</small>
			</div>
		</div>
		<div class="explainer">
			<p>
				La puntuación en este municipio impulsa mas <b>{context.topDriver.key}</b> ({context
					.topDriver.delta >= 0
					? '+'
					: ''}{context.topDriver.delta.toFixed(3)} pts) y penaliza mas
				<b>{context.mainPenalty.key}</b>
				({context.mainPenalty.delta >= 0 ? '+' : ''}{context.mainPenalty.delta.toFixed(3)} pts).
			</p>
			<p>
				Posicion {context.rank}/{context.total} ({context.percentile.toFixed(0)} percentil), score {context.selectedScore.toFixed(
					3
				)}.
			</p>
			<p>
				Comparativa: {context.selectedScore >= context.provinceAvg ? 'mejor' : 'peor'} que su provincia
				({context.provinceAvg.toFixed(3)}), {context.selectedScore >= context.bucketAvg
					? 'mejor'
					: 'peor'} que su grupo de accesibilidad ({context.bucketAvg.toFixed(3)}) y {context.selectedScore >=
				context.globalAvg
					? 'mejor'
					: 'peor'} que la media global ({context.globalAvg.toFixed(3)}).
			</p>
		</div>
		<div class="block-grid">
			{#each context.blockBreakdown as block}
				{@const pctAbove = block.avgRaw > 0 ? ((block.raw - block.avgRaw) / block.avgRaw) * 100 : 0}
				{@const barWidth = Math.max(0, Math.min(100, 50 + pctAbove * 2))}
				<div class="block-item">
					<span>{blockLabel(block.key)}</span>
					<div class="bar-track">
						<div class="bar-fill" class:positive={pctAbove >= 0} class:negative={pctAbove < 0} style="width: {barWidth}%"></div>
					</div>
					<em class={pctAbove >= 0 ? 'up' : 'down'}>
						{pctAbove >= 0 ? '↑' : '↓'} {Math.abs(pctAbove).toFixed(0)}% vs media
					</em>
				</div>
			{/each}
		</div>
		<div class="drivers-grid">
			<div>
				<strong>✅ Beneficia</strong>
				{#if context.positiveDrivers.length > 0}
					<ul class="driver-list">
						{#each context.positiveDrivers as driver}
							<li><b>{driver.key}</b>: {driver.summary}</li>
						{/each}
					</ul>
				{:else}
					<p class="empty">No hay impulso claro sobre la media.</p>
				{/if}
			</div>
			<div>
				<strong>❌ Penaliza</strong>
				{#if context.negativeDrivers.length > 0}
					<ul class="driver-list">
						{#each context.negativeDrivers as driver}
							<li><b>{driver.key}</b>: {driver.summary}</li>
						{/each}
					</ul>
				{:else}
					<p class="empty">No hay penalizacion significativa frente a la media.</p>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.explain-card {
		margin-top: 0.5rem;
		padding: 0.5rem;
		border-radius: 8px;
		border: 1px solid rgba(19, 63, 70, 0.18);
		background: rgba(234, 246, 242, 0.62);
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
		border-radius: 10px;
		border: 1px solid rgba(30, 56, 51, 0.22);
		background: rgba(255, 255, 255, 0.82);
	}
	.hero-label {
		display: block;
		font-size: 0.64rem;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #4b6461;
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
		color: #425c58;
	}
	.score-hero.very-low {
		border-color: rgba(140, 29, 24, 0.45);
		background: rgba(252, 233, 231, 0.84);
	}
	.score-hero.low {
		border-color: rgba(217, 72, 65, 0.45);
		background: rgba(255, 239, 236, 0.85);
	}
	.score-hero.mid {
		border-color: rgba(245, 159, 0, 0.42);
		background: rgba(255, 248, 227, 0.88);
	}
	.score-hero.high {
		border-color: rgba(102, 194, 74, 0.45);
		background: rgba(237, 251, 234, 0.9);
	}
	.score-hero.very-high {
		border-color: rgba(21, 128, 61, 0.45);
		background: rgba(227, 248, 232, 0.92);
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
		color: #27423f;
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
		color: #2f4542;
	}
	.driver-list li b {
		text-transform: capitalize;
	}
	.empty {
		font-size: 0.72rem;
		color: #455d5a;
		margin-top: 0.18rem;
	}
	.explainer p {
		margin-bottom: 0.5rem;
	}
	.block-grid {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 0.3rem;
	}
	.block-item {
		padding: 0.3rem;
		border-radius: 8px;
		background: rgba(248, 253, 250, 0.8);
		border: 1px solid rgba(35, 68, 64, 0.16);
		display: grid;
		gap: 0.2rem;
	}
	.block-item > span {
		display: block;
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #35514e;
	}
	.block-grid em {
		display: block;
		margin-top: 0;
		font-style: normal;
		font-size: 0.7rem;
	}
	.block-grid em.up {
		color: #0f766e;
	}
	.bar-track {
		height: 6px;
		background: rgba(209, 213, 216, 0.5);
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
		background: linear-gradient(90deg, #22c55e, #16a34a);
	}
	.bar-fill.negative {
		background: linear-gradient(90deg, #ef4444, #dc2626);
	}
	.block-grid em.down {
		color: #b91c1c;
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

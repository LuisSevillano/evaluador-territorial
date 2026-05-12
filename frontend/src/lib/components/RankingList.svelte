<script lang="ts">
	import type { Municipio } from '$lib/types/municipio';
	import { classifyMixedScore, labelForScoreBand, normalizeScoreThresholds } from '$lib/components/map/scoreClassification';
	import { formatScorePercent } from '$lib/utils/numberFormat';

	type Props = {
		rows?: Municipio[];
		limit?: number;
		onSelect?: (municipio: Municipio) => void;
		compact?: boolean;
		scoreThresholds?: number[];
	};

	let { rows = [], limit = 25, onSelect = () => undefined, compact = false, scoreThresholds = [] }: Props = $props();
	const normalizedThresholds = $derived(normalizeScoreThresholds(scoreThresholds));
	const scoreBadge = (score?: number) => {
		if (!Number.isFinite(score)) return '-';
		const band = classifyMixedScore(score as number, normalizedThresholds);
		return `${labelForScoreBand(band)} (${formatScorePercent(score as number)}%)`;
	};
</script>

<div class:compact class="rank-list">
	{#each rows.slice(0, limit) as municipio, idx (municipio.id)}
		<button class="rank-row" onclick={() => onSelect(municipio)}>
			<span class="idx">#{idx + 1}</span>
			<span>{municipio.nombre}</span>
			<small>{municipio.provincia}</small>
			<strong>{scoreBadge(municipio.mixed_score)}</strong>
		</button>
	{/each}
</div>

<style>
	.rank-list {
		display: grid;
		gap: 0;
		border-top: 1px solid var(--divider-border);
	}
	.rank-row {
		display: grid;
		grid-template-columns: auto 1fr auto;
		gap: 0.12rem 0.62rem;
		align-items: center;
		text-align: left;
		border: 0;
		border-bottom: 1px solid var(--divider-border);
		border-radius: 0;
		background: transparent;
		padding: 0.52rem 0.18rem;
		cursor: pointer;
		transition: background-color 140ms ease, color 140ms ease;
	}
	.rank-row:hover {
		background: var(--hover-bg);
	}
	.rank-row .idx {
		min-width: 2.1rem;
		font-size: 0.68rem;
		font-variant-numeric: tabular-nums;
		color: var(--text-muted);
	}
	.rank-row span {
		font-size: 0.84rem;
		font-weight: 600;
		line-height: 1.15;
	}
	.rank-row small {
		grid-column: 2;
		font-size: 0.7rem;
		color: var(--text-muted);
	}
	.rank-row strong {
		font-size: 0.76rem;
		font-weight: 700;
		color: var(--brand);
		font-variant-numeric: tabular-nums;
	}
	.rank-list.compact {
		gap: 0;
	}
	.rank-list.compact .rank-row {
		border-radius: 0;
		padding: 0.42rem 0.12rem;
		gap: 0.2rem 0.45rem;
	}
	.rank-list.compact .rank-row .idx {
		font-size: 0.68rem;
	}
	.rank-list.compact .rank-row span {
		font-size: 0.78rem;
	}
	.rank-list.compact .rank-row small {
		font-size: 0.68rem;
	}
	.rank-list.compact .rank-row strong {
		font-size: 0.75rem;
	}
</style>

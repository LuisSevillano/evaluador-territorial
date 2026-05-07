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
		gap: 0.28rem;
	}
	.rank-row {
		display: grid;
		grid-template-columns: auto 1fr auto;
		gap: 0.16rem 0.5rem;
		align-items: center;
		text-align: left;
		border: 1px solid rgba(21, 32, 33, 0.12);
		border-radius: 9px;
		background: rgba(255, 255, 255, 0.74);
		padding: 0.42rem 0.5rem;
		cursor: pointer;
	}
	.rank-row .idx {
		font-size: 0.7rem;
		color: #4a615d;
	}
	.rank-row span {
		font-size: 0.82rem;
		font-weight: 600;
		line-height: 1.1;
	}
	.rank-row small {
		grid-column: 2;
		font-size: 0.7rem;
		color: #4a615d;
	}
	.rank-row strong {
		font-size: 0.78rem;
	}
	.rank-list.compact {
		gap: 0.2rem;
	}
	.rank-list.compact .rank-row {
		border-radius: 8px;
		padding: 0.36rem 0.45rem;
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

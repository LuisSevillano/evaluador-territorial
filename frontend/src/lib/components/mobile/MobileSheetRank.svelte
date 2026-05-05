<script lang="ts">
	import RankingList from '$lib/components/RankingList.svelte';
	import type { Municipio } from '$lib/types/municipio';

	type Props = {
		rows: Municipio[];
		scoreThresholds: number[];
		onSelect: (municipio: Municipio | null) => void;
	};

	let { rows, scoreThresholds, onSelect }: Props = $props();
</script>

<div class="sheet-rank">
	<p class="sheet-meta">Top 25 en base a score mixto actual.</p>
	<RankingList rows={rows} limit={25} compact={true} onSelect={onSelect} scoreThresholds={scoreThresholds} />
</div>

<style>
	.sheet-rank {
		display: grid;
		gap: 0.2rem;
	}
</style>

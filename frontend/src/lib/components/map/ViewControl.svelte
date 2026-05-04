<script lang="ts">
	import type { MapViewMode } from '$lib/state/mapViewMode';

	type Props = {
		viewMode: MapViewMode;
		onChange: (mode: MapViewMode) => void;
	};

	let { viewMode, onChange }: Props = $props();

	const modes: { value: MapViewMode; label: string }[] = [
		{ value: 'auto', label: 'Auto' },
		{ value: 'municipality', label: 'Municipios' },
		{ value: 'grid', label: 'Rejilla' }
	];
</script>

<div class="view-control" role="group" aria-label="Modo de vista del mapa">
	{#each modes as mode}
		<button
			class="mode-btn"
			class:active={viewMode === mode.value}
			onclick={() => onChange(mode.value)}
			title={mode.label}
		>
			{mode.label}
		</button>
	{/each}
</div>

<style>
	.view-control {
		display: inline-flex;
		gap: 0;
		padding: 0.18rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.26);
		background: rgba(255, 252, 245, 0.9);
		box-shadow: 0 4px 10px rgba(16, 44, 54, 0.2);
	}

	.mode-btn {
		width: auto;
		border: 0;
		background: transparent;
		color: #3f5652;
		font-size: 0.74rem;
		font-weight: 600;
		padding: 0.34rem 0.72rem;
		border-radius: 999px;
		cursor: pointer;
		transition:
			background-color 180ms ease,
			color 180ms ease;
	}

	.mode-btn:hover {
		background: rgba(47, 125, 133, 0.14);
	}

	.mode-btn.active {
		background: #2f7d85;
		color: #f7f4ec;
	}
</style>

<script lang="ts">
	import type { MapViewMode } from '$lib/state/mapViewMode';

	type Props = {
		viewMode: MapViewMode;
		onChange: (mode: MapViewMode) => void;
	};

	let { viewMode, onChange }: Props = $props();

	const modes: { value: MapViewMode; label: string; icon: string }[] = [
		{ value: 'auto', label: 'Auto', icon: '🔄' },
		{ value: 'municipality', label: 'Municipios', icon: '🏘' },
		{ value: 'grid', label: 'Rejilla', icon: '⊞' }
	];
</script>

<div class="view-control">
	{#each modes as mode}
		<button
			class="mode-btn"
			class:active={viewMode === mode.value}
			onclick={() => onChange(mode.value)}
			title={mode.label}
		>
			<span class="icon">{mode.icon}</span>
			<span class="label">{mode.label}</span>
		</button>
	{/each}
</div>

<style>
	.view-control {
		display: flex;
		gap: 0.25rem;
		background: rgba(255, 255, 255, 0.9);
		padding: 0.25rem;
		border-radius: 8px;
		border: 1px solid rgba(21, 32, 33, 0.12);
	}

	.mode-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		border: 1px solid rgba(21, 32, 33, 0.1);
		border-radius: 6px;
		background: transparent;
		cursor: pointer;
		font-size: 0.78rem;
		color: #3f5652;
		transition: all 160ms ease;
	}

	.mode-btn:hover {
		background: rgba(238, 248, 245, 0.6);
	}

	.mode-btn.active {
		background: linear-gradient(120deg, #2f7d85, #245f66);
		color: #f7f4ec;
		border-color: #2f7d85;
	}

	.icon {
		font-size: 0.9rem;
	}

	.label {
		font-weight: 500;
	}
</style>
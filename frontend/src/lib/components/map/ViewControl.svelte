<script lang="ts">
	import type { MapViewMode } from '$lib/state/mapViewMode';

	type Props = {
		viewMode: MapViewMode;
		gridMinZoom?: number;
		currentZoom?: number;
		onChange: (mode: MapViewMode) => void;
	};

	let { viewMode, gridMinZoom = 6, currentZoom = 0, onChange }: Props = $props();

	const modes: { value: Exclude<MapViewMode, 'auto'>; label: string; title: string }[] = [
		{
			value: 'municipality',
			label: 'Municipios',
			title: 'Ver puntuaciones agregadas por municipio'
		},
		{
			value: 'grid',
			label: 'Detalle 2 km',
			title: 'Acércate más para ver la variación interna mediante celdas de 2 km'
		}
	];

	const activeMode = $derived.by(() => {
		if (viewMode === 'grid') return 'grid';
		if (viewMode === 'municipality') return 'municipality';
		// auto mode: use zoom threshold to determine active
		const gridVisible = currentZoom >= getGridMinZoom();
		return gridVisible ? 'grid' : 'municipality';
	});

	const getGridMinZoom = () => 9;
</script>

<div class="view-control" role="group" aria-label="Modo de vista del mapa">
	{#each modes as mode}
		{@const isGridDisabled = mode.value === 'grid' && gridMinZoom < 6}
		<button
			class="mode-btn"
			class:active={activeMode === mode.value}
			class:disabled={isGridDisabled}
			disabled={isGridDisabled}
			onclick={() => !isGridDisabled && onChange(mode.value)}
			title={mode.title}
		>
			{mode.label}
		</button>
	{/each}
</div>

<style>
	.view-control {
		display: inline-flex;
		gap: 0.25rem;
		padding: 0.18rem;
		border-radius: var(--radius-pill);
		border: 1px solid var(--control-border);
		background: color-mix(in srgb, var(--control-bg) 92%, transparent);
		box-shadow: var(--shadow-soft);
		backdrop-filter: blur(8px);
	}

	.mode-btn {
		width: auto;
		border: 0;
		background: transparent;
		color: var(--text-secondary);
		font-size: 0.74rem;
		font-weight: 600;
		padding: 0.34rem 0.72rem;
		border-radius: var(--radius-pill);
		cursor: pointer;
		transition:
			background-color 180ms ease,
			color 180ms ease;
	}

	.mode-btn:hover {
		background: var(--active-bg);
	}

	.mode-btn.active {
		background: var(--brand);
		color: var(--text-inverse);
	}

	.mode-btn.disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.mode-btn.disabled:hover {
		background: transparent;
	}
</style>

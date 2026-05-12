<script lang="ts">
	import ColorLegend from '$lib/components/ColorLegend.svelte';

	type LegendConfig = {
		title: string;
		thresholds: number[];
		colors: string[];
		formatLabel: (value: number) => string;
		labels?: string[];
	};

	type Props = {
		legendConfig: LegendConfig;
	};

	let { legendConfig }: Props = $props();
</script>

<div class="map-header">
	<div>
		<h3>Atlas Municipal</h3>
		<p class="intro">Compara clima, acceso y naturaleza de un vistazo.</p>
	</div>
	<div class="legend">
		<ColorLegend
			title={legendConfig.title}
			thresholds={legendConfig.thresholds}
			colors={legendConfig.colors}
			labels={legendConfig.labels ?? []}
			formatLabel={legendConfig.formatLabel}
			width={220}
		/>
	</div>
</div>

<style>
	.map-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		border: 0;
		border-radius: var(--radius-panel);
		background: color-mix(in srgb, var(--paper-2) 88%, transparent);
		backdrop-filter: blur(4px);
	}

	h3 {
		font-family: 'Fraunces', serif;
		font-size: 1.05rem;
		margin: 0;
	}

	.intro {
		margin: 0.16rem 0 0;
		font-size: 0.72rem;
		letter-spacing: 0.02em;
		color: var(--text-secondary);
	}

	.legend {
		display: flex;
		align-items: center;
		color: var(--text-primary);
	}

	@media (max-width: 900px) {
		.map-header {
			display: none;
		}
	}
</style>

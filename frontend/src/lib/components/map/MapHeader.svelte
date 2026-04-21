<script lang="ts">
	import ColorLegend from '$lib/components/ColorLegend.svelte';

	type LegendConfig = {
		title: string;
		thresholds: number[];
		colors: string[];
		formatLabel: (value: number) => string;
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
		border: 1px solid rgba(16, 44, 54, 0.25);
		border-radius: 14px;
		background: rgba(246, 240, 226, 0.88);
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
		color: #425955;
	}

	.legend {
		display: flex;
		align-items: center;
		color: #2d4240;
	}

	@media (max-width: 900px) {
		.map-header {
			display: none;
		}
	}
</style>

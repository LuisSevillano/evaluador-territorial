<script>
	import { onMount } from 'svelte';
	import { select } from 'd3-selection';
	import { scaleThreshold } from 'd3-scale';
	import { Legend } from '$lib/utils/colorLegend';
	let {
		title,
		thresholds,
		colors,
		labels = [],
		formatLabel = (value) => `${value}`,
		width = 220
	} = $props();

	let container = $state(null);

	const hasQualitativeLabels = () => Array.isArray(labels) && labels.length === colors.length;

	const render = () => {
		if (hasQualitativeLabels()) return;
		if (!container || thresholds.length + 1 !== colors.length) return;
		container.innerHTML = '';

		const color = scaleThreshold().domain(thresholds).range(colors);
		const node = Legend(color, {
			title,
			width,
			tickSize: 5,
			tickValues: thresholds,
			tickFormat: (value) => formatLabel(Number(value)),
			height: 45
		});

		select(container).append(() => node);
	};

	onMount(render);
	$effect(() => {
		render();
	});
</script>

<div class="legend-wrap">
	{#if hasQualitativeLabels()}
		<p class="legend-title">{title}</p>
		<div class="legend-scale" style={`max-width:${width}px`} role="img" aria-label={title}>
			{#each colors as color, index}
				<span class="legend-band" style={`background:${color}`} aria-hidden="true"></span>
			{/each}
		</div>
		<div class="legend-labels" style={`max-width:${width}px;--legend-label-count:${labels.length}`}>
			{#each labels as label}
				<span>{label}</span>
			{/each}
		</div>
	{:else}
		<div class="legend-svg" bind:this={container}></div>
	{/if}
</div>

<style>
	.legend-wrap {
		display: grid;
		gap: 0.2rem;
	}
	.legend-title {
		margin: 0;
		font-size: 0.62rem;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: #415753;
	}
	.legend-scale {
		display: grid;
		grid-auto-flow: column;
		grid-auto-columns: 1fr;
		height: 9px;
		border-radius: 0;
		overflow: hidden;
	}
	.legend-band {
		display: block;
		height: 100%;
	}
	.legend-labels {
		display: grid;
		grid-template-columns: repeat(var(--legend-label-count, 5), minmax(0, 1fr));
		gap: 0.2rem;
		--legend-label-count: 5;
	}
	.legend-labels span {
		font-size: 0.56rem;
		line-height: 1.15;
		color: #3f5753;
		text-align: center;
		white-space: nowrap;
	}
</style>

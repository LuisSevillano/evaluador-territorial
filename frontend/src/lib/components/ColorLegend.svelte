<script>
	import { onMount } from 'svelte';
	import { select } from 'd3-selection';
	import { scaleThreshold } from 'd3-scale';
	import { Legend } from '$lib/utils/colorLegend';
	let { title, thresholds, colors, formatLabel = (value) => `${value}`, width = 220 } = $props();

	let container;

	const render = () => {
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
	<div class="legend-svg" bind:this={container}></div>
</div>

<style>
	.legend-wrap {
		display: grid;
	}
</style>

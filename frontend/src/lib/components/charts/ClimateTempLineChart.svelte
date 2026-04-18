<script>
	import { onMount } from 'svelte';
	import { select } from 'd3-selection';
	import { scaleLinear, scalePoint } from 'd3-scale';
	import { extent } from 'd3-array';
	import { axisLeft, axisBottom } from 'd3-axis';
	import { line, curveCatmullRom } from 'd3-shape';

	let { data = [] } = $props();

	const monthLabels = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
	let el;

	const render = () => {
		if (!el) return;

		const safeData = data.filter(
			(d) => Number.isFinite(d?.month) && Number.isFinite(d?.temp_mean_c)
		);
		const width = 320;
		const height = 104;
		const margin = { top: 10, right: 8, bottom: 20, left: 24 };

		const svg = select(el);
		svg.selectAll('*').remove();

		if (safeData.length < 2) {
			svg
				.append('text')
				.attr('x', 160)
				.attr('y', 64)
				.attr('text-anchor', 'middle')
				.attr('fill', '#5b6f6c')
				.attr('font-size', 8)
				.text('Sin datos climaticos suficientes');
			return;
		}

		const x = scalePoint()
			.domain(safeData.map((d) => d.month))
			.range([margin.left, width - margin.right]);

		const y = scaleLinear()
			.domain([
				(extent(safeData, (d) => d.temp_mean_c)[0] ?? 0) - 2,
				(extent(safeData, (d) => d.temp_mean_c)[1] ?? 1) + 2
			])
			.range([height - margin.bottom, margin.top]);

		svg
			.append('g')
			.attr('transform', `translate(0,${height - margin.bottom})`)
			.call(axisBottom(x).tickFormat((d) => monthLabels[(Number(d) || 1) - 1]));

		svg.append('g').attr('transform', `translate(${margin.left},0)`).call(axisLeft(y).ticks(4));

		const path = line()
			.x((d) => x(d.month) ?? margin.left)
			.y((d) => y(d.temp_mean_c))
			.curve(curveCatmullRom.alpha(0.55));

		svg
			.append('path')
			.datum(safeData)
			.attr('fill', 'none')
			.attr('stroke', '#bb5b31')
			.attr('stroke-width', 2.25)
			.attr('d', path);
	};

	onMount(render);
	$effect(() => {
		render();
	});
</script>

<svg bind:this={el} viewBox="0 0 320 104" class="chart" aria-label="Grafico temperatura mensual"
></svg>

<style>
	.chart {
		width: 100%;
		height: auto;
	}
	:global(.chart .domain),
	:global(.chart .tick line) {
		stroke: rgba(21, 32, 33, 0.3);
	}
	:global(.chart .tick text) {
		fill: #334947;
		font-size: 8px;
	}
</style>

<script>
	import { onMount } from 'svelte';
	import { select } from 'd3-selection';
	import { scaleBand, scaleLinear } from 'd3-scale';
	import { max } from 'd3-array';
	import { axisLeft, axisBottom } from 'd3-axis';

	let { data = [] } = $props();
	let el;
	const monthLabels = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

	const render = () => {
		if (!el) return;

		const safeData = data.filter((d) => Number.isFinite(d?.month) && Number.isFinite(d?.precip_mm));
		const width = 320;
		const height = 104;
		const margin = { top: 10, right: 8, bottom: 20, left: 24 };

		const svg = select(el);
		svg.selectAll('*').remove();

		if (safeData.length === 0) {
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

		const x = scaleBand()
			.domain(safeData.map((d) => d.month))
			.range([margin.left, width - margin.right])
			.padding(0.22);

		const y = scaleLinear()
			.domain([0, max(safeData, (d) => d.precip_mm) || 1])
			.nice()
			.range([height - margin.bottom, margin.top]);

		svg
			.append('g')
			.attr('transform', `translate(0,${height - margin.bottom})`)
			.call(axisBottom(x).tickFormat((d) => monthLabels[(Number(d) || 1) - 1]));

		svg.append('g').attr('transform', `translate(${margin.left},0)`).call(axisLeft(y).ticks(4));

		svg
			.append('g')
			.selectAll('rect')
			.data(safeData)
			.join('rect')
			.attr('x', (d) => x(d.month))
			.attr('y', (d) => y(d.precip_mm))
			.attr('width', x.bandwidth())
			.attr('height', (d) => y(0) - y(d.precip_mm))
			.attr('fill', '#2f7d85')
			.attr('rx', 2);
	};

	onMount(render);
	$effect(() => {
		render();
	});
</script>

<svg bind:this={el} viewBox="0 0 320 104" class="chart" aria-label="Grafico precipitacion mensual"
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

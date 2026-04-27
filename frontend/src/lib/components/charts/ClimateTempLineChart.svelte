<script>
	import { onMount } from 'svelte';
	import { select } from 'd3-selection';
	import { scaleLinear, scalePoint } from 'd3-scale';
	import { extent } from 'd3-array';
	import { axisLeft, axisBottom } from 'd3-axis';
	import { line, area, curveCatmullRom } from 'd3-shape';

	let { data = [], provinceData = [], ccaaData = [] } = $props();

	const monthLabels = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
	let el;

	const render = () => {
		if (!el) return;

		const safeData = data.filter(
			(d) => Number.isFinite(d?.month) && Number.isFinite(d?.temp_mean_c)
		);
		const safeProvince = provinceData.filter(
			(d) => Number.isFinite(d?.month) && Number.isFinite(d?.temp_mean_c)
		);
		const safeCcaa = ccaaData.filter(
			(d) => Number.isFinite(d?.month) && Number.isFinite(d?.temp_mean_c)
		);
		const enriched = safeData.map((d) => ({
			...d,
			temp_low_c: d.temp_mean_c - 2.5,
			temp_high_c: d.temp_mean_c + 2.5
		}));
		const compareCombined = [...safeProvince, ...safeCcaa];
		const width = 320;
		const height = 104;
		const margin = { top: 10, right: 8, bottom: 20, left: 24 };

		const svg = select(el);
		svg.selectAll('*').remove();

		if (enriched.length < 2) {
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
			.domain(enriched.map((d) => d.month))
			.range([margin.left, width - margin.right]);

		const y = scaleLinear()
			.domain([
				Math.min(
					(extent(enriched, (d) => d.temp_low_c)[0] ?? 0) - 1,
					(extent(compareCombined, (d) => d.temp_mean_c)[0] ?? 0) - 1
				),
				Math.max(
					(extent(enriched, (d) => d.temp_high_c)[1] ?? 1) + 1,
					(extent(compareCombined, (d) => d.temp_mean_c)[1] ?? 1) + 1
				)
			])
			.range([height - margin.bottom, margin.top]);

		const xAxis = svg
			.append('g')
			.attr('transform', `translate(0,${height - margin.bottom})`)
			.call(axisBottom(x).tickFormat((d) => monthLabels[(Number(d) || 1) - 1]));

		const yAxis = svg.append('g').attr('transform', `translate(${margin.left},0)`).call(axisLeft(y).ticks(4));
		xAxis.select('.domain').attr('stroke', '#000000');
		xAxis.selectAll('.tick line').remove();
		yAxis
			.selectAll('.tick line')
			.attr('x2', -4)
			.attr('stroke', 'rgba(33, 52, 49, 0.7)')
			.attr('stroke-width', 0.7);
		yAxis.select('.domain').remove();

		const rangeArea = area()
			.x((d) => x(d.month) ?? margin.left)
			.y0((d) => y(d.temp_low_c))
			.y1((d) => y(d.temp_high_c))
			.curve(curveCatmullRom.alpha(0.55));

		svg
			.append('path')
			.datum(enriched)
			.attr('fill', 'rgba(187, 91, 49, 0.18)')
			.attr('stroke', 'none')
			.attr('d', rangeArea);

		const path = line()
			.x((d) => x(d.month) ?? margin.left)
			.y((d) => y(d.temp_mean_c))
			.curve(curveCatmullRom.alpha(0.55));

		const provincePath = line()
			.x((d) => x(d.month) ?? margin.left)
			.y((d) => y(d.temp_mean_c));

		const ccaaPath = line()
			.x((d) => x(d.month) ?? margin.left)
			.y((d) => y(d.temp_mean_c));

		if (safeCcaa.length > 0) {
			svg
				.append('path')
				.datum(safeCcaa)
				.attr('fill', 'none')
				.attr('stroke', '#64748b')
				.attr('stroke-width', 1.25)
				.attr('stroke-dasharray', '4 2')
				.attr('d', ccaaPath);
		}

		if (safeProvince.length > 0) {
			svg
				.append('path')
				.datum(safeProvince)
				.attr('fill', 'none')
				.attr('stroke', '#2f7d85')
				.attr('stroke-width', 1.35)
				.attr('stroke-dasharray', '3 2')
				.attr('d', provincePath);
		}

		svg
			.append('path')
			.datum(enriched)
			.attr('fill', 'none')
			.attr('stroke', '#bb5b31')
			.attr('stroke-width', 2.25)
			.attr('d', path);

			svg
				.append('g')
			.selectAll('circle')
			.data(enriched)
			.join('circle')
			.attr('cx', (d) => x(d.month) ?? margin.left)
			.attr('cy', (d) => y(d.temp_mean_c))
			.attr('r', 1.8)
				.attr('fill', '#8a3d20');

		const legend = svg.append('g').attr('transform', 'translate(28,10)');
		legend.append('line').attr('x1', 0).attr('x2', 12).attr('y1', 0).attr('y2', 0).attr('stroke', '#bb5b31').attr('stroke-width', 2);
		legend.append('text').attr('x', 14).attr('y', 2.5).attr('font-size', 7).attr('fill', '#304744').text('Municipio');
		legend.append('line').attr('x1', 58).attr('x2', 70).attr('y1', 0).attr('y2', 0).attr('stroke', '#2f7d85').attr('stroke-width', 1.3).attr('stroke-dasharray', '3 2');
		legend.append('text').attr('x', 72).attr('y', 2.5).attr('font-size', 7).attr('fill', '#304744').text('Provincia');
		legend.append('line').attr('x1', 118).attr('x2', 130).attr('y1', 0).attr('y2', 0).attr('stroke', '#64748b').attr('stroke-width', 1.2).attr('stroke-dasharray', '4 2');
		legend.append('text').attr('x', 132).attr('y', 2.5).attr('font-size', 7).attr('fill', '#304744').text('CCAA');
	};

	onMount(render);
	$effect(() => {
		render();
	});
</script>

<svg bind:this={el} viewBox="0 0 320 104" class="chart" aria-label="Gráfico de temperatura mensual"
></svg>

<style>
	.chart {
		width: 100%;
		height: auto;
	}
	:global(.chart .tick text) {
		fill: #334947;
		font-size: 8px;
	}
</style>

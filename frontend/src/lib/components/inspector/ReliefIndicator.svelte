<script lang="ts">
	import { reliefVariantFromNorm } from '$lib/state/reliefSemantics';
	import reliefFlat from './icons/relief-flat.svg?raw';
	import reliefMild from './icons/relief-mild.svg?raw';
	import reliefMountain from './icons/relief-mountain.svg?raw';
	import reliefVeryMountain from './icons/relief-very-mountain.svg?raw';

	type Props = {
		relieveNorm?: number;
	};

	let { relieveNorm }: Props = $props();

	const variant = $derived(reliefVariantFromNorm(relieveNorm));

	const svgMap = {
		flat: reliefFlat,
		mild: reliefMild,
		mountain: reliefMountain,
		'very-mountain': reliefVeryMountain
	};

	const svgContent = $derived(svgMap[variant.tone] ?? '');
</script>

<div class="relief-inline" style:--relief-color={variant.color}>
	<span class="icon-wrap">
		{@html svgContent}
	</span>
	<span class="label">{variant.label}</span>
</div>

<style>
	.relief-inline {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.2rem 0.55rem;
		border-radius: 999px;
		background: color-mix(in srgb, var(--relief-color) 8%, rgba(255, 255, 255, 0));
	}

	.icon-wrap {
		display: inline-flex;
		align-items: center;
		width: 1.1rem;
		height: 0.55rem;
		line-height: 0;
		color: var(--relief-color);
	}

	.icon-wrap :global(svg) {
		width: 100%;
		height: 100%;
	}

	.label {
		font-family: 'Fraunces', serif;
		font-size: 0.74rem;
		font-weight: 400;
		font-style: italic;
		color: #3f5652;
	}
</style>

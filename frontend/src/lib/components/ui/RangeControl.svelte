<script lang="ts">
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';

	type Variant = 'desktop' | 'sheet';

	type Props = {
		id: string;
		name?: string;
		label: string;
		value: number;
		min: number;
		max: number;
		step?: number;
		onChange: (value: number) => void;
		helpText?: string;
		variant?: Variant;
	};

	let {
		id,
		name,
		label,
		value,
		min,
		max,
		step = 1,
		onChange,
		helpText,
		variant = 'desktop'
	}: Props = $props();

	const toNumber = (event: Event) => Number((event.currentTarget as HTMLInputElement).value);
</script>

<div class={`range-control ${variant}`}>
	<div class="label-help-row">
		<label for={id}>{label}</label>
		{#if helpText}
			<FilterHelp text={helpText} />
		{/if}
	</div>
	<input
		{id}
		name={name ?? id}
		type="range"
		{min}
		{max}
		{step}
		{value}
		oninput={(event) => onChange(toNumber(event))}
	/>
</div>

<style>
	.range-control {
		display: grid;
		gap: 0.2rem;
	}

	.label-help-row {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		flex-wrap: nowrap;
	}

	.label-help-row label {
		display: inline;
		min-width: 0;
		line-height: 1.15;
		font-size: 0.74rem;
		color: var(--text-secondary);
	}

	.label-help-row :global(.help-wrap) {
		flex: 0 0 auto;
	}

	input[type='range'] {
		appearance: none;
		-webkit-appearance: none;
		margin: 0;
		width: 100%;
		height: 1.15rem;
		accent-color: var(--brand);
		cursor: pointer;
		background: transparent;
	}

	input[type='range']::-webkit-slider-runnable-track {
		height: 0.3rem;
		border-radius: var(--radius-pill);
		background: color-mix(in srgb, var(--ink) 18%, var(--surface));
		border: 1px solid color-mix(in srgb, var(--ink) 14%, transparent);
	}

	input[type='range']::-webkit-slider-thumb {
		appearance: none;
		-webkit-appearance: none;
		width: 1rem;
		height: 1rem;
		margin-top: calc((0.2rem - 1rem) / 2);
		border: 2px solid var(--surface);
		border-radius: var(--radius-pill);
		background: var(--brand);
		box-shadow: var(--shadow-soft);
	}

	input[type='range']::-moz-range-track {
		height: 0.3rem;
		border-radius: var(--radius-pill);
		background: color-mix(in srgb, var(--ink) 18%, var(--surface));
		border: 1px solid color-mix(in srgb, var(--ink) 14%, transparent);
	}

	input[type='range']::-moz-range-progress {
		height: 0.3rem;
		border-radius: var(--radius-pill);
		background: var(--brand);
	}

	input[type='range']::-moz-range-thumb {
		width: 0.86rem;
		height: 0.86rem;
		border: 2px solid var(--surface);
		border-radius: var(--radius-pill);
		background: var(--brand);
	}

	.range-control.desktop input[type='range'] {
		max-width: 150px;
		justify-self: end;
		align-self: center;
	}

	@media (max-width: 435px) {
		.range-control.sheet .label-help-row label {
			font-size: 0.6rem;
		}
	}
</style>

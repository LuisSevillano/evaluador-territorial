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
		color: #3f5753;
	}

	.label-help-row :global(.help-wrap) {
		flex: 0 0 auto;
	}

	input[type='range'] {
		margin-bottom: 0.1rem;
		width: 100%;
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

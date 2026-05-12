<script lang="ts">
	type Variant = 'ghost' | 'solid';

	type Props = {
		label: string;
		onclick?: () => void;
		type?: 'button' | 'submit' | 'reset';
		disabled?: boolean;
		variant?: Variant;
	};

	let {
		label,
		onclick = () => undefined,
		type = 'button',
		disabled = false,
		variant = 'ghost'
	}: Props = $props();
</script>

<button class={`app-btn ${variant}`} {type} {onclick} {disabled}>
	{label}
</button>

<style>
	.app-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 0.3rem 0.6rem;
		border-radius: var(--radius-pill);
		border: 1px solid var(--control-border);
		background: var(--control-bg);
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--text-primary);
		cursor: pointer;
		transition: transform 120ms ease, background-color 120ms ease;
	}

	.app-btn:hover {
		transform: translateY(-0.5px);
		background: var(--control-bg-hover);
	}

	.app-btn:focus-visible {
		outline: 2px solid var(--focus-ring);
		outline-offset: 2px;
	}

	.app-btn.solid {
		background: color-mix(in srgb, var(--brand) 14%, white);
		border-color: color-mix(in srgb, var(--brand) 38%, transparent);
		color: var(--brand);
	}

	.app-btn:disabled {
		opacity: 0.55;
		cursor: not-allowed;
		transform: none;
	}
</style>

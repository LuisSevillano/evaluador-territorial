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
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.22);
		background: rgba(255, 255, 255, 0.8);
		font-size: 0.75rem;
		font-weight: 600;
		color: #2f4743;
		cursor: pointer;
		transition: transform 120ms ease, background-color 120ms ease;
	}

	.app-btn:hover {
		transform: translateY(-1px);
		background: rgba(255, 255, 255, 0.94);
	}

	.app-btn:focus-visible {
		outline: 2px solid rgba(47, 125, 133, 0.7);
		outline-offset: 2px;
	}

	.app-btn.solid {
		background: rgba(47, 125, 133, 0.18);
		border-color: rgba(26, 79, 85, 0.38);
		color: #1d5f66;
	}

	.app-btn:disabled {
		opacity: 0.55;
		cursor: not-allowed;
		transform: none;
	}
</style>

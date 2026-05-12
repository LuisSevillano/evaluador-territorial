<script lang="ts">
	type Props = {
		label: string;
		active?: boolean;
		onclick?: () => void;
		compact?: boolean;
		size?: 'regular' | 'small';
	};

	let {
		label,
		active = false,
		onclick = () => undefined,
		compact = false,
		size = 'regular'
	}: Props = $props();
</script>

<button
	type="button"
	class={`chip-btn ${active ? 'active' : ''} ${compact ? 'compact' : ''} ${size === 'small' ? 'small' : ''}`}
	{onclick}
	aria-pressed={active}
>
	{label}
</button>

<style>
	.chip-btn {
		width: auto;
		padding: 0.28rem 0.56rem;
		border-radius: var(--radius-pill);
		border: 1px solid var(--control-border);
		background: var(--control-bg);
		color: var(--text-secondary);
		font-size: 0.72rem;
		line-height: 1.1;
		letter-spacing: 0.01em;
		cursor: pointer;
		transition:
			transform 160ms ease,
			border-color 160ms ease,
			background-color 160ms ease,
			color 160ms ease;
	}
	.chip-btn:hover {
		transform: translateY(-0.5px);
		background: var(--control-bg-hover);
		border-color: var(--control-border);
	}
	.chip-btn:focus-visible {
		outline: 2px solid var(--focus-ring);
		outline-offset: 2px;
	}
	.chip-btn.active {
		background: var(--active-bg);
		color: var(--brand);
		border-color: color-mix(in srgb, var(--brand) 36%, transparent);
		font-weight: 600;
	}
	.chip-btn.compact {
		padding-left: 0;
		padding-right: 0;
		justify-content: center;
		text-align: center;
	}
	.chip-btn.small {
		padding: 0.24rem 0.42rem;
		font-size: 0.68rem;
	}
</style>

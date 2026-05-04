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
		padding: 0.3rem 0.55rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.2);
		background: rgba(255, 255, 255, 0.72);
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
		transform: translateY(-1px);
		border-color: #2f7d85;
	}
	.chip-btn:focus-visible {
		outline: 2px solid #2f7d85;
		outline-offset: 2px;
	}
	.chip-btn.active {
		background: #2f7d85;
		color: #f5f4ef;
		border-color: #1f5f66;
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

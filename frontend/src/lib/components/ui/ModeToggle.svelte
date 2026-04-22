<script lang="ts">
	type Mode = 'exploracion' | 'evaluacion';

	type Props = {
		mode?: Mode;
		onChange?: (mode: Mode) => void;
	};

	let { mode = 'exploracion', onChange = () => undefined }: Props = $props();
</script>

<div class="mode-toggle" role="tablist" aria-label="Modo de uso">
	<button
		type="button"
		role="tab"
		aria-selected={mode === 'exploracion'}
		class:active={mode === 'exploracion'}
		onclick={() => onChange('exploracion')}
	>
		Exploración
	</button>
	<button
		type="button"
		role="tab"
		aria-selected={mode === 'evaluacion'}
		class:active={mode === 'evaluacion'}
		onclick={() => onChange('evaluacion')}
	>
		Evaluación
	</button>
</div>

<style>
	.mode-toggle {
		display: inline-flex;
		gap: 0;
		padding: 0.18rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.26);
		width: fit-content;
	}
	button {
		width: auto;
		border: 0;
		border-radius: 999px;
		background: transparent;
		padding: 0.34rem 0.8rem;
		min-width: 108px;
		font-size: 0.76rem;
		font-weight: 600;
		color: #3f5652;
		cursor: pointer;
		transition:
			background-color 180ms ease,
			color 180ms ease;
	}
	button.active {
		background: #2f7d85;
		color: #f7f4ec;
	}
</style>

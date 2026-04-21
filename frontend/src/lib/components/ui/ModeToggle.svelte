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
		Exploracion
	</button>
	<button
		type="button"
		role="tab"
		aria-selected={mode === 'evaluacion'}
		class:active={mode === 'evaluacion'}
		onclick={() => onChange('evaluacion')}
	>
		Evaluacion
	</button>
</div>

<style>
	.mode-toggle {
		display: inline-flex;
		gap: 0.25rem;
		padding: 0.2rem;
		border-radius: 999px;
		border: 1px solid rgba(21, 32, 33, 0.2);
		background: rgba(255, 252, 245, 0.8);
	}
	button {
		width: auto;
		border: 0;
		border-radius: 999px;
		background: transparent;
		padding: 0.32rem 0.7rem;
		font-size: 0.76rem;
		font-weight: 600;
		color: #3f5652;
		cursor: pointer;
	}
	button.active {
		background: #2f7d85;
		color: #f7f4ec;
	}
</style>

<script lang="ts">
	type PaletteItem = { key: string; color: string; label: string };

	type Props = {
		palette?: PaletteItem[];
	};

	let { palette = [] }: Props = $props();
</script>

<div class="landuse-legend">
	<strong>Usos del suelo</strong>
	<div>
		{#each palette as item}
			<span><i style={`background:${item.color}`}></i>{item.label}</span>
		{/each}
	</div>
</div>

<style>
	.landuse-legend {
		position: absolute;
		bottom: 1.35rem;
		left: 1.55rem;
		z-index: 18;
		padding: 0.55rem 0.7rem;
		background: color-mix(in srgb, var(--panel-bg-strong) 94%, transparent);
		border: 1px solid var(--control-border);
		border-radius: var(--radius-card);
		box-shadow: var(--shadow-soft);
		backdrop-filter: blur(8px);
		display: grid;
		gap: 0.25rem;
	}

	.landuse-legend strong {
		font-size: 0.72rem;
		letter-spacing: 0.04em;
		text-transform: uppercase;
		color: var(--text-primary);
	}

	.landuse-legend div {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem 0.5rem;
		font-size: 0.72rem;
	}

	.landuse-legend span {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		color: var(--text-secondary);
	}

	i {
		display: inline-block;
		width: 0.65rem;
		height: 0.65rem;
		border-radius: 2px;
		border: 1px solid var(--divider-border);
	}
</style>

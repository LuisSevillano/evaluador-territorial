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
		background: rgba(248, 246, 240, 0.94);
		border: 1px solid rgba(18, 40, 44, 0.22);
		border-radius: 10px;
		display: grid;
		gap: 0.25rem;
	}

	.landuse-legend strong {
		font-size: 0.72rem;
		letter-spacing: 0.04em;
		text-transform: uppercase;
		color: #2d4240;
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
		color: #3a4f4c;
	}

	i {
		display: inline-block;
		width: 0.65rem;
		height: 0.65rem;
		border-radius: 2px;
		border: 1px solid rgba(0, 0, 0, 0.22);
	}
</style>

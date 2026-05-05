<script lang="ts">
	import { BarChart3, Info, Layers, MapPin, SlidersHorizontal } from 'lucide-svelte';

	type SheetTab = 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';
	type Props = {
		activeSheetTab: SheetTab;
		selectedName?: string | null;
		onSelect: (tab: SheetTab) => void;
	};

	let { activeSheetTab, selectedName = null, onSelect }: Props = $props();
</script>

<div class="sheet-tabs" role="tablist" aria-label="Panel móvil">
	<button class:active={activeSheetTab === 'sel'} class:has-selection={Boolean(selectedName)} onclick={() => onSelect('sel')} aria-label={selectedName ? `Selección activa: ${selectedName}` : 'Selección'}>
		<MapPin size={16} />Sel.
	</button>
	<button class:active={activeSheetTab === 'filtr'} onclick={() => onSelect('filtr')}><SlidersHorizontal size={16} />Filtros</button>
	<button class:active={activeSheetTab === 'capas'} onclick={() => onSelect('capas')}><Layers size={16} />Capas</button>
	<button class:active={activeSheetTab === 'rank'} onclick={() => onSelect('rank')}><BarChart3 size={16} />Rank</button>
	<button class:active={activeSheetTab === 'meta'} onclick={() => onSelect('meta')}><Info size={16} />Meta</button>
</div>

<style>
	.sheet-tabs {
		display: grid;
		grid-template-columns: repeat(5, minmax(0, 1fr));
		gap: 0.25rem;
		position: sticky;
		top: 0;
		padding: 0.2rem 0 0.45rem;
		background: linear-gradient(180deg, rgba(252, 248, 238, 0.98), rgba(248, 242, 226, 0.96));
		z-index: 2;
	}
	.sheet-tabs button {
		border: 0;
		border-radius: 8px;
		padding: 0.4rem 0.2rem;
		font-size: 0.68rem;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.22rem;
		background: transparent;
		color: #3d5551;
	}
	.sheet-tabs button :global(svg) {
		width: 15px;
		height: 15px;
	}
	.sheet-tabs button.active {
		background: rgba(47, 125, 133, 0.14);
		color: #2f7d85;
		font-weight: 600;
	}
	.sheet-tabs button.has-selection {
		position: relative;
	}
	.sheet-tabs button.has-selection::after {
		content: '';
		position: absolute;
		top: 0.22rem;
		right: 0.35rem;
		width: 0.42rem;
		height: 0.42rem;
		border-radius: 999px;
		background: #2f7d85;
		box-shadow: 0 0 0 2px rgba(252, 248, 238, 0.95);
	}
</style>

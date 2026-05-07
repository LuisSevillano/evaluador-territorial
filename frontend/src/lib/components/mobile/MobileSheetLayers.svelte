<script lang="ts">
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';
	import type { MapColorMetric } from '$lib/components/map/coloring';

	type LayerItem = { key: string; label: string; visible: boolean };
	type Props = {
		mapColorMetric: MapColorMetric;
		layerItems: LayerItem[];
		showIgnWmsBase: boolean;
		showIgnSatellite: boolean;
		onMapColorMetricChange: (value: MapColorMetric) => void;
		onToggleLayer: (key: string, checked: boolean) => void;
		onLayerOrderChange: (next: string[]) => void;
		onToggleIgnWmsBase: (checked: boolean) => void;
		onToggleIgnSatellite: (checked: boolean) => void;
	};

	let props: Props = $props();
</script>

<div class="sheet-block">
	<p class="sheet-subtitle sheet-subtitle-help">Color municipal <FilterHelp text={FILTER_HELP.mapColor} /></p>
	<div class="chips-row">
		<ChipButton label="Puntuacion global" active={props.mapColorMetric === 'mixed_score'} onclick={() => props.onMapColorMetricChange('mixed_score')} />
		<ChipButton label="Precipitacion" active={props.mapColorMetric === 'precip_annual_mm'} onclick={() => props.onMapColorMetricChange('precip_annual_mm')} />
		<ChipButton label="Tiempo de desplazamiento" active={props.mapColorMetric === 'travel_bucket'} onclick={() => props.onMapColorMetricChange('travel_bucket')} />
		<ChipButton label="Transporte OSM" active={props.mapColorMetric === 'transporte_norm'} onclick={() => props.onMapColorMetricChange('transporte_norm')} />
		<ChipButton label="Renfe a Madrid" active={props.mapColorMetric === 'servicio_renfe_norm'} onclick={() => props.onMapColorMetricChange('servicio_renfe_norm')} />
		<ChipButton label="Acceso a bano" active={props.mapColorMetric === 'river_access_score'} onclick={() => props.onMapColorMetricChange('river_access_score')} />
	</div>
	<LayerOrderList items={props.layerItems} onToggle={props.onToggleLayer} onReorder={props.onLayerOrderChange} />
	<label><input type="checkbox" checked={props.showIgnWmsBase} onchange={(e) => props.onToggleIgnWmsBase((e.currentTarget as HTMLInputElement).checked)} /> Base IGN</label>
	<label><input type="checkbox" checked={props.showIgnSatellite} onchange={(e) => props.onToggleIgnSatellite((e.currentTarget as HTMLInputElement).checked)} /> Satelite IGN</label>
</div>

<style>
	.sheet-block {
		display: grid;
		gap: 0.45rem;
	}
	.sheet-block label {
		font-size: 0.75rem;
		color: #3f5753;
	}
	.sheet-subtitle {
		margin: 0.3rem 0 0.05rem;
		font-size: 0.7rem;
		font-weight: 700;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: #3d5551;
	}
	.sheet-subtitle-help {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		white-space: nowrap;
	}
	.sheet-subtitle-help :global(.help-wrap) {
		flex: 0 0 auto;
	}
	@media (max-width: 435px) {
		.sheet-subtitle-help {
			font-size: 0.68rem;
		}
	}
	.chips-row {
		display: flex;
		flex-wrap: wrap;
		column-gap: 0.25rem;
		row-gap: 0.25rem;
	}
</style>

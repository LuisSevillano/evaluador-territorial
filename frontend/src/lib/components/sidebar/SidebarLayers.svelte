<script lang="ts">
	import type { MapColorMetric } from '$lib/components/map/coloring';
	import ChipButton from '$lib/components/ui/ChipButton.svelte';
	import FilterHelp from '$lib/components/ui/FilterHelp.svelte';
	import LayerOrderList from '$lib/components/layers/LayerOrderList.svelte';
	import { FILTER_HELP } from '$lib/state/filterHelp';

	type LayerItem = {
		key: string;
		label: string;
		visible: boolean;
	};

	type Props = {
		mapColorMetric?: MapColorMetric;
		layerItems?: LayerItem[];
		showIgnWmsBase?: boolean;
		showIgnSatellite?: boolean;
		onMapColorMetricChange?: (value: MapColorMetric) => void;
		onLayerOrderChange?: (value: string[]) => void;
		onToggleLayerVisibility?: (layerKey: string, checked: boolean) => void;
		onToggleIgnWmsBase?: (value: boolean) => void;
		onToggleIgnSatellite?: (value: boolean) => void;
	};

	let {
		mapColorMetric = 'mixed_score',
		layerItems = [],
		showIgnWmsBase = false,
		showIgnSatellite = false,
		onMapColorMetricChange = () => undefined,
		onLayerOrderChange = () => undefined,
		onToggleLayerVisibility = () => undefined,
		onToggleIgnWmsBase = () => undefined,
		onToggleIgnSatellite = () => undefined
	}: Props = $props();

	const toggleLayerVisibility = (layerKey: string, checked: boolean) => {
		onToggleLayerVisibility(layerKey, checked);
	};
</script>

<section class="panel">
	<h2>Capas</h2>
	<div class="layers">
		<p class="control-title control-title-help">Color municipal <FilterHelp text={FILTER_HELP.mapColor} /></p>
		<div class="chips-wrap compact">
			<ChipButton label="Puntuacion global" active={mapColorMetric === 'mixed_score'} onclick={() => onMapColorMetricChange('mixed_score')} />
			<ChipButton label="Precipitacion" active={mapColorMetric === 'precip_annual_mm'} onclick={() => onMapColorMetricChange('precip_annual_mm')} />
			<ChipButton label="Tiempo de desplazamiento" active={mapColorMetric === 'travel_bucket'} onclick={() => onMapColorMetricChange('travel_bucket')} />
			<ChipButton label="Transporte OSM" active={mapColorMetric === 'transporte_norm'} onclick={() => onMapColorMetricChange('transporte_norm')} />
			<ChipButton label="Servicio Renfe" active={mapColorMetric === 'servicio_renfe_norm'} onclick={() => onMapColorMetricChange('servicio_renfe_norm')} />
			<ChipButton label="Acceso a bano" active={mapColorMetric === 'river_access_score'} onclick={() => onMapColorMetricChange('river_access_score')} />
		</div>
		<p class="muted">Arrastra para cambiar el orden de pintado (arriba = se pinta encima).</p>
		<LayerOrderList items={layerItems} onToggle={toggleLayerVisibility} onReorder={onLayerOrderChange} />
		<label><input type="checkbox" checked={showIgnWmsBase} onchange={(e) => onToggleIgnWmsBase((e.currentTarget as HTMLInputElement).checked)} /><span>Base IGN WMS</span></label>
		<label><input type="checkbox" checked={showIgnSatellite} onchange={(e) => onToggleIgnSatellite((e.currentTarget as HTMLInputElement).checked)} /><span>Satelite IGN (PNOA)</span></label>
	</div>
</section>

<style>
	section.panel {
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		padding: 0.8rem;
		background: rgba(255, 255, 255, 0.62);
	}
	h2 {
		font-family: 'Fraunces', serif;
		font-size: 1rem;
		margin: 0 0 0.5rem 0;
	}
	h2, p {
		margin: 0;
	}
	.control-title {
		margin: 0;
		font-size: 0.78rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #405753;
	}
	.control-title-help {
		display: inline-flex;
		align-items: center;
		gap: 0.32rem;
		flex-wrap: wrap;
	}
	.chips-wrap {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		margin-top: 0.25rem;
	}
	.chips-wrap.compact {
		gap: 0.3rem;
	}
	.layers {
		display: grid;
		gap: 0rem;
		margin-bottom: 0.75rem;
		gap: 0.45rem;
	}
	.layers label {
		display: flex;
		gap: 0.45rem;
		align-items: center;
		font-size: 0.8rem;
	}
	.muted {
		color: #48615d;
		font-size: 0.76rem;
		line-height: 1.35;
		margin: 0;
	}
</style>
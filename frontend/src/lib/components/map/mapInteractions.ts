import type maplibregl from 'maplibre-gl';
import type { Municipio } from '$lib/types/municipio';
import { normalizeProvinceName } from '$lib/state/provinces';

type HoverSetter = (
	nextId: string | number | null,
	source?: string,
	sourceLayer?: string
) => void;

type RegisterParams = {
	map: maplibregl.Map;
	municipios: Municipio[];
	allMunicipios?: Municipio[];
	onMapSelection: (municipio: Municipio | null) => void;
	municipiosPolygonsFillLayerId: string;
	gridFillLayerId: string;
	gridLineLayerId: string;
	gridPmtilesSourceId: string;
	getHoveredFeatureId: () => string | number | null;
	setHoverFeatureState: HoverSetter;
};

const buildCellAsMunicipio = (props: any, sourceMunicipios: Municipio[]): Municipio | null => {
	if (!props?.cell_id) return null;
	const parentMunicipio = sourceMunicipios.find((m) => String(m.codigo ?? m.id) === String(props.municipio_id));
	const parentProvince = normalizeProvinceName(
		((parentMunicipio as any)?.provincia_nombre_geo ?? parentMunicipio?.provincia ?? props.provincia) as string
	);

	return {
		id: props.cell_id,
		codigo: props.municipio_id,
		nombre: props.municipio_nombre,
		provincia: parentProvince,
		population: undefined,
		mixed_score: props.mixed_score,
		precip_annual_mm: props.precip_annual ?? props.precip_annual_mm,
		temp_winter_mean_c: props.temp_winter,
		temp_summer_mean_c: props.temp_summer,
		temp_jan_mean_c: props.temp_winter,
		temp_jul_mean_c: props.temp_summer,
		travel_bucket: props.isochrone_bucket,
		forest_pct: props.natural_cover_pct,
		water_pct: undefined,
		artificial_pct: undefined,
		naturality_index: undefined,
		landcover_diversity: undefined,
		forest_norm: undefined,
		water_norm: undefined,
		artificial_norm: undefined,
		naturality_norm: props.natural_cover_norm,
		diversity_norm: undefined,
		river_access_norm: props.river_access_norm,
		river_access_score: props.river_access_score,
		river_access_class: props.river_buffer_class,
		river_nearest_name: undefined,
		river_nearest_distance_km: props.river_distance_km,
		climate_block_score: props.climate_block_score,
		access_block_score: props.access_block_score,
		nature_block_score: props.nature_block_score,
		dist_estacion_tren_km: undefined,
		dist_parada_bus_km: undefined,
		transporte_norm: props.accesibilidad_norm,
		dist_renfe_km: undefined,
		renfe_salidas_dia: undefined,
		renfe_tipo_servicio: undefined,
		servicio_renfe_norm: props.accesibilidad_norm,
		relieve_norm: 0.5,
		relieve_score_raw: undefined,
		iso_01h30m: props.isochrone_bucket === '<=1h30',
		iso_02h00m: props.isochrone_bucket === '<=2h00',
		iso_02h30m: props.isochrone_bucket === '<=2h30',
		iso_03h30m: props.isochrone_bucket === '<=3h30',
		iso_04h00m: props.isochrone_bucket === '<=4h00',
		precip_norm: props.precip_norm,
		temp_verano_norm: props.temp_verano_norm,
		temp_invierno_norm: props.temp_invierno_norm,
		accesibilidad_norm: props.accesibilidad_norm
	} as unknown as Municipio;
};

export const registerMapInteractions = ({
	map,
	municipios,
	allMunicipios,
	onMapSelection,
	municipiosPolygonsFillLayerId,
	gridFillLayerId,
	gridLineLayerId,
	gridPmtilesSourceId,
	getHoveredFeatureId,
	setHoverFeatureState
}: RegisterParams) => {
	map.on('click', (event) => {
		const gridHits = map.queryRenderedFeatures(event.point, { layers: [gridFillLayerId, gridLineLayerId] });
		if (gridHits.length > 0) {
			const sourceMunicipios = (allMunicipios && allMunicipios.length > 0 ? allMunicipios : municipios) as Municipio[];
			const cellAsMunicipio = buildCellAsMunicipio(gridHits[0].properties, sourceMunicipios);
			if (cellAsMunicipio) onMapSelection(cellAsMunicipio);
			return;
		}

		const hits = map.queryRenderedFeatures(event.point, { layers: [municipiosPolygonsFillLayerId] });
		if (hits.length === 0) onMapSelection(null);
	});

	map.on('mouseenter', municipiosPolygonsFillLayerId, () => {
		map.getCanvas().style.cursor = 'pointer';
	});

	map.on('mousemove', municipiosPolygonsFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
		const feature = e.features?.[0];
		const nextHoveredId = feature ? (feature.id ?? feature.properties?.id ?? feature.properties?.codigo ?? null) : null;
		if (nextHoveredId === getHoveredFeatureId()) return;
		setHoverFeatureState(nextHoveredId);
	});

	map.on('mouseleave', municipiosPolygonsFillLayerId, () => {
		map.getCanvas().style.cursor = '';
		setHoverFeatureState(null);
	});

	map.on('mouseenter', gridFillLayerId, () => {
		map.getCanvas().style.cursor = 'pointer';
	});

	map.on('mousemove', gridFillLayerId, (e: maplibregl.MapLayerMouseEvent) => {
		const feature = e.features?.[0];
		const nextHoveredId = feature ? (feature.properties?.cell_id ?? null) : null;
		if (nextHoveredId === getHoveredFeatureId()) return;
		setHoverFeatureState(nextHoveredId, gridPmtilesSourceId, 'grid');
	});

	map.on('mouseleave', gridFillLayerId, () => {
		map.getCanvas().style.cursor = '';
		setHoverFeatureState(null, gridPmtilesSourceId, 'grid');
	});
};

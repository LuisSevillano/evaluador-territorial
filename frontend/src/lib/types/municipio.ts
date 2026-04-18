export type Municipio = {
	id: string;
	codigo: string;
	nombre: string;
	provincia: string;
	lat: number;
	lon: number;
	precip_annual_mm: number;
	temp_winter_mean_c: number;
	temp_summer_mean_c: number;
	temp_jan_mean_c: number;
	temp_jul_mean_c: number;
	iso_01h30m: boolean;
	iso_02h00m: boolean;
	iso_02h30m: boolean;
	iso_03h30m: boolean;
	iso_04h00m: boolean;
	travel_bucket: string;
	precip_norm?: number;
	temp_verano_norm?: number;
	temp_invierno_norm?: number;
	accesibilidad_norm?: number;
};

export type MunicipioClimateMonthly = {
	id: string;
	nombre: string;
	provincia: string;
	month: number;
	temp_mean_c: number;
	precip_mm: number;
};

export type DatasetMetadata = {
	dataset_version: string;
	generated_at_utc: string;
	analysis_scope: string;
	climate_source: string;
	climate_period: string;
	aggregation_method: string;
	isochrones_definition: string;
};

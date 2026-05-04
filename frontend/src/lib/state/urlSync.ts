import { buildUrlState, parseUrlState, type SheetTab } from '$lib/state/urlState';
import { clampNumber, type TravelBucketFilter } from '$lib/state/filters';

type SyncState = {
	mapViewMode: 'auto' | 'municipality' | 'grid';
	query: string;
	provinceFilter: string;
	maxTravelBucket: TravelBucketFilter;
	minPrecipAnnual: number;
	minWinterTemp: number;
	maxSummerTemp: number;
	maxThermalAmplitude: number;
	maxThermalAmplitudeDefault: number;
	minCompositeScore: number;
	climateWeight: number;
	accessWeight: number;
	natureWeight: number;
	activeSheetTab: SheetTab;
	isMobileView: boolean;
	isBottomSheetOpen: boolean;
	selectedMunicipioId?: string;
};

export const applyUrlToState = (search: string, current: SyncState) => {
	const parsed = parseUrlState(search);
	const next: Partial<SyncState> = {};

	if (parsed.mapView) next.mapViewMode = parsed.mapView;
	if (parsed.q) next.query = parsed.q;
	if (parsed.province) next.provinceFilter = parsed.province;
	if (parsed.travel) next.maxTravelBucket = parsed.travel;

	if (parsed.ppt !== undefined) next.minPrecipAnnual = clampNumber(parsed.ppt, 0, 1800);
	if (parsed.tw !== undefined) next.minWinterTemp = clampNumber(parsed.tw, -15, 15);
	if (parsed.ts !== undefined) next.maxSummerTemp = clampNumber(parsed.ts, 15, 40);
	if (parsed.ta !== undefined) next.maxThermalAmplitude = clampNumber(parsed.ta, 12, 40);
	if (parsed.score !== undefined) next.minCompositeScore = clampNumber(parsed.score, 0, 1);

	if (parsed.clima !== undefined) next.climateWeight = clampNumber(parsed.clima, 0, 100);
	if (parsed.accesibilidad !== undefined)
		next.accessWeight = clampNumber(parsed.accesibilidad, 0, 100);
	if (parsed.naturaleza !== undefined) next.natureWeight = clampNumber(parsed.naturaleza, 0, 100);

	if (parsed.tab) next.activeSheetTab = parsed.tab;

	if (parsed.open && current.isMobileView) next.isBottomSheetOpen = true;

	return {
		next,
		pendingSelectedMunicipioId: parsed.sel ?? null
	};
};

export const buildUrlFromState = (state: SyncState) =>
	buildUrlState({
		q: state.query.trim().length > 0 ? state.query.trim() : undefined,
		province: state.provinceFilter !== 'Todas' ? state.provinceFilter : undefined,
		travel: state.maxTravelBucket !== null && state.maxTravelBucket !== '>4h00' ? state.maxTravelBucket : undefined,
		ppt: state.minPrecipAnnual !== 0 ? state.minPrecipAnnual : undefined,
		tw: state.minWinterTemp !== -10 ? state.minWinterTemp : undefined,
		ts: state.maxSummerTemp !== 40 ? state.maxSummerTemp : undefined,
		ta:
			state.maxThermalAmplitude !== state.maxThermalAmplitudeDefault
				? Number(state.maxThermalAmplitude.toFixed(1))
				: undefined,
		score: state.minCompositeScore > 0 ? state.minCompositeScore : undefined,
		clima: state.climateWeight,
		accesibilidad: state.accessWeight,
		naturaleza: state.natureWeight,
		mapView: state.mapViewMode !== 'auto' ? state.mapViewMode : undefined,
		tab: state.isMobileView && state.activeSheetTab !== 'filtr' ? state.activeSheetTab : undefined,
		sel: state.selectedMunicipioId,
		open: state.isMobileView ? state.isBottomSheetOpen : undefined
	});
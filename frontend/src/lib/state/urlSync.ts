import { buildUrlState, parseUrlState } from '$lib/state/urlState';
import { clampNumber } from '$lib/state/filters';
import { tabForMode } from '$lib/state/viewMode';

type SyncState = {
	viewMode: 'exploracion' | 'evaluacion';
	query: string;
	provinceFilter: string;
	maxTravelBucket: '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';
	minPrecipAnnual: number;
	minWinterTemp: number;
	maxSummerTemp: number;
	maxThermalAmplitude: number;
	maxThermalAmplitudeDefault: number;
	minCompositeScore: number;
	climateWeight: number;
	accessWeight: number;
	natureWeight: number;
	activeSheetTab: 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';
	isMobileView: boolean;
	isBottomSheetOpen: boolean;
	selectedMunicipioId?: string;
};

export const applyUrlToState = (search: string, current: SyncState) => {
	const parsed = parseUrlState(search);
	const next: Partial<SyncState> = {};

	if (parsed.mode) next.viewMode = parsed.mode;
	if (parsed.q) next.query = parsed.q;
	if (parsed.province) next.provinceFilter = parsed.province;
	if (parsed.travel) next.maxTravelBucket = parsed.travel;

	if (parsed.ppt !== undefined) next.minPrecipAnnual = clampNumber(parsed.ppt, 0, 1800);
	if (parsed.tw !== undefined) next.minWinterTemp = clampNumber(parsed.tw, -15, 15);
	if (parsed.ts !== undefined) next.maxSummerTemp = clampNumber(parsed.ts, 15, 40);
	if (parsed.ta !== undefined) next.maxThermalAmplitude = clampNumber(parsed.ta, 12, 40);
	if (parsed.score !== undefined) next.minCompositeScore = clampNumber(parsed.score, 0, 1);

	if (parsed.cw !== undefined) next.climateWeight = clampNumber(parsed.cw, 0, 100);
	if (parsed.aw !== undefined) next.accessWeight = clampNumber(parsed.aw, 0, 100);
	if (parsed.nw !== undefined) next.natureWeight = clampNumber(parsed.nw, 0, 100);

	if (parsed.tab) {
		next.activeSheetTab = tabForMode(
			parsed.mode ?? current.viewMode,
			parsed.tab,
			current.isMobileView,
			Boolean(parsed.sel)
		);
	}

	if (parsed.open && current.isMobileView) next.isBottomSheetOpen = true;

	return {
		next,
		pendingSelectedMunicipioId: parsed.sel ?? null
	};
};

export const buildUrlFromState = (state: SyncState) =>
	buildUrlState({
		mode: state.viewMode,
		q: state.query.trim().length > 0 ? state.query.trim() : undefined,
		province: state.provinceFilter !== 'Todas' ? state.provinceFilter : undefined,
		travel: state.maxTravelBucket !== '>4h00' ? state.maxTravelBucket : undefined,
		ppt: state.minPrecipAnnual !== 0 ? state.minPrecipAnnual : undefined,
		tw: state.minWinterTemp !== -10 ? state.minWinterTemp : undefined,
		ts: state.maxSummerTemp !== 40 ? state.maxSummerTemp : undefined,
		ta:
			state.maxThermalAmplitude !== state.maxThermalAmplitudeDefault
				? Number(state.maxThermalAmplitude.toFixed(1))
				: undefined,
		score: state.minCompositeScore > 0 ? state.minCompositeScore : undefined,
		cw: state.viewMode === 'evaluacion' ? state.climateWeight : undefined,
		aw: state.viewMode === 'evaluacion' ? state.accessWeight : undefined,
		nw: state.viewMode === 'evaluacion' ? state.natureWeight : undefined,
		tab: state.isMobileView && state.activeSheetTab !== 'filtr' ? state.activeSheetTab : undefined,
		sel: state.selectedMunicipioId,
		open: state.isMobileView ? state.isBottomSheetOpen : undefined
	});

export type ViewMode = 'exploracion' | 'evaluacion';
export type SheetTab = 'sel' | 'filtr' | 'capas' | 'rank' | 'meta';
export type TravelBucket = '<=1h30' | '<=2h00' | '<=2h30' | '<=3h30' | '<=4h00' | '>4h00';

export type UrlState = {
	mode?: ViewMode;
	q?: string;
	province?: string;
	travel?: TravelBucket;
	ppt?: number;
	tw?: number;
	ts?: number;
	ta?: number;
	score?: number;
	clima?: number;
	accesibilidad?: number;
	naturaleza?: number;
	tab?: SheetTab;
	sel?: string;
	open?: boolean;
	mapView?: 'auto' | 'municipality' | 'grid';
};

const toFiniteNumber = (value: string | null): number | undefined => {
	if (value === null) return undefined;
	const parsed = Number(value);
	return Number.isFinite(parsed) ? parsed : undefined;
};

export const parseUrlState = (search: string): UrlState => {
	const params = new URLSearchParams(search);
	const mode = params.get('mode');
	const travel = params.get('travel');
	const tab = params.get('tab');
	const mapView = params.get('mapView');

	return {
		mode: mode === 'exploracion' || mode === 'evaluacion' ? mode : undefined,
		q: params.get('q') ?? undefined,
		province: params.get('province') ?? undefined,
		travel:
			travel === '<=1h30' ||
			travel === '<=2h00' ||
			travel === '<=2h30' ||
			travel === '<=3h30' ||
			travel === '<=4h00' ||
			travel === '>4h00'
				? travel
				: undefined,
		ppt: toFiniteNumber(params.get('ppt')),
		tw: toFiniteNumber(params.get('tw')),
		ts: toFiniteNumber(params.get('ts')),
		ta: toFiniteNumber(params.get('ta')),
		score: toFiniteNumber(params.get('score')),
		clima: toFiniteNumber(params.get('clima')) ?? toFiniteNumber(params.get('cw')),
		accesibilidad:
			toFiniteNumber(params.get('accesibilidad')) ?? toFiniteNumber(params.get('aw')),
		naturaleza: toFiniteNumber(params.get('naturaleza')) ?? toFiniteNumber(params.get('nw')),
		tab:
			tab === 'sel' ||
			tab === 'filtr' ||
			tab === 'filter' ||
			tab === 'capas' ||
			tab === 'rank' ||
			tab === 'meta'
				? (tab === 'filter' ? 'filtr' : tab)
				: undefined,
		sel: params.get('sel') ?? undefined,
		open: params.get('open') === '1',
		mapView: mapView === 'auto' || mapView === 'municipality' || mapView === 'grid' ? mapView : undefined
	};
};

export const buildUrlState = (state: UrlState): URLSearchParams => {
	const params = new URLSearchParams();
	if (state.mode) params.set('mode', state.mode);
	if (state.q) params.set('q', state.q);
	if (state.province) params.set('province', state.province);
	if (state.travel) params.set('travel', state.travel);
	if (state.ppt !== undefined) params.set('ppt', String(state.ppt));
	if (state.tw !== undefined) params.set('tw', String(state.tw));
	if (state.ts !== undefined) params.set('ts', String(state.ts));
	if (state.ta !== undefined) params.set('ta', String(state.ta));
	if (state.score !== undefined) params.set('score', state.score.toFixed(2));
	if (state.clima !== undefined) params.set('clima', String(state.clima));
	if (state.accesibilidad !== undefined) params.set('accesibilidad', String(state.accesibilidad));
	if (state.naturaleza !== undefined) params.set('naturaleza', String(state.naturaleza));
	if (state.tab) params.set('tab', state.tab);
	if (state.sel) params.set('sel', state.sel);
	if (state.open) params.set('open', '1');
	if (state.mapView) params.set('mapView', state.mapView);
	return params;
};

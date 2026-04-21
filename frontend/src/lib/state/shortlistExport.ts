import type { Municipio } from '$lib/types/municipio';

const downloadFile = (filename: string, content: string, mimeType: string) => {
	if (typeof window === 'undefined') return;
	const blob = new Blob([content], { type: mimeType });
	const url = URL.createObjectURL(blob);
	const link = document.createElement('a');
	link.href = url;
	link.download = filename;
	link.click();
	URL.revokeObjectURL(url);
};

const csvCell = (value: string | number | undefined | null) => {
	if (value === undefined || value === null) return '';
	const text = String(value);
	return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
};

export const exportShortlistCsv = (rows: Municipio[]) => {
	if (rows.length === 0) return;
	const headers = ['id', 'codigo', 'nombre', 'provincia', 'travel_bucket', 'mixed_score'];
	const body = rows.map((m) =>
		[m.id, m.codigo, m.nombre, m.provincia, m.travel_bucket, m.mixed_score?.toFixed(4) ?? '']
			.map(csvCell)
			.join(',')
	);
	downloadFile('shortlist_el_buen_vivir.csv', `${headers.join(',')}\n${body.join('\n')}`, 'text/csv;charset=utf-8');
};

export const exportShortlistJson = (rows: Municipio[]) => {
	if (rows.length === 0) return;
	downloadFile(
		'shortlist_el_buen_vivir.json',
		JSON.stringify(rows, null, 2),
		'application/json;charset=utf-8'
	);
};

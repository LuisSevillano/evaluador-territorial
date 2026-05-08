import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const dataPath = resolve('static/data/municipios_v2.json');
const compactPath = resolve('static/data/municipios_v2.compact.json');
const dictionaryPath = resolve('static/data/municipios_v2.dictionary.json');

const raw = readFileSync(dataPath, 'utf8');
const rows = JSON.parse(raw);

if (!Array.isArray(rows) || rows.length === 0) {
	throw new Error('municipios_v2.json is empty or invalid');
}

const fields = Object.keys(rows[0]);
const codeForIndex = (index) => index.toString(36);

const keyToCode = Object.fromEntries(fields.map((field, index) => [field, codeForIndex(index)]));
const codeToKey = Object.fromEntries(fields.map((field, index) => [codeForIndex(index), field]));
const compactRows = rows.map((row) => fields.map((field) => row[field]));

const compactPayload = {
	version: 1,
	fields: fields.map((field) => keyToCode[field]),
	rows: compactRows
};

const dictionaryPayload = {
	version: 1,
	codeToKey
};

writeFileSync(compactPath, JSON.stringify(compactPayload));
writeFileSync(dictionaryPath, JSON.stringify(dictionaryPayload, null, 2));

const bytes = Buffer.byteLength(JSON.stringify(compactPayload));
console.log(`Wrote compact data (${compactRows.length} rows, ${fields.length} fields, ${bytes} bytes).`);

#!/usr/bin/env node
/*
 * gen-i18n.cjs — generate editor/src/generated/i18nData.ts from the shared
 * i18n/ CSV dictionaries at the repo root.
 *
 * This removes the long-standing duplication between the Prolog grammar's
 * keyword lists and the Monaco keyword tables in le-language.ts: both sides
 * now read i18n/keywords.csv. The generated module also carries the UI chrome
 * catalog (ui.csv) and the language registry (languages.csv) for the editor's
 * language selector and i18n runtime.
 *
 * Run automatically as part of `npm run build` (see package.json). No deps.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const i18nDir = path.join(repoRoot, 'i18n');
const outDir = path.join(__dirname, '..', 'src', 'generated');
const outFile = path.join(outDir, 'i18nData.ts');

// --- tiny CSV parser (RFC-4180 quoting) -----------------------------------
function parseCSV(text) {
    const rows = [];
    let row = [], field = '', inQuotes = false;
    for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (inQuotes) {
            if (c === '"') {
                if (text[i + 1] === '"') { field += '"'; i++; }
                else inQuotes = false;
            } else field += c;
        } else if (c === '"') {
            inQuotes = true;
        } else if (c === ',') {
            row.push(field); field = '';
        } else if (c === '\n' || c === '\r') {
            if (c === '\r' && text[i + 1] === '\n') i++;
            row.push(field); field = '';
            if (row.length > 1 || row[0] !== '') rows.push(row);
            row = [];
        } else field += c;
    }
    if (field !== '' || row.length) { row.push(field); rows.push(row); }
    return rows;
}

function readCSV(name) {
    const file = path.join(i18nDir, name);
    const rows = parseCSV(fs.readFileSync(file, 'utf8'));
    const header = rows.shift();
    return { header, rows };
}

const NON_LANG_COLS = new Set(['category', 'key', 'id', 'functor', 'types',
    'code', 'autonym', 'opener', 'decimal_sep', 'thousands_sep', 'list_sep', 'status']);

function langColumns(header) {
    return header.filter(h => !NON_LANG_COLS.has(h));
}

// --- keywords.csv -> keywords[lang][key] = string[][] (synonym -> words) ---
const kw = readCSV('keywords.csv');
const kwLangs = langColumns(kw.header);
const keywords = {};
const keywordCategories = {};
for (const lang of kwLangs) keywords[lang] = {};
for (const row of kw.rows) {
    const rec = Object.fromEntries(kw.header.map((h, i) => [h, row[i] ?? '']));
    if (!rec.category || !rec.key) continue;
    keywordCategories[rec.key] = rec.category;
    for (const lang of kwLangs) {
        const cell = rec[lang];
        if (!cell) continue;
        const syns = cell.split('|').map(s => s.trim()).filter(Boolean)
            .map(s => s.split(/\s+/));
        // longest first (mirrors the Prolog loader) so regex alternations
        // built from these lists match the longest phrase first
        syns.sort((a, b) => b.join(' ').length - a.join(' ').length);
        keywords[lang][rec.key] = syns;
    }
}

// --- ui.csv -> ui[lang][key] = string --------------------------------------
const uiCsv = readCSV('ui.csv');
const uiLangs = langColumns(uiCsv.header);
const ui = {};
for (const lang of uiLangs) ui[lang] = {};
for (const row of uiCsv.rows) {
    const rec = Object.fromEntries(uiCsv.header.map((h, i) => [h, row[i] ?? '']));
    if (!rec.key) continue;
    for (const lang of uiLangs) {
        if (rec[lang]) ui[lang][rec.key] = rec[lang];
    }
}

// --- languages.csv -> registry ---------------------------------------------
const langsCsv = readCSV('languages.csv');
const languages = [];
for (const row of langsCsv.rows) {
    const rec = Object.fromEntries(langsCsv.header.map((h, i) => [h, row[i] ?? '']));
    if (!rec.code) continue;
    languages.push({
        code: rec.code,
        autonym: rec.autonym,
        opener: rec.opener,
        decimalSep: rec.decimal_sep,
        thousandsSep: rec.thousands_sep,
        listSep: rec.list_sep,
        status: rec.status,
    });
}

// --- emit -------------------------------------------------------------------
const banner = `// GENERATED FILE — do not edit.
// Built by editor/scripts/gen-i18n.cjs from the shared i18n/*.csv dictionaries
// at the repository root. Edit those CSVs (and re-run npm run build) instead.
`;

const body = `${banner}
export type KeywordTable = Record<string, string[][]>;

/** Grammar keyword surface forms per language: key -> synonyms -> words. */
export const keywords: Record<string, KeywordTable> = ${JSON.stringify(keywords, null, 2)} as const;

/** Category of each keyword key (section, connective, class, ...). */
export const keywordCategories: Record<string, string> = ${JSON.stringify(keywordCategories, null, 2)} as const;

/** UI chrome strings per language, keyed by the canonical English string. */
export const uiCatalog: Record<string, Record<string, string>> = ${JSON.stringify(ui, null, 2)} as const;

export interface LanguageInfo {
    code: string;
    autonym: string;
    opener: string;
    decimalSep: string;
    thousandsSep: string;
    listSep: string;
    status: string;
}

/** Registry of supported program languages (i18n/languages.csv). */
export const languages: LanguageInfo[] = ${JSON.stringify(languages, null, 2)} as const;

/** All synonyms of a keyword as space-joined phrases (longest first). */
export function keywordPhrases(lang: string, key: string): string[] {
    const table = keywords[lang] ?? keywords['en'];
    const syns = table[key] ?? keywords['en']?.[key] ?? [];
    return syns.map(words => words.join(' '));
}
`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outFile, body);

// JSON catalog for pages that are served without bundling (Executive view).
const jsonOut = path.join(repoRoot, 'web_extras', 'executive', 'i18n-ui.json');
fs.writeFileSync(jsonOut, JSON.stringify({ ui, languages }, null, 1));
console.log(`gen-i18n: wrote ${path.relative(process.cwd(), outFile)} ` +
    `(${Object.keys(keywordCategories).length} keys, langs: ${kwLangs.join(', ')})`);

#!/usr/bin/env node
/*
 * harvest-ui-strings.cjs — extract user-visible English strings from the
 * editor's HTML surfaces (and the Executive app) into i18n/ui.csv rows.
 *
 * The extraction mirrors the runtime auto-translation walk in src/i18n.ts:
 * simple text-only widgets (buttons, labels, options, menu/dropdown items,
 * headings, link items) plus title= and placeholder= attributes. Existing
 * ui.csv rows (and their translations) are preserved; only new keys are
 * appended, so translators never lose work.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const files = [
    'editor/index.html', 'editor/proof-game.html', 'editor/graph.html',
    'editor/hierarchy.html', 'editor/scenario-editor.html',
    'editor/query-editor.html', 'editor/scenario-variations.html',
    'editor/explanation-drill.html', 'web_extras/executive/index.html',
].map(f => path.join(repoRoot, f)).filter(f => fs.existsSync(f));

const found = new Set();

function looksTranslatable(s) {
    s = s.trim();
    if (s.length < 2 || s.length > 400) return false;
    if (!/[A-Za-z]{2}/.test(s)) return false;      // needs some words
    if (/^[A-Z_0-9]+$/.test(s)) return false;      // ID-like
    if (/^https?:|^\/|^#|^\w+\.(html|js|css)$/.test(s)) return false;
    if (/[{}<>]/.test(s)) return false;
    return true;
}

for (const file of files) {
    const html = fs.readFileSync(file, 'utf8');
    // strip <style> and <script> bodies
    const cleaned = html.replace(/<style[\s\S]*?<\/style>/gi, '')
                        .replace(/<script[\s\S]*?<\/script>/gi, '');
    // simple text-only elements
    const elRe = /<(button|label|option|h1|h2|h3|h4|th|summary|legend|b|a|span|div|small|p|td)\b[^>]*>([^<]+)<\/\1>/gi;
    let m;
    while ((m = elRe.exec(cleaned))) {
        const tag = m[1].toLowerCase();
        const attrs = m[0].slice(0, m[0].indexOf('>'));
        const text = m[2];
        // divs/spans only when they are menu/dropdown items or explicit i18n hooks
        if ((tag === 'div' || tag === 'span') &&
            !/class="[^"]*(dropdown-item|menu|status|hint|note|label|caption)[^"]*"/.test(attrs) &&
            !/data-i18n/.test(attrs)) continue;
        if (looksTranslatable(text)) found.add(text.trim());
    }
    // menu items: first text node before a nested tag
    const menuRe = /class="menu-item"[^>]*>\s*([A-Za-z][A-Za-z &…\.]*?)\s*</g;
    while ((m = menuRe.exec(cleaned))) {
        if (looksTranslatable(m[1])) found.add(m[1].trim());
    }
    // attributes
    const attrRe = /\b(title|placeholder|aria-label|alt|value)="([^"]+)"/gi;
    while ((m = attrRe.exec(cleaned))) {
        const [, attr, text] = m;
        if (attr.toLowerCase() === 'value') {
            // only submit-button values
            const before = cleaned.slice(Math.max(0, m.index - 200), m.index);
            if (!/type=["'](submit|button)["']/.test(before)) continue;
        }
        if (looksTranslatable(text)) found.add(text.trim());
    }
}

// merge with existing ui.csv
const uiPath = path.join(repoRoot, 'i18n', 'ui.csv');
const existing = fs.readFileSync(uiPath, 'utf8');
const lines = existing.split(/\r?\n/).filter(l => l.length);
const header = lines[0];
const nLangs = header.split(',').length - 1;

function parseKey(line) {
    // first CSV field (possibly quoted)
    if (line[0] === '"') {
        let out = '', i = 1;
        while (i < line.length) {
            if (line[i] === '"') {
                if (line[i + 1] === '"') { out += '"'; i += 2; continue; }
                break;
            }
            out += line[i++];
        }
        return out;
    }
    return line.split(',')[0];
}
const existingKeys = new Set(lines.slice(1).map(parseKey));

function csvQuote(s) {
    return (/[",\n]/.test(s)) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

const additions = [...found].filter(k => !existingKeys.has(k)).sort();
const newLines = additions.map(k => csvQuote(k) + ','.repeat(nLangs));
fs.writeFileSync(uiPath, lines.concat(newLines).join('\n') + '\n');
console.log(`harvest-ui-strings: ${additions.length} new keys (total ${existingKeys.size + additions.length})`);

/*
 * le-language.ts — Monaco language configuration and Monarch tokenizer for
 * Logical English, built per language from the shared lexicon.
 *
 * The keyword tables come from i18n/keywords.csv via the generated
 * src/generated/i18nData.ts (single source with the Prolog grammar — this
 * file no longer duplicates the keyword lists). buildLeMonarchTokens(lang)
 * returns the tokenizer for one program language; the editor re-registers it
 * when the open program declares a different language.
 */
import { kwTable } from './i18n';

export const leLanguageConfiguration = {
    comments: {
        lineComment: '%',
        blockComment: ['/*', '*/'],
    },
    brackets: [
        ['[', ']'],
        ['(', ')'],
        ['{', '}']
    ],
    autoClosingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '*', close: '*' }
    ],
    surroundingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '*', close: '*' }
    ]
};

// --- regex helpers over the lexicon ----------------------------------------

function esc(w: string): string {
    return w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** One phrase (word list) as a regex fragment with flexible spacing. */
function phraseRe(words: string[]): string {
    return words.map(esc).join('[ \\t]+');
}

/** Alternation of every synonym of the given keys, longest phrases first. */
function alt(table: Record<string, string[][]>, keys: string[]): string {
    const phrases: string[][] = [];
    for (const key of keys) {
        for (const syn of table[key] ?? []) phrases.push(syn);
    }
    phrases.sort((a, b) => b.join(' ').length - a.join(' ').length);
    return phrases.map(phraseRe).join('|');
}

/** Alternation of the single words of the given keys. */
function words(table: Record<string, string[][]>, keys: string[]): string {
    const ws = new Set<string>();
    for (const key of keys) {
        for (const syn of table[key] ?? []) {
            if (syn.length === 1) ws.add(syn[0]);
        }
    }
    return [...ws].sort((a, b) => b.length - a.length).map(esc).join('|');
}

/**
 * Build the Monarch tokenizer for one program language. Word boundaries use
 * lookarounds on [A-Za-zÀ-ÿ0-9_] so accented keywords (é, não, …) match
 * correctly — \b misfires around non-ASCII letters.
 */
export function buildLeMonarchTokens(lang: string): any {
    const T = kwTable(lang);
    const W = '[A-Za-zÀ-ÖØ-öø-ÿ0-9_]';
    const b = (re: string) => `(?<!${W})(?:${re})(?!${W})`;

    const headers = alt(T, ['kb_open', 'contract_open', 'scenario', 'query', 'ontology', 'meta_target']);
    const templateHeaders = alt(T, ['predicates', 'templates', 'fluents', 'events']);
    const structural = alt(T, [
        'resources_include', 'kb_include', 'if', 'only_if', 'either', 'any_of',
        'all_of', 'at_least_one_of', 'unless', 'and_unless', 'forall',
        'it_the_case', 'not_the_case', 'such_that', 'sum', 'count', 'average',
        'min', 'max', 'marker',
    ]);
    const expects = alt(T, ['expects']) && `(?:${alt(T, ['expects'])})[ \\t]+(?:${alt(T, ['answers'])})`;
    const andOr = words(T, ['and', 'or']);
    const articles = words(T, ['article', 'each', 'wh_var']);
    const qualifiers = words(T, ['qualifier']);
    const copulas = words(T, ['copula', 'ignorable', 'meta_marker', 'that']);
    const preps = words(T, ['connective_heuristic', 'of']);
    const additions = alt(T, ['defines_global', 'opposite', 'synonym', 'prepositional', 'unknown', 'undefined']);

    return {
        tokenizer: {
            root: [
                // Section headers
                [new RegExp(`(?:${templateHeaders}):`), { token: 'keyword.header', next: '@templates' }],
                [new RegExp(b(headers)), 'keyword.header'],

                // Structural keywords
                [new RegExp(b(structural)), 'keyword'],
                [new RegExp(`^\\s*(?:${andOr})(?!${W})`), 'keyword'],
                [new RegExp(b(expects)), 'keyword.expects'],

                // Template words (copula followed by article/preposition) —
                // prevents "is a parent" matching the variable rule
                [new RegExp(`${b(copulas)}[ \\t]+${b(preps)}`), 'templateWord'],

                // Variables (article/each/which + optional qualifier + word)
                [new RegExp(`${b(articles)}[ \\t]+(?:(?:${qualifiers})[ \\t]+)?(${W}+)(?!${W})`), 'variable'],

                // Standalone template words
                [new RegExp(b(copulas)), 'templateWord'],
                [new RegExp(b(preps)), 'templateWord'],

                // Standalone IDs / Variables (Capitalized)
                [/\b[A-Z][A-Z0-9_]*\b/, 'variable'],

                // Variables in *...*
                [/\*[^*]+\*/, 'variable'],

                // Catch-all for words (may include a single apostrophe)
                [new RegExp(`${W}+(?:'${W}*)?`), 'text'],

                // Strings
                [/"([^"\\]|\\.)*$/, 'string.invalid'],
                [/'([^'\\]|\\.)*$/, 'string.invalid'],
                [/"/, { token: 'string.quote', bracket: '@open', next: '@string_double' }],
                [/'/, { token: 'string.quote', bracket: '@open', next: '@string_single' }],

                // Dates before numbers
                [/\d{4}-\d{2}-\d{2}/, 'number.date'],

                // Numbers (both . and , accepted as decimal separator visually)
                [/\d+([.,]\d+)?/, 'number'],

                // Comments
                [/%.*$/, 'comment'],
                [/\/\*/, 'comment', '@comment'],

                // Punctuation
                [/[{}()\[\]]/, '@brackets'],
                [/[<>!=]=?/, 'operator'],
                [/[.,:]/, 'delimiter'],
            ],

            templates: [
                [new RegExp(b(additions)), 'keyword.addition'],
                [new RegExp(b(headers)), { token: 'keyword.header', next: '@pop' }],
                [/\*[^*]+\*/, 'variable'],
                [/%.*$/, 'comment'],
                [/\/\*/, 'comment', '@comment'],
                [/[.,;]/, 'delimiter'],
                [new RegExp(b(copulas)), 'text'],
                [new RegExp(`${W}+(?:'${W}*)?`), 'text'],
                [/./, 'text']
            ],

            comment: [
                [/[^\/*]+/, 'comment'],
                [/\/\*/, 'comment', '@push'],
                ["\\*/", 'comment', '@pop'],
                [/[\/*]/, 'comment']
            ],

            string_double: [
                [/[^\\"]+/, 'string'],
                [/\\./, 'string.escape'],
                [/"/, { token: 'string.quote', bracket: '@close', next: '@pop' }]
            ],

            string_single: [
                [/[^\\']+/, 'string'],
                [/\\./, 'string.escape'],
                [/'/, { token: 'string.quote', bracket: '@close', next: '@pop' }]
            ],
        }
    };
}

// English tables, for existing imports.
export const leMonarchTokens = buildLeMonarchTokens('en');

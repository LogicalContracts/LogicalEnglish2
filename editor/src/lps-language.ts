/*
 * lps-language.ts — Monaco language configuration and Monarch tokenizer for
 * LPS *external* syntax: the `.lps` files that sit beside a `.le` document and
 * carry what Logical English deliberately does not (display/2, Prolog escapes,
 * real-time plumbing — docs/le_lps_surface.md §7).
 *
 * A SECOND mode rather than an extension of `le`, because the two languages
 * share no lexis. LE is English with indentation-significant structure; this is
 * Prolog with an operator table. One Monarch grammar covering both would be a
 * mode-switching monster, and the LSP features differ in kind: template
 * extraction is meaningless for `.lps`, operator completion is meaningless for
 * `.le`. See docs/le_lps_design.md §3.
 *
 * The keyword list is the §I.4 operator table of the LPS(2) repository
 * (src/core/lps_ops.pl) — an interface specification, not a guess.
 */

export const lpsLanguageConfiguration = {
    comments: {
        lineComment: '%',
        blockComment: ['/*', '*/'] as [string, string],
    },
    brackets: [
        ['[', ']'],
        ['(', ')'],
        ['{', '}'],
    ] as [string, string][],
    autoClosingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
    ],
    surroundingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
    ],
};

/** Declarations: what a program says about its own vocabulary. */
const DECLARATIONS = [
    'maxTime', 'maxRealTime', 'minCycleTime',
    'simulatedRealTimePerCycle', 'simulatedRealTimeBeginning',
    'fluents', 'actions', 'events', 'prolog_events', 'unserializable',
    'initially', 'observe', 'display',
];

/** The rule vocabulary, from the §I.4 operator table. */
const OPERATORS = [
    'if', 'then', 'else', 'false', 'from', 'to', 'at', 'during',
    'initiates', 'terminates', 'updates', 'in', 'not', 'achieve',
    'initiate', 'terminate', 'lps_terminate',
];

/** The internal vocabulary, so a generated `.lpsw` also highlights. */
const INTERNAL = [
    'reactive_rule', 'l_int', 'l_events', 'l_timeless',
    'initiated', 'terminated', 'updated', 'd_pre', 'initial_state',
    'holds', 'happens', 'lps_engine',
];

export const lpsMonarchTokens: any = {
    defaultToken: '',
    declarations: DECLARATIONS,
    operators: OPERATORS,
    internal: INTERNAL,
    tokenizer: {
        root: [
            // A directive is structure, not a goal.
            [/:-/, 'keyword.header'],

            // Quoted atoms before bare identifiers, so 'it''s' is one token.
            [/'([^'\\]|\\.|'')*'/, 'string'],
            [/"([^"\\]|\\.)*"/, 'string'],
            [/'([^'\\]|\\.)*$/, 'string.invalid'],
            [/"([^"\\]|\\.)*$/, 'string.invalid'],

            // Variables are Prolog's: an initial capital or underscore.
            [/[A-Z_][a-zA-Z0-9_]*/, 'variable'],

            [/[a-z][a-zA-Z0-9_]*/, {
                cases: {
                    '@declarations': 'keyword.header',
                    '@operators': 'keyword',
                    '@internal': 'type',
                    '@default': 'identifier',
                },
            }],

            [/\d{4}-\d{2}-\d{2}/, 'number.date'],
            [/\d+\.\d+/, 'number.float'],
            [/\d+/, 'number'],

            [/%.*$/, 'comment'],
            [/\/\*/, 'comment', '@comment'],

            [/[{}()\[\]]/, '@brackets'],
            [/(=<|>=|=:=|=\\=|\\==|==|\\=|@<|@>|@=<|@>=|<|>|=|is)/, 'operator'],
            [/[,.;|]/, 'delimiter'],
        ],

        comment: [
            [/[^\/*]+/, 'comment'],
            [/\/\*/, 'comment', '@push'],
            ['\\*/', 'comment', '@pop'],
            [/[\/*]/, 'comment'],
        ],
    },
};

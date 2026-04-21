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

export const leMonarchTokens = {
    tokenizer: {
        root: [
            // Section headers
            [/the knowledge base|scenario|query|the ontology|the predicates|the templates|the fluents|the events|the target language/, 'keyword.header'],
            
            // Keywords
            [/\b(includes|is|are|if|and|or|for all cases in which|it is the case that|it is not the case that|not the case that|sum|count|average|min|max|such that)\b/, 'keyword'],
            
            // Variables
            [/\*[^*]+\*/, 'variable'],
            
            // Strings
            [/"([^"\\]|\\.)*$/, 'string.invalid'],  // non-teminated string
            [/'([^'\\]|\\.)*$/, 'string.invalid'],  // non-teminated string
            [/"/,  { token: 'string.quote', bracket: '@open', next: '@string_double' } ],
            [/'/,  { token: 'string.quote', bracket: '@open', next: '@string_single' } ],

            // Numbers
            [/\d+(\.\d+)?/, 'number'],

            // Dates
            [/\d{4}-\d{2}-\d{2}/, 'number.date'],

            // Comments
            [/%.*$/, 'comment'],
            [/\/\*/, 'comment', '@comment'],

            // Punctuation
            [/[{}()\[\]]/, '@brackets'],
            [/[<>!=]=?/, 'operator'],
            [/[.,:]/, 'delimiter'],
        ],

        comment: [
            [/[^\/*]+/, 'comment'],
            [/\/\*/,    'comment', '@push' ],    // nested comment
            ["\\*/",    'comment', '@pop'  ],
            [/[\/*]/,   'comment' ]
        ],

        string_double: [
            [/[^\\"]+/,  'string'],
            [/\\./,      'string.escape'],
            [/"/,        { token: 'string.quote', bracket: '@close', next: '@pop' } ]
        ],

        string_single: [
            [/[^\\']+/,  'string'],
            [/\\./,      'string.escape'],
            [/'/,        { token: 'string.quote', bracket: '@close', next: '@pop' } ]
        ],
    }
};

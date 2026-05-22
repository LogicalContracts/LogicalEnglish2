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
            [/the (predicates|templates|fluents|events) are:/, { token: 'keyword.header', next: '@templates' }],
            [/the knowledge base|the contract|scenario|query|the ontology|the target language/, 'keyword.header'],
            
            // Structural Keywords
            [/\b(includes|if|either|any\s+of|all\s+of|unless|for\s+all\s+cases\s+in\s+which|it\s+is\s+the\s+case\s+that|it\s+is\s+not\s+the\s+case\s+that|not\s+the\s+case\s+that|says\s+that|sum|count|average|min|max|such\s+that)\b/, 'keyword'],
            [/^\s*(and|or)\b/, 'keyword'],
            [/\b(which|what)\s+[a-zA-Z]\w*/, 'variable'],
            [/\bexpects answers\b/, 'keyword.expects'],

            // Template words (verbs followed by articles/prepositions)
            // This prevents "is a parent" from matching the variable rule for "a parent"
            [/\b(is|are|was|were|has|have|had|does|do|did)\s+(a|an|the|of|in|on|at|to|from|for|with|by)\b/, 'templateWord'],
            
            // Variables (a/an/the/each/some/which/what + word(s))
            [/\b(a|an|the|each|some|which|what)\s+(?:(?:other|another|third|fourth|fifth)\s+)?([a-zA-Z]\w*)\b/, 'variable'],
            
            // Standalone Template words
            [/\b(is|are|was|were|has|have|had|does|do|did|should|must|can|could|may|might|will|would|says|said|that)\b/, 'templateWord'],
            [/\b(of|in|on|at|to|from|for|with|by|about|between|through|during|before|after|above|below|under|over|again|further|then|there)\b/, 'templateWord'],
            
            // Standalone IDs / Variables (Capitalized)
            [/\b[A-Z][A-Z0-9_]*\b/, 'variable'],
            
            // Variables in *...*
            [/\*[^*]+\*/, 'variable'],

            // Catch-all for words to prevent partial keyword matching
            [/[a-zA-Z_]\w*/, 'text'],
            
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

        templates: [
            [/the knowledge base|the contract|scenario|query|the ontology|the target language/, { token: 'keyword.header', next: '@pop' }],
            [/\*[^*]+\*/, 'variable'],
            [/%.*$/, 'comment'],
            [/\/\*/, 'comment', '@comment'],
            [/[.,;]/, 'delimiter'],
            [/\b(is|are|has|have|was|were|been|does|do|did)\b/, 'text'], // Don't color as predicate in definitions
            [/[a-zA-Z_]\w*/, 'text'],
            [/./, 'text']
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

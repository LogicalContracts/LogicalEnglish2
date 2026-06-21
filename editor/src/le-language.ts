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
            [/the[ \t]+(predicates|templates|fluents|events)[ \t]+are:/, { token: 'keyword.header', next: '@templates' }],
            [/the[ \t]+knowledge[ \t]+base|the[ \t]+contract|scenario|query|the[ \t]+ontology|the[ \t]+target[ \t]+language/, 'keyword.header'],
            
            // Structural Keywords
            [/\b(includes\s+these\s+resources|includes|if|either|any\s+of|all\s+of|unless|for\s+all\s+cases\s+in\s+which|it\s+is\s+the\s+case\s+that|it\s+is\s+not\s+the\s+case\s+that|not\s+the\s+case\s+that|it\s+is\s+(?:unknown|assumed|assumable)\s+whether|says\s+that|sum|count|average|min|max|such\s+that)\b/, 'keyword'],
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

            // Catch-all for words to prevent partial keyword matching. A word may
            // include a single apostrophe (e.g. "employers'", "don't") so a lone
            // apostrophe does not start a string and mis-colour the rest of the line.
            [/[a-zA-Z_]\w*(?:'\w*)?/, 'text'],

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
            // Template additions must come first so 'scenario element' is matched
            // before the keyword.header rule sees the bare word 'scenario'.
            [/scenario\s+element/, 'keyword.addition'],
            [/defines\s+global/, 'keyword.addition'],
            [/\b(opposite|prepositional|assumable|assumed|unknown|undefined)\b/, 'keyword.addition'],
            [/the[ \t]+knowledge[ \t]+base|the[ \t]+contract|scenario|query|the[ \t]+ontology|the[ \t]+target[ \t]+language/, { token: 'keyword.header', next: '@pop' }],
            [/\*[^*]+\*/, 'variable'],
            [/%.*$/, 'comment'],
            [/\/\*/, 'comment', '@comment'],
            [/[.,;]/, 'delimiter'],
            [/\b(is|are|has|have|was|were|been|does|do|did)\b/, 'text'],
            [/[a-zA-Z_]\w*(?:'\w*)?/, 'text'],
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

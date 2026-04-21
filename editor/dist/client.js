// src/le-language.ts
var leLanguageConfiguration = {
  comments: {
    lineComment: "%",
    blockComment: ["/*", "*/"]
  },
  brackets: [
    ["[", "]"],
    ["(", ")"],
    ["{", "}"]
  ],
  autoClosingPairs: [
    { open: "[", close: "]" },
    { open: "(", close: ")" },
    { open: "{", close: "}" },
    { open: '"', close: '"' },
    { open: "'", close: "'" },
    { open: "*", close: "*" }
  ],
  surroundingPairs: [
    { open: "[", close: "]" },
    { open: "(", close: ")" },
    { open: "{", close: "}" },
    { open: '"', close: '"' },
    { open: "'", close: "'" },
    { open: "*", close: "*" }
  ]
};
var leMonarchTokens = {
  tokenizer: {
    root: [
      // Section headers
      [/the knowledge base|scenario|query|the ontology|the predicates|the templates|the fluents|the events|the target language/, "keyword.header"],
      // Keywords
      [/\b(includes|is|are|if|and|or|for all cases in which|it is the case that|it is not the case that|not the case that|sum|count|average|min|max|such that)\b/, "keyword"],
      // Variables
      [/\*[^*]+\*/, "variable"],
      // Strings
      [/"([^"\\]|\\.)*$/, "string.invalid"],
      // non-teminated string
      [/'([^'\\]|\\.)*$/, "string.invalid"],
      // non-teminated string
      [/"/, { token: "string.quote", bracket: "@open", next: "@string_double" }],
      [/'/, { token: "string.quote", bracket: "@open", next: "@string_single" }],
      // Numbers
      [/\d+(\.\d+)?/, "number"],
      // Dates
      [/\d{4}-\d{2}-\d{2}/, "number.date"],
      // Comments
      [/%.*$/, "comment"],
      [/\/\*/, "comment", "@comment"],
      // Punctuation
      [/[{}()\[\]]/, "@brackets"],
      [/[<>!=]=?/, "operator"],
      [/[.,:]/, "delimiter"]
    ],
    comment: [
      [/[^\/*]+/, "comment"],
      [/\/\*/, "comment", "@push"],
      // nested comment
      ["\\*/", "comment", "@pop"],
      [/[\/*]/, "comment"]
    ],
    string_double: [
      [/[^\\"]+/, "string"],
      [/\\./, "string.escape"],
      [/"/, { token: "string.quote", bracket: "@close", next: "@pop" }]
    ],
    string_single: [
      [/[^\\']+/, "string"],
      [/\\./, "string.escape"],
      [/'/, { token: "string.quote", bracket: "@close", next: "@pop" }]
    ]
  }
};

// src/client.ts
function start() {
  if (typeof monaco === "undefined") {
    console.error("Monaco not loaded");
    return;
  }
  monaco.languages.register({ id: "le" });
  monaco.languages.setLanguageConfiguration("le", leLanguageConfiguration);
  monaco.languages.setMonarchTokensProvider("le", leMonarchTokens);
  function getInitialValue() {
    const params = new URLSearchParams(window.location.search);
    const text = params.get("text");
    return text || "% Welcome to Logical English Editor\n\nthe knowledge base my_kb includes:\n  *a person* is happy if\n    *the person* is healthy.\n";
  }
  const savedTheme = localStorage.getItem("le-editor-theme") || "vs-dark";
  const container = document.getElementById("container");
  const editor = monaco.editor.create(container, {
    value: getInitialValue(),
    language: "le",
    theme: savedTheme,
    automaticLayout: true,
    fontSize: 16,
    minimap: { enabled: false },
    folding: true,
    showFoldingControls: "always"
  });
  const themeSelect = document.getElementById("theme-select");
  if (themeSelect) {
    themeSelect.value = savedTheme;
    themeSelect.addEventListener("change", () => {
      const newTheme = themeSelect.value;
      monaco.editor.setTheme(newTheme);
      localStorage.setItem("le-editor-theme", newTheme);
    });
  }
  const worker = new Worker(new URL("../dist/server.js", import.meta.url), { type: "module" });
  let messageId = 0;
  const pendingRequests = /* @__PURE__ */ new Map();
  worker.onmessage = (event) => {
    const message = event.data;
    if (message.id !== void 0) {
      const resolve = pendingRequests.get(message.id);
      if (resolve) {
        resolve(message.result);
        pendingRequests.delete(message.id);
      }
    } else if (message.method === "textDocument/publishDiagnostics") {
      const diagnostics = message.params.diagnostics;
      const markers = diagnostics.map((d) => ({
        severity: d.severity === 1 ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning,
        startLineNumber: d.range.start.line + 1,
        startColumn: d.range.start.character + 1,
        endLineNumber: d.range.end.line + 1,
        endColumn: d.range.end.character + 1,
        message: d.message
      }));
      monaco.editor.setModelMarkers(editor.getModel(), "le", markers);
    }
  };
  function sendRequest(method, params) {
    const id = messageId++;
    return new Promise((resolve) => {
      pendingRequests.set(id, resolve);
      worker.postMessage({ jsonrpc: "2.0", id, method, params });
    });
  }
  function sendNotification(method, params) {
    worker.postMessage({ jsonrpc: "2.0", method, params });
  }
  sendRequest("initialize", { capabilities: {} });
  sendNotification("initialized", {});
  const model = editor.getModel();
  sendNotification("textDocument/didOpen", {
    textDocument: {
      uri: "file:///main.le",
      languageId: "le",
      version: 1,
      text: model.getValue()
    }
  });
  editor.onDidChangeModelContent(() => {
    const text = model.getValue();
    sendNotification("textDocument/didChange", {
      textDocument: {
        uri: "file:///main.le",
        version: 1
      },
      contentChanges: [{ text }]
    });
    const url = new URL(window.location.href);
    url.searchParams.set("text", encodeURIComponent(text));
    window.history.replaceState({}, "", url.toString());
  });
  monaco.languages.registerHoverProvider("le", {
    provideHover: async (model2, position) => {
      const res = await sendRequest("textDocument/hover", {
        textDocument: { uri: "file:///main.le" },
        position: { line: position.lineNumber - 1, character: position.column - 1 }
      });
      if (res && res.contents) {
        return {
          contents: Array.isArray(res.contents) ? res.contents : [res.contents]
        };
      }
      return null;
    }
  });
  monaco.languages.registerCompletionItemProvider("le", {
    triggerCharacters: [" ", "*"],
    provideCompletionItems: async (model2, position) => {
      const res = await sendRequest("textDocument/completion", {
        textDocument: { uri: "file:///main.le" },
        position: { line: position.lineNumber - 1, character: position.column - 1 }
      });
      if (res) {
        const items = Array.isArray(res) ? res : res.items;
        const lineContent = model2.getLineContent(position.lineNumber);
        const textBefore = lineContent.substring(0, position.column - 1);
        const articles = ["a", "an", "the", "some"];
        return {
          suggestions: items.map((item) => {
            const label = item.label;
            const templateText = String(item.insertText || label).replace(/\*/g, "");
            const wordsBefore = textBefore.split(/(\s+)/);
            const wordsTemplate = templateText.split(/(\s+)/);
            const cleanWordsBefore = wordsBefore.filter((w) => w.trim().length > 0);
            const cleanWordsTemplate = wordsTemplate.filter((w) => w.trim().length > 0);
            let overlapCleanWords = 0;
            for (let n = 1; n <= Math.min(cleanWordsBefore.length, cleanWordsTemplate.length); n++) {
              let match = true;
              for (let i = 0; i < n; i++) {
                const wBefore = cleanWordsBefore[cleanWordsBefore.length - n + i].toLowerCase();
                const wTemplate = cleanWordsTemplate[i].toLowerCase();
                if (wBefore === wTemplate || articles.includes(wBefore) && articles.includes(wTemplate) || i === n - 1 && wTemplate.startsWith(wBefore)) {
                  continue;
                }
                match = false;
                break;
              }
              if (match)
                overlapCleanWords = n;
            }
            let range;
            let insertText = templateText;
            if (overlapCleanWords > 0) {
              const overlapSequence = cleanWordsBefore.slice(cleanWordsBefore.length - overlapCleanWords);
              let searchIdx = textBefore.length;
              for (let i = overlapSequence.length - 1; i >= 0; i--) {
                searchIdx = textBefore.toLowerCase().lastIndexOf(overlapSequence[i].toLowerCase(), searchIdx - 1);
              }
              if (searchIdx !== -1) {
                range = { startLineNumber: position.lineNumber, startColumn: searchIdx + 1, endLineNumber: position.lineNumber, endColumn: position.column };
                const keptText = textBefore.substring(searchIdx);
                let templateOverlapEndIdx = 0;
                let templateWordsFound = 0;
                while (templateWordsFound < overlapCleanWords && templateOverlapEndIdx < templateText.length) {
                  const remainingTemplate = templateText.substring(templateOverlapEndIdx);
                  const nextWordMatch = remainingTemplate.match(/\S+/);
                  if (nextWordMatch) {
                    templateOverlapEndIdx += nextWordMatch.index + nextWordMatch[0].length;
                    templateWordsFound++;
                  } else
                    break;
                }
                insertText = keptText + templateText.substring(templateOverlapEndIdx);
              } else {
                const word = model2.getWordUntilPosition(position);
                range = { startLineNumber: position.lineNumber, startColumn: word.startColumn, endLineNumber: position.lineNumber, endColumn: word.endColumn };
              }
            } else {
              const word = model2.getWordUntilPosition(position);
              range = { startLineNumber: position.lineNumber, startColumn: word.startColumn, endLineNumber: position.lineNumber, endColumn: word.endColumn };
            }
            return { label, kind: item.kind !== void 0 ? item.kind - 1 : 1, insertText, detail: item.detail, range };
          })
        };
      }
      return { suggestions: [] };
    }
  });
  monaco.languages.registerFoldingRangeProvider("le", {
    provideFoldingRanges: async (model2, context, token) => {
      const res = await sendRequest("textDocument/foldingRange", {
        textDocument: { uri: "file:///main.le" }
      });
      if (res) {
        return res.map((range) => ({
          start: range.startLine + 1,
          end: range.endLine + 1,
          kind: range.kind === 3 ? monaco.languages.FoldingRangeKind.Region : void 0
        }));
      }
      return [];
    }
  });
}
window.startEditor = start;

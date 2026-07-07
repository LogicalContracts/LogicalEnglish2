// src/le-templates.ts
function splitTemplate(label) {
  const segs = [];
  const re = /\*([^*]+)\*/g;
  let last = 0;
  let m;
  while ((m = re.exec(label)) !== null) {
    const lit = label.slice(last, m.index).trim();
    if (lit)
      segs.push({ kind: "literal", text: lit });
    segs.push({ kind: "field", text: m[1].trim() });
    last = m.index + m[0].length;
  }
  const tail = label.slice(last).trim();
  if (tail)
    segs.push({ kind: "literal", text: tail });
  return segs;
}
function parseTemplateDefs(source) {
  const defs = [];
  const sectionHeader = /^(?:the\s+knowledge\s+base|the\s+contract|the\s+ontology|the\s+predicates|the\s+templates|the\s+fluents|the\s+events|the\s+target\s+language|scenario|query)\b/im;
  const templateHeader = /the\s+(predicates|templates|fluents|events)\s+are\s*:/gi;
  let m;
  while ((m = templateHeader.exec(source)) !== null) {
    const remaining = source.substring(m.index + m[0].length);
    const next = remaining.match(sectionHeader);
    const sectionText = next ? remaining.substring(0, next.index) : remaining;
    for (const line of sectionText.split("\n")) {
      const t = line.trim();
      if (!t || t.startsWith("%"))
        continue;
      const semi = t.indexOf(";");
      const annotation = semi >= 0 ? t.slice(semi + 1) : "";
      const isUndefined = /\b(undefined|scenario\s+element)\b/i.test(annotation);
      const main = (semi >= 0 ? t.slice(0, semi) : t).replace(/[.,]\s*$/, "").trim();
      if (main)
        defs.push({ label: main, isUndefined });
      const opp = annotation.match(/opposite:\s*([^;]+)/i);
      if (opp) {
        const o = opp[1].replace(/[.,;]\s*$/, "").trim();
        if (o)
          defs.push({ label: o, isUndefined });
      }
      for (const sm of annotation.matchAll(/\bsynonym\s+([^;]+)/gi)) {
        const s = sm[1].replace(/[.,;]\s*$/, "").trim();
        if (s)
          defs.push({ label: s, isUndefined });
      }
    }
  }
  return defs;
}
function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
function templateRegex(label) {
  const segs = splitTemplate(label);
  if (!segs.some((s) => s.kind === "field"))
    return null;
  const pieces = segs.map((s) => {
    if (s.kind === "field")
      return "(.+?)";
    const lit = escapeRegex(s.text).replace(/\s+/g, "\\s+");
    const lb = /^\w/.test(s.text) ? "\\b" : "";
    const rb = /\w$/.test(s.text) ? "\\b" : "";
    return lb + lit + rb;
  });
  try {
    return new RegExp("^\\s*" + pieces.join("\\s*") + "\\s*$", "i");
  } catch {
    return null;
  }
}
function literalLength(label) {
  return splitTemplate(label).filter((s) => s.kind === "literal").reduce((n, s) => n + s.text.length, 0);
}
function matchFact(fact, templates) {
  const f = fact.trim().replace(/\.\s*$/, "");
  const norm = (s) => s.replace(/\s+/g, " ").trim().toLowerCase();
  const fNorm = norm(f);
  const sorted = [...templates].sort((a, b) => literalLength(b) - literalLength(a));
  for (const label of sorted) {
    const segs = splitTemplate(label);
    if (!segs.some((s) => s.kind === "field")) {
      const lit = segs.map((s) => s.text).join(" ");
      if (norm(lit) === fNorm)
        return { label, values: [] };
      continue;
    }
    const re = templateRegex(label);
    if (!re)
      continue;
    const m = re.exec(f);
    if (m)
      return { label, values: m.slice(1).map((v) => (v || "").trim()) };
  }
  return null;
}
function fillTemplate(label, values) {
  const segs = splitTemplate(label);
  let fi = 0;
  const out = segs.map((s) => s.kind === "field" ? values[fi++] ?? "" : s.text).join(" ");
  return out.replace(/\s+/g, " ").trim();
}
function scanBlocks(source, headerRe) {
  const blocks = [];
  const lines = source.split("\n");
  const offsets = [];
  let off = 0;
  for (const ln of lines) {
    offsets.push(off);
    off += ln.length + 1;
  }
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(headerRe);
    if (!m)
      continue;
    const name = m[1].trim();
    const start = offsets[i];
    const bodyLines = [];
    let j = i + 1;
    let lastContent = i;
    while (j < lines.length) {
      const ln = lines[j];
      const t = ln.trim();
      if (t === "") {
        bodyLines.push(ln);
        j++;
        continue;
      }
      if (t.startsWith("%")) {
        bodyLines.push(ln);
        lastContent = j;
        j++;
        continue;
      }
      if (/^\s/.test(ln)) {
        bodyLines.push(ln);
        lastContent = j;
        j++;
        continue;
      }
      break;
    }
    const end = offsets[lastContent] + lines[lastContent].length;
    blocks.push({ name, start, end, bodyLines });
  }
  return blocks;
}
function parseScenarioBlocks(source) {
  return scanBlocks(source, /^scenario\s+(.+?)\s+is\s*:/i).map((b) => ({ name: b.name, start: b.start, end: b.end, facts: splitFacts(b.bodyLines) }));
}
function stripInlineComment(line) {
  let inStr = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"')
      inStr = !inStr;
    else if (c === "%" && !inStr)
      return line.slice(0, i);
  }
  return line;
}
function splitFacts(bodyLines) {
  const facts = [];
  let cur = "";
  for (const raw of bodyLines) {
    const t = stripInlineComment(raw).trim();
    if (t === "")
      continue;
    cur = cur ? cur + " " + t : t;
    if (t.endsWith(".")) {
      facts.push(cur.replace(/\.\s*$/, "").trim());
      cur = "";
    }
  }
  if (cur.trim())
    facts.push(cur.replace(/\.\s*$/, "").trim());
  return facts;
}

// src/scenario-form.ts
var SYSTEM_TYPE = ["*a thing* is a *type*", "*a thing* is an *type*"];
var isTestDirective = (fact) => /\bexpects?\s+answers?\b/i.test(fact);
var UNKNOWN_PREFIX = /^it is (?:unknown|assumed|assumable) whether\s+/i;
var WRITE_IN_ENGLISH = "__write_in_english__";
var DEFAULT_ASSUME_TITLE = "if checked, fact is assumed, unknown";
var ScenarioForm = class _ScenarioForm {
  templates;
  // all templates (for recognising facts)
  addableTemplates;
  // those offered in the Add menu
  testLines = [];
  // tests from the loaded scenario, kept as comments
  rows = [];
  opts;
  constructor(opts) {
    this.opts = opts;
    const defs = parseTemplateDefs(opts.source);
    this.templates = [...defs.map((d) => d.label), ...SYSTEM_TYPE];
    const used = /* @__PURE__ */ new Set();
    for (const b of parseScenarioBlocks(opts.source)) {
      for (const f of b.facts) {
        const m = matchFact(f, this.templates);
        if (m)
          used.add(m.label);
      }
    }
    const seen = /* @__PURE__ */ new Set();
    const addable = [];
    for (const d of defs) {
      if ((d.isUndefined || used.has(d.label)) && !seen.has(d.label)) {
        seen.add(d.label);
        addable.push(d.label);
      }
    }
    for (const t of SYSTEM_TYPE) {
      if (used.has(t) && !seen.has(t)) {
        seen.add(t);
        addable.push(t);
      }
    }
    this.addableTemplates = addable;
    opts.addSelect.innerHTML = "";
    for (const label of addable) {
      const o = document.createElement("option");
      o.value = label;
      o.textContent = label.replace(/\*/g, "");
      opts.addSelect.appendChild(o);
    }
    if (opts.onWriteInEnglish) {
      const o = document.createElement("option");
      o.value = WRITE_IN_ENGLISH;
      o.textContent = "Write it in English";
      opts.addSelect.appendChild(o);
    }
    opts.btnAdd.addEventListener("click", () => {
      const val = opts.addSelect.value;
      if (!val)
        return;
      if (val === WRITE_IN_ENGLISH) {
        this.opts.onWriteInEnglish?.();
        return;
      }
      this.rows.push({ templateLabel: val, values: [], raw: "", assumed: false });
      this.changed();
      this.render();
      opts.rowsEl.lastElementChild?.querySelector("input.field")?.focus();
    });
  }
  changed() {
    this.opts.onChange?.();
  }
  // Load a scenario's facts: template instances become editable rows, "expects
  // answers" tests are kept aside, everything else is preserved read-only.
  loadFacts(facts) {
    this.rows = [];
    this.testLines = [];
    for (const fact of facts) {
      if (isTestDirective(fact)) {
        this.testLines.push(fact);
        continue;
      }
      const assumed = UNKNOWN_PREFIX.test(fact);
      const inner = assumed ? fact.replace(UNKNOWN_PREFIX, "") : fact;
      const m = matchFact(inner, this.templates);
      if (m)
        this.rows.push({ templateLabel: m.label, values: m.values, raw: "", assumed });
      else
        this.rows.push({ templateLabel: null, values: [], raw: inner, assumed });
    }
    this.render();
  }
  clear() {
    this.rows = [];
    this.testLines = [];
    this.render();
  }
  // --- Rendering -------------------------------------------------------------
  render() {
    const rowsEl = this.opts.rowsEl;
    rowsEl.innerHTML = "";
    if (this.rows.length === 0) {
      const hint = document.createElement("div");
      hint.className = "empty-hint";
      hint.textContent = "No facts yet \u2014 pick a template below and click \u201CAdd\u201D.";
      rowsEl.appendChild(hint);
      return;
    }
    this.rows.forEach((row, idx) => rowsEl.appendChild(this.renderRow(row, idx)));
  }
  sizeField(input) {
    const n = Math.max((input.value || input.placeholder).length + 1, 6);
    input.size = Math.min(n, 80);
  }
  renderRow(row, idx) {
    const el = document.createElement("div");
    el.className = "fact-row";
    if (row.assumed)
      el.classList.add("assumed");
    const fieldInputs = [];
    if (row.templateLabel === null) {
      const span = document.createElement("span");
      span.className = "preserved";
      span.textContent = row.raw;
      span.title = "This line matches no template \u2014 edit it in the main editor";
      el.appendChild(span);
    } else {
      const segs = splitTemplate(row.templateLabel);
      let fieldIdx = 0;
      for (const seg of segs) {
        if (seg.kind === "literal") {
          const span = document.createElement("span");
          span.className = "word";
          span.textContent = seg.text;
          el.appendChild(span);
        } else {
          const fi = fieldIdx++;
          const input = document.createElement("input");
          input.type = "text";
          input.className = "field";
          input.placeholder = seg.text;
          input.title = seg.text;
          input.value = row.values[fi] ?? "";
          input.disabled = row.assumed;
          this.sizeField(input);
          input.addEventListener("input", () => {
            row.values[fi] = input.value;
            this.sizeField(input);
            this.changed();
          });
          el.appendChild(input);
          fieldInputs.push(input);
        }
      }
    }
    const tools = document.createElement("div");
    tools.className = "row-tools";
    const assume = document.createElement("label");
    assume.className = "assume";
    assume.title = this.opts.assumeTitle || DEFAULT_ASSUME_TITLE;
    const check = document.createElement("input");
    check.type = "checkbox";
    check.checked = row.assumed;
    check.addEventListener("change", () => {
      row.assumed = check.checked;
      fieldInputs.forEach((inp) => inp.disabled = row.assumed);
      el.classList.toggle("assumed", row.assumed);
      this.changed();
    });
    assume.appendChild(check);
    assume.appendChild(document.createTextNode(" Assume"));
    tools.appendChild(assume);
    const del = document.createElement("button");
    del.textContent = "\u2715";
    del.title = "Delete";
    del.addEventListener("click", () => {
      this.rows.splice(idx, 1);
      this.changed();
      this.render();
    });
    tools.appendChild(del);
    el.appendChild(tools);
    return el;
  }
  // --- Patching from an explanation node -------------------------------------
  // A fact's surface text as compared for add/remove (no "it is unknown whether"
  // prefix, no trailing period): the raw line, or the template filled with values.
  factBase(row) {
    return row.templateLabel === null ? row.raw.trim().replace(/\.\s*$/, "").trim() : fillTemplate(row.templateLabel, row.values);
  }
  // Normalise a fact's text for add/remove comparison. Besides trimming, dropping a
  // trailing period and collapsing whitespace, it canonicalises date tokens so a
  // scenario fact written "2021-10-09" matches the explanation's rendered
  // "2021-10-9T0:0:0.0" (same calendar date, different surface form).
  static norm(text) {
    let s = text.trim().replace(/\.\s*$/, "").replace(/\s+/g, " ").trim().toLowerCase();
    s = s.replace(
      /\b(\d{1,4})-(\d{1,2})-(\d{1,2})(t[\d:.]*)?/g,
      (_m, y, mo, d) => `${+y}-${+mo}-${+d}`
    );
    return s;
  }
  // Does a scenario fact matching `text` currently exist? (date-tolerant)
  hasFact(text) {
    const key = _ScenarioForm.norm((text || "").trim().replace(/\.\s*$/, "").trim());
    if (!key)
      return false;
    return this.rows.some((r) => _ScenarioForm.norm(this.factBase(r)) === key);
  }
  // Is `text` a sensible scenario fact to add — i.e. does it instantiate one of the
  // program's templates? (Compound/negated explanation literals do not.)
  matchesTemplate(text) {
    const base = (text || "").trim().replace(/\.\s*$/, "").trim();
    return !!base && !!matchFact(base, this.templates);
  }
  // Add a scenario fact from an explanation node's surface text (the LE literal).
  // If the fact is already present, only its "assumed" flag is updated. `assumed`
  // adds it as "it is unknown whether …" — the equivalent of the Assume checkbox.
  // Returns false if the text was empty (nothing done).
  addFact(text, assumed = false) {
    const base = (text || "").trim().replace(/\.\s*$/, "").trim();
    if (!base)
      return false;
    const key = _ScenarioForm.norm(base);
    const existing = this.rows.find((r) => _ScenarioForm.norm(this.factBase(r)) === key);
    let idx;
    if (existing) {
      existing.assumed = assumed;
      idx = this.rows.indexOf(existing);
    } else {
      const m = matchFact(base, this.templates);
      if (m)
        this.rows.push({ templateLabel: m.label, values: m.values, raw: "", assumed });
      else
        this.rows.push({ templateLabel: null, values: [], raw: base, assumed });
      idx = this.rows.length - 1;
    }
    this.changed();
    this.render();
    this.selectRow(idx);
    return true;
  }
  // Highlight, reveal and focus a row (used after adding a fact from a tree node).
  selectRow(idx) {
    const rowEl = this.opts.rowsEl.children[idx];
    if (!rowEl)
      return;
    this.opts.rowsEl.querySelectorAll(".fact-row.selected").forEach((e) => e.classList.remove("selected"));
    rowEl.classList.add("selected");
    rowEl.scrollIntoView({ block: "nearest", behavior: "smooth" });
    rowEl.querySelector("input.field")?.focus();
  }
  // Remove every scenario fact whose surface text matches `text` (ignoring an
  // "it is unknown whether" prefix). Returns how many rows were removed.
  removeFact(text) {
    const key = _ScenarioForm.norm((text || "").trim().replace(/\.\s*$/, "").trim());
    if (!key)
      return 0;
    const before = this.rows.length;
    this.rows = this.rows.filter((r) => _ScenarioForm.norm(this.factBase(r)) !== key);
    const removed = before - this.rows.length;
    if (removed > 0) {
      this.changed();
      this.render();
    }
    return removed;
  }
  // --- Producing text --------------------------------------------------------
  factText(row) {
    const base = this.factBase(row);
    if (!base)
      return "";
    return row.assumed ? `it is unknown whether ${base}` : base;
  }
  // Each fact's text (no trailing period), skipping wholly-empty rows.
  factLines() {
    return this.rows.map((r) => this.factText(r)).filter((t) => !!t);
  }
  // The facts as runnable LE text (each terminated by "."), for use as a custom
  // scenario. Tests are NOT included (they are not facts).
  factsText() {
    return this.factLines().map((t) => `${t}.`).join("\n");
  }
  // A full "scenario <name> is:" block; tests are appended commented-out.
  blockText(name) {
    const lines = [`scenario ${name} is:`];
    for (const t of this.factLines())
      lines.push(`    ${t}.`);
    if (this.testLines.length) {
      lines.push(`    % tests (review and uncomment to re-enable):`);
      for (const t of this.testLines)
        lines.push(`    % ${t}.`);
    }
    return lines.join("\n");
  }
};

// src/nl-input.ts
var TOKEN = "myToken123";
function assistantModel() {
  return localStorage.getItem("le-assistant-model") || "";
}
function assistantKeys() {
  return {
    openai: localStorage.getItem("le-openai-key"),
    anthropic: localStorage.getItem("le-anthropic-key"),
    google: localStorage.getItem("le-google-key"),
    groq: localStorage.getItem("le-groq-key"),
    together: localStorage.getItem("le-together-key")
  };
}
function ensureStyles() {
  if (document.getElementById("nl-input-styles"))
    return;
  const style = document.createElement("style");
  style.id = "nl-input-styles";
  style.textContent = `
        .nl-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex;
            align-items: center; justify-content: center; z-index: 1000; }
        .nl-dialog { background: var(--panel-bg, #252526); color: var(--text-color, #d4d4d4);
            border: 1px solid var(--border-color, #444); border-radius: 8px; width: min(640px, 92vw);
            max-height: 90vh; overflow: auto; padding: 18px 20px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        .nl-dialog h2 { margin: 0 0 8px 0; font-size: 16px; }
        .nl-instruction { color: var(--muted, #888); font-size: 12px; margin: 0 0 12px 0; line-height: 1.5; }
        .nl-dialog textarea { width: 100%; min-height: 96px; resize: vertical; font-family: inherit;
            font-size: 14px; background: var(--field-bg, #2d2d30); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 8px; box-sizing: border-box; }
        .nl-status { font-size: 12px; margin: 10px 0 0 0; min-height: 16px; white-space: pre-line; }
        .nl-status.error { color: #f48771; }
        .nl-status.warn { color: #e2b93d; }
        .nl-actions { display: flex; gap: 10px; align-items: center; justify-content: flex-end; margin-top: 14px; }
        .nl-actions .spacer { flex: 1; }
        .nl-model { color: var(--muted, #888); font-size: 11px; }
        .nl-dialog button { background: var(--input-bg, #3c3c3c); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 6px 12px; font: inherit; cursor: pointer; }
        .nl-dialog button.primary { background: var(--accent, #0e639c); color: #fff; border-color: var(--accent, #0e639c); }
        .nl-dialog button:disabled { opacity: 0.5; cursor: default; }
    `;
  document.head.appendChild(style);
}
function openNlInput(opts) {
  ensureStyles();
  const overlay = document.createElement("div");
  overlay.className = "nl-overlay";
  const dialog = document.createElement("div");
  dialog.className = "nl-dialog";
  overlay.appendChild(dialog);
  const h = document.createElement("h2");
  h.textContent = opts.title;
  const instr = document.createElement("p");
  instr.className = "nl-instruction";
  instr.textContent = opts.instruction;
  const textarea = document.createElement("textarea");
  textarea.placeholder = opts.placeholder || "Type your sentence(s) here\u2026";
  const status = document.createElement("div");
  status.className = "nl-status";
  const actions = document.createElement("div");
  actions.className = "nl-actions";
  const model = assistantModel();
  const modelLabel = document.createElement("span");
  modelLabel.className = "nl-model";
  modelLabel.textContent = model ? `Model: ${model}` : "No model configured";
  const spacer = document.createElement("span");
  spacer.className = "spacer";
  const cancel = document.createElement("button");
  cancel.textContent = "Cancel";
  const regenerate = document.createElement("button");
  regenerate.textContent = "Regenerate";
  regenerate.style.display = "none";
  const generate = document.createElement("button");
  generate.className = "primary";
  generate.textContent = "Generate";
  actions.appendChild(modelLabel);
  actions.appendChild(spacer);
  actions.appendChild(cancel);
  actions.appendChild(regenerate);
  actions.appendChild(generate);
  dialog.appendChild(h);
  dialog.appendChild(instr);
  dialog.appendChild(textarea);
  dialog.appendChild(status);
  dialog.appendChild(actions);
  document.body.appendChild(overlay);
  setTimeout(() => textarea.focus(), 0);
  const close = () => {
    overlay.remove();
    document.removeEventListener("keydown", onKey);
  };
  const onKey = (e) => {
    if (e.key === "Escape")
      close();
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      generate.click();
    }
  };
  document.addEventListener("keydown", onKey);
  cancel.addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay)
      close();
  });
  if (!model) {
    status.className = "nl-status warn";
    status.textContent = "Configure an LLM model first: in the main editor, Misc \u2192 API Keys\u2026";
    generate.disabled = true;
  }
  let primaryMode = "generate";
  let pendingLe = "";
  function toGenerateMode() {
    primaryMode = "generate";
    generate.textContent = "Generate";
    regenerate.style.display = "none";
  }
  textarea.addEventListener("input", () => {
    if (primaryMode === "insert")
      toGenerateMode();
  });
  async function run() {
    const sentence = textarea.value.trim();
    if (!sentence) {
      textarea.focus();
      return;
    }
    if (!assistantModel())
      return;
    generate.disabled = true;
    cancel.disabled = true;
    regenerate.disabled = true;
    status.className = "nl-status";
    status.textContent = "Generating and verifying\u2026";
    const templates = [...new Set(parseTemplateDefs(opts.source).map((d) => d.label))];
    try {
      const res = await fetch("/leapi", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: TOKEN,
          operation: "nl_to_le",
          kind: opts.kind,
          sentence,
          templates,
          content: opts.source,
          // the program, for baseline-diff verification
          model: assistantModel(),
          api_keys: assistantKeys()
        })
      }).then((r) => r.json());
      generate.disabled = false;
      cancel.disabled = false;
      regenerate.disabled = false;
      if (res && res.result === "ok" && typeof res.le === "string" && res.le.trim()) {
        const warnings = Array.isArray(res.warnings) ? res.warnings : [];
        if (warnings.length === 0) {
          opts.onResult(res.le);
          close();
        } else {
          pendingLe = res.le;
          primaryMode = "insert";
          generate.textContent = "Insert anyway";
          regenerate.style.display = "";
          status.className = "nl-status warn";
          status.textContent = `Verification found ${warnings.length} new issue${warnings.length === 1 ? "" : "s"} vs. your program:
` + warnings.map((w) => `\u2022 ${w}`).join("\n") + "\nYou can insert it anyway, or rephrase and regenerate.";
        }
      } else if (res && res.result === "ok") {
        toGenerateMode();
        status.className = "nl-status warn";
        status.textContent = "The model returned nothing that matches your templates. Try rephrasing.";
      } else {
        toGenerateMode();
        status.className = "nl-status error";
        status.textContent = "Error: " + (res && res.error || "the LLM request failed.");
      }
    } catch {
      generate.disabled = false;
      cancel.disabled = false;
      regenerate.disabled = false;
      toGenerateMode();
      status.className = "nl-status error";
      status.textContent = "Could not reach the server.";
    }
  }
  generate.addEventListener("click", () => {
    if (primaryMode === "insert") {
      opts.onResult(pendingLe);
      close();
    } else
      run();
  });
  regenerate.addEventListener("click", run);
}
function splitStatements(leText) {
  return leText.split(/\.(?=\s|$)/).map((s) => s.replace(/\s+/g, " ").trim()).filter(Boolean);
}

// src/scenario-editor.ts
var CHANNEL = "le-scenario-editor";
function initScenarioEditor(data) {
  const source = data.source || "";
  const blocks = parseScenarioBlocks(source);
  const blockByName = /* @__PURE__ */ new Map();
  blocks.forEach((b) => blockByName.set(b.name, b));
  const channel = new BroadcastChannel(CHANNEL);
  const $ = (id) => document.getElementById(id);
  const picker = $("scenario-picker");
  const nameInput = $("scenario-name");
  const statusEl = $("status");
  let loadedName = "";
  let dirty = false;
  function setStatus(text) {
    statusEl.textContent = text;
  }
  function markDirty() {
    dirty = true;
    setStatus("Unsaved changes");
  }
  const form = new ScenarioForm({
    source,
    rowsEl: $("rows"),
    addSelect: $("add-template"),
    btnAdd: $("btn-add"),
    onChange: markDirty,
    onWriteInEnglish: () => openNlInput({
      kind: "facts",
      source,
      title: "Add facts \u2014 write it in English",
      instruction: "Type one or more sentences describing precise facts to be added to the scenario. The facts must respect the predicates (templates) already in your program; if you need to expand these first, use the editor or the LE Assistant.",
      placeholder: "e.g. Alice is the mother of John, and John was born in the UK on 2021-10-09.",
      onResult: (leText) => {
        const facts = splitStatements(leText);
        facts.forEach((f) => form.addFact(f));
        setStatus(`Added ${facts.length} fact${facts.length === 1 ? "" : "s"} from English`);
      }
    })
  });
  picker.innerHTML = "";
  const newOpt = document.createElement("option");
  newOpt.value = "__new__";
  newOpt.textContent = "New\u2026";
  picker.appendChild(newOpt);
  blocks.forEach((b) => {
    const o = document.createElement("option");
    o.value = b.name;
    o.textContent = b.name;
    picker.appendChild(o);
  });
  function loadScenario(name) {
    const block = blockByName.get(name);
    loadedName = block ? block.name : "";
    nameInput.value = block ? block.name : "";
    form.loadFacts(block ? block.facts : []);
    dirty = false;
    const n = form.testLines.length;
    setStatus(block ? `Loaded scenario "${name}"${n ? ` (${n} test line${n > 1 ? "s" : ""} kept as comments)` : ""}` : "");
  }
  function newScenario() {
    loadedName = "";
    nameInput.value = "";
    form.clear();
    dirty = false;
    setStatus("New scenario");
  }
  function requireName() {
    const name = nameInput.value.trim();
    if (!name) {
      alert("Please give the scenario a name.");
      nameInput.focus();
      return null;
    }
    if (/\s/.test(name)) {
      alert("A scenario name must be a single word (no spaces).");
      nameInput.focus();
      return null;
    }
    return name;
  }
  document.getElementById("btn-copy").addEventListener("click", async () => {
    const name = requireName();
    if (!name)
      return;
    const text = form.blockText(name);
    try {
      await navigator.clipboard.writeText(text);
      dirty = false;
      setStatus("Copied to clipboard");
    } catch {
      window.prompt("Copy the scenario text:", text);
      dirty = false;
      setStatus("Copied");
    }
  });
  document.getElementById("btn-insert").addEventListener("click", () => {
    const name = requireName();
    if (!name)
      return;
    channel.postMessage({ type: "insert-scenario", name, blockText: form.blockText(name), replaceName: loadedName });
    dirty = false;
    setStatus("Inserted into editor");
    setTimeout(() => window.close(), 100);
  });
  picker.addEventListener("change", () => {
    if (dirty && !confirm("Discard unsaved changes and load the selected scenario?")) {
      picker.value = loadedName || "__new__";
      return;
    }
    if (picker.value === "__new__")
      newScenario();
    else
      loadScenario(picker.value);
  });
  nameInput.addEventListener("input", markDirty);
  window.addEventListener("beforeunload", (e) => {
    if (dirty) {
      e.preventDefault();
      e.returnValue = "";
      return "";
    }
  });
  picker.value = "__new__";
  newScenario();
}
export {
  initScenarioEditor
};

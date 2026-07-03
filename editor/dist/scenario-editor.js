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
  const sectionHeader = /^the\s+(knowledge\s+base|scenario|query|ontology|predicates|templates|fluents|events|target\s+language)/im;
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
      if (main.includes("*"))
        defs.push({ label: main, isUndefined });
      const opp = annotation.match(/opposite:\s*([^;]+)/i);
      if (opp) {
        const o = opp[1].replace(/[.,;]\s*$/, "").trim();
        if (o.includes("*"))
          defs.push({ label: o, isUndefined });
      }
      for (const sm of annotation.matchAll(/\bsynonym\s+([^;]+)/gi)) {
        const s = sm[1].replace(/[.,;]\s*$/, "").trim();
        if (s.includes("*"))
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
  const sorted = [...templates].sort((a, b) => literalLength(b) - literalLength(a));
  for (const label of sorted) {
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
function parseScenarioBlocks(source) {
  const blocks = [];
  const lines = source.split("\n");
  const offsets = [];
  let off = 0;
  for (const ln of lines) {
    offsets.push(off);
    off += ln.length + 1;
  }
  const headerRe = /^scenario\s+(.+?)\s+is\s*:/i;
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
    blocks.push({ name, start, end, facts: splitFacts(bodyLines) });
  }
  return blocks;
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
    opts.btnAdd.addEventListener("click", () => {
      const val = opts.addSelect.value;
      if (!val)
        return;
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
  static norm(text) {
    return text.trim().replace(/\.\s*$/, "").replace(/\s+/g, " ").trim().toLowerCase();
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
    onChange: markDirty
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

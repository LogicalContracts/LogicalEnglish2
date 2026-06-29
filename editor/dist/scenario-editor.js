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
      const opp = annotation.match(/opposite:\s*(.+)/i);
      if (opp) {
        const o = opp[1].replace(/[.,;]\s*$/, "").trim();
        if (o.includes("*"))
          defs.push({ label: o, isUndefined });
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
function splitFacts(bodyLines) {
  const facts = [];
  let cur = "";
  for (const raw of bodyLines) {
    const t = raw.trim();
    if (t === "" || t.startsWith("%"))
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
var ScenarioForm = class {
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
      this.rows.push({ templateLabel: val, values: [], raw: "" });
      this.changed();
      this.render();
      opts.rowsEl.lastElementChild?.querySelector("input")?.focus();
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
      const m = matchFact(fact, this.templates);
      if (m)
        this.rows.push({ templateLabel: m.label, values: m.values, raw: "" });
      else
        this.rows.push({ templateLabel: null, values: [], raw: fact });
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
          this.sizeField(input);
          input.addEventListener("input", () => {
            row.values[fi] = input.value;
            this.sizeField(input);
            this.changed();
          });
          el.appendChild(input);
        }
      }
    }
    const tools = document.createElement("div");
    tools.className = "row-tools";
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
  // --- Producing text --------------------------------------------------------
  factText(row) {
    if (row.templateLabel === null)
      return row.raw.trim().replace(/\.\s*$/, "").trim();
    return fillTemplate(row.templateLabel, row.values);
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

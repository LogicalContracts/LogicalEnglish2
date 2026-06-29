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

// src/scenario-editor.ts
var CHANNEL = "le-scenario-editor";
function initScenarioEditor(data) {
  const source = data.source || "";
  const defs = parseTemplateDefs(source);
  const SYSTEM_TYPE = ["*a thing* is a *type*", "*a thing* is an *type*"];
  const templates = [...defs.map((d) => d.label), ...SYSTEM_TYPE];
  const blocks = parseScenarioBlocks(source);
  const blockByName = /* @__PURE__ */ new Map();
  blocks.forEach((b) => blockByName.set(b.name, b));
  const usedLabels = /* @__PURE__ */ new Set();
  for (const block of blocks) {
    for (const fact of block.facts) {
      const mm = matchFact(fact, templates);
      if (mm)
        usedLabels.add(mm.label);
    }
  }
  const seen = /* @__PURE__ */ new Set();
  const addableTemplates = [];
  for (const d of defs) {
    if ((d.isUndefined || usedLabels.has(d.label)) && !seen.has(d.label)) {
      seen.add(d.label);
      addableTemplates.push(d.label);
    }
  }
  for (const t of SYSTEM_TYPE) {
    if (usedLabels.has(t) && !seen.has(t)) {
      seen.add(t);
      addableTemplates.push(t);
    }
  }
  const channel = new BroadcastChannel(CHANNEL);
  const $ = (id) => document.getElementById(id);
  const picker = $("scenario-picker");
  const nameInput = $("scenario-name");
  const rowsEl = $("rows");
  const addSelect = $("add-template");
  const btnAdd = $("btn-add");
  const btnCopy = $("btn-copy");
  const btnInsert = $("btn-insert");
  const statusEl = $("status");
  let rows = [];
  let loadedName = "";
  let dirty = false;
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
  addSelect.innerHTML = "";
  addableTemplates.forEach((label) => {
    const o = document.createElement("option");
    o.value = label;
    o.textContent = label.replace(/\*/g, "");
    addSelect.appendChild(o);
  });
  function markDirty() {
    dirty = true;
    setStatus("Unsaved changes");
  }
  function setStatus(text) {
    statusEl.textContent = text;
  }
  function sizeField(input) {
    const n = Math.max((input.value || input.placeholder).length + 1, 6);
    input.size = Math.min(n, 80);
  }
  function loadScenario(name) {
    const block = blockByName.get(name);
    loadedName = block ? block.name : "";
    nameInput.value = block ? block.name : "";
    rows = [];
    if (block) {
      for (const fact of block.facts) {
        const m = matchFact(fact, templates);
        if (m)
          rows.push({ templateLabel: m.label, values: m.values, raw: "" });
        else
          rows.push({ templateLabel: null, values: [], raw: fact });
      }
    }
    render();
    dirty = false;
    setStatus(block ? `Loaded scenario "${name}"` : "");
  }
  function newScenario() {
    loadedName = "";
    nameInput.value = "";
    rows = [];
    render();
    dirty = false;
    setStatus("New scenario");
  }
  function render() {
    rowsEl.innerHTML = "";
    if (rows.length === 0) {
      const hint = document.createElement("div");
      hint.className = "empty-hint";
      hint.textContent = "No facts yet \u2014 pick a template below and click \u201CAdd\u201D.";
      rowsEl.appendChild(hint);
      return;
    }
    rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
  }
  function renderRow(row, idx) {
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
          sizeField(input);
          input.addEventListener("input", () => {
            row.values[fi] = input.value;
            sizeField(input);
            markDirty();
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
      rows.splice(idx, 1);
      markDirty();
      render();
    });
    tools.appendChild(del);
    el.appendChild(tools);
    return el;
  }
  function factText(row) {
    if (row.templateLabel === null)
      return row.raw.trim().replace(/\.\s*$/, "").trim();
    return fillTemplate(row.templateLabel, row.values);
  }
  function buildBlockText(name) {
    const lines = [`scenario ${name} is:`];
    for (const row of rows) {
      const text = factText(row);
      if (!text)
        continue;
      lines.push(`    ${text}.`);
    }
    return lines.join("\n");
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
  btnAdd.addEventListener("click", () => {
    const val = addSelect.value;
    if (!val)
      return;
    rows.push({ templateLabel: val, values: [], raw: "" });
    markDirty();
    render();
    const last = rowsEl.lastElementChild;
    last?.querySelector("input")?.focus();
  });
  btnCopy.addEventListener("click", async () => {
    const name = requireName();
    if (!name)
      return;
    const text = buildBlockText(name);
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
  btnInsert.addEventListener("click", () => {
    const name = requireName();
    if (!name)
      return;
    const blockText = buildBlockText(name);
    channel.postMessage({ type: "insert-scenario", name, blockText, replaceName: loadedName });
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

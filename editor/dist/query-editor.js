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
function parseQueryBlocks(source) {
  return scanBlocks(source, /^query\s+(.+?)\s+is\s*:/i).map((b) => {
    const body = b.bodyLines.map((l) => stripInlineComment(l).trim()).filter((t) => t !== "").join(" ").replace(/\.\s*$/, "").trim();
    return { name: b.name, start: b.start, end: b.end, body };
  });
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

// src/query-editor.ts
var CHANNEL = "le-query-editor";
var NEG_PREFIX = /^it is not the case that\s+/i;
function initQueryEditor(data) {
  const source = data.source || "";
  const templates = parseTemplateDefs(source).map((d) => d.label);
  const addable = [...new Set(templates)];
  const blocks = parseQueryBlocks(source);
  const blockByName = /* @__PURE__ */ new Map();
  blocks.forEach((b) => blockByName.set(b.name, b));
  const channel = new BroadcastChannel(CHANNEL);
  const $ = (id) => document.getElementById(id);
  const picker = $("query-picker");
  const nameInput = $("query-name");
  const rowsEl = $("rows");
  const addSelect = $("add-template");
  const statusEl = $("status");
  let loadedName = "";
  let dirty = false;
  let rows = [];
  const setStatus = (text) => {
    statusEl.textContent = text;
  };
  const markDirty = () => {
    dirty = true;
    setStatus("Unsaved changes");
  };
  addSelect.innerHTML = "";
  for (const label of addable) {
    const o = document.createElement("option");
    o.value = label;
    o.textContent = label.replace(/\*/g, "");
    addSelect.appendChild(o);
  }
  $("btn-add").addEventListener("click", () => {
    const val = addSelect.value;
    if (!val)
      return;
    rows.push({ templateLabel: val, values: [], raw: "", negated: false, connective: "and" });
    markDirty();
    render();
    rowsEl.lastElementChild?.querySelector("input.field, input.raw")?.focus();
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
  function parseBody(body) {
    if (!body.trim())
      return [];
    const toks = body.split(/\s+(and|or)\s+/i);
    const parts = [{ connective: "and", text: toks[0] }];
    for (let i = 1; i < toks.length; i += 2) {
      parts.push({ connective: toks[i].toLowerCase(), text: toks[i + 1] ?? "" });
    }
    const parsed = [];
    for (const p of parts) {
      const negated = NEG_PREFIX.test(p.text);
      const inner = negated ? p.text.replace(NEG_PREFIX, "").trim() : p.text.trim();
      const m = matchFact(inner, templates);
      if (!m)
        return [{ templateLabel: null, values: [], raw: body.trim(), negated: false, connective: "and" }];
      parsed.push({ templateLabel: m.label, values: m.values, raw: "", negated, connective: p.connective });
    }
    return parsed;
  }
  function loadQuery(name) {
    const block = blockByName.get(name);
    loadedName = block ? block.name : "";
    nameInput.value = block ? block.name : "";
    rows = block ? parseBody(block.body) : [];
    dirty = false;
    render();
    setStatus(block ? `Loaded query "${name}"` : "");
  }
  function newQuery() {
    loadedName = "";
    nameInput.value = "";
    rows = [];
    dirty = false;
    render();
    setStatus("New query");
  }
  function sizeField(input) {
    const n = Math.max((input.value || input.placeholder).length + 1, 6);
    input.size = Math.min(n, 80);
  }
  function render() {
    rowsEl.innerHTML = "";
    if (rows.length === 0) {
      const hint = document.createElement("div");
      hint.className = "empty-hint";
      hint.textContent = "No conditions yet \u2014 pick a template below and click \u201CAdd\u201D.";
      rowsEl.appendChild(hint);
      return;
    }
    rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
  }
  function renderRow(row, idx) {
    const el = document.createElement("div");
    el.className = "fact-row";
    if (row.negated)
      el.classList.add("negated");
    if (idx > 0) {
      const conn = document.createElement("select");
      conn.className = "connective";
      for (const c of ["and", "or"]) {
        const o = document.createElement("option");
        o.value = c;
        o.textContent = c;
        conn.appendChild(o);
      }
      conn.value = row.connective;
      conn.addEventListener("change", () => {
        row.connective = conn.value;
        markDirty();
      });
      el.appendChild(conn);
    } else {
      const spacer = document.createElement("span");
      spacer.className = "connective-spacer";
      el.appendChild(spacer);
    }
    if (row.negated) {
      const neg = document.createElement("span");
      neg.className = "neg-phrase";
      neg.textContent = "it is not the case that";
      el.appendChild(neg);
    }
    if (row.templateLabel === null) {
      const input = document.createElement("input");
      input.type = "text";
      input.className = "raw";
      input.value = row.raw;
      input.placeholder = "condition";
      input.size = Math.min(Math.max(row.raw.length + 1, 20), 80);
      input.addEventListener("input", () => {
        row.raw = input.value;
        input.size = Math.min(Math.max(input.value.length + 1, 20), 80);
        markDirty();
      });
      el.appendChild(input);
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
          input.title = `${seg.text} \u2014 a value, or a query variable like "which ${seg.text.replace(/^(a|an|the)\s+/i, "")}"`;
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
    const negLabel = document.createElement("label");
    negLabel.className = "negate";
    negLabel.title = 'Wrap this condition in "it is not the case that \u2026"';
    const check = document.createElement("input");
    check.type = "checkbox";
    check.checked = row.negated;
    check.addEventListener("change", () => {
      row.negated = check.checked;
      markDirty();
      render();
    });
    negLabel.appendChild(check);
    negLabel.appendChild(document.createTextNode(" not"));
    tools.appendChild(negLabel);
    const del = document.createElement("button");
    del.textContent = "\u2715";
    del.title = "Delete condition";
    del.addEventListener("click", () => {
      rows.splice(idx, 1);
      markDirty();
      render();
    });
    tools.appendChild(del);
    el.appendChild(tools);
    return el;
  }
  function condBase(row) {
    if (row.templateLabel === null)
      return row.raw.trim().replace(/\.\s*$/, "").trim();
    const segs = splitTemplate(row.templateLabel);
    let fi = 0;
    const out = segs.map((s) => {
      if (s.kind === "literal")
        return s.text;
      const v = (row.values[fi++] ?? "").trim();
      return v || s.text;
    }).join(" ");
    return out.replace(/\s+/g, " ").trim();
  }
  function condText(row) {
    const base = condBase(row);
    if (!base)
      return "";
    return row.negated ? `it is not the case that ${base}` : base;
  }
  function bodyLines() {
    const out = [];
    rows.forEach((row) => {
      const c = condText(row);
      if (!c)
        return;
      out.push(out.length === 0 ? c : `${row.connective} ${c}`);
    });
    return out;
  }
  function blockText(name) {
    const lines = bodyLines();
    const body = lines.length ? lines.map((l) => `    ${l}`).join("\n") : "    ";
    return `query ${name} is:
${body}.`;
  }
  function requireName() {
    const name = nameInput.value.trim();
    if (!name) {
      alert("Please give the query a name.");
      nameInput.focus();
      return null;
    }
    if (/\s/.test(name)) {
      alert("A query name must be a single word or number (no spaces).");
      nameInput.focus();
      return null;
    }
    if (bodyLines().length === 0) {
      alert("Add at least one condition to the query.");
      return null;
    }
    return name;
  }
  $("btn-copy").addEventListener("click", async () => {
    const name = requireName();
    if (!name)
      return;
    const text = blockText(name);
    try {
      await navigator.clipboard.writeText(text);
      dirty = false;
      setStatus("Copied to clipboard");
    } catch {
      window.prompt("Copy the query text:", text);
      dirty = false;
      setStatus("Copied");
    }
  });
  $("btn-insert").addEventListener("click", () => {
    const name = requireName();
    if (!name)
      return;
    channel.postMessage({ type: "insert-query", name, blockText: blockText(name), replaceName: loadedName });
    dirty = false;
    setStatus("Inserted into editor");
    setTimeout(() => window.close(), 100);
  });
  picker.addEventListener("change", () => {
    if (dirty && !confirm("Discard unsaved changes and load the selected query?")) {
      picker.value = loadedName || "__new__";
      return;
    }
    if (picker.value === "__new__")
      newQuery();
    else
      loadQuery(picker.value);
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
  newQuery();
}
export {
  initQueryEditor
};

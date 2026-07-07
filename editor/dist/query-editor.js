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
    const bodyLines = b.bodyLines.map((l) => stripInlineComment(l).replace(/\s+$/, "")).filter((l) => l.trim() !== "");
    const body = bodyLines.map((l) => l.trim()).join(" ").replace(/\.\s*$/, "").trim();
    return { name: b.name, start: b.start, end: b.end, body, bodyLines };
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
        .nl-dialog h2 { margin: 0 0 8px 0; font-size: 16px; cursor: move; user-select: none; }
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
function makeDraggable(box, handle) {
  let dx = 0, dy = 0;
  let startX = 0, startY = 0, ox = 0, oy = 0, dragging = false;
  const onMove = (e) => {
    if (!dragging)
      return;
    dx = ox + (e.clientX - startX);
    dy = oy + (e.clientY - startY);
    box.style.transform = `translate(${dx}px, ${dy}px)`;
  };
  const onUp = () => {
    dragging = false;
    document.removeEventListener("mousemove", onMove);
    document.removeEventListener("mouseup", onUp);
    document.body.style.userSelect = "";
  };
  handle.addEventListener("mousedown", (e) => {
    dragging = true;
    startX = e.clientX;
    startY = e.clientY;
    ox = dx;
    oy = dy;
    document.body.style.userSelect = "none";
    document.addEventListener("mousemove", onMove);
    document.addEventListener("mouseup", onUp);
    e.preventDefault();
  });
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
  makeDraggable(dialog, h);
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

// src/query-editor.ts
var WRITE_IN_ENGLISH = "__write_in_english__";
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
  const nlOpt = document.createElement("option");
  nlOpt.value = WRITE_IN_ENGLISH;
  nlOpt.textContent = "Write it in English";
  addSelect.appendChild(nlOpt);
  $("btn-add").addEventListener("click", () => {
    const val = addSelect.value;
    if (!val)
      return;
    if (val === WRITE_IN_ENGLISH) {
      writeInEnglish();
      return;
    }
    const indent = rows.length ? rows[rows.length - 1].indent : 0;
    rows.push({ templateLabel: val, values: [], raw: "", negated: false, connective: "and", indent });
    markDirty();
    render();
    rowsEl.lastElementChild?.querySelector("input.field, input.raw")?.focus();
  });
  function writeInEnglish() {
    openNlInput({
      kind: "query",
      source,
      title: "Add conditions \u2014 write it in English",
      instruction: "Type one or more sentences describing the query to build (a question, and its conditions). The query must respect the predicates (templates) already in your program; if you need to expand these first, use the editor or the LE Assistant.",
      placeholder: "e.g. which person is happy and is not the brother of Bob",
      onResult: (leText) => {
        const lines = leText.split(/\r?\n/).filter((l) => l.trim() !== "");
        const added = parseBody(lines);
        rows.push(...added);
        normalizeIndents();
        markDirty();
        render();
        setStatus(`Added ${added.length} condition${added.length === 1 ? "" : "s"} from English`);
      }
    });
  }
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
  function leadWidth(s) {
    let w = 0;
    for (const ch of s) {
      if (ch === " ")
        w++;
      else if (ch === "	")
        w += 4;
      else
        break;
    }
    return w;
  }
  function normalizeIndents() {
    let prev = -1;
    for (const r of rows) {
      r.indent = Math.max(0, Math.min(r.indent, prev + 1));
      prev = r.indent;
    }
  }
  function parseBody(bodyLines2) {
    if (bodyLines2.length === 0)
      return [];
    const conds = [];
    for (const raw of bodyLines2) {
      const trimmed = raw.trim();
      const cm = trimmed.match(/^(and|or)\b\s*/i);
      if (conds.length === 0) {
        conds.push({ width: leadWidth(raw), connective: "and", text: trimmed });
      } else if (cm) {
        conds.push({ width: leadWidth(raw), connective: cm[1].toLowerCase(), text: trimmed.slice(cm[0].length) });
      } else {
        conds[conds.length - 1].text += " " + trimmed;
      }
    }
    conds[conds.length - 1].text = conds[conds.length - 1].text.replace(/\.\s*$/, "").trim();
    const widths = [...new Set(conds.map((c) => c.width))].sort((a, b) => a - b);
    const wholeBody = bodyLines2.map((l) => l.trim()).join(" ").replace(/\.\s*$/, "").trim();
    const parsed = [];
    for (const c of conds) {
      const negated = NEG_PREFIX.test(c.text);
      const inner = negated ? c.text.replace(NEG_PREFIX, "").trim() : c.text.trim();
      const m = matchFact(inner, templates);
      if (!m)
        return [{ templateLabel: null, values: [], raw: wholeBody, negated: false, connective: "and", indent: 0 }];
      parsed.push({ templateLabel: m.label, values: m.values, raw: "", negated, connective: c.connective, indent: widths.indexOf(c.width) });
    }
    return parsed;
  }
  function loadQuery(name) {
    const block = blockByName.get(name);
    loadedName = block ? block.name : "";
    nameInput.value = block ? block.name : "";
    rows = block ? parseBody(block.bodyLines) : [];
    normalizeIndents();
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
  function indentRow(idx, delta) {
    rows[idx].indent = Math.max(0, rows[idx].indent + delta);
    normalizeIndents();
    markDirty();
    render();
  }
  function renderRow(row, idx) {
    const el = document.createElement("div");
    el.className = "fact-row";
    if (row.negated)
      el.classList.add("negated");
    el.style.marginLeft = `${row.indent * 28}px`;
    if (row.indent > 0)
      el.classList.add("indented");
    const maxIndent = idx > 0 ? rows[idx - 1].indent + 1 : 0;
    const indentTools = document.createElement("div");
    indentTools.className = "indent-tools";
    const outdent = document.createElement("button");
    outdent.className = "indent-btn";
    outdent.textContent = "\u21E4";
    outdent.title = "Unindent (widen this condition\u2019s scope)";
    outdent.disabled = row.indent === 0;
    outdent.addEventListener("click", () => indentRow(idx, -1));
    const indent = document.createElement("button");
    indent.className = "indent-btn";
    indent.textContent = "\u21E5";
    indent.title = "Indent (nest this condition to bind tighter)";
    indent.disabled = row.indent >= maxIndent;
    indent.addEventListener("click", () => indentRow(idx, 1));
    indentTools.appendChild(outdent);
    indentTools.appendChild(indent);
    el.appendChild(indentTools);
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
      const conn = out.length === 0 ? "" : `${row.connective} `;
      out.push(`${" ".repeat(4 + row.indent * 4)}${conn}${c}`);
    });
    return out;
  }
  function blockText(name) {
    const lines = bodyLines();
    const body = lines.length ? lines.join("\n") : "    ";
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

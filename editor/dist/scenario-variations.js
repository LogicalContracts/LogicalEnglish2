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

// src/explanation-view.ts
var activeView = null;
var menusWired = false;
function wireMenus(m) {
  if (menusWired)
    return;
  menusWired = true;
  document.addEventListener("click", () => {
    m.answerContextMenu.style.display = "none";
    m.explanationContextMenu.style.display = "none";
  });
  m.menuCopyAnswer.addEventListener("click", (e) => {
    e.stopPropagation();
    if (activeView && activeView.currentAnswerToCopy)
      navigator.clipboard.writeText(activeView.currentAnswerToCopy);
    m.answerContextMenu.style.display = "none";
  });
  m.menuGotoOriginal.addEventListener("click", (e) => {
    e.stopPropagation();
    activeView?.gotoOriginal();
    m.explanationContextMenu.style.display = "none";
  });
  m.menuCopyExplanation.addEventListener("click", (e) => {
    e.stopPropagation();
    activeView?.copyExplanation();
    m.explanationContextMenu.style.display = "none";
  });
}
var ExplanationView = class {
  currentAnswerToCopy = "";
  o;
  m;
  lastWhy = null;
  currentRepeatedOf = null;
  pathToContainer = /* @__PURE__ */ new Map();
  currentExpansion = null;
  fullByLiteral = /* @__PURE__ */ new Map();
  // Per-answer expansion state (keyed by the answer's `why` object), so toggles
  // persist when switching between answers.
  expansionStore = /* @__PURE__ */ new WeakMap();
  constructor(opts) {
    this.o = opts;
    this.m = opts.menus;
    wireMenus(opts.menus);
  }
  failedNodePrefix() {
    return this.o.failedNodePrefix?.() ?? "x ";
  }
  hierarchical() {
    return this.o.hierarchicalNumbering?.() ?? false;
  }
  clear() {
    this.o.answersList.innerHTML = "";
    this.o.explanationTree.innerHTML = "";
    this.lastWhy = null;
  }
  rerender() {
    if (this.lastWhy)
      this.renderExplanation(this.lastWhy);
  }
  // e.g. after a preference change
  showMessage(text) {
    this.o.answersList.textContent = text;
    this.o.explanationTree.innerHTML = "";
  }
  // Render the answer list of an `answeringQuery` response and auto-select one.
  // Handles the success (results), failure (why), interrupted and error cases.
  showResults(res, selectIndex = 0) {
    const answersList = this.o.answersList;
    answersList.innerHTML = "";
    this.o.explanationTree.innerHTML = "";
    this.m.answerTooltip.style.display = "none";
    if (res && res.results && res.results.length > 0) {
      const target = Math.min(Math.max(selectIndex, 0), res.results.length - 1);
      res.results.forEach((result, index) => {
        const item = document.createElement("div");
        item.className = "answer-item";
        item.textContent = result.answer;
        const unknowns = Array.isArray(result.unknowns) ? result.unknowns : [];
        if (unknowns.length > 0) {
          item.classList.add("has-unknowns");
          const marker = document.createElement("span");
          marker.className = "unknowns-marker";
          marker.textContent = "?";
          item.appendChild(marker);
          this.attachAnswerTooltip(item, unknowns);
        }
        item.addEventListener("click", () => {
          answersList.querySelectorAll(".answer-item").forEach((el) => el.classList.remove("selected"));
          item.classList.add("selected");
          this.renderExplanation(result.why);
          this.o.onSelectAnswer?.(index + 1);
        });
        item.addEventListener("contextmenu", (e) => this.answerMenu(e, result.answer));
        answersList.appendChild(item);
        if (index === target)
          item.click();
      });
    } else if (res && res.why) {
      const item = document.createElement("div");
      item.className = "answer-item failure selected";
      item.style.color = "#f48771";
      item.textContent = "No answers (false)";
      item.addEventListener("click", () => {
        answersList.querySelectorAll(".answer-item").forEach((el) => el.classList.remove("selected"));
        item.classList.add("selected");
        this.renderExplanation(res.why);
      });
      item.addEventListener("contextmenu", (e) => this.answerMenu(e, "No answers (false)"));
      answersList.appendChild(item);
      this.renderExplanation(res.why);
    } else if (res && res.interrupted) {
      answersList.textContent = "Query interrupted.";
    } else if (res && res.error) {
      answersList.textContent = "Error: " + res.error;
    } else {
      answersList.textContent = "No results returned.";
    }
  }
  answerMenu(e, answer) {
    e.preventDefault();
    activeView = this;
    this.currentAnswerToCopy = answer;
    this.m.answerContextMenu.style.display = "block";
    this.m.answerContextMenu.style.left = `${e.clientX}px`;
    this.m.answerContextMenu.style.top = `${e.clientY}px`;
  }
  // --- Unknown-goal tooltip --------------------------------------------------
  attachAnswerTooltip(item, unknowns) {
    const tip = this.m.answerTooltip;
    item.addEventListener("mouseenter", (e) => {
      const title = document.createElement("div");
      title.className = "tooltip-title";
      title.textContent = unknowns.length === 1 ? "Unknown goal:" : `${unknowns.length} unknown goals:`;
      tip.innerHTML = "";
      tip.appendChild(title);
      unknowns.forEach((u) => {
        const line = document.createElement("div");
        line.className = "tooltip-unknown";
        line.textContent = u;
        tip.appendChild(line);
      });
      tip.style.display = "block";
      this.positionTooltip(e);
    });
    item.addEventListener("mousemove", (e) => {
      if (tip.style.display === "block")
        this.positionTooltip(e);
    });
    item.addEventListener("mouseleave", () => {
      tip.style.display = "none";
    });
  }
  positionTooltip(e) {
    const tip = this.m.answerTooltip;
    const offset = 12;
    let x = e.clientX + offset, y = e.clientY + offset;
    const rect = tip.getBoundingClientRect();
    if (x + rect.width > window.innerWidth)
      x = e.clientX - rect.width - offset;
    if (y + rect.height > window.innerHeight)
      y = e.clientY - rect.height - offset;
    tip.style.left = `${Math.max(0, x)}px`;
    tip.style.top = `${Math.max(0, y)}px`;
  }
  // --- Copy / navigate context-menu actions ----------------------------------
  gotoOriginal() {
    if (this.currentRepeatedOf) {
      const target = this.pathToContainer.get(this.currentRepeatedOf);
      if (target)
        this.revealAndHighlight(target);
    }
  }
  copyExplanation() {
    if (!this.lastWhy)
      return;
    const text = this.explanationToText(this.lastWhy, 0, "");
    const html = this.explanationToHtml(this.lastWhy, 0, "");
    try {
      navigator.clipboard.write([new ClipboardItem({
        "text/plain": new Blob([text], { type: "text/plain" }),
        "text/html": new Blob([html], { type: "text/html" })
      })]);
    } catch {
      navigator.clipboard.writeText(text);
    }
  }
  explanationToText(node, depth = 0, prefix = "") {
    if (Array.isArray(node))
      return node.map((n, i) => this.explanationToText(n, depth, (i + 1).toString())).join("");
    const indent = "  ".repeat(depth);
    let text = node && typeof node === "object" ? node.literal ?? "" : node;
    if (node.type === "failure")
      text = `${this.failedNodePrefix()}${text}`;
    if (node.repeated) {
      const c = node.repeatedCount;
      text = typeof c === "number" && c > 1 ? `${text} [${c} repeated sub-explanations]` : `${text} [Repeated sub-explanation]`;
    }
    if (this.hierarchical() && prefix && depth > 0)
      text = `${prefix} ${text}`;
    let result = `${indent}${text}
`;
    if (node.children)
      node.children.forEach((child, i) => result += this.explanationToText(child, depth + 1, prefix ? `${prefix}.${i + 1}` : `${i + 1}`));
    return result;
  }
  explanationToHtml(node, depth = 0, prefix = "") {
    if (Array.isArray(node))
      return node.map((n, i) => this.explanationToHtml(n, depth, (i + 1).toString())).join("");
    const indent = "&nbsp;&nbsp;".repeat(depth);
    let text = node && typeof node === "object" ? node.literal ?? "" : node;
    if (node.type === "failure")
      text = `${this.failedNodePrefix()}${text}`;
    if (node.repeated) {
      const c = node.repeatedCount;
      text = typeof c === "number" && c > 1 ? `${text} [${c} repeated sub-explanations]` : `${text} [Repeated sub-explanation]`;
    }
    if (this.hierarchical() && prefix && depth > 0)
      text = `${prefix} ${text}`;
    const color = node.type === "failure" ? "#f48771" : node.type === "unknown" ? "#e2b93d" : "#89d185";
    let result = `<div style="color: ${color}; font-family: monospace; white-space: nowrap;">${indent}${text}</div>`;
    if (node.children)
      node.children.forEach((child, i) => result += this.explanationToHtml(child, depth + 1, prefix ? `${prefix}.${i + 1}` : `${i + 1}`));
    return result;
  }
  revealAndHighlight(container) {
    const tree = this.o.explanationTree;
    let el = container;
    while (el && el !== tree) {
      const parent = el.parentElement;
      if (parent && parent.classList.contains("tree-children")) {
        parent.style.display = "block";
        const ownerLabel = parent.previousElementSibling;
        const toggle = ownerLabel?.querySelector(".tree-toggle");
        if (toggle)
          toggle.textContent = "-";
        const ownerPath = parent.parentElement?.dataset.path;
        if (ownerPath)
          this.currentExpansion?.set(ownerPath, true);
      }
      el = el.parentElement;
    }
    container.scrollIntoView({ block: "center", behavior: "smooth" });
    const label = container.querySelector(":scope > .tree-label");
    if (label) {
      label.classList.add("explanation-highlight");
      setTimeout(() => label.classList.remove("explanation-highlight"), 2200);
    }
  }
  // --- The explanation tree --------------------------------------------------
  renderExplanation(why) {
    activeView = this;
    const tree = this.o.explanationTree;
    this.lastWhy = why;
    tree.innerHTML = "";
    this.pathToContainer = /* @__PURE__ */ new Map();
    this.fullByLiteral = /* @__PURE__ */ new Map();
    if (!why)
      return;
    let expansion;
    if (why !== null && typeof why === "object") {
      expansion = this.expansionStore.get(why) || /* @__PURE__ */ new Map();
      this.expansionStore.set(why, expansion);
    } else {
      expansion = /* @__PURE__ */ new Map();
    }
    this.currentExpansion = expansion;
    tree.oncontextmenu = (e) => {
      if (e.target === tree) {
        e.preventDefault();
        activeView = this;
        this.currentRepeatedOf = null;
        this.m.menuGotoOriginal.style.display = "none";
        this.m.explanationContextMenu.style.display = "block";
        this.m.explanationContextMenu.style.left = `${e.clientX}px`;
        this.m.explanationContextMenu.style.top = `${e.clientY}px`;
      }
    };
    const repeatedLabels = [];
    const navTargetFor = (node, prefix) => {
      if (!node || !node.repeated)
        return null;
      let target = null;
      if (typeof node.repeatedOf === "string")
        target = node.repeatedOf;
      else if ((!node.children || node.children.length === 0) && typeof node.literal === "string") {
        target = this.fullByLiteral.get(node.literal) ?? null;
      }
      return target && target !== prefix ? target : null;
    };
    const createNode = (node, depth, prefix = "") => {
      const container = document.createElement("div");
      container.className = "tree-node";
      container.dataset.path = prefix;
      this.pathToContainer.set(prefix, container);
      const label = document.createElement("div");
      label.className = `tree-label ${node.type || "success"}`;
      const hasChildren = node.children && node.children.length > 0;
      if (hasChildren && typeof node.literal === "string" && !this.fullByLiteral.has(node.literal)) {
        this.fullByLiteral.set(node.literal, prefix);
      }
      const titleParts = [];
      if (node.type === "failure")
        titleParts.push("Failed: this condition could not be proven");
      else if (node.type === "unknown")
        titleParts.push('Unknown: could not be proven true or false, but was assumed true because it matches an "unknown" template');
      else
        titleParts.push(node.naf === true ? "Succeeded: this negative condition holds (the inner statement could not be proven)" : "Succeeded: this condition was proven");
      if (node.repeated) {
        label.classList.add("repeated");
        repeatedLabels.push({ label, node, prefix });
        const c = node.repeatedCount;
        const noun = hasChildren ? "sub-explanation" : "occurrence";
        titleParts.push(typeof c === "number" && c > 1 ? `${c} repeated ${noun}s` : `Repeated ${noun}`);
      }
      label.title = titleParts.join(" \xB7 ");
      const isExpandedNow = expansion.has(prefix) ? expansion.get(prefix) : depth < 2;
      if (hasChildren) {
        const toggle = document.createElement("span");
        toggle.className = "tree-toggle";
        toggle.textContent = isExpandedNow ? "-" : "+";
        label.appendChild(toggle);
      }
      const textEl = document.createElement("span");
      textEl.className = "tree-text";
      let labelText = node && typeof node === "object" ? node.literal ?? "" : node;
      if (this.hierarchical() && prefix && depth > 0)
        labelText = `${prefix} ${labelText}`;
      textEl.textContent = labelText;
      label.appendChild(textEl);
      label.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        e.stopPropagation();
        activeView = this;
        this.currentRepeatedOf = navTargetFor(node, prefix);
        this.m.menuGotoOriginal.style.display = this.currentRepeatedOf ? "block" : "none";
        this.m.explanationContextMenu.style.display = "block";
        this.m.explanationContextMenu.style.left = `${e.clientX}px`;
        this.m.explanationContextMenu.style.top = `${e.clientY}px`;
      });
      if (node.start !== void 0 && node.end !== void 0) {
        textEl.addEventListener("click", (e) => {
          e.stopPropagation();
          this.o.onNavigate?.(node.start, node.end);
        });
      }
      container.appendChild(label);
      if (hasChildren) {
        const childrenContainer = document.createElement("div");
        childrenContainer.className = "tree-children";
        childrenContainer.style.display = isExpandedNow ? "block" : "none";
        label.querySelector(".tree-toggle")?.addEventListener("click", (e) => {
          e.stopPropagation();
          const newExpanded = childrenContainer.style.display === "none";
          childrenContainer.style.display = newExpanded ? "block" : "none";
          e.target.textContent = newExpanded ? "-" : "+";
          expansion.set(prefix, newExpanded);
        });
        node.children.forEach((child, index) => childrenContainer.appendChild(createNode(child, depth + 1, prefix ? `${prefix}.${index + 1}` : `${index + 1}`)));
        container.appendChild(childrenContainer);
      }
      return container;
    };
    if (Array.isArray(why))
      why.forEach((w, index) => tree.appendChild(createNode(w, 0, (index + 1).toString())));
    else
      tree.appendChild(createNode(why, 0, "1"));
    for (const { label, node, prefix } of repeatedLabels) {
      if (navTargetFor(node, prefix)) {
        label.classList.add("navigable");
        label.title = `${label.title} \xB7 right-click \u2192 "Go to full sub-explanation"`;
      }
    }
  }
};

// src/scenario-variations.ts
var TOKEN = "myToken123";
async function leapi(body) {
  return fetch("/leapi", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: TOKEN, ...body })
  }).then((r) => r.json());
}
async function initScenarioVariations() {
  const $ = (id) => document.getElementById(id);
  const url = new URLSearchParams(location.search);
  const ls = JSON.parse(localStorage.getItem("le_scenario_variations_data") || "{}");
  let source = url.get("text") || ls.source || "";
  let sessionModule = ls.sessionModule || null;
  let kbName = ls.kbName || "";
  let queryDefs = Array.isArray(ls.queries) ? ls.queries : [];
  if (source && (!sessionModule || queryDefs.length === 0)) {
    const r = await leapi({ operation: "load", le: source });
    if (r && r.sessionModule) {
      sessionModule = r.sessionModule;
      if (!kbName)
        kbName = r.kb || "";
      if (queryDefs.length === 0 && Array.isArray(r.queries)) {
        queryDefs = r.queries.map((q) => ({ name: q.name, label: q.le || q.template }));
      }
    }
  }
  const blocks = parseScenarioBlocks(source);
  const blockByName = new Map(blocks.map((b) => [b.name, b]));
  const scenarioNames = Array.isArray(ls.scenarios) && ls.scenarios.length ? ls.scenarios : blocks.map((b) => b.name);
  $("title").textContent = `Scenario variations for ${kbName || "this program"}`;
  const picker = $("scenario-picker");
  picker.innerHTML = "";
  const emptyOpt = document.createElement("option");
  emptyOpt.value = "";
  emptyOpt.textContent = "(empty)";
  picker.appendChild(emptyOpt);
  scenarioNames.forEach((n) => {
    const o = document.createElement("option");
    o.value = n;
    o.textContent = n;
    picker.appendChild(o);
  });
  const statusEl = $("status");
  const btnRun = $("btn-run");
  const setStatus = (t) => {
    statusEl.textContent = t;
  };
  const form = new ScenarioForm({
    source,
    rowsEl: $("rows"),
    addSelect: $("add-template"),
    btnAdd: $("btn-add"),
    onChange: () => {
      markStale();
      syncUrl();
    }
  });
  const menus = {
    answerContextMenu: $("answer-context-menu"),
    menuCopyAnswer: $("menu-copy-answer"),
    explanationContextMenu: $("explanation-context-menu"),
    menuCopyExplanation: $("menu-copy-explanation"),
    menuGotoOriginal: $("menu-goto-original"),
    answerTooltip: $("answer-tooltip")
  };
  const failedNodePrefix = () => localStorage.getItem("le-failed-node-prefix") ?? "x ";
  const hierarchical = () => localStorage.getItem("le-hierarchical-numbering") === "true";
  const navigate = (start, end) => {
    window.opener?.postMessage({ type: "le-highlight", loc: { start, end } }, "*");
  };
  const queryCards = [];
  const queryListEl = $("query-list");
  function addQueryCard(name) {
    const card = document.createElement("div");
    card.className = "query-card";
    const header = document.createElement("div");
    header.className = "query-header";
    const nameEl = document.createElement("span");
    nameEl.className = "query-name";
    const def = queryDefs.find((q) => q.name === name);
    nameEl.textContent = def?.label ? `${def.label} (${name})` : name;
    header.appendChild(nameEl);
    const remove = document.createElement("button");
    remove.className = "query-remove";
    remove.textContent = "\u2715";
    remove.title = "Remove query";
    header.appendChild(remove);
    card.appendChild(header);
    const area = document.createElement("div");
    area.className = "results-area";
    const aPanel = document.createElement("div");
    aPanel.className = "answers-panel";
    aPanel.innerHTML = '<div class="panel-label">Answers</div>';
    const answersList = document.createElement("div");
    aPanel.appendChild(answersList);
    const ePanel = document.createElement("div");
    ePanel.className = "explanation-panel";
    ePanel.innerHTML = '<div class="panel-label">Explanation</div>';
    const explanationTree = document.createElement("div");
    ePanel.appendChild(explanationTree);
    area.appendChild(aPanel);
    area.appendChild(ePanel);
    card.appendChild(area);
    const view = new ExplanationView({
      answersList,
      explanationTree,
      menus,
      failedNodePrefix,
      hierarchicalNumbering: hierarchical,
      onNavigate: navigate
    });
    const entry = { name, card, view };
    remove.addEventListener("click", () => {
      const i = queryCards.indexOf(entry);
      if (i >= 0)
        queryCards.splice(i, 1);
      card.remove();
      markStale();
      syncUrl();
    });
    queryCards.push(entry);
    queryListEl.appendChild(card);
    return entry;
  }
  const addQuerySelect = $("add-query");
  addQuerySelect.innerHTML = "";
  queryDefs.forEach((q) => {
    const o = document.createElement("option");
    o.value = q.name;
    o.textContent = q.label ? `${q.label} (${q.name})` : q.name;
    addQuerySelect.appendChild(o);
  });
  $("btn-add-query").addEventListener("click", () => {
    const name = addQuerySelect.value;
    if (!name)
      return;
    addQueryCard(name);
    markStale();
    syncUrl();
  });
  function markStale() {
    btnRun.disabled = false;
  }
  async function ensureSession() {
    if (sessionModule)
      return true;
    const r = await leapi({ operation: "load", le: source });
    if (r && r.sessionModule) {
      sessionModule = r.sessionModule;
      return true;
    }
    return false;
  }
  async function runOne(entry) {
    entry.view.showMessage("Running\u2026");
    const reqBody = () => ({
      operation: "answeringQuery",
      sessionModule,
      query: entry.name,
      customScenario: form.factsText(),
      detailedFailures: localStorage.getItem("le-detailed-failures") === "true",
      hideRepeated: (localStorage.getItem("le-hide-repeated-explanations") ?? "true") === "true"
    });
    let res = await leapi(reqBody());
    if (res && res.session_expired) {
      sessionModule = null;
      if (await ensureSession())
        res = await leapi(reqBody());
    }
    entry.view.showResults(res);
  }
  btnRun.addEventListener("click", async () => {
    if (queryCards.length === 0) {
      setStatus("Add a query first.");
      return;
    }
    if (!await ensureSession()) {
      setStatus("Could not load the program on the server.");
      return;
    }
    btnRun.disabled = true;
    setStatus("Running queries\u2026");
    for (const entry of queryCards)
      await runOne(entry);
    setStatus(`Ran ${queryCards.length} quer${queryCards.length > 1 ? "ies" : "y"}`);
  });
  $("btn-copy-scenario").addEventListener("click", async () => {
    const name = picker.value || "variation";
    const text = form.blockText(name);
    try {
      await navigator.clipboard.writeText(text);
      setStatus("Scenario copied to clipboard");
    } catch {
      window.prompt("Copy the scenario text:", text);
    }
  });
  function syncUrl() {
    const u = new URL(location.href);
    u.searchParams.set("text", source);
    u.searchParams.set("scenario", picker.value);
    u.searchParams.set("scenarioText", form.factsText());
    u.searchParams.set("queries", queryCards.map((q) => q.name).join(","));
    window.history.replaceState({}, "", u.toString());
  }
  function loadScenarioFromPicker() {
    const name = picker.value;
    const block = name ? blockByName.get(name) : null;
    form.loadFacts(block ? block.facts : []);
  }
  picker.addEventListener("change", () => {
    loadScenarioFromPicker();
    markStale();
    syncUrl();
  });
  const urlScenario = url.get("scenario");
  const urlScenarioText = url.get("scenarioText");
  const urlQueries = url.get("queries");
  picker.value = urlScenario !== null ? urlScenario : ls.selectedScenario || "";
  if (urlScenarioText !== null) {
    form.loadFacts(urlScenarioText.split(/\n+/).map((s) => s.trim()).filter(Boolean));
  } else {
    loadScenarioFromPicker();
  }
  const initialQueries = urlQueries !== null ? urlQueries.split(",").map((s) => s.trim()).filter(Boolean) : ls.selectedQuery ? [ls.selectedQuery] : [];
  initialQueries.forEach((n) => addQueryCard(n));
  syncUrl();
  setStatus("Ready");
}
export {
  initScenarioVariations
};

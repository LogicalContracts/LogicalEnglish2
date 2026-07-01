// src/explanation-drill.ts
var TOKEN = "myToken123";
var leapi = (body) => fetch("/leapi", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ token: TOKEN, ...body })
}).then((r) => r.json()).catch(() => null);
async function initExplanationDrill() {
  const $ = (id) => document.getElementById(id);
  const ls = JSON.parse(localStorage.getItem("le_explanation_drill_data") || "{}");
  const source = ls.source || "";
  const why = ls.why;
  $("title").textContent = `Explanation Drill${ls.kbName ? ` \u2014 ${ls.kbName}` : ""}`;
  const root = Array.isArray(why) ? why[0] : why;
  const rootLiteral = root && root.literal ? String(root.literal) : "this answer";
  $("drill-title").textContent = `Understanding why ${rootLiteral}:`;
  let answers = [];
  let initialCount = 0;
  let sentWhy = false;
  let sessionModule = null;
  let sessionLoad = null;
  function startSessionLoad() {
    if (!sessionLoad) {
      sessionLoad = (source ? leapi({ operation: "load", le: source }) : Promise.resolve(null)).then((r) => {
        if (r && r.sessionModule)
          sessionModule = r.sessionModule;
      }).catch(() => {
      });
    }
    return sessionLoad;
  }
  async function ensureSession() {
    if (sessionModule)
      return true;
    await startSessionLoad();
    if (!sessionModule && ls.sessionModule)
      sessionModule = ls.sessionModule;
    return !!sessionModule;
  }
  const setStatus = (t) => {
    $("status").textContent = t;
  };
  async function drill() {
    if (!await ensureSession())
      return { error: "Could not load the program on the server." };
    const req = () => {
      const b = { operation: "explanationDrill", sessionModule, answers };
      if (!sentWhy)
        b.why = why;
      return b;
    };
    let res = await leapi(req()) || { error: "network" };
    if (res && res.session_expired) {
      sessionModule = null;
      sessionLoad = null;
      sentWhy = false;
      if (await ensureSession())
        res = await leapi(req()) || { error: "network" };
    }
    if (res && res.ok)
      sentWhy = true;
    return res;
  }
  function highlight(q) {
    if (!q || q.start < 0)
      return;
    window.opener?.postMessage({ type: "le-highlight", loc: { start: q.start, end: q.end }, noFocus: true }, "*");
  }
  function answer(i, val) {
    if (i < answers.length && answers[i] === val)
      answers = answers.slice(0, i);
    else
      answers = answers.slice(0, i).concat([val]);
    refresh();
  }
  function deleteQuestion(i) {
    if (i < 0 || i >= answers.length)
      return;
    answers = answers.slice(0, i).concat(answers.slice(i + 1));
    refresh();
  }
  function questionCard(q, i, isPending, isTopFinal) {
    const card = document.createElement("div");
    card.className = "q-card" + (isTopFinal ? " top-final" : "");
    card.title = "Click to show this in the editor";
    card.addEventListener("click", () => highlight(q));
    if (!isPending) {
      const del = document.createElement("button");
      del.className = "q-del";
      del.textContent = "\u2715";
      del.title = "Delete this question";
      del.addEventListener("click", (e) => {
        e.stopPropagation();
        deleteQuestion(i);
      });
      card.appendChild(del);
    }
    const node = document.createElement("div");
    node.className = "q-node";
    node.textContent = q.text;
    card.appendChild(node);
    const row = document.createElement("div");
    row.className = "q-row";
    const label = document.createElement("span");
    label.className = "q-label";
    label.textContent = "Accept?";
    row.appendChild(label);
    const mkBtn = (val, text) => {
      const b = document.createElement("button");
      b.className = `q-btn ${val === "yes" ? "yes" : "notyet"}` + (q.answer === val ? " on" : "");
      b.textContent = text;
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        answer(i, val);
      });
      return b;
    };
    row.appendChild(mkBtn("yes", "Yes"));
    row.appendChild(mkBtn("not_yet", "Not yet"));
    card.appendChild(row);
    return card;
  }
  function render(res) {
    const container = $("questions");
    container.innerHTML = "";
    const questions = res.questions || [];
    const pending = res.pending || null;
    questions.forEach((q, i) => {
      const isTopFinal = !pending && q.path === res.topPath;
      container.appendChild(questionCard(q, i, false, isTopFinal));
    });
    if (pending) {
      container.appendChild(questionCard(pending, questions.length, true, false));
    }
    if (typeof res.initialCount === "number" && res.initialCount > 0)
      initialCount = res.initialCount;
    const progress = res.progress || 0;
    const pct = initialCount > 0 ? Math.round(progress / initialCount * 100) : 0;
    $("progress-fill").style.width = `${pct}%`;
    $("progress-label").textContent = "Progress";
    const final = $("final");
    if (!pending) {
      final.style.display = "";
      final.textContent = "Nothing else to show. Feel free to alter your choices above.";
      highlight(questions.find((q) => q.path === res.topPath) || questions[questions.length - 1]);
      setStatus("Done");
    } else {
      final.style.display = "none";
      highlight(pending);
      setStatus("Answer the highlighted question, or revise an earlier one.");
    }
  }
  async function refresh() {
    const res = await drill();
    if (res && res.session_expired) {
      setStatus("The session has expired \u2014 reopen the Explanation Drill.");
      return;
    }
    if (!res || !res.ok) {
      setStatus("Error: " + (res && res.error || "no response"));
      return;
    }
    render(res);
  }
  if (!why) {
    setStatus("No explanation to drill.");
    return;
  }
  startSessionLoad();
  refresh();
}
export {
  initExplanationDrill
};

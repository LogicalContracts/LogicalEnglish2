# Plan: dual-engine Logical English — Prolog **and** s(CASP)

**Goal.** Let an LE2 program be executed by either the existing Prolog backend or
by s(CASP), from the same source, with the answers and explanations rendered in
the existing UI — reusing the explanation tree wherever the two engines agree,
and adding new components only where s(CASP) genuinely offers something Prolog
cannot (answer sets, constructive negation, constraint answers, abduction).

Two facts make this cheap:

1. **s(CASP) is a SWI-Prolog pack, in-process.** `library(scasp)` runs inside the
   same SWI-Prolog instance that already hosts LE2. No second runtime, no server
   hop, no serialisation boundary: `scasp/2` returns bindings, the (partial)
   stable model and the justification as ordinary Prolog terms. It is also the
   fast port (~10× the Ciao original) and pure Prolog, so it will later run in
   `swipl-wasm` alongside LE2 itself.
2. **s(CASP)'s justification trees are structurally what the LE explanation tree
   already displays.** If the s(CASP) proof is converted into the *same* JSON
   node schema the current tree consumes, the whole existing UI — node colours,
   tooltips, expand/collapse, hierarchical numbering, repeated-sub-explanation
   collapsing, the Explanation Drill, Copy as Mermaid, click-to-source — works
   unchanged.

---

## 1. Architecture

```
            LE source (.le)
                  |
            existing parser
                  |
        internal representation (IR)      <-- single source of truth
             /            \
   existing Prolog      NEW s(CASP)
     emitter              emitter
        |                    |
   SWI-Prolog           library(scasp)
     solve                 scasp/2
        |                    |
   proof term          justification term
        \                   /
      NEW normaliser -> common explanation-tree JSON
                  |
        existing explanation UI (+ new panels, §5)
```

**Key decision: do not feed the existing generated Prolog to s(CASP).** The
current output carries engine-specific plumbing (`is/2`, `findall`-based
aggregates, LE system predicates, meta-interpreter hooks) that s(CASP) either
cannot run or runs badly. Emit a *second target* from the same IR. The IR is the
integration point; the two emitters are siblings.

**Traceability contract.** Every clause emitted for s(CASP) must carry its LE
rule ID and source span (start/end offsets), exactly as the Prolog path does via
`le_source_info/4`. Keep an explicit clause-ID → LE-source map; the justification
normaliser uses it to attach spans so tree nodes remain clickable back into the
editor. **If this map is not built in from day one, retrofitting it is painful.**

---

## 2. LE construct → s(CASP) mapping

| LE construct | Prolog backend (today) | s(CASP) backend |
|---|---|---|
| Rule `H if B` | `H :- B.` | same |
| `it is not the case that G` | `\+ G` | `not G` (constructive; dual rules generated) |
| `unless C` | `\+ C` | `not C` |
| `; opposite: T` | separate predicate | **classical negation** `-p(...)`, plus `false :- p(X), -p(X).` |
| `only if` (§15.1) | contrapositive rule | contrapositive into `-Head`, or a global constraint `false :- Head, not Body.` |
| `; unknown` / `; assumable` | assumed true, amber node | `#abducible p(X).` — assumption sets come back per model |
| `; undefined` (scenario element) | scenario facts | same (facts asserted per session) |
| Ontology `is_a` | facts | same |
| Dates `date(Y,M,D)` | `@</@>` term order | same term order; **verify** s(CASP) compares compound terms as expected, else emit an explicit `date_before/2` predicate |
| Arithmetic | `is/2` | CLP(ℚ) constraints — **different lowering**, see below |
| Comparisons `>`,`>=`,… | arithmetic/term compare | CLP constraints (`#>`, `#>=`) when numeric |
| Aggregates (`sum/count/... of each`) | `findall` + aggregate | **no native support** — see §3 |
| `prolog <goal>` (§15.6) | direct call | **unsupported**; flag at compile time |
| `.pl` resources (§14.1) | asserted facts | unsupported (or: usable only as ground facts, no goals) |
| Queries | goal + bindings | `scasp/2` goal; one query may yield several models |
| Scenarios | asserted facts | same |
| `expects answers [...]` | test runner | same runner, per engine (§7) |

**Mark arithmetic abstractly in the IR** (`arith_op(Op, Args, Result)`), not as a
pre-built `is/2` goal, so each emitter lowers it its own way. This is the single
most important IR change; everything else is fairly mechanical.

### `#pred` annotations — free English justifications

s(CASP) supports `#pred` directives attaching a natural-language pattern to a
predicate, used by its `--human` justification output. **LE templates map to
`#pred` almost one-to-one.** Emit them. Two benefits:

- s(CASP)'s own human-readable justification becomes a cross-check against the
  LE renderer while developing (invaluable for debugging the normaliser).
- Any raw s(CASP) output (CLI, logs, bug reports) reads in the program's own
  domain language.

---

## 3. Known gaps and how to handle them

| Gap | Handling |
|---|---|
| **Aggregates** | Either (a) restrict to the Prolog backend and report a compile-time issue "aggregates are not supported by s(CASP); run this query with the Prolog engine", or (b) compile to explicit recursion over a list. Start with (a) — it is honest and cheap. |
| **`prolog` goals / `.pl` resources** | Compile-time `le_issue` warning; the program is Prolog-only. |
| **Performance** | s(CASP) builds dual rules for every clause; cost grows fast. Set a per-query time/inference budget, run asynchronously, and surface a "still solving…" state with a cancel button. Do not block the editor. |
| **Loops through negation** | Prolog (SLDNF) may loop or give unsound answers; s(CASP) handles them under stable-model semantics. Add a **stratification check** to the existing verifier (§7). |
| **Floats / division** | Works better in s(CASP) than in Prolog-with-`is/2` in some cases (CLP(ℚ) is exact rationals) — but answers may come back *as constraints*, see §5. |
| **Answer identity** | Prolog answers are ground bindings; s(CASP) answers may be non-ground plus constraints. The answers-pane data model must allow a non-ground answer. |

---

## 4. Work packages

Ordered so that each package is independently demonstrable.

**WP1 — IR cleanup (prerequisite).**
Abstract arithmetic and comparison goals in the IR; add the clause-ID → LE-source
map as a first-class IR artefact; make the existing Prolog emitter consume the
new IR unchanged (pure refactor, no behaviour change). *Definition of done: full
existing test suite green.*

**WP2 — s(CASP) emitter.**
IR → s(CASP) text/clauses, covering the mapping table in §2, plus `#pred`
directives, `#abducible` for assumables, `-p` for opposites, global constraints
for `only if`. Compile-time issues for unsupported constructs. *DoD: `See s(CASP)`
menu item next to the existing `See PROLOG`, showing the generated program.*

**WP3 — Runner.**
Load the emitted program into a session module and call `scasp/2` (or
`scasp_model/2` + justification) with the scenario facts asserted. Time-budgeted,
cancellable, async. *DoD: a query returns answers in the console/log.*

**WP4 — Justification normaliser.**
s(CASP) justification term → the existing explanation-tree JSON schema. Attach
source spans via the WP1 map. Map node status: proven → green, assumed
(abducible) → amber, negation-as-proved → the existing "negative condition holds"
style. *DoD: an s(CASP) answer renders in the current explanation component, and
clicking a node highlights the right LE source.*

**WP5 — Engine selector + answers pane.**
Engine dropdown (Prolog | s(CASP) | Both) in the Query tab, encoded in the URL
like every other piece of state. Answers pane gains a model grouping level (§5).
*DoD: shareable URL that pins program + scenario + query + engine.*

**WP6 — New UI affordances.**
Constraint answers, assumption sets, model tabs (§5).

**WP7 — Differential testing + verifier check.** (§7)

WP1–WP5 constitute a usable dual-engine system; WP6–WP7 are the payoff.

---

## 5. UI: what to reuse, what to add

### Reuse unchanged
The explanation tree and everything hanging off it — colours, tooltips,
expand/collapse, hierarchical numbering, repeated-sub-explanation collapsing (the
`↩` "go to full sub-explanation" logic), the **Explanation Drill**, Copy
Explanation, **Copy as Mermaid**, click-to-source. All of it comes for free if
WP4 emits the same node schema. The Drill in particular ("accept? / not yet")
works just as well over an s(CASP) justification as over a Prolog one.

### Add

**(a) Model grouping in the answers pane.** Prolog yields a flat stream of
answers; s(CASP) yields *answer sets*: one query may have several models, each
with its own bindings, its own partial model, and its own justification. Add one
level above the current answer cards — tabs or cards per model, e.g.
`Model 1 of 3`. In `/executive` this reads naturally as **"Answer 1 of 3 possible
worlds"**. When there is exactly one model (the common legal-reasoning case),
collapse the level entirely so the UI is identical to today's.

**(b) Constraint / symbolic answers.** An s(CASP) binding may be a constraint
rather than a value — `Amount > 25000`, or `Date` unconstrained. The answer
renderer needs a symbolic mode: render `Amount > 25000` through the LE template
as *"any amount greater than 25,000"*. **This is a headline feature, not a
workaround**: it lets a user ask *"under what conditions would we pay?"* with no
concrete scenario at all, and get an answer. Worth designing deliberately rather
than falling out of the implementation.

**(c) Assumption sets (abduction).** Each model may carry a set of assumed
abducibles. Render assumed literals amber in the tree (consistent with today's
"unknown" nodes) **and** show a per-model header line: *"This holds if we assume:
… "*. In **Scenario Variations** this closes a loop the window is already 80%
toward: today it answers *"what if Alice were not a citizen?"*; with abduction it
can answer *"what would have to be true for Alice to qualify?"*. Suggest a
**"What would make this true?"** button next to each failed query result.

**(d) Negation rendering.** In Prolog, `\+ G` failing is an absence — a red
"could not be proven" leaf. In s(CASP), `not G` is *proved* via dual rules, so
the justification contains a real sub-proof of why `G` fails, rule by rule. This
is strictly better explanation material and roughly what the existing
"Detailed failure explanations (per-rule nodes)" preference approximates. Give
these nodes their own style, and consider making that preference a no-op (always
on) for the s(CASP) engine.

**(e) Trace stays Prolog-only.** Grey out the Trace button for s(CASP); the
justification tree supersedes step tracing. Don't try to unify them.

**(f) `/executive` mode.** Add engine as a URL parameter only — do **not** add a
visible engine control to the executive UI. Non-technical users should never see
an engine choice; the program (or the sharer's link) decides.

---

## 6. Which engine, when — guidance to surface in the editor

- **Prolog**: stratified programs, aggregates, `prolog` goals, large fact sets.
  Much faster. This stays the default.
- **s(CASP)**: loops through negation, exact/constraint arithmetic, "what must be
  assumed" questions, non-finitely-groundable rules, and any case where the
  *quality of the explanation of a failure* is what matters.

Make this advisory, not automatic: report it as an editor hint, keep the choice
with the user.

---

## 7. Testing

**Differential testing is the main quality mechanism, and it comes almost free.**
The engine selector's **"Both"** mode is exactly a diff harness: same program,
same scenario, same query, two engines, answers side by side. Any divergence is
either a compiler bug or a genuine semantic difference — and the genuine ones
(non-stratified programs) are precisely the cases worth flagging to the user.

- **Reuse `expects answers [...]`.** The existing scenario expectation syntax and
  test runner should run per engine. Add an optional engine qualifier for the
  cases where divergence is expected and correct.
- **Run the whole examples corpus under both engines** in CI; produce a
  compatibility matrix (per example: both / Prolog-only / s(CASP)-only, with the
  reason). This matrix is also useful documentation.
- **Verifier addition: stratification check.** Detect loops through negation in
  the dependency graph (the Source Graph already computes `negates` edges — reuse
  it). Warn in the editor: *"this program is not stratified; the Prolog engine may
  loop or give unsound answers — consider the s(CASP) engine."*
- **Cross-check the normaliser** against s(CASP)'s own `--human` output during
  WP4 development (see §2, `#pred`).

---

## 8. Forward compatibility: the browser

Both engines are SWI-Prolog libraries, and the s(CASP) SWI port is pure Prolog.
The official SWI-Prolog WASM demo site already ships an s(CASP) example that
loads the pack from GitHub and solves in the browser. So this whole dual-engine
design ports unchanged to `swipl-wasm` later: the engine toggle simply selects
which library answers, entirely client-side, with the LE parser in the same
instance. Two implications for now:

- Keep the runner interface (WP3) free of server-only assumptions — no file-system
  or process dependencies in the solve path.
- Precompiling matters when that day comes: loading sCASP from source takes
  seconds. Bundle it into the WASM image or a saved state rather than
  `use_module`-ing a URL.

No work is needed today; just don't design against it.

---

## 9. Open questions for the developer

1. How much of the current explanation-tree JSON is Prolog-proof-shaped rather
   than display-shaped? If the schema leaks engine detail, WP4 gets harder — worth
   auditing before WP1.
2. Does `scasp/2`'s justification expose enough per-node identity to attach source
   spans reliably, or is a wrapper/meta-level needed?
3. Aggregates: restrict to Prolog (cheap, honest) or compile to recursion
   (general, slower, more work)? Recommend deferring.
4. Should a program be able to *declare* its engine (`the target language is:
   scasp.`, mirroring the existing `the target language is: prolog.` meta line)?
   This would make `/executive` links self-describing.

---

## 10. Findings — open questions resolved (2026-07-21)

Audited both sides (s(CASP) pack v1.1.4, already installed locally; and the LE2
code). Answers to §9:

1. **The explanation JSON is display-shaped, not proof-shaped — WP4 is cheap.**
   `convert_why/3` (`classic_web_api.pl:1615`) emits nodes of just
   `{type: success|failure|unknown, literal: <rendered LE sentence>, start, end,
   children[], naf, repeated*, ruleAttempt}`. No `is/2`, clause bodies, or
   meta-interpreter internals leak. The UI colours off `type` and navigates off
   `start`/`end` only (`explanation-view.ts:387,517`). **Bonus:** s(CASP) ships
   its own JSON exporter, `scasp_results_json/2` in `library(scasp/json)`
   (`#{node, children}`, `truth: true|false|likely|unlikely`, flags
   `assume/proved/abduced/chs`, optional `source_file/source_line`). WP4 becomes
   JSON→JSON: `truth:false/unlikely`→`type:failure`+`naf`; `assume/abduced`→amber;
   `value`→`literal` via the `#pred` templates.
2. **Per-node source identity is exposed — no meta-wrapper needed.** s(CASP) wraps
   nodes as `goal_origin(Node, Origin)` and resolves `Origin` via
   `library(scasp/source_ref)`. It exports `assert_scasp_source_reference/3`, so
   the emitter registers each generated clause's origin pointing at the LE
   `(Start,End,ID)` triple that `le_source_info/4` already stores
   (`le_kbs.pl:665`); it surfaces automatically as `source_file/source_line` in
   the JSON. The WP1 clause-ID→source map plugs into an existing hook.
3. **Aggregates: restrict to Prolog (deferred), confirmed cheap.** LE aggregates
   are already a symbolic IR node (`is_aggregate/5` grammar → single `aggregate`
   node solved in `reasoner.pl:140`), *not* lowered to `findall/3` at compile
   time, so a compile-time "needs the Prolog engine" issue is a trivial IR check.
4. **Yes — and it was a real gap. DONE.** `the target language is: prolog.` was
   parsed then discarded (`meta([])`). Now `section(meta(Target))` captures the
   target (`le_grammar:le_allowed_target/1` ∈ {prolog, scasp}), records
   `le_target_language/1` per KB module, and `kb_target_language/2` (le_kbs)
   resolves it (defaulting to `prolog`). Unknown targets still fall through to
   `unknown_section` as before. Full suite green (unit + LE + 99 e2e).

**Under-weighted risk surfaced by the audit:** the answers data model is
ground-bindings-only (`AnswerStr` + `bindings` + `unknowns`,
`classic_web_api.pl:1085`) — no slot for CLP constraints or non-ground/partial
models. §5(a) model grouping and §5(b) constraint answers (the chosen headline
feature) are where the schema genuinely has to grow; **WP6 is heavier than its
ordering suggests, WP4 lighter.** The `unknowns` mechanism is the precedent to
extend.

---

## 11. Implementation status (WP1–WP7 delivered)

A working dual-engine core is implemented and the full test suite is green (unit
+ LE examples + Playwright e2e, incl. new suites). New/changed code, no git
commits (per AGENTS.md):

- **`le_scasp.pl`** (new) — the whole s(CASP) backend: emitter, `#pred`
  directives, `#abducible`, opposites, runner, justification normaliser,
  stratification analysis.
- **`classic_web_api.pl`** — `getScasp` + `scaspQuery` ops.
- **`le_verifier.pl`** — `non_stratified` check (+ i18n `non_stratified_desc`).
- **`le_grammar.pl` / `le_kbs.pl` / `reasoner.pl`** — target-language declaration
  (`kb_target_language/2`).
- **`editor/`** — `See s(CASP)` menu, engine selector (URL-pinned), Trace greyed
  under s(CASP).
- **Tests** — `testing/test_scasp.pl` (plunit) + `editor/tests/scasp-engine.spec.ts`.

| WP | Status | Notes |
|----|--------|-------|
| WP1 IR + source map + target decl | ✅ | Target decl done; IR already kept comparisons/arith symbolic, so "cleanup" was mostly confirming that. Source spans attached by functor→template/rule lookup (`kb_pred_source`). |
| WP2 s(CASP) emitter | ✅ | `#pred`, `#abducible`, opposites, CLP lowering of comparisons/arith, DNF clause-splitting of `;`, compile-time issues for aggregates/`prolog`/universals/dates. |
| WP3 runner | ✅ | Mode-A temp-file consult into a fresh module + `scasp/2`; time-budgeted (`call_with_time_limit`), `findnsols`-bounded model count. |
| WP4 justification normaliser | ✅ | Raw tree → LE explanation JSON (`type/literal/children/start/end/naf/assumed`); internal `o_nmr`/`o_chk` nodes dropped; literals via `item_to_instance`+`canonical_string`. |
| WP5 engine selector + answers pane | ✅ | Prolog/s(CASP) dropdown, URL param `engine`, response reuses `showResults`; model grouping is one card per stable model. |
| WP6 new UI affordances | ✅ | Model grouping ✅, negation nodes ✅ (`naf`), assumed/amber ✅. **§5b constraint answers ✅** — `le_scasp_symbolic_goal/4` lowers CLP residuals into LE phrases ("any amount greater than 25000") rendered through the template. **§5c abduction set ✅** — `le_scasp_assumptions/3` collects abduced literals from the tree; surfaced via the existing `unknowns` amber-marker/tooltip channel (no editor change). |
| WP7 differential testing + verifier | ✅ | Stratification check wired into `verify/2`; `test_scasp.pl` runs citizenship under both engines and asserts agreement with the recorded `expects answers`. "Both" side-by-side diff view in the UI not yet built. |

**Remaining polish (not blockers):** (b) a UI "Both" engine side-by-side diff view
(the backend diff already exists as the differential test harness). Constraint
numbers are rendered raw (no thousands separator / locale). Source spans are
head-granularity (`kb_pred_source`) — could refine to sub-goal via s(CASP)'s
`assert_scasp_source_reference`.

**Demo files:** `examples/moreExamples/dual_engine_demo.le` (non-stratified —
Prolog gives no answer, s(CASP) finds the stable model),
`examples/moreExamples/clp_coverage.le` (§5b constraint answer),
`examples/moreExamples/abduction/sunglasses.le` (§5c abduction set),
`examples/moreExamples/abduction/loan_approval.le` (**multi-model** — 4 distinct
"possible worlds" each with its own assumption set; also a valid Prolog abduction
test). s(CASP) enumerates a model per truth-assignment of *unused* abducibles, so
the web handler dedups by (answer + assumption set) and stamps `modelIndex`/
`modelCount`; the editor labels each card "world i of n" (§5a).

### WP1 detail
- [x] Target-language declaration parses & records `prolog`/`scasp` (`kb_target_language/2`).
- [x] Engine-neutral source attribution — `kb_pred_source/4` maps a predicate to
      its defining rule/template span (head-granularity click-to-source).
- [x] Arithmetic/comparisons lowered *relationally* to CLP(ℚ) (`#=`/`#>`/…) in the
      s(CASP) emitter (`lower_leaf/3`), per the "constraints as headline" choice.

# s(CASP) on Logical English

Logical English 2 can execute the **same program** under either of two reasoning
engines:

- the default **Prolog** backend (SLDNF + a meta-interpreter, `reasoner.pl`), and
- an **s(CASP)** backend (goal-directed Answer Set Programming under stable-model
  semantics, `library(scasp)` run in-process).

This document describes the s(CASP) support as it is actually implemented. For the
original design rationale and work-package breakdown see
[`sCASP_plan.md`](sCASP_plan.md); this is the "what it does and how to use it"
companion. The whole backend lives in **`le_scasp.pl`**, with web plumbing in
`classic_web_api.pl` and UI in `editor/`.

> **Why two engines?** Prolog is fast, handles aggregates, `prolog` goals and
> large fact sets, and stays the default. s(CASP) adds four things Prolog cannot
> do well: **constraint (symbolic) answers**, **multiple stable models / possible
> worlds**, **abduction ("what would have to be true?")**, and **constructive
> negation** with a real sub-proof of *why* something fails. It also gives sound
> answers for programs that loop through negation (non-stratified programs), where
> Prolog may loop or answer unsoundly.

---

## Contents

- [1. Choosing the engine](#1-choosing-the-engine)
- [2. Architecture](#2-architecture)
  - [Runner (Mode A)](#runner-mode-a)
- [3. Traceability — click-to-source](#3-traceability--click-to-source)
- [4. LE construct → s(CASP) mapping](#4-le-construct--scasp-mapping)
  - [Constraints are relational, not functional](#constraints-are-relational-not-functional)
  - [DNF clause-splitting](#dnf-clause-splitting)
- [5. Answers: constraints, multiple models, abduction](#5-answers-constraints-multiple-models-abduction)
  - [Constraint / symbolic answers (§5b)](#constraint--symbolic-answers-5b)
  - [Multiple models — "possible worlds" (§5a)](#multiple-models--possible-worlds-5a)
  - [Abduction — assumption sets (§5c)](#abduction--assumption-sets-5c)
- [6. Explanations](#6-explanations)
- [7. Negation: De Morgan normalisation](#7-negation-de-morgan-normalisation)
- [8. Unsupported constructs → issues (errors)](#8-unsupported-constructs--issues-errors)
- [9. Stratification check (verifier)](#9-stratification-check-verifier)
- [10. Testing](#10-testing)
- [11. Guidance: which engine, when](#11-guidance-which-engine-when)
- [12. Current status and known limitations](#12-current-status-and-known-limitations)
  - [Forward compatibility (browser)](#forward-compatibility-browser)
- [13. Code map](#13-code-map)

---

## 1. Choosing the engine

There are three ways the engine is selected, in increasing precedence:

1. **Program declaration.** A program's first statement may declare its target:
   `the target language is: prolog.` or `the target language is: scasp.`
   (multilingual: `a linguagem alvo é: scasp.`, etc.). This is parsed into
   `kb_target_language/2` and used to **pre-select** the engine dropdown in the
   editor (`editor/src/client.ts`, `res.target`).
2. **Editor engine dropdown.** A Prolog | s(CASP) selector in the Query tab. The
   choice is pinned in the URL as `?engine=scasp`, so a shared link reproduces the
   program + scenario + query + engine exactly. Once the user picks an engine
   manually it is not overridden by the declaration (`engineUserSet`).
3. **Engine-picker visibility preference** (Misc menu). Because LE is
   Prolog-biased, the picker can be hidden for Prolog programs — "Always show
   engine choice" vs "Show engine choice only for non-Prolog". The target language
   is detected from the editor text (`detectTargetLanguage`, `editor/src/i18n.ts`)
   so visibility is correct before any server round-trip.

When s(CASP) is selected, the client sends the `scaspQuery` operation instead of
the usual `answer`; "See s(CASP)" (next to "See PROLOG") sends `getScasp` to show
the generated s(CASP) source.

**Availability.** s(CASP) is an optional SWI-Prolog pack. `le_scasp_available/0`
is true only when `library(scasp)` is installed; otherwise every entry point
fails cleanly with the localized issue `scasp_engine_not_installed` (rather than
crashing). The pack is installed in the Docker image via `pack_install(scasp)`
(see the `Dockerfile`), because `swipl:latest` does not bundle it.

---

## 2. Architecture

The two engines are **siblings emitted from the same loaded KB**, not one feeding
the other:

```
                LE source (.le)
                      │  existing parser
              loaded KB module (clauses + le_dict + le_source_info)
                     ╱                         ╲
         existing Prolog                    le_scasp.pl emitter
          reasoner.pl                     (lower_body / lower_leaf)
              │                                    │
          solve/8                        s(CASP) program text
              │                                    │  consult into a fresh unit
       proof term (success/failure)      scasp(Unit:Goal,[model,tree])
              │                                    │
      postprocess_why → JSON            le_scasp_tree_json (normaliser)
                     ╲                         ╱
                      common explanation-tree JSON
                              │
              existing explanation UI (+ model tabs, constraint answers)
```

Crucially, the Prolog-generated code is **not** handed to s(CASP): it carries
`is/2`, `findall`-based aggregates and meta-interpreter hooks s(CASP) can't run.
Instead `le_scasp.pl` re-emits an s(CASP) program from the loaded clauses. The LE
rule bodies are trees of `and/2`, `or/2`, `not/1` and `le_at/3` source wrappers
over leaf goals; the emitter strips `le_at`, translates the connectives, and
lowers each leaf (§4).

### Runner (Mode A)

`le_scasp_query/6` writes the emitted program (plus the scenario's facts) to a
temporary module file that `:- use_module(library(scasp)).`, consults it, and
calls `scasp(Unit:Goal, [model(Model), tree(Tree)])`, backtracking over stable
models. Key facts:

- **Mode A only.** Plain clauses in a module — *not* `begin_scasp/end_scasp`
  units, which are not queryable via `scasp/2`. The `#pred` / `#abducible` /
  opposite directives are emitted as clause-level terms; `library(scasp)`'s term
  expansion registers them on load.
- **Query variables are named before solving** (`name_bindings/3`) because
  s(CASP) binds them in place; `findnsols/4` copies each answer out.
- **Time-budgeted and bounded**: `call_with_time_limit/2` (default 10 s) and
  `findnsols(Max, …)` (default 25 models). A timeout yields the
  `scasp_timeout` issue plus whatever was found first.

---

## 3. Traceability — click-to-source

Every s(CASP) tree node is rendered back to an LE sentence and, where possible,
carries a source span so clicking it highlights the rule/template in the editor —
exactly as for the Prolog explanation. Spans are attached at **head
granularity** by `kb_pred_source/4`: the defining rule head, else the template
declaration span (from `le_source_info/4`). Node literals are rendered through
`le_kbs:item_to_instance/3` + `canonical_string/2`, so they read as the program's
own English.

---

## 4. LE construct → s(CASP) mapping

The emitter (`lower_body/5`, `lower_leaf/3`) translates each construct:

| LE construct | s(CASP) lowering |
|---|---|
| Rule `H if B` | `H :- B.` (a `;` in the body is DNF-expanded, see below) |
| `and` / `or` | `,` / `;` — the `;` is then lifted to separate clauses |
| `it is not the case that G`, `unless C` | `not G` (default negation; De Morgan-normalised, see §7) |
| `; opposite: T` | classical negation `-p(…)` + global constraint `false :- p(X), -p(X).` (`opposite_constraints/2`) |
| `; assumable` / `; unknown` | `#abducible p(…).` — assumption sets returned per model (`abducible_directive/2`) |
| Every user template | a `#pred` directive carrying the LE sentence with typed `@`-placeholders (`pred_directive/2`) — powers s(CASP)'s own `--human` output and cross-checks our normaliser |
| Comparisons `>`, `>=`, `<`, `=<` | **CLP(ℚ) constraints** `#>`, `#>=`, `#<`, `#=<` |
| Equality / assignment (`is`, `=`) on numbers | `#=` (relational); on non-numbers, plain `=` |
| Arithmetic `+ - * /` etc. | left symbolic inside `#=` (CLP), never `is/2` |
| Scenario facts | asserted as ground clauses in the unit |

### Constraints are relational, not functional

This is the single most important lowering choice. `an amount is greater than
25000` becomes `Amount #> 25000`, not a test on a bound value. Consequently a
query can be answered **with no concrete scenario at all**, and the answer comes
back *as a constraint* — the headline feature (§5).

### DNF clause-splitting

s(CASP) forbids `;/2` in a clause body. `body_to_dnf/2` distributes `;` over `,`
into one clause per conjunction, using only `append/3` (never `findall`, which
would copy terms and sever head↔body variable sharing → unbound answers). Each
resulting clause is printed whole so its head and body variables correspond.

---

## 5. Answers: constraints, multiple models, abduction

s(CASP) answers are richer than Prolog's ground bindings, and the answers pane
grows three capabilities.

### Constraint / symbolic answers (§5b)

When the answer goal is **non-ground**, `le_scasp_symbolic_goal/4` reads the
CLP(ℚ) residual attached to each variable (via `copy_term/3` attributes), maps the
operator to English (`greater than`, `less than or equal to`, …), and fills the
slot using the **template's type noun**. So a program

```
a claim of an amount is covered if the amount is greater than 25000.
```

queried as `a claim of which amount is covered` with no scenario answers:

> *a claim of **any amount greater than 25000** is covered*

The result carries `symbolic: true` and a `constraints` list. This lets a user ask
*"under what conditions would this hold?"* directly.

### Multiple models — "possible worlds" (§5a)

One query may yield several stable models, each with its own bindings, partial
model and justification. s(CASP) enumerates a model for **every truth assignment
of the unused abducibles**, so the same "possible world" can recur many times; the
web handler therefore:

1. builds one result per model (`scasp_answers_json/3`),
2. **deduplicates** by *(answer sentence + order-insensitive assumption set)*
   (`scasp_dedup_results/2`), and
3. stamps 1-based `modelIndex` / `modelCount` (`number_results/4`).

The editor labels each distinct card **"world *i* of *n*"** (`explanation-view.ts`;
in `/executive` this reads as "possible worlds"). With exactly one model — the
common legal-reasoning case — the badge is hidden and the UI is identical to
today's.

### Abduction — assumption sets (§5c)

Each model may have needed to **assume** some abducibles to make the query hold.
`le_scasp_assumptions/3` walks the justification tree collecting the ground
`abduced`/`assume` atoms (skipping the internal NMR subtree), deduplicated, and
renders them in LE. These are surfaced through the **same `unknowns` channel** the
Prolog engine already uses for assumed facts, so the existing amber "?" marker and
tooltip render them with no editor change. This answers *"what would have to be
true for X to hold?"* — demonstrated by
`examples/moreExamples/abduction/loan_approval.le` (four distinct worlds, each with
its own assumption set).

---

## 6. Explanations

`le_scasp_tree_json/4` converts the s(CASP) justification term (`Node-Children`,
where `Node` is `goal_origin(Atom,Ref)` possibly wrapped in
`assume/abduced/chs/proved/not/-`) into the **same explanation-tree JSON schema**
the UI already consumes: `{type, literal, children[, start, end, naf, assumed,
classicalNegation]}`. Because the schema is display-shaped rather than
proof-shaped, the entire existing explanation UI works unchanged — colours,
tooltips, expand/collapse, hierarchical numbering, repeated-sub-explanation
collapsing, the Explanation Drill, Copy as Mermaid, and click-to-source.

Node status mapping (`node_atom_status/4` + `apply_flags/3`):

| s(CASP) node | JSON `type` | flag |
|---|---|---|
| plain atom, `proved` | `success` | — |
| `not A` (constructive negation) | `failure` | `naf: true` |
| `-A` (classical negation) | `failure` | `classicalNegation: true` |
| `assume(A)` / `abduced(A)` | `unknown` | `assumed: true` (amber) |
| internal `o_nmr_check` / `o_chk_*` | *dropped* | — |

**Negation is proved, not absent.** In Prolog, `\+ G` failing is an absence — a
red "could not be proven" leaf. In s(CASP), `not G` is *proved via dual rules*, so
the tree contains a real sub-proof of why `G` fails, rule by rule (`naf` nodes).
This is strictly better failure-explanation material — roughly what the Prolog
"Detailed failure explanations (per-rule nodes)" preference approximates.

**Trace stays Prolog-only.** The step Trace button is disabled under s(CASP)
(`editor/src/client.ts`); the justification tree supersedes it.

---

## 7. Negation: De Morgan normalisation

s(CASP) bodies accept **only `not <literal>`**. It rejects `not (a ; b)`,
`not (a , b)`, and even `not not a`. LE freely allows `and`/`or` inside `it is not
the case that …`, so `demorgan_negate/2` (called from `lower_body(not(G))`) pushes
the negation inward:

- `not (A or B)` → `not A and not B`
- `not (A and B)` → `not A or not B` (the `;` then lifted by DNF, §4)

This is sound for default negation. **Double negation** cannot be expressed in
this s(CASP); it throws `le_scasp_untranslatable(scasp_double_negation)`, which
`emit_rules/4` catches and reports as a targeted issue (the rule is skipped, the
program runs Prolog-only for that rule) rather than crashing.

A safety net in `run_models_recover/3` converts any residual `permission_error` /
`determinism_error` from s(CASP) into an `unsupported_construct` issue instead of
letting it escape as an HTTP 500.

---

## 8. Unsupported constructs → issues (errors)

Where an LE extended construct has no s(CASP) equivalent, the emitter does **not**
fail silently: it emits an `le_scasp_issue(Kind, RuleID, Message)` and (where it
must) substitutes `true` for the leaf so the rest of the program still runs. The
issues are shown next to the "See s(CASP)" output and query results. **All
messages come from the i18n dictionaries** (`i18n/messages.csv`, keys `scasp_*`),
never hardcoded, so they appear in the active language; the handlers call
`ensure_kb_language/1` first so the language matches the program.

| LE construct | Issue key | Handling |
|---|---|---|
| Aggregates (`sum/count/… of each`) | `scasp_aggregate` | not supported — use the Prolog engine |
| `prolog <goal>` / `.pl` resources | `scasp_prolog_goal` | Prolog-only |
| `for all cases …` (universal) | `scasp_universal` | not translated |
| Date arithmetic (`… days after …`) | `scasp_date_arithmetic` | not supported |
| `is in` (list membership) | `scasp_list_membership` | not translated |
| non-numeric `is different from` | `scasp_term_disequality` | not translated |
| `is known` | `scasp_unsupported_known` | only approximated |
| double negation | `scasp_double_negation` | can't be expressed (§7) |
| any other untranslatable rule | `scasp_untranslatable_rule` | rule skipped |
| query timeout | `scasp_timeout` | partial answers returned |
| residual illegal construct | `scasp_unsupported_construct` | e.g. an "or" the emitter couldn't lift |
| pack absent | `scasp_engine_not_installed` | whole engine unavailable |

The consistent advice in these messages is *"run this query with the Prolog
engine"* — the two engines are complementary, not competing.

---

## 9. Stratification check (verifier)

Programs that **loop through negation** (non-stratified) are exactly where the two
engines diverge: Prolog (SLDNF) may loop or answer unsoundly, while s(CASP)
computes the stable model. `le_scasp_stratification/2` builds the predicate
dependency graph (`pos`/`neg` edges) and finds cycles that traverse at least one
`not` edge. This is wired into `verify/2`, which warns in the editor via the
localized `non_stratified_desc` message: *"…{name} depend on one another through
negation. The Prolog engine may loop or give unsound answers — consider running
this query with the s(CASP) engine."*

---

## 10. Testing

- **Prolog unit tests:** `testing/test_scasp.pl` — emitter, De Morgan
  (`or_positive_dnf_expands`, `or_under_negation_demorgan`,
  `double_negation_reports_issue`), i18n (`issue_message_localized`), and a
  **differential test** running citizenship under both engines and asserting they
  agree with the recorded `expects answers`.
- **Editor e2e:** `editor/tests/scasp-engine.spec.ts` — the engine selector, the
  target-language pre-selection, a symbolic constraint answer, multi-model
  "world *i* of *n*" cards, and Trace being disabled under s(CASP).
- **Differential testing** is the main quality mechanism (plan §7): the same
  program/scenario/query under both engines. Any divergence is either a compiler
  bug or a genuine semantic difference (a non-stratified program), and the genuine
  ones are precisely what the stratification warning flags.

Demo files:

| File | Feature |
|---|---|
| `examples/moreExamples/dual_engine_demo.le` | non-stratified — Prolog gives no answer, s(CASP) finds the stable model |
| `examples/moreExamples/clp_coverage.le` | §5b constraint / symbolic answer |
| `examples/moreExamples/abduction/sunglasses.le` | §5c abduction set |
| `examples/moreExamples/abduction/loan_approval.le` | multi-model — 4 possible worlds, each with its own assumptions |

---

## 11. Guidance: which engine, when

- **Prolog** (default): stratified programs, aggregates, `prolog` goals, large
  fact sets, date arithmetic. Much faster.
- **s(CASP)**: loops through negation, exact/constraint arithmetic, "what must be
  assumed?" (abduction), non-finitely-groundable rules, and any case where the
  *quality of the explanation of a failure* matters most.

The stratification check surfaces this as an editor hint; the choice stays with
the user.

---

## 12. Current status and known limitations

WP1–WP7 of the plan are delivered and the full test suite is green (Prolog unit +
LE examples + Playwright e2e). Remaining polish, none blocking:

- **No "Both" side-by-side diff view** in the UI yet (the backend diff exists as
  the differential test harness).
- **Constraint numbers render raw** — no thousands separator / locale formatting
  (`25000`, not `25,000`).
- **Source spans are head-granularity** (`kb_pred_source/4`) — clicking a tree
  node highlights the defining rule head or template, not the exact sub-goal.
  Could be refined via s(CASP)'s `assert_scasp_source_reference/3`.

### Forward compatibility (browser)

Both engines are SWI-Prolog libraries and the s(CASP) SWI port is pure Prolog, so
the design ports to `swipl-wasm` unchanged: the engine toggle simply selects which
library answers, client-side, with the LE parser in the same instance. The runner
(`le_scasp_query/6`) is kept free of server-only assumptions apart from the
temp-file consult, which would be replaced by an in-memory load in that setting.

---

## 13. Code map

| Concern | Location |
|---|---|
| Emitter, `#pred`/`#abducible`/opposites, De Morgan, CLP lowering, DNF | `le_scasp.pl` — `le_scasp_program_text/3`, `lower_body/5`, `lower_leaf/3`, `demorgan_negate/2`, `body_to_dnf/2` |
| Runner (Mode A, time budget, model collection) | `le_scasp.pl` — `le_scasp_query/6`, `load_scasp_unit/4`, `run_models/6` |
| Justification normaliser | `le_scasp.pl` — `le_scasp_tree_json/4`, `node_json/3`, `node_atom_status/4` |
| Constraint (symbolic) answers | `le_scasp.pl` — `le_scasp_symbolic_goal/4` |
| Abduction sets | `le_scasp.pl` — `le_scasp_assumptions/3` |
| Stratification | `le_scasp.pl` — `le_scasp_stratification/2`; wired in `le_verifier.pl` |
| Web ops `getScasp` / `scaspQuery`, model dedup + numbering | `classic_web_api.pl` — `handle_get_scasp/2`, `handle_scasp_query/2`, `scasp_dedup_results/2` |
| Target-language declaration | `le_grammar.pl`, `le_kbs.pl` — `kb_target_language/2` |
| Engine selector, "See s(CASP)", Trace gating, world badge | `editor/src/client.ts`, `editor/src/explanation-view.ts`, `editor/src/i18n.ts` |
| Issue messages (i18n) | `i18n/messages.csv` — `scasp_*`, `non_stratified_desc` |
| Tests | `testing/test_scasp.pl`, `editor/tests/scasp-engine.spec.ts` |

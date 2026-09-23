# s(CASP) on Logical English

*Kind: reference · Audience: users, developers · Status: current (2026-09-16)*

Logical English 2 can run the **same program** with either of two reasoning
engines, that is, with either of two pieces of software that work out the
answers:

- the default **Prolog** engine, which answers a question by working backwards
  through the rules (SLDNF), driven by an interpreter of our own written in
  Prolog itself, `reasoner.pl`; and
- an **s(CASP)** engine, a goal-directed form of Answer Set Programming: it too
  starts from the question, and it works out the complete, self-consistent sets
  of facts — the stable models — in which the answer holds. `library(scasp)`
  provides that engine, and Logical English runs the library inside its own
  process rather than calling out to a separate program.

This document describes the s(CASP) support as it is actually built. For the
reasons behind the design, and for the list of work packages, see
[`sCASP_plan.md`](../../project/plans/sCASP_plan.md); the present page is the
companion that says what the support does and how to use it. The engine itself
is all in **`le_scasp.pl`**. The code that carries a question from the web page
to the engine and the answer back is in `classic_web_api.pl`, and the screens
the user sees are in `editor/`.

> **Why two engines?** Prolog is fast. Prolog handles totals and counts over many
> facts, `prolog` goals and large collections of facts, and Prolog stays the
> default. s(CASP) adds four things Prolog does not do well. s(CASP) can answer
> **with a condition rather than a value**, such as *any amount over 25000*.
> s(CASP) can find **several stable models**, which are several possible worlds
> in which the answer holds. s(CASP) can work out **what would have to be true**
> for the answer to hold, which is called abduction. And s(CASP) **proves a
> negative statement** instead of merely failing to find the positive one, so the
> answer carries a real proof of *why* something fails. s(CASP) also gives
> trustworthy answers for programs whose rules loop through a negation
> (non-stratified programs), where Prolog may run for ever or answer wrongly.

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
- [14. Reading s(CASP) back](#14-reading-scasp-back-september-2026)

---

## 1. Choosing the engine

Three things choose the engine. Where they disagree, each one in this list
overrules the one before it:

1. **The program says so.** A program's first sentence may name the engine the
   program is written for: `the target language is: prolog.` or
   `the target language is: scasp.`. Other languages have their own wording,
   such as `a linguagem alvo é: scasp.`. The server reads that sentence and
   keeps the answer as `kb_target_language/2`, and the editor uses the answer to
   **choose in advance** which engine its engine menu offers
   (`editor/src/client.ts`, `res.target`).
2. **The engine menu in the editor.** The Query tab has a menu offering Prolog
   or s(CASP). The editor keeps the choice in the web address as
   `?engine=scasp`, so a link one user sends another brings back the same
   program, the same scenario, the same query and the same engine. Once the user
   has chosen an engine by hand, the program's own declaration no longer
   overrides that choice (`engineUserSet`).
3. **The setting that shows or hides the engine menu** (Misc menu). Most Logical
   English programs are written for Prolog, so the menu can be hidden for those
   programs: the setting offers "Always show engine choice" or "Show engine
   choice only for non-Prolog". The editor works out which engine a program
   declares by reading the text on the screen (`detectTargetLanguage`,
   `editor/src/i18n.ts`), so the menu appears or stays hidden correctly without
   the editor first having to ask the server.

When the user has chosen s(CASP), the editor asks the server for `scaspQuery`
instead of the usual `answer`. The "See s(CASP)" button, next to "See PROLOG",
asks for `getScasp`, which shows the s(CASP) program that Logical English wrote
from the user's program.

**Availability.** s(CASP) is an optional addition to SWI-Prolog, called a pack.
`le_scasp_available/0` holds only when `library(scasp)` is installed. Without
the pack nothing crashes: every way into the engine stops politely and reports
the problem `scasp_engine_not_installed` in the reader's own language. A query
answers with that message, and See s(CASP) shows the message in a dialog box.
The ready-made SWI-Prolog image, `swipl:latest`, does not include the pack, so
the `Dockerfile` installs it with `pack_install(scasp)`.

---

## 2. Architecture

The two engines are **two children of the same loaded knowledge base** (KB, the
program as the system holds it in memory). Each engine's program is written out
from that knowledge base, and neither engine feeds the other:

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

The Prolog code is **not** handed to s(CASP), and that matters. The Prolog code
uses `is/2`, works out totals and counts with `findall`, and contains places
where our own Prolog interpreter takes over the running; s(CASP) can run none of
those. So `le_scasp.pl` writes a fresh s(CASP) program from the loaded rules
instead. A Logical English rule body is a tree built from `and/2`, `or/2`,
`not/1` and `le_at/3`, the last of which wraps a condition to record where in
the document the condition came from; the single conditions at the tips of the
tree are its leaves. `le_scasp.pl` removes each `le_at` wrapper, translates the
`and`, `or` and `not`, and turns every leaf into s(CASP) (§4).

### Runner (Mode A)

`le_scasp_query/6` writes the new program, together with the scenario's facts,
into a temporary file. The file opens with `:- use_module(library(scasp)).`.
`le_scasp_query/6` then loads the file and calls
`scasp(Unit:Goal, [model(Model), tree(Tree)])`, asking for one stable model
after another. Three points are worth knowing:

- **Mode A only.** The rules go into a module as ordinary clauses, and *not*
  into `begin_scasp/end_scasp` units, because `scasp/2` cannot ask a question of
  a program written as such a unit. The `#pred`, `#abducible` and opposite
  instructions are written out alongside the clauses; `library(scasp)` notices
  each of them as the file loads and records it.
- **The question's variables are given names before the search begins**
  (`name_bindings/3`), because s(CASP) fills variables in where they stand;
  `findnsols/4` then copies each answer out.
- **The search is limited in time and in size**: `call_with_time_limit/2` stops
  it after ten seconds by default, and `findnsols(Max, …)` collects 25 models by
  default. When the time runs out, the reply is the `scasp_timeout` problem
  together with whatever the search had already found.

---

## 3. Traceability — click-to-source

Every step of an s(CASP) proof tree is written back out as a Logical English
(LE) sentence. Where possible, the step also records which stretch of the
document it came from, so that clicking the step highlights the rule or the
template in the editor, exactly as clicking a step of a Prolog explanation does.
`kb_pred_source/4` attaches those stretches **one whole conclusion at a time**:
the stretch is the head of the rule that defines the conclusion or, failing
that, the stretch where the template was declared (from `le_source_info/4`).
`le_kbs:item_to_instance/3` and `canonical_string/2` write out the sentence in
each step, so a step reads as the program's own English.

---

## 4. LE construct → s(CASP) mapping

`lower_body/5` and `lower_leaf/3` translate each construct:

| LE construct | s(CASP) lowering |
|---|---|
| Rule `H if B` | `H :- B.` (an `or`, written `;`, in the body is multiplied out into separate rules, see below) |
| `and` / `or` | `,` / `;` — each `;` is then turned into separate clauses |
| `it is not the case that G`, `unless C` | `not G` (negation as failure, that is, the condition counts as false when it cannot be proved; pushed inwards by De Morgan's laws, see §7) |
| `; opposite: T` | classical negation `-p(…)`, which states the opposite outright: every rule, fact and condition of the opposite form is written as `-p(…)`, its wording as `#pred -p(…) :: '…'`, and the global constraint `false :- p(X), -p(X).` ties the two together, since nothing may be both (`opposite_map/2`, `to_classical/2`, `opposite_constraints/2`) |
| `; assumable` / `; unknown` | `#abducible p(…).` — each model comes back with the set of facts it had to assume (`abducible_directive/2`); an element of a scenario (`; undefined`) may not be assumed |
| `it must not be true that …` ([language.md](language.md) §3.3) | the global constraint `false :- Conditions.` (`kb_constraint_clauses/2`): every model, and so every set of assumed facts, must obey the constraint. The Prolog reasoner applies the same consistency test to the facts it assumes (`reasoner:consistent_assumptions/4`) |
| `for all cases in which C it is the case that G` | the denial of a helper rule that goes looking for a counter-example (the Lloyd–Topor transformation): `not le_forall_K(Shared)` together with `le_forall_K(Shared) :- C, not G.` The helper is needed because s(CASP)'s own `forall/2` speaks of one variable at a time and s(CASP) has no `call/1` |
| The ontology section's `is_a/2` clauses | clauses of the unit, like any other |
| Decision tables, service conditions, `according to` in a rule, `the minimum/maximum of`, a sentence used as a condition (`… is the case`), a condition with no template | one reported problem each, since none can be translated (§8); a Logical English record is never left in the output as it stands |
| Every user template | a `#pred` directive carrying the Logical English sentence, with the places marked by `@` and typed (`pred_directive/2`). The directive is what drives s(CASP)'s own `--human` output, and it double-checks the sentences we write out ourselves |
| Comparisons `>`, `>=`, `<`, `=<` | **CLP(ℚ) constraints** `#>`, `#>=`, `#<`, `#=<`, which hold as standing requirements on a number rather than as tests of a known one |
| Equality / assignment (`is`, `=`) on numbers | `#=`, again a standing requirement; between things that are not numbers, plain `=` |
| Arithmetic `+ - * /` etc. | left unworked-out inside `#=` as a requirement on the numbers, never `is/2` |
| Scenario facts | stated in the unit as clauses with every value filled in |
| A query (`which person is happy and the person is rich`, a custom query) | translated like a rule body (`le_scasp_query_goal/6`) into the clauses of a helper, `le_query(Vars)`, whose arguments are the query's variables; s(CASP) is then asked the helper, and the explanation shows the query's own conditions rather than the helper. Before the helper existed, a query of several conditions reached s(CASP) as Logical English's own `and/2`, which the unit does not define (`existence_error: scasp_predicate …:and/2`). Asking the helper also keeps a query about a predicate with no clause in the unit — no rule and no fact in this scenario — from raising an error: the query simply has no answer, as in Prolog |
| Where a document is published, where its text is (`… is published at …`, `the text of … is at …`) | not written out: these are records that the explanation's citations read, not clauses of the program |

### Constraints are relational, not functional

Of all the choices made in translating, this one matters most. `an amount is
greater than 25000` becomes `Amount #> 25000`, which is a requirement the
amount must meet, and not a test applied to an amount already known. Because
the requirement stands on its own, a query can be answered **with no scenario
at all**, and the answer comes back *as a condition on the amount* rather than
as a number. That is the headline feature (§5).

### DNF clause-splitting

s(CASP) forbids `;/2`, the *or*, in the body of a clause. `body_to_dnf/2`
therefore distributes each `;` over the `,` around it — that is, it multiplies
each *or* out over the *and*s — leaving one clause for every combination of
conditions. `body_to_dnf/2` does the work with
`append/3` alone, and never with `findall`: `findall` would copy the terms, and
a copy breaks the link between a variable in the head and the same variable in
the body, so the answers would come back with nothing filled in. Each clause
that results is printed as a whole, so that the variables in its head and the
variables in its body still match.

---

## 5. Answers: constraints, multiple models, abduction

A Prolog answer fills each variable of the question with a definite value. An
s(CASP) answer can say more than that, and the answers pane gains three
abilities.

### Constraint / symbolic answers (§5b)

When the answer still holds a variable that **no value has filled**,
`le_scasp_symbolic_goal/4` reads the arithmetic requirements s(CASP) has left
attached to that variable, which `copy_term/3` hands over. `le_scasp_symbolic_goal/4`
then turns each comparison into English — `greater than`, `less than or equal to`, and so on —
and names the value by the **noun the template gives that place's type**. So a
program

```
a claim of an amount is covered if the amount is greater than 25000.
```

asked `a claim of which amount is covered`, with no scenario at all, answers:

> *a claim of **any amount greater than 25000** is covered*

The result carries `symbolic: true` and a list of `constraints`. An answer of
this kind lets a user ask *"under what conditions would this hold?"* and be
answered directly.

### Multiple models — "possible worlds" (§5a)

One query may produce several stable models. Each model comes with its own
values for the variables, its own set of facts that hold, and its own
justification. s(CASP) produces a model for **every way of settling, as true or
as false, each assumable fact the proof did not need**, so the same "possible
world" can come back many times over. The server therefore does three things:

1. it builds one result for each model (`scasp_answers_json/3`),
2. it **throws the duplicates away**, counting two results as the same when they
   have the same answer sentence and the same set of assumptions, whatever order
   the assumptions come in (`scasp_dedup_results/2`), and
3. it numbers what is left from one upwards, as `modelIndex` out of
   `modelCount` (`number_results/4`).

The editor labels each card that survives **"world *i* of *n*"**
(`explanation-view.ts`); on the `/executive` page the same thing reads as
"possible worlds". When there is exactly one model, which is the usual case in
legal reasoning, the editor hides the label and the screen looks just as it
always did.

### Abduction — assumption sets (§5c)

To make the query hold, a model may have had to **assume** some of the assumable
facts. `le_scasp_assumptions/3` walks the justification tree and collects every
fully settled `abduced` or `assume` atom, leaving out the part of the tree
s(CASP) keeps for its own internal checks. `le_scasp_assumptions/3` then throws
away the duplicates and writes the assumptions out in Logical English. The
assumptions reach the editor by the **same `unknowns` route** the Prolog engine
already uses for the facts it assumes, so the amber "?" marker and its tooltip
show them with no change to the editor at all. Assumptions answer the question
*"what would have to be true for X to hold?"*, as is shown by
`examples/moreExamples/language/abduction/loan_approval.le` (four distinct worlds, each with
its own assumption set).

---

## 6. Explanations

s(CASP) returns its justification as a tree written `Node-Children`, in which
each `Node` is `goal_origin(Atom,Ref)`, sometimes wrapped in one of
`assume/abduced/chs/proved/not/-`. `le_scasp_tree_json/4` converts that
tree into the **same shape of explanation tree** the screens already read,
written in JSON (JavaScript Object Notation, a plain-text way of writing data
down): `{type, literal, children[, start, end, naf, assumed,
classicalNegation]}`. That shape describes how an explanation is to be
displayed, not how it was proved, so the whole of the existing explanation
display works unchanged: the colours, the tooltips, opening and closing a step,
the numbering of steps within steps, the folding away of a sub-explanation that
repeats, the Explanation Drill, Copy as Mermaid, and clicking a step to reach
the sentence it came from.

`node_atom_status/4` and `apply_flags/3` turn the state of a node into what the
display shows:

| s(CASP) node | JSON `type` | flag |
|---|---|---|
| plain atom, `proved` | `success` | — |
| `not A` (constructive negation) | `failure` | `naf: true` |
| `-A` (classical negation) | `failure` | `classicalNegation: true` |
| `assume(A)` / `abduced(A)` | `unknown` | `assumed: true` (amber) |
| internal `o_nmr_check` / `o_chk_*` | *dropped* | — |

**A negative statement is proved, not merely missing.** In Prolog, when `\+ G`
holds, all that has happened is that `G` could not be found, and the explanation
shows a red "could not be proven" leaf. In s(CASP), `not G` is *proved*, by
rules that s(CASP) derives for the negative case, so the tree holds a real proof
of why `G` fails, rule by rule (the `naf` nodes). A proof of that kind explains
a failure far better; it is roughly what the Prolog preference "Detailed failure
explanations (per-rule nodes)" tries to come close to.

**Trace stays Prolog-only.** The editor disables the step-by-step Trace button
when s(CASP) is the engine (`editor/src/client.ts`), because the justification
tree takes the place of a trace.

---

## 7. Negation: De Morgan normalisation

In the body of an s(CASP) rule, a negation may take the form **`not <literal>`
and no other**: `not` may stand in front of one single condition and nothing
more. s(CASP) rejects `not (a ; b)`, `not (a , b)` and
even `not not a`. Logical English, by contrast, allows `and` and `or` freely
inside `it is not the case that …`. `demorgan_negate/2`, which
`lower_body(not(G))` calls, therefore pushes the negation inwards until it
stands in front of single conditions:

- `not (A or B)` → `not A and not B`
- `not (A and B)` → `not A or not B` (the `;` then lifted by DNF, §4)

Pushing the negation inwards leaves the meaning untouched, as long as the
negation is negation as failure. **A negation of a negation**, however, cannot
be written in this version of s(CASP). The translation raises
`le_scasp_untranslatable(scasp_double_negation)`, `emit_rules/4` catches the
error, and the user is told precisely what the problem is instead of the program
crashing. The problem is one that blocks, so the s(CASP) engine refuses the
program (§8) and the program runs with Prolog only.

`run_models_recover/3` is the safety net. Should s(CASP) still raise a
`permission_error` or a `determinism_error` while running, `run_models_recover/3`
turns the error into an `unsupported_construct` problem, so the user reads what
went wrong rather than the web server reporting a bare internal failure (an HTTP
500).

---

## 8. Unsupported constructs → issues (errors)

Where a Logical English construct has no equivalent in s(CASP), the translation
does **not** fail quietly. The translation reports
`le_scasp_issue(Kind, RuleID, Message)`, in which `RuleID` names the rule the
construct sits in. A program with such a construct is **refused**. "See
s(CASP)" then shows no program at all, only the list of problems with the line
each one is on, and the s(CASP) engine does not run the program (`scaspQuery`
answers with an error carrying the same list). The refusal is deliberate: the
text the translation keeps for its own use (`le_scasp_program_text/3` puts
`true` where the untranslatable condition was, which makes the rule apply more
widely) would mean something other than the Logical English does.
`le_scasp_check/3` draws up the list of problems. `le_scasp_blocking_issue/1`
says which problems refuse a program: all of them except the engine's own
three — the pack being absent, the time running out, and a construct the engine
rejects while it runs. The converters to other systems refuse in the same way
(`docs/dev/migration.md`, "Exporting: the check before the text"). **Every
message comes from the translation dictionaries** (`i18n/messages.csv`, the keys
`scasp_*`) and none is written into the code, so each message reaches
the reader in the language in use. The code that answers a request calls
`ensure_kb_language/1` first, so the language of the message matches the
language of the program.

| LE construct | Issue key | Handling |
|---|---|---|
| Totals, counts and the like (`sum/count/… of each`) | `scasp_aggregate` | refused — use the Prolog engine |
| `prolog <goal>` / `.pl` resources | `scasp_prolog_goal` | refused (Prolog-only) |
| `for all cases …` (universal) | `scasp_universal` | refused (the ordinary universal statement is translated, by the Lloyd-Topor transformation) |
| Date arithmetic (`… days after …`) | `scasp_date_arithmetic` | refused |
| `is in` (list membership) | `scasp_list_membership` | refused |
| `is known` | `scasp_unsupported_known` | refused |
| double negation | `scasp_double_negation` | refused: s(CASP) has no way to say it (§7) |
| `the minimum/maximum of` | `scasp_min_max` | refused |
| Decision tables | `scasp_decision_table` | refused |
| Service conditions (semantic comparisons, §17.6 of the language reference) | `scasp_service` | refused |
| `according to` in a rule (source-scoped proof) | `scasp_scoped_proof` | refused |
| a sentence used as a condition (`… is the case`) | `scasp_meta_call` | refused |
| a condition with no template | `scasp_missing_template` | refused |
| any other untranslatable rule | `scasp_untranslatable_rule` | refused |
| query timeout | `scasp_timeout` | partial answers returned |
| a construct the translation left exactly as it was (Logical English's `and/2`, `le_flip/2`, a built-in condition inside a comparison, a sentence with no template written as a fact, …) in a rule, a fact or a query | `scasp_leftover_construct` | refused: `leftover_in_clauses/2` inspects every translated clause, so nothing belonging to Logical English itself is left for s(CASP) to call; should one slip through even so, the run reports the same problem rather than an error |
| an illegal construct still left over | `scasp_unsupported_construct` | for example, an "or" the translation could not turn into separate clauses |
| pack absent | `scasp_engine_not_installed` | the engine cannot be used at all |

An `is different from` between two things that are not numbers becomes
s(CASP)'s own `X \= Y`, which states outright that the two differ. One warning
about s(CASP) 1.1.4: where facts may be assumed, a global constraint that uses
`\=` and still holds a variable no value has filled can be answered wrongly,
because a model may assume the very thing the constraint forbids. A constraint
with every value filled in is answered correctly.

Every one of these messages gives the same advice: *"run this query with the
Prolog engine"*. The two engines complete each other; they do not compete.

---

## 9. Stratification check (verifier)

A program **loops through negation** when a conclusion depends, through a chain
of rules, on the denial of itself; such a program is called non-stratified.
Non-stratified programs are exactly where the two engines part company: Prolog
may run for ever or answer wrongly, while s(CASP) works out the stable model.
`le_scasp_stratification/2` draws the map of which conclusion depends on which,
marking each dependency as positive (`pos`) or negative (`neg`), and then looks
for a loop that passes through at least one negative step, that is, through at
least one `not`. `verify/2` calls
`le_scasp_stratification/2` and warns in the editor with the
`non_stratified_desc` message, in the reader's own language: *"…{name} depend on one another through
negation. The Prolog engine may loop or give unsound answers — consider running
this query with the s(CASP) engine."*

---

## 10. Testing

- **Prolog unit tests:** `testing/test_scasp.pl` covers the translation itself,
  the use of De Morgan's laws (`or_positive_dnf_expands`,
  `or_under_negation_demorgan`, `double_negation_reports_issue`) and the
  translated messages (`issue_message_localized`). The same file holds a
  **comparison test**, which runs the citizenship program under both engines and checks that
  both agree with the answers the program records in its `expects answers`.
- **Tests of the editor from end to end:** `editor/tests/scasp-engine.spec.ts`
  checks the engine menu, the engine being chosen in advance from the program's
  declaration, an answer given as a condition rather than a value, the
  "world *i* of *n*" cards when there are several models, and Trace being
  disabled under s(CASP).
- **Running the same thing under both engines** is the main way quality is kept
  (plan §7): the same program, the same scenario and the same query, answered
  twice. Any difference between the two answers is either a fault in the
  translation or a real difference in meaning, which is what a non-stratified
  program produces. The real differences are precisely the ones the
  stratification warning points out.

Demo files:

| File | Feature |
|---|---|
| `examples/moreExamples/language/scasp/dual_engine_demo.le` | loops through negation — Prolog gives no answer, s(CASP) finds the stable model |
| `examples/moreExamples/language/scasp/clp_coverage.le` | §5b, an answer given as a condition rather than a value |
| `examples/moreExamples/language/abduction/sunglasses.le` | §5c, a set of assumptions |
| `examples/moreExamples/language/abduction/loan_approval.le` | several models — 4 possible worlds, each with its own assumptions |

---

## 11. Guidance: which engine, when

- **Prolog** (the default): programs that do not loop through negation, totals
  and counts, `prolog` goals, large collections of facts, arithmetic on dates.
  Much faster.
- **s(CASP)**: programs that loop through negation, exact arithmetic and answers
  given as conditions, the question "what must be assumed?" (abduction), rules
  whose variables range over values too many to list one by one, and any case
  where the *quality of the explanation of a failure* matters most.

The stratification check offers the same advice as a hint in the editor; the
choice stays with the user.

---

## 12. Current status and known limitations

Work packages 1 to 7 of the plan are finished, with the tests of §10. What is
left is polish, and none of it stops anyone working:

- **There is no "Both" view yet**, showing the two engines' answers side by
  side; the comparison exists only as the test that runs both engines.
- **A number inside a condition appears unformatted** — no thousands separator
  and no grouping to suit the reader's country (`25000`, not `25,000`).
- **A step points at a whole conclusion, not at one condition**
  (`kb_pred_source/4`): clicking a step of the tree highlights the head of the
  rule that defines it, or the template, rather than the exact condition.
  s(CASP)'s `assert_scasp_source_reference/3` could make the pointing finer.

### Forward compatibility (browser)

Both engines are SWI-Prolog libraries, and the SWI-Prolog version of s(CASP) is
written in Prolog alone, so the whole design carries over unchanged to
`swipl-wasm`, which runs SWI-Prolog inside a web browser. In the browser the
engine menu would simply choose which of the two libraries answers, on the
reader's own machine, with the part that reads Logical English running in the
same copy of Prolog. `le_scasp_query/6`, which runs a query, assumes nothing
that only a server can provide, apart from loading the temporary file; in the
browser it would load the program from memory instead.

---

## 13. Code map

| Concern | Location |
|---|---|
| Writing the s(CASP) program: `#pred`, `#abducible`, opposites, De Morgan's laws, the CLP constraints, multiplying out the `or`s | `le_scasp.pl` — `le_scasp_program_text/3`, `lower_body/5`, `lower_leaf/3`, `demorgan_negate/2`, `body_to_dnf/2` |
| Running a query (Mode A, the time limit, collecting the models) | `le_scasp.pl` — `le_scasp_query/6`, `load_scasp_unit/4`, `run_models/6` |
| Putting the justification into the display's own form | `le_scasp.pl` — `le_scasp_tree_json/4`, `node_json/3`, `node_atom_status/4` |
| Answers given as a condition rather than a value | `le_scasp.pl` — `le_scasp_symbolic_goal/4` |
| The sets of assumed facts | `le_scasp.pl` — `le_scasp_assumptions/3` |
| Looking for loops through negation | `le_scasp.pl` — `le_scasp_stratification/2`; called from `le_verifier.pl` |
| The web requests `getScasp` and `scaspQuery`, and the removing and numbering of duplicate models | `classic_web_api.pl` — `handle_get_scasp/2`, `handle_scasp_query/2`, `scasp_dedup_results/2` |
| The sentence that declares the target language | `le_grammar.pl`, `le_kbs.pl` — `kb_target_language/2` |
| The engine menu, "See s(CASP)", the disabling of Trace, the world label | `editor/src/client.ts`, `editor/src/explanation-view.ts`, `editor/src/i18n.ts` |
| The wording of the problems, in every language | `i18n/messages.csv` — `scasp_*`, `non_stratified_desc` |
| Tests | `testing/test_scasp.pl`, `editor/tests/scasp-engine.spec.ts` |

## 14. Reading s(CASP) back (September 2026)

`le_writer:prolog_file_to_ir/3` reads an s(CASP) program back into Logical
English, which is this same translation run backwards
(lpsPlus/docs/migration/roadmap.md §5.7, Phase 2c). Each piece of the s(CASP)
tells the reader something. `#pred` gives back the templates, and `@(X:type)`
names each place in a template. `-p` gives back the opposite form.
`#abducible` gives back the `; unknown` addition. A `le_forall_K` helper gives
back the universal statement. `#>`, `#=` and the rest give back the comparisons
and the assignments. A denial gives back a query the scenarios expect to have
no answer (convention N1). And `?-` gives back a query.

`testing/scasp_roundtrip.pl` is the check that guards both directions. The
check takes the core collection of programs and runs each one from Logical
English to s(CASP), back to Logical English, and to s(CASP) once more. On 16
September 2026, 84 of the 88 programs this target can write came back as the
same s(CASP) program: the same clauses, the same assumable facts, the same
constraints on opposite forms and the same `#pred` wordings, differing only in
the names of the variables. Four came back different: one program has two
templates that share a predicate but give its places different types, one has a
universal statement that says nothing, one has an unknown only partly filled
in, and one is the ontology-rule case that `le_writer_roundtrip.pl` also leaves
out. (One further program was deliberately broken, in that a sentence with no
template was written as a fact; that program is now refused, §8.)

Building the check found four faults in this target, all since fixed. Universal
statements were written as Prolog's `forall/2`, which s(CASP) rejects. Opposite
forms were written as separate predicates with constraints that said nothing,
instead of as `-p`. Elements of a scenario were made assumable. And Logical
English's own records — the ontology record, the flip expectations, the
services — were written into the program as facts, as were a document's
addresses (`le_text_at/2`, `le_published_at/2`) until 16 September 2026. The
constraints on the opposite forms now name their variables:
`false :- p(A), -p(A).`, rather than `_126456`.

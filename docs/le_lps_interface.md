# The LE2 ↔ LPS2 interface

**Version 2.** This document is duplicated verbatim in both repositories —
`docs/le_lps_interface.md` in LPS2 and in LogicalEnglish2. Change it in one
and copy it to the other, in the same commit, or the version stamp is a lie.

It is the whole contract. Everything else about how the two systems work is
private to each of them.

---

## 1. What crosses the boundary

One thing, in one direction: **LPS internal syntax, as Prolog text, plus a
provenance list**.

```
  foo.le  ─ LE2 ──▶ { lps, provenance, issues } ─ LPS2 ──▶ program → session → trace
```

LE2 parses Logical English and emits internal syntax. LPS2 reads terms and
runs them. LE2 knows nothing about how the engine works; LPS2 knows nothing
about templates, ordinals or head-noun typing.

**Internal syntax as text, not as JSON-encoded terms.** It is Prolog, LE2
already writes Prolog, and a text blob is diffable, pasteable into `./lps run`,
and inspectable when something goes wrong. JSON-encoding Prolog terms would
require both sides to agree on an encoding of variables, operators and
`'$VAR'`, which is work with no payoff.

---

## 2. The reply

```json
{ "lps":         "<internal-syntax Prolog text>",
  "provenance":  [ { "index": 3, "line": 12, "col": 4,
                     "kind": "le", "file": "foo.le" }, … ],
  "issues":      [ { "severity": "error", "type": "missing_template",
                     "message": "…", "line": 7, "col": 0 }, … ] }
```

`lps` — the program. Read with `read_term/3` under the LPS operator table
(`src/core/lps_ops.pl`); LE2 must therefore write it with those operators in
scope, or write only canonical terms.

`provenance` — one entry per **term** of `lps`, in term order, `index`
0-based. Entries may be missing: a term LE2 generated with no `.le` sentence
behind it (a system declaration, say) simply has none, and keeps the line
number it has in the generated text. `file` defaults to the `.le` document.
`kind` is `le` for anything an author wrote in Logical English.

`issues` — LE-side diagnostics: unparseable sentence, template mismatch,
undeclared word. They are *concatenated* with LPS2's own, never merged:
neither side needs the other's rule set. LE2 reports what it can see, LPS2
reports `achieve` without planning mode, undeclared fluents, `false` clauses
that can never fire.

Positions are **line and column**, 1-based lines, 0-based columns. LE2 stores
character offsets internally; converting is LE2's job, because LE2 is the side
that has the source text.

---

## 3. The transports

There are three, and every one of them carries exactly the payload of §2.

### 3.1 HTTP — LE2's `/leapi`

```
POST /leapi   { "operation": "getLps", "le": "<document text>" }
POST /leapi   { "operation": "getLps", "sessionModule": "s…" }
```

The first form translates a document with no session; the second translates the
document already loaded in a session, as `getScasp` does. Both answer with §2.

### 3.2 Prolog, in-process — LE2's own modules, for its own tests

```prolog
le_lps:le_lps_text(+LEText, -InternalText, -Provenance, -Issues)
le_lps:le_lps_file(+Path,   -InternalText, -Provenance, -Issues)
le_lps:le_lps_json(+Path)    % writes the §2 object to current output
```

`Provenance` is a list of `prov(Index, File, Line, Col, Kind)`; `Issues` is a
list of `le_lps_issue(Severity, Type, Message, Line, Col)`.

### 3.3 Subprocess — for isolation

`le_lps_json/1` in a child SWI-Prolog inside an LE2 checkout, read as the JSON
object on its last line of stdout. The reason was that a `.le` document can
pull in arbitrary Prolog resources; §3.5 explains why that is no longer the
default, and this transport remains for whoever wants the isolation anyway.

### 3.5 Prolog, in-process — LE2 loaded into LPS2

LE2 exposes **`le_service.pl`**: one module, the documented surface an embedder
loads. LPS2 loads it into its own image and calls predicates, so translating a
document is a predicate call — 0.2 s for a document, against a process start —
which is what makes *editing* Logical English in the LPS2 IDE practical.

```prolog
le_service:le_lps_text(+LEText, -InternalText, -Provenance, -Issues)
le_service:le_lps_dict(+Text, +Provenance, +Issues, -Dict)   % the §2 object
le_service:le_service_version(-Version)                      % '1.1'
```

The payload is identical to §3.1's and §3.3's — LPS2 shapes all three through
the same code — and that is a *gate*, not a hope: `tools/m8a_test.pl` runs
LE2's fifteen `examples/lps/*.le` through this transport and the subprocess and
requires the terms to be `variant/2`-equal with identical provenance and issues.

Two things an embedder should say to LE2 on loading, both about being in
somebody else's process:

```prolog
le_service:set_le_issue_reporting(false)   % the issues come back as data
le_service:set_le_network_allowed(false)   % a document's URL resources
```

Loading a document parses and asserts; it does not run it —
`le_kbs:load_prolog_resource/4` honours only `dynamic/1`, `discontiguous/1` and
`use_module(library(_))`, strips `module/2` and skips every goal — which is why
the subprocess is no longer needed by default. What a document *can* still
reach for on its own is the network, hence the second switch.

### 3.6 Which one, and never a guess

LPS2 picks by environment variable:

| variable | meaning |
|---|---|
| `LPS_LE2_LIB` | an LE2 checkout, loaded into this process (§3.5). Used when set. |
| `LPS_LE2_URL` | an LE2 `/leapi` endpoint. Used when there is no `LIB`. |
| `LPS_LE2_DIR` | an LE2 checkout. **In-process by default**; set `LPS_LE2_SUBPROCESS` for §3.3. |
| `LPS_LE2_NETWORK` | allow a document's URL-valued resources to be fetched. Off. |

With none set, `./lps run foo.le` **refuses**, naming the variables. It does not
fall back to an approximate parser: a `.le` file compiled by the wrong LE2 is a
program whose meaning nobody stated.

**LE2 is optional.** Nothing in LPS2 loads it at build time and nothing else
references it. With no LE2 present the engine, the IDE, the CLI and every gate
work unchanged; the only thing that stops working is Logical English, and it
says so.

---

## 4. The LPS side: `/lpsapi`

`compile` and `analyse` accept the §2 payload directly:

```json
{ "operation": "compile", "syntax": "internal",
  "source": "<the lps field>", "provenance": [ … ] }
```

Every diagnostic in the reply carries both the old printed `position` and a
decomposed `source`:

```json
{ "severity": "error", "code": "undeclared_fluent",
  "position": "src(foo.le,12,4,le)",
  "source": { "file": "foo.le", "line": 12, "col": 4, "kind": "le" },
  "message": "…" }
```

`source` is `null` when the position is unknown. An editor places its marker
from `source`, and never parses `position`.

---

## 5. The internal term set

This is the §I.4 vocabulary, frozen since 2016 and pinned by 108 golden
traces. LE2 may emit any of it; LPS2 accepts all of it.

| term | meaning |
|---|---|
| `maxTime(N)` | run length |
| `maxRealTime(N)`, `minCycleTime(N)`, `simulatedRealTimePerCycle(N)`, `simulatedRealTimeBeginning(N)` | real-time settings |
| `events([E, …])` | event declarations |
| `actions([A, …])` | action declarations |
| `fluents([F, …])` | fluent declarations |
| `prolog_events([E, …])` | polled Prolog-defined events |
| `unserializable([F, …])` | fluents excluded from the trace |
| `initial_state([F, …])` | the state at time 1 |
| `observe([E, …], T)` | events seen *at* T (i.e. spanning T-1 to T) |
| `reactive_rule(Antecedents, Consequents)` | a rule |
| `reactive_rule(Antecedents, Consequents, Priority)` | with a priority |
| `l_int(holds(F, T), Conditions)` | an intensional fluent |
| `l_events(happens(E, T1, T2), Conditions)` | a composite event |
| `l_timeless(Head, Conditions)` | a timeless predicate with a body |
| `initiated(happens(E, T1, T2), F, Conditions)` | a causal law |
| `terminated(happens(E, T1, T2), F, Conditions)` | a causal law |
| `updated(happens(E, T1, T2), F(Old), Old-New, Conditions)` | an update |
| `d_pre([C1, …])` | an integrity constraint (a denial) |
| `achieve(G)` | a planning goal (§I.7) |
| `display(Term, Properties)` | the visual mapping (§I.10.4) |
| anything else | the program's own Prolog |

Inside conditions and consequents:

| form | meaning |
|---|---|
| `holds(F, T)` | fluent F holds at T |
| `holds(not F, T)` | F does not hold at T |
| `happens(E, T1, T2)` | E happens from T1 to T2 |
| `happens(initiate F, T1, T2)` | initiate F as an effect |
| `happens(terminate F, T1, T2)` | terminate F |
| any other goal | called as Prolog, at no particular time |

Condition lists are **lists**, not `,/2` conjunctions. Antecedents and
consequents of a `reactive_rule` are lists too.

Times are ordinary Prolog variables, shared across the terms of one rule the
usual way. There are no time constants beyond integers.

---

## 6. The editor-facing queries (§3.5 only)

An editor needs more than a translation: it needs to know the language well
enough to colour it and to complete it. That data is LE2's — the keyword
tables come from `i18n/*.csv` and the templates from the document — and it
crosses the boundary **as data, never as code**: LPS2 does not carry a copy of
the lexicon, because a copy would be wrong for every language but English
within a release.

```prolog
le_service:le_lexicon_dict(+Lang, -Dict)       % keywords, categories, languages
le_service:le_analyse_dict(+Text, +Options, -Dict)  % language, target,
					       %   templates, blocks, issues
le_service:le_english_to_le(+Kind, +Sentence, +Templates, +Program,
			    +Model, +Options, -LEText, -Issues)
le_service:set_le_llm_provider(+Module)        % whose LLM client to use
```

A template comes back with its **role** — `fluent | event | action |
prolog_event | timeless` — its surface form with `*slots*`, its slot types and
its position in the source. That is what makes completion in an LPS-targeted
document useful rather than decorative: two templates that read alike are a
fluent and an action, and which is which is the first thing an author needs.

`set_le_llm_provider/1` is why English→LE works in an embedder: LE2's own
client is the default, and a module exporting the same `llm_request/4` replaces
it, so the keys and the model registry are the embedder's. LPS2 registers
`lps_llm`.

These are reachable over `/lpsapi` as `le_lexicon`, `le_analyse`, `le_nl` and
`le_compile`, so a browser talks to one origin whichever transport is
configured.

---

## 7. Extensions

Adding a term to §5 is a change to this document and a version bump. Adding a
*Logical English* construct that maps onto terms already in §5 is not: it is
private to LE2, and LPS2 will not notice.

The one direction that is *not* specified here is internal → LE. That is
`dump_le`, it lives in LE2 because LE2 owns the template dictionary, and §I.9.5
makes it a test rather than a feature. See `docs/le_lps_roundtrip.md`.

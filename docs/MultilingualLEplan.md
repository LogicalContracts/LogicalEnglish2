# Multilingual Logical English — Implementation Plan

**Status:** Design draft. No code yet. This document evaluates the difficulty of
turning Logical English (LE) into a multilingual family — *Português Lógico*,
*Español Lógico*, *Français Logique*, *Italiano Logico*, … — and proposes a
phased implementation, calling out the design decisions that need resolving
before coding.

> **Revision 2 (2026-07-15).** Updated for the ~87 commits since the June 24
> draft, which noticeably grew the linguistic surface: template **synonyms**,
> the **composite/prepositional** chaining machinery (with English copulas and
> the definite determiner *this* baked in — partly in the **InsurLE2 sibling
> repo**), meta-template parse priority on *that*/*says*, abductive answers
> labelled "*…, assuming …*", four new editor windows plus the Executive page
> (UI strings ~180 → ~300), and **two additional LLM pipelines** ("Write it in
> English…" and the LE Contract Assistant) beside the original Assistant. See
> **Appendix A** for the change log; inventory sections below are updated in
> place (line references marked *(Jun 24)* have drifted; new items carry fresh
> references).

The guiding constraint from the request:

- One LE program file uses **exactly one** natural language, declared by its
  **first statement** (`the target language is: prolog` → English;
  `a linguagem alvo é: prolog` → Portuguese; etc.).
- All LE keywords, template determiners, system templates, and messages need
  per-language versions — ideally **without** duplicating DCG rules per language.
- The Assistant must generate the chosen language.
- All UI strings become translatable, with the **English string as the canonical
  key**, driven by a new language selector.
- Monaco/editor keyword tables must be multilingual too — and this is a chance to
  stop duplicating keyword strings between the Prolog backend and the TypeScript
  editor.
- System multilingual strings live together in **per-language dictionary files**,
  preferably **CSV** (translator-friendly), with a first-stab machine translation.
- Examples get translated, via a filename convention or per-language subtrees.

---

## Contents

- [Multilingual Logical English — Implementation Plan](#multilingual-logical-english--implementation-plan)
  - [Contents](#contents)
  - [1. How things are wired today (evidence)](#1-how-things-are-wired-today-evidence)
    - [1.1 The grammar bakes English atoms directly into DCG clauses](#11-the-grammar-bakes-english-atoms-directly-into-dcg-clauses)
    - [1.2 System templates are a separate surface-phrase table](#12-system-templates-are-a-separate-surface-phrase-table)
    - [1.3 Messages use `format/3` + `print_message/2-3`, scattered](#13-messages-use-format3--print_message2-3-scattered)
    - [1.4 The tokenizer is *mostly* language-neutral — but has Anglo/locale assumptions](#14-the-tokenizer-is-mostly-language-neutral--but-has-anglolocale-assumptions)
    - [1.5 The editor re-declares keywords and holds ~300 English UI strings](#15-the-editor-re-declares-keywords-and-holds-300-english-ui-strings)
    - [1.6 THREE LLM pipelines now speak English (was one)](#16-three-llm-pipelines-now-speak-english-was-one)
    - [1.7 Examples \& tests](#17-examples--tests)
  - [2. Difficulty assessment](#2-difficulty-assessment)
  - [3. Proposed architecture](#3-proposed-architecture)
    - [3.1 Single source of truth: shared lexicon/dictionary files](#31-single-source-of-truth-shared-lexicondictionary-files)
    - [3.2 Active-language detection and threading (backend)](#32-active-language-detection-and-threading-backend)
    - [3.3 Where shared DCG is *not* enough (the honest caveats)](#33-where-shared-dcg-is-not-enough-the-honest-caveats)
    - [3.4 System templates \& messages](#34-system-templates--messages)
    - [3.5 Editor: de-duplicate keywords + i18n the chrome](#35-editor-de-duplicate-keywords--i18n-the-chrome)
    - [3.6 LLM surfaces (Assistant, "Write it in English…", Contract Assistant)](#36-llm-surfaces-assistant-write-it-in-english-contract-assistant)
    - [3.7 Examples](#37-examples)
    - [3.8 First-stab machine translation pipeline](#38-first-stab-machine-translation-pipeline)
  - [4. Phased roadmap](#4-phased-roadmap)
  - [5. Open design decisions (need resolution before/at coding)](#5-open-design-decisions-need-resolution-beforeat-coding)
  - [6. Risk summary](#6-risk-summary)
  - [Appendix A — Changes since the June 24 draft](#appendix-a--changes-since-the-june-24-draft)

---

## 1. How things are wired today (evidence)

A survey of the codebase establishes the starting point. References are
`file:line` so the plan is concrete.

### 1.1 The grammar bakes English atoms directly into DCG clauses

The DCG in `le_grammar.pl` matches keywords as **literal Prolog atoms inline**.
Examples:

- Language/header lines — `section(meta(...))` matches the token sequence
  `the target language is : prolog .` as
  `t(word(the,_)), t(word(target)), t(word(language)), t(word(is)), t(punctuation(':')), t(word(prolog))` (`le_grammar.pl:240`).
- Section headers: `the knowledge base … includes` (`:162`), `the contract …
  states that` (`:170`), `scenario … is` (`:200`), `query … is` (`:209`),
  `the templates are` (`:226`), `the predicates/fluents/events are`
  (`:221,:231,:236`), `the ontology is` (`:216`), `expects answers` / `and
  unknowns` (`:381`).
- Connectives: `if` / `only if` / `unless` (`:405–430`); NAF phrasings in
  `is_not_the_case/1` = `[it,is,not,the,case,that] | [not,the,case,that] |
  [unless] | [and,unless]` (`:2189`); universals in `is_forall/1` =
  `[for,all,cases,in,which]` and `is_it_the_case/1` = `[it,is,the,case,that]`
  (`:2140,:2183`); `for case` / `it is true that` case markers (`:921`).
- Determiner / article / qualifier lists, all hardcoded membership checks:
  - `is_article/1` = `[a,an,the,some,'A','An','The','Some']` (`:639`).
  - `is_ignorable/1` = `[a,an,the,are,was,were,has,have,had,do,does,did,been]`
    (`:641`).
  - `is_reserved/1` = `[says,that,if,and,or,unless]` (`:785`).
  - `is_var_qualifier/1` = `[first…tenth, other, another, new, previous, next,
    current, last, same, original, single, given]` (`:964`).
  - `extract_var_name/2` special-cases `each/which/what/who/what/when/where`
    (`:791`).
  - reserved section words `[knowledge,contract,ontology,predicates,templates,
    fluents,events,target]` (`:497`).
- Template additions after `;`: `defines global`, `opposite`,
  `prepositional|composite` (`:653–654`), `unknown|assumed|assumable`
  (`:659–661`), `undefined|scenario element`, and — new since the June draft —
  `synonym: <alternative wording>` (chainable; several synonyms per template;
  each synonym becomes an extra surface form of the SAME predicate,
  `:627–637`).
- Section markers inside a knowledge base (missing from the June inventory):
  `section <name> is:` (`:388`) and the annexes shorthand
  `the annexes to the contract|knowledge base are:` (`:393`).
- Resource inclusion sections: `the knowledge base <name> includes these
  resources:` / `the contract <name> includes these resources:` (`:151–157`),
  now also loading Prolog resources.
- **Meta-template markers now drive parse PRIORITY, not just slot typing.**
  `is_meta_prev/1` = `[that, says]` (`:1217`) classifies a template as meta,
  and `candidate_template/3` (`:1136`) tries meta templates FIRST as the outer
  literal (otherwise a wordier template absorbs the meta phrase into an
  ordinary slot). The marker word set is per-language, so lexicalization must
  preserve this classification, not merely translate the words.
- **Prepositional/composite chaining lives partly OUTSIDE `le_grammar.pl`** —
  in `le_extensions.pl`, which is a symlink into the **InsurLE2 sibling
  repository**. It hardcodes more English surface: the copulas skippable
  inside a chain, `[is, are, was, were]`
  (`le_extensions.pl:466`), and the definite determiner `this` used to lift a
  `this <type>` anchor phrase into a chained variable
  (`atom_concat('this ', Type, …)`, `:394,:483`). Any lexicon mechanism must
  be consumable from extension repos, not just from this one.
- Generated answer surface: an abductive answer is labelled
  `"<answer>, assuming <unknown> and <unknown>"`
  (`classic_web_api.pl:1201`) — a new English-generating site (the connectives
  `assuming` and `and`) that belongs in the message/phrase catalog.

**Conclusion:** keywords are not in one table — they are scattered as literal
atoms across dozens of DCG clauses and helper predicates, and now also across
an extension module in a sibling repository. This is the single biggest
refactor, and it is the crux of "do we need per-language DCG rules?".

### 1.2 System templates are a separate surface-phrase table

`le_system_templates.pl:12–32` maps built-in predicates to English surface
phrases (`is equal to`, `is greater than or equal to`, `is after`, `is before`,
`is different from`, `is V days after`, `is in`, `is known`, …). Aggregates
(`sum/count/average/min/max … of each … such that`) live in `le_grammar.pl` *(Jun 24: :2122)*
and are re-rendered in `le_kbs.pl` *(Jun 24: :884–903)*. These already form a near-table and
are the *easiest* multilingual target: same predicate, different surface words.

Since June the **rendering** direction gained a non-trivial piece: prepositional
chains are re-folded from the internal conjunction back into the compact
sentence the user wrote (`fold_prep_chain` in `le_kbs.pl`, used for answers and
explanation nodes). The folding is word-order logic over the program's own
template words, so it mostly ports for free — but it drops/reinserts the chain
copula, which ties it to the per-language copula set noted in §1.1.

### 1.3 Messages use `format/3` + `print_message/2-3`, scattered

Verifier/grammar diagnostics are built ad hoc with `format/3` templates, e.g.
"Missing template for '~w'" (`le_verifier.pl:36` *(Jun 24)*), "Undefined predicate
'~w/~w'", "Scenario '~w' defined before rules", "Template contains the reserved
word '~w'", "Misplaced '~w' before expectation", "A prepositional template must
have exactly two arguments", plus API messages in `classic_web_api.pl`. There is
no message catalog; strings are inline.

The catalog's scope has **grown since June**: new diagnostics include
`stray_asterisk`, `synonym_with_other_additions` (`le_grammar.pl:604`),
`single_variable_fact` (KB and scenario variants), `suspicious_is_a`, and
`unmarked_meta_template` ("it seems you want to use a meta-template here…") —
the `prolog:message//1` type list in `le_verifier.pl` now spans ~24 issue
types, each with an English description AND an English fix suggestion. Beyond
diagnostics, user-facing English is also generated for: access control
("Access denied: this example requires login" and the server-rendered `/login`
page), the abductive answer labels (§1.1), explanation annotations ("N repeated
sub-explanations", "Important reason"), and the KB summaries served by the
listing endpoints ("KB: … Top predicates: …", `kbSummary/2`).

### 1.4 The tokenizer is *mostly* language-neutral — but has Anglo/locale assumptions

`tokenizer.pl` starts words on any Unicode `alpha` code (`:185`), so accented
letters already work. Three locale hazards:

- **Numbers** use comma as a thousands separator (`thousands_groups`, `:169`)
  and `.` as the decimal point — the **opposite** of Portuguese/Spanish/French/
  Italian convention (`1.234,56`). The comma also collides with list separators
  `[a, b]` and template argument commas. (See open issue O-3.)
- **Apostrophe** handling (`:238`) was added for English possessives/
  contractions (`employers'`, `don't`); French elision (`l'`, `d'`, `qu'`) is a
  different need (it joins two tokens) and may want different treatment.
- **Dates** are ISO `YYYY-MM-DD` only (`:144`) — locale-neutral, fine to keep.

### 1.5 The editor re-declares keywords and holds ~300 English UI strings

- `editor/src/le-language.ts` is a **second, independent copy** of the keyword/
  determiner/connective lists, as Monarch regexes: section headers,
  `if/either/any of/all of/unless/for all cases in which/it is the case
  that/it is not the case that/…`, articles, qualifiers (`other/another/third/
  …`), template additions (now including `synonym` and `composite` — the
  duplicate table has already had to chase the grammar twice since June). This
  duplicates `le_grammar.pl` and will drift.
- `editor/src/tokenizer.ts` (the LSP tokenizer) is language-agnostic — no
  keyword constants. Good; little to do there.
- The user-facing surface has **more than doubled since June**: to the four
  original pages (`index.html`, `proof-game.html`, `graph.html`,
  `hierarchy.html`) add the **Scenario Editor**, **Query Editor**, **Scenario
  Variations**, and **Explanation Drill** windows, the **Executive** page
  (`web_extras/executive/`, its own HTML+JS app), the server-rendered **landing
  page** and **/login page**, a **Help menu** of links, and Mermaid export. A
  rough count now finds **~300 user-visible English strings** (was ~180):
  ~200 static in HTML plus ~80–100 dynamic in `client.ts`, `proof-game.ts`,
  `graph-client.ts`, `scenario-editor.ts`, `query-editor.ts`,
  `scenario-variations.ts`, `explanation-drill.ts`, `mermaid-export.ts` and
  `web_extras/executive/app.js`. Still no i18n infrastructure: no `data-i18n`,
  no catalog, no `lang` parameter on any `/leapi` call.
- Program-language vs chrome split still holds — and the new windows follow it
  nicely: the Scenario/Query editors render **fill-in-the-blank forms whose
  labels are the program's own template words** (program language, free), and
  Proof Game / Graph / Mermaid node **labels** come from the program's
  templates. Only chrome (buttons, legends, "FAIL"/"STOP", "assumed" captions,
  tooltips, generated suffixes like "(N repeated sub-explanations)") needs
  i18n.

### 1.6 THREE LLM pipelines now speak English (was one)

The June draft covered one Assistant; there are now **three English-prompted
LLM surfaces**, all needing the same treatment:

1. **LE Assistant** (light/deep): `le_assistant_light.pl` assembles the system
   prompt from `AGENTS_LE_template.md` (instructions, English),
   `docs/le_summary.md` (syntax reference, English), and hardcoded curated
   example files. The editor passes `command, content, model, mode, max_steps`
   to `/leapi` — **no language**. Nothing localizes the model output.
2. **"Write it in English…"** (new, `nl_to_le.pl`, in the Query *and* Scenario
   editors): a one-shot conversion of an English sentence into LE facts or a
   query body, respecting the program's templates, with baseline-diffed
   verification. Prompts are hardcoded English — and the feature's very *name*
   presumes English; per language it becomes "Write it in Portuguese…" etc.,
   with a prompt that teaches the model that language's LE keyword set.
3. **LE Contract Assistant** (new, `le_contract_assistant.pl`): a multi-step
   contract-text→LE pipeline that reads `docs/le_summary.md` as its syntax
   source (`:1430`), with model-specific prompt tuning (e.g. GPT-5.5 tweaks).
   Same dependency: a per-language syntax summary and per-language
   instructions.

Additionally the **MCP/REST tools** (`llm/mcp.pl`, `le_tools.pl`) expose
`list_examples`/`get_example_details`/`query`/`verify` with English tool
descriptions and English-generated example summaries — the surface an external
agent sees.

### 1.7 Examples & tests

`examples/moreExamples/` has grown to **~106 `.le` files**, reorganized into
**topical subdirectories** (`abduction/`, `rkBook/`, `short/`, `testing/`, …)
that the landing page can focus on via `?dir=<subdirectory>`. One subdirectory,
`insureLE2/`, is a **symlink into the InsurLE2 sibling repository** — the
per-language layout decision (O-7) must therefore compose with (a) topical
subdirs and (b) example trees living in *other repos*. Tests are **embedded**
in scenarios as `… expects answers ["…"]` (no separate `.le.tests` files);
`le_kbs:runTestsInDir/2` discovers `.le` files **recursively**, and
`runTestsFor/2` runs a single file's embedded expectations. Filenames are plain
English; no locale convention exists. (The AGENTS.md reference to `*.le.tests`
files is still stale — O-11's "drop them" decision remains to be executed.)

Since June the **regression safety net for the Phase 1 refactor** also grew
substantially: new plunit suites pin the trickiest parses — meta-template
priority (`testing/test_meta_template_priority.pl`), prepositional folding and
`this`-anchor lifting (`test_prep_fold.pl`), the verifier warning corpus
(`test_verifier_warnings.pl`), the proof game's variable naming/meta behavior
(`test_proof_game.pl`), plus a hardened Playwright e2e suite. Grammar
lexicalization can now be gated on a much stronger green bar than in June.

---

## 2. Difficulty assessment

| Area | Difficulty | Why |
|------|-----------|-----|
| Language declaration + detection | **Low** | Match the first statement against each language's opener; set an active-language flag. |
| System templates (comparisons, aggregates, dates) | **Low–Med** | Pure surface-phrase table per predicate; some have multiple synonyms. |
| Message catalog (errors/warnings) | **Med** | Many scattered `format/3` sites to route through a catalog (~24 issue types + API/answer-label strings, growing); placeholders must survive translation/reordering. |
| **Grammar keyword externalization** | **High** | Keywords are inline atoms across many DCG clauses — and now also in `le_extensions.pl` (sibling repo): chain copulas, the `this`-anchor determiner, meta markers driving parse *priority*. Needs a lexicon-driven terminal, threading of the active language, and a lexicon API usable from extension modules. |
| Tokenizer locale (numbers/separators) | **Med–High** | Decimal/thousands separator conflict with list/arg commas is a real ambiguity, not a string swap. The scenario/query editors' front-end number handling now shares this concern. |
| Determiners / articles / morphology | **Med** | Membership lists are easy; gender/number agreement and article rendering (`a`/`an`; Romance `o/a/os/as`, contractions) are linguistic, not mechanical. The `this <type>` chain-anchor convention and the `defines global this X` idiom add a **definite-determiner** hook per language. |
| Editor Monaco tables | **Med** | Must become language-aware *and* stop duplicating the backend lists (the duplicate has already chased `synonym`/`composite` since June). |
| UI string i18n (~300) | **Med–High** | Mechanical but broad, and broader than in June: 8 editor surfaces + Executive app + server-rendered landing/login pages. Needs catalog + selector + HTML markup pass + a server-side rendering hook. |
| LLM pipelines multilingual (×3 + MCP) | **Med** | Assistant, "Write it in English…", Contract Assistant: per-language instructions, syntax summary, curated examples, output-language directive; MCP tool descriptions/summaries. |
| Example translation | **Med** | ~106 files × N languages (some in a sibling repo); naming/layout decision; keep tests green. |

---

## 3. Proposed architecture

### 3.1 Single source of truth: shared lexicon/dictionary files

Create a top-level `i18n/` directory of **CSV** dictionaries (translator-friendly,
diff-friendly), each a table with one canonical key column and one column per
language. Both the Prolog backend and the TypeScript editor consume these — the
backend reads them at load; the editor gets generated tables at build time (see
§3.5). Proposed files:

- `i18n/keywords.csv` — grammar keywords/phrases. Columns:
  `category, key_en, en, pt, es, fr, it, …` where `category` ∈ {section, connective,
  naf, forall, article, ignorable, reserved, qualifier, template_addition,
  section_marker, resources, meta_marker, copula, determiner_definite,
  answer_connective, …}
  and each language cell holds the **surface phrase** (possibly multi-word,
  possibly a `|`-separated synonym set). `key_en` is the stable identifier
  (e.g. `forall_open`), `en` is the English surface (the canonical display key).
  The June draft's category list has grown: `meta_marker` (that/says — drives
  parse priority, §1.1), `copula` (is/are/was/were, skippable in prepositional
  chains), `determiner_definite` (*this*, the chain-anchor/globals determiner),
  `section_marker` (`section … is:`, the annexes shorthand), `resources`
  (`includes these resources`), `template_addition` now including
  `synonym`/`composite`, and `answer_connective` (`assuming`, list `and`).
- `i18n/system_templates.csv` — built-in predicate → surface phrase per language
  (`le_equal_to, is equal to, é igual a, es igual a, …`). Supports synonyms.
- `i18n/messages.csv` — diagnostic catalog: `msg_id, en, pt, …` where each cell
  is a `format/3`-style template with **named/numbered placeholders** (see O-5).
- `i18n/ui.csv` — editor/UI chrome strings keyed by the English string (or a
  short id) per the request that English be the canonical key.
- `i18n/languages.csv` — registry: `lang_code, autonym (Português Lógico),
  opener_phrase (a linguagem alvo é), decimal_sep, thousands_sep, list_sep, …`
  — locale parameters consumed by the tokenizer and number formatting.

Rationale for CSV over JSON: the request prefers CSV for human translators;
multi-line/nested data is minimal here. We can still emit JSON internally if a
consumer needs it (the build step can convert).

### 3.2 Active-language detection and threading (backend)

1. **Detect:** before/at parse start, match the file's first statement against
   every `languages.csv` opener (`the target language is`, `a linguagem alvo é`,
   `el lenguaje objetivo es`, `la langue cible est`, `il linguaggio obiettivo è`,
   …). The matched row determines `Lang`. If none match → error in a
   language-neutral way (or default English) (see O-1).
2. **Thread:** set the active language for the parse. Two options (O-2):
   - (a) a `thread_local le_active_language/1` flag set at parse start — minimal
     churn, naturally per-session/per-thread safe; or
   - (b) thread `Lang` through the DCG as an extra argument — purer, but touches
     every clause.
   Recommendation: **(a) thread-local flag**, because the DCG is large and parses
   are already per-session.
3. **Lexicon terminals:** replace inline `t(word(the))`-style literals with
   lexicon-aware terminals, e.g. a helper `kw(KeyId, Tokens, Rest)` /
   `kw_phrase(KeyId)//0` that consults `keywords.csv` for the active language and
   matches the corresponding token sequence. The DCG *structure* (clause shapes,
   recursion, precedence) stays **single-source**; only the terminals become
   data-driven. This is how we avoid per-language DCG duplication.

### 3.3 Where shared DCG is *not* enough (the honest caveats)

Most of the grammar can be shared via lexicalized terminals, but a few places
encode English morphology/word-order and will need either parameterization or a
small number of per-language hook predicates:

- **Article allomorphy / rendering.** English `a`/`an` is phonological; Romance
  languages inflect articles for gender/number (`o/a/os/as`, `un/una`,
  `le/la/les`, `il/lo/la`). Matching is just a bigger `article` set, but
  **rendering** templates/instances back to text (e.g. choosing the right article
  when echoing "an other creature") is language-specific. Identify every site
  that *emits* `a`/`an` and route through a per-language `indefinite_article/…`
  hook. (English-only `an` selection must not leak into other languages.)
- **Adjective/qualifier position.** `is_var_qualifier` words like "other",
  "another", ordinals attach to variable phrases; Romance order differs
  ("an other creature" → "uma outra criatura" keeps order, but some qualifiers
  follow the noun). Variable-id extraction (`extract_var_name/2`) strips the
  leading article then keeps the remaining words as the identifier — this is
  largely order-agnostic and should port, but qualifier handling needs review per
  language.
- **Possessives / elision in the tokenizer.** English `'s`/`s'` vs French `l'`/
  `d'` are different operations; the apostrophe rule may need a per-language mode.
- **Chain copulas (new).** Prepositional chaining optionally skips a copula
  between the anchor and the phrase (`maybe_strip_chain_copula`,
  `le_extensions.pl:466`, hardcoded `is/are/was/were`), and answer folding
  reinserts one. Romance languages have two copulas (ser/estar, essere/stare)
  plus number/person inflection — a per-language copula *set* for matching is
  enough (echo-verbatim keeps rendering safe, per O-8), but the set must come
  from the lexicon.
- **Definite chain anchors (new).** A `this <type>` phrase anchoring a
  prepositional chain is lifted into a shared variable
  (`lift_this_anchors`, `le_extensions.pl:394`), and `defines global this X`
  keys globals by the same determiner. `this` inflects in Romance languages
  (`este/esta`, `ce/cette`, `questo/questa`), so the anchor-detection must
  match a per-language determiner set and the `atom_concat('this ', Type)`
  pattern must become lexicon-driven.
- **Meta markers as a priority class (new).** `that`/`says` don't just mark a
  slot — they now decide which template wins the outer-literal parse
  (§1.1). Each language contributes its own marker set (pt `que`/`diz`,
  fr `que`/`dit`, …); note `que` is far more frequent in Romance text than
  `that` in English, so the pilot language should re-validate the priority
  heuristic against real programs.

The plan should treat these as a **bounded set of hook predicates** (article
rendering, qualifier order, elision, copula set, definite-anchor determiners,
meta-marker set) rather than full DCG forks. Each new language implements the
hooks + fills the CSV columns. One packaging consequence of §1.1: the lexicon
loader/API must be **importable from extension modules in other repositories**
(`le_extensions.pl` lives in InsurLE2), so hooks and word sets can't be private
to `le_grammar.pl`.

### 3.4 System templates & messages

- System templates: load `system_templates.csv` and assert the per-language
  surface forms the same way `le_system_templates.pl` does today, gated by active
  language. Predicates and semantics unchanged.
- Messages: introduce `le_message(MsgId, Args)` that looks up `messages.csv` for
  the active **UI/program** language and formats with reordered placeholders.
  Migrate the scattered `format/3`/`print_message/2` sites incrementally; keep a
  fallback to English when a translation cell is empty.

### 3.5 Editor: de-duplicate keywords + i18n the chrome

- **Kill the duplicate keyword table.** Generate `editor/src/le-language.*`
  Monarch keyword arrays from `i18n/keywords.csv` at build time (a small codegen
  step in the editor build), producing a per-language highlighter. The editor's
  language selector picks which generated table Monaco uses. This removes the
  drift between `le_grammar.pl` and `le-language.ts`.
- **UI catalog.** Add a lightweight i18n runtime keyed by the English string (or
  id) from `ui.csv`. Mark up ALL nine client surfaces — `index.html`,
  `proof-game.html`, `graph.html`, `hierarchy.html`, `scenario-editor.html`,
  `query-editor.html`, `scenario-variations.html`, `explanation-drill.html`,
  and `web_extras/executive/` — with `data-i18n` keys and substitute on load;
  wrap the dynamic strings in the corresponding `.ts` files (and
  `executive/app.js`, `mermaid-export.ts`) with a `t()` lookup. English remains
  the canonical key and the fallback. The **server-rendered** pages (landing,
  `/login`, test-results tables) need the same catalog on the Prolog side —
  they cannot use the client runtime.
- **Language selector.** New UI control (next to Theme/Font). It sets: (i) the UI
  chrome language, (ii) the Monaco highlighter, and (iii) the default language for
  *new* programs and for the Assistant. The program's *own* language is still
  authoritative for parsing a loaded file (the selector should follow, or warn on
  mismatch — O-6).
- **Backend language param.** Add an optional `lang` to relevant `/leapi`
  operations so server-produced messages (errors, statuses) come back localized.

### 3.6 LLM surfaces (Assistant, "Write it in English…", Contract Assistant)

- Per-language prompt assets, shared by all three pipelines:
  `AGENTS_LE_template.<lang>.md` and a translated `docs/le_summary.<lang>.md`
  (the Contract Assistant reads `le_summary` directly, so translating it serves
  two pipelines at once); curated examples in the target language (§3.7).
- Pass the active language to `le_assistant_light`, `nl_to_le`, and
  `le_contract_assistant`, and add an explicit instruction ("Respond and write
  LE in <language>; use the <language> keyword set"). Select the
  language-appropriate syntax reference and examples in each pipeline's prompt
  assembly.
- `nl_to_le`'s verification loop parses the model's output with the normal
  grammar, so once Phase 1 lands it validates non-English output for free —
  a nice built-in quality gate for the machine-translation pipeline (§3.8).
- Rename the editor affordance per language ("Escreva em Português…", …) via
  the UI catalog; the `kind: facts|query` API contract is language-neutral.
- MCP tool descriptions and `kbSummary` phrasing go through the message catalog
  (they are the surface external agents see).

### 3.7 Examples

Two layout options (O-7):

- **(A) Per-language subtrees:** `examples/en/…`, `examples/pt/…`, mirroring
  structure. Cleanest separation; `runTestsInDir` already recurses, so each tree
  tests independently; easy to run "all PT examples". Requires moving current
  files under `examples/en/` (or treating `moreExamples/` as the en tree).
- **(B) Sibling filenames:** `citizenship.le`, `citizenship.pt.le`, … in one
  directory. Less churn but clutters directories and complicates "list canonical
  examples"; the recursive runner would run all variants together.

Recommendation: **(A) per-language subtrees**, with the English set as the
reference whose expectations are authoritative; translated files carry the same
`expects answers` (answer strings themselves get translated where they are
natural-language, but many are individual names/dates that stay the same).

### 3.8 First-stab machine translation pipeline

Use our own LLM agent to seed every CSV language column and translate examples:

1. Freeze the canonical English CSVs (keys + en cells) and the example corpus.
2. For each target language, run an agent pass that fills the CSV cells,
   respecting placeholders/synonyms and producing *idiomatic* keyword phrases (a
   logician/linguist persona). Keyword translations especially need human review.
3. Translate `docs/le_summary.md` and the curated examples; re-run the test suite
   per language to catch parse/answer regressions; iterate.
4. Mark machine-translated cells (e.g. a `status` column or a sidecar) so human
   translators know what to verify.

---

## 4. Phased roadmap

**Phase 0 — Foundations (no behavior change).**
Create `i18n/` with English-only CSVs extracted from current hardcoded lists —
including the surface that lives in `le_extensions.pl` (copulas, `this`,
meta markers) and the generated-answer connectives (`assuming`); add the
`languages.csv` registry with English + locale params; build the loader in
Prolog (importable from extension repos) and the codegen in the editor build,
both still emitting English. Prove parity: tests stay green using CSV-sourced
English. *The linguistic surface has been growing ~monthly (synonyms,
composite, annexes, assuming-labels since June); the longer Phase 0 waits, the
bigger the extraction — freeze-and-extract early, then let new features add
CSV rows instead of inline atoms.*

**Phase 1 — Language plumbing.**
First-statement detection + active-language flag; lexicalize the grammar
terminals (`kw_phrase//1`) in `le_grammar.pl` *and* the extension hooks in
`le_extensions.pl`; route system templates and messages through the catalog.
Still English-only data, but fully data-driven. This is the heavy refactor;
gate it behind green tests — the plunit corpus grown since June
(meta-template priority, prepositional folding/anchors, verifier warnings)
now pins exactly the parses this refactor is most likely to disturb.

**Phase 2 — First second language (Portuguese as pilot).**
Fill PT columns (machine + human review); implement the bounded hook predicates
(article rendering, qualifier order, elision); resolve the number-separator issue
(O-3) for PT; translate a handful of examples; add PT to the example tree and
test suite.

**Phase 3 — Editor i18n + selector.**
UI catalog + `data-i18n` markup + `t()` wrapping across all nine client
surfaces plus the server-rendered landing/login pages; generated per-language
Monaco tables; language selector; `lang` param on `/leapi`; localized server
messages.

**Phase 4 — LLM surfaces multilingual.**
Per-language prompt assets and syntax docs shared by the Assistant, "Write it
in <language>…", and the Contract Assistant; output-language instruction;
curated examples per language; localized MCP tool descriptions/summaries. Use
`nl_to_le`'s parse-back verification as the automatic quality gate for
non-English generation.

**Phase 5 — Scale to ES/FR/IT/…**
Each new language = fill CSV columns + implement/verify hooks + translate
examples + run the per-language suite. Marginal cost should be mostly translation
+ review, not engineering.

---

## 5. Open design decisions (need resolution before/at coding)

CHOICES below:

- **O-1 Missing/ambiguous opener.** If the first statement matches no language,
  is it an error, or default to English? How are errors phrased when we don't yet
  know the language? (Proposal: try-all-openers; on no match, emit a bilingual/
  language-neutral error and default English.) CHOICE: PROPOSAL ACCEPTED
- **O-2 Language threading.** Thread-local flag vs DCG extra-argument. (Proposal:
  thread-local; revisit only if concurrency within a single parse appears.) CHOICE: THREAD-LOCAL FLAG
- **O-3 Number & separator conflict (highest-risk).** PT/ES/FR/IT use `,` as the
  decimal separator and `.`/space as thousands — colliding with the current
  comma-thousands parsing *and* with list `[a, b]` and template argument commas.
  Options: (a) keep numbers locale-independent (always `.` decimal, no grouping)
  even in non-English LE; (b) make separators language-config and disambiguate
  commas by context; (c) require a different list/argument separator in those
  languages. This needs an explicit decision — it affects tokenizer correctness,
  not just strings.  CHOICE: TAKE OPTION (B)
- **O-4 Functor naming across languages.** Internal predicate functors are derived
  from the program's own template words (so PT programs yield PT-derived functors).
  Confirm we accept that KBs in different languages do **not** interoperate at the
  predicate level, and that cross-language `is_a`/ontology sharing is out of scope
  (or define a neutral interchange). CHOICE: CONFIRMED. CROSS-LANGUAGE IS OUT OF SCOPE.
- **O-5 Message placeholders.** Translations must reorder arguments; adopt
  numbered/named placeholders (not bare `~w` positional) so translators can move
  them. Decide the catalog format and the `format/3` shim.  CHOICE: Named-placeholder templates + a substitution helper. Worry about plural/gender later.
- **O-6 Selector vs program language.** When the UI selector says ES but the
  loaded file declares PT, which wins for parsing/messages? (Proposal: the file's
  own declaration always governs parsing; selector governs chrome + new files +
  Assistant; warn on mismatch.) CHOICE: PROPOSAL ACCEPTED
- **O-7 Example layout.** Per-language subtrees (A) vs sibling `.lang.le`
  filenames (B). (Proposal: A.) Also: do translated expectation answer-strings
  diverge from English, and how do we keep them in sync? CHOICE: OPTION (A). Translated expectations are different per language but we don't care; the main system tests+/expectations will reamin in English.
- **O-8 Article/gender rendering scope.** How far do we go with gender/number
  agreement in *generated* text (explanations, Proof Game/Graph labels echoing
  templates)? Minimal (echo program text verbatim) vs full agreement. (Proposal:
  echo verbatim from the program's own template instances first; defer
  morphological generation.) CHOICE: MINIMAL
- **O-9 Keyword synonyms per language.** English allows variants (`it is not the
  case that` / `not the case that` / `unless`). Each language needs its own
  idiomatic synonym set, possibly different in number — the CSV must allow
  multi-synonym cells and the lexicon loader must expand them. CHOICE: YES.
- **O-10 Mixed/shared resources.** "Included resources"/ontologies referenced by a
  program — must they match the program's language? Can an English library be used
  from a PT program? (Likely: same-language only, initially.) CHOICE: SAME-LANGAUGE ONLY
- **O-11 Reconcile test docs.** AGENTS.md mentions `*.le.tests` files, but the
  runner uses embedded `expects answers`. Clarify the canonical mechanism while we
  touch the example tree. CHOICE: LET'S DROP .le.tests FILES, NO LONGER NEEDED
  *(Rev 2 note: still pending — AGENTS.md unchanged as of 2026-07-15.)*
- **O-12 (new) Lexicon access from extension repos.** `le_extensions.pl` (in the
  InsurLE2 sibling repository) hardcodes chain copulas, the `this` anchor
  determiner, and hooks the grammar via multifile predicates. Where do ITS
  language hooks and word sets live — in this repo's `i18n/` (extensions consume
  a published lexicon API), or can extension repos ship their own CSV columns?
  (Proposal: the lexicon API + core word sets live here; extensions only
  *consume* them — an extension needing new categories adds rows to the core
  CSVs.) CHOICE: proposal accepted
- **O-13 (new) Server-rendered pages.** The landing page, `/login`, and the test
  dashboard are rendered by Prolog (`reply_html_page`), outside the client i18n
  runtime. Localize server-side from the same `ui.csv` (keyed by session/`lang`
  cookie), or keep them English-only initially? (Proposal: same catalog,
  server-side substitution, language from a cookie set by the editor's
  selector; English until Phase 3.) CHOICE: proposal accepted
- **O-14 (new) Meta-marker frequency in Romance languages.** `que` (pt/es/fr)
  and `che` (it) are vastly more frequent than English `that`, and the parser now
  gives meta-marked templates parse priority (§1.1/§3.3). Validate on the pilot
  language that this heuristic doesn't over-trigger; if it does, the priority
  may need to be conditional on the template's marker being followed by a slot
  (already the case) plus language-specific guards. CHOICE: VALIDATE IN PHASE 2
  PILOT.

---

## 6. Risk summary

- **Highest risk / most engineering:** grammar lexicalization (§3.2–3.3) and the
  number-separator ambiguity (O-3). These are semantic, not cosmetic.
- **Broad but mechanical:** UI i18n (~300 strings across 9 client surfaces plus
  server-rendered pages) and message-catalog migration.
- **Mostly translation effort:** system templates, examples, Assistant assets —
  cheap per additional language once the framework exists.
- **Payoff of de-duplication:** generating the editor's Monaco tables from the
  shared CSV removes a standing source of backend/editor drift, independent of
  multilingual goals — the `le-language.ts` duplicate has already had to chase
  `synonym` and `composite` since June.
- **Surface growth risk (new):** the linguistic surface is actively expanding
  (≈ one new keyword/phrase family per month recently). Every month Phase 0 is
  deferred, the extraction gets bigger and new features bake in more inline
  English. Conversely, the fast-growing plunit corpus makes the Phase 1
  refactor *safer* than it was in June.

---

*Next step after sign-off:* resolve O-1…O-14 (O-12/O-13 are new), then execute
Phase 0 (extract current English into `i18n/` CSVs with zero behavior change)
so every later phase runs against green tests.

---

## Appendix A — Changes since the June 24 draft

Linguistic-surface-relevant changes in the ~87 commits between the June 24
draft and 2026-07-15, and where this revision absorbs them:

| Change (commit theme) | Linguistic surface added | Plan impact |
|---|---|---|
| Template **synonyms** (`; synonym: …`, chainable) | keyword `synonym`; N surface forms per predicate; error `synonym_with_other_additions` | §1.1, §3.1 (`template_addition`), §1.3 catalog |
| **composite** accepted for `prepositional` | keyword synonym pair | §1.1, keywords.csv synonym cells (O-9) |
| Prepositional **chain unfolding** in answers/explanations | copula insertion/removal; word-order folding | §1.2, copula hook (§3.3) |
| `this <type>` **anchor lifting** in chains; `defines global this X` | definite determiner `this` hardcoded (in `le_extensions.pl`, sibling repo) | §3.3 hook, O-12 |
| **Meta-template parse priority** on `that`/`says` | marker words now steer template choice | §1.1, §3.3, O-14 |
| Abduction focus: `; assumable`, **"…, assuming …" answer labels**, Proof Game assumption cards | generated answer connectives; "assumed" chrome | §1.1, §1.3, ui.csv |
| New verifier warnings (`unmarked_meta_template`, `stray_asterisk`, `single_variable_fact`, `suspicious_is_a`, …) | ~24 issue types, each with description + fix text | §1.3 catalog scope |
| **Scenario Editor, Query Editor, Scenario Variations, Explanation Drill** windows | 4 new UI surfaces; template-derived form labels (program-language, free) | §1.5, §3.5 |
| **Executive page**, landing-page overhaul, Help menu, New from URL, `/login` | client app + server-rendered English pages | §1.5, §3.5, O-13 |
| **"Write it in English…"** (`nl_to_le.pl`) in Query/Scenario editors | 2nd LLM pipeline; English prompts; English feature name | §1.6, §3.6 |
| **LE Contract Assistant** (`le_contract_assistant.pl`) | 3rd LLM pipeline; reads `docs/le_summary.md` | §1.6, §3.6 |
| Resources: include **Prolog files** too | `includes these resources` section family | §1.1, O-10 |
| Examples reorganized into **topical subdirs**; `insureLE2/` symlinked to sibling repo; corpus ~106 files | layout constraints for per-language trees | §1.7, O-7 |
| **Mermaid export** (explanations + source graph) | program-language labels + English generated suffixes | §1.5 |
| Large new plunit/e2e regression corpus (meta priority, prep folding, warnings, proof game, graph) | — | §1.7, Phase 1 safety |

Pre-June surface the original inventory missed, also folded in: `section <name>
is:` / `the annexes to the contract|knowledge base are:` markers (§1.1).

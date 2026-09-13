# Migrating programs into Logical English: the shared machinery

This is the reference for the infrastructure every translator into Logical
English shares — Phase 0 of the roadmap in
`InsurLE2/docs/MiggratingFromOtherSystems.md` (§4 and §8). The source-specific
readers (Socotra, Oracle Intelligent Advisor, Bitcoin Miniscript, Solidity)
live in the InsurLE repository (`InsurLE2/migration/`) and are described
there; everything here is core LE and has no knowledge of any source system.

```
source artefacts ──reader──▶ Migration IR ──le_writer──▶ program.le
source tests ─────reader──▶ test(...) terms ─le_migration─▶ scenarios with expects
                            ledger entries ──le_migration─▶ ledger.md / ledger.json
program.le with RESIDUE blocks ──Contract Assistant, mode residue──▶ residue translated
```

| Piece | Where | Roadmap item |
|---|---|---|
| The general LE writer: Migration IR → LE text; a loaded knowledge base → IR; plain Prolog / s(CASP) → IR | `le_writer.pl` | E1 |
| The migration ledger, source tests as scenarios, fidelity | `le_migration.pl` | E14 |
| Residue mode: a fixed skeleton, only the residue translated by the LLM | `le_contract_assistant.pl` (mode `residue`), prompts `llm/contract_prompts/residue_*.md` | Phase 0 item 4 |
| Dates, periods and lock times | `lib/temporal.le` + `lib/temporal.pl` | E3 |
| Integer division `//` and remainder `mod` | `le_grammar.pl` | E4 |
| `either`/`any of` with nested `all of`; negation in numbered items | `le_extensions.pl` (InsurLE) | D1, D2 |
| `; opposite:` forms are not negation in a condition — documented, and diagnosed (`opposite_as_condition`) | `le_verifier.pl`, `docs/le_summary.md` §2 | D3 |
| `verify/1` on LPS documents, with the LPS emitter's own diagnostics | `le_kbs.pl` | D4 |

## 1. The Migration IR

A translator's output is a Prolog term, not text:

```prolog
program(Header, Items)
```

### Header

| Term | Meaning |
|---|---|
| `kb(Name)` | the knowledge base's name |
| `target(prolog)` / `target(lps)` | the target language (default `prolog`) |
| `language(Lang)` | the program's language (`en`, `pt`, `es`, `fr`, `it`; default `en`) |
| `comment(Text)` | a comment block at the top (attribution, source, licence) |
| `includes([Resource, ...])` | `the knowledge base N includes these resources:` |
| `services([service(Name, Address, Kind), ...])` | `... includes these services:` |
| `provenance_required` | `scenario facts require provenance.` |
| `extensions(auto\|true\|false)` | whether nested forms may use the InsurLE `all of`/`either` blocks (default: when `le_extensions` is loaded) |
| `setting(max_time, N)` etc. | LPS settings |

### Items

| Item | Written as |
|---|---|
| `template(F, Text, Additions)` | a line of `the templates are:`. `F` is the translator's name for the predicate (its literals use it, with as many arguments as `Text` has places); LE derives its own functor from the words, and the two never need to agree. `Text` is the declaration, `"*a person* is born in *a place* on *a date*"`. Additions: `undefined`, `assumable`, `judged`, `prepositional`, `opposite(Text)`, `synonym(Text)`, `via_service(S)`, `known_as(F)`, `defines_global(G)`, `included` (declared by an included resource: known for writing, not written) |
| `fluent/event/action(F, Text, Additions)` | the LPS declaration sections |
| `rule(Head, Body, Options)` | a rule. Options: `label(L)` (`rule L:`), `provenance(P)` (with a label: `rule L with provenance ...:`), `numbered(true)` (a numbered outline, §15.5), `comment(Text)` |
| `fact(Head, Options)` | a fact; Options `provenance(P)` (trailers), `ontology` (in `the ontology is:`) |
| `table(Name, Options, Columns, Rows)` | a decision table (§17.3). Options: `policy(first\|unique\|all)`, `loaded_from(File)`, `provenance(P)`. Cells: a constant, `any`, `or_list([...])`, `cond(E)` with `E` built from `Op-Value` (`(>=)-1`) and `and/2`, `or/2`, `quote(Text)` (a citation column), `raw(Text)` |
| `section(Name)` | `section Name is:` |
| `residue(Id, Options)` | a residue block (§4): Options `title(T)`, `locator(L)`, `source(Language, Code)`, `note(Text)`, `placeholder(LE)`, `concludes([F, ...])` (what the block must conclude — the expectations that depend on it are pending, §3) |
| `document(Name, Options)` | `Name is published at "..."` / `the text of Name is at "..."`: Options `url(U)`, `text(Path)` |
| `scenario(Name, Lines, Options)` | a scenario. Lines: `fact(L)`, `fact(L, Provenance)`, `unknown(L)`, `rule(H, B)`, `expects(Query, Answers)`, `expects(Query, Answers, Unknowns)`, `expects_changes(Query, Sets)`, `pending(Why, Line)` (a line written as a comment, with its reason), `comment(T)`. Answers are strings or ground IR literals (written through their templates). Options: `as_stated_in(Doc)`, `at(Locator)` — the scenario's default provenance |
| `query(Name, Body)` / `query(Name, flip(Goal))` | a query; its variables are written `which <type>` |
| `view(Name, Sentences)` | a view (§17.10), its sentences verbatim |
| `comment(Text)`, `blank`, `raw(Text)` | verbatim material in the knowledge base |
| `lps(Term)` | an LPS internal-syntax term (target `lps`), written by `le_lps_write.pl` |

**Provenance** is a list of `according_to(Source)`, `as_stated_in(Document)`,
`at(Locator)`, `confer(Quote)`, `because(Reason)`. A document whose name would
not read back as a constant (`policy.json`) is written in quotes; a locator is
written as plain words (`coverages[2]` becomes `coverages 2`).

**Bodies** combine `and/2`, `or/2`, `not/1` (or Prolog's `,`, `;`, `\+`, `->`),
`otherwise([Alt1, Alt2, ...])`, `forall(Condition, Goal)`,
`agg(Op, Element, Goal, Result)` (Op one of `sum count average min max`),
`according_to(Goal, Scope)`, `prolog(Goal)`, comparisons (`<`, `=<`, `>`, `>=`,
or LE's `le_gt/2` ...), `X is Expr` / `le_assign(X, Expr)` (arithmetic with
`+ - * / // mod` and `round/floor/ceiling/truncate/integer/abs/sign/sqrt`),
`X = Y`, `X \= Y`, `member(X, List)`, `min(X, Y, Z)`, `max(X, Y, Z)`, and
literals of the IR's templates. LE's own internal forms (`le_at/3`, the
aggregate terms, `le_type_check/2`) are accepted too, which is how a loaded
knowledge base becomes IR.

Build conjunctions left-associated — `and(and(A, B), C)` — which is how LE
reads sibling lines; `le_writer:prolog_to_ir/3` does it for Prolog sources.

## 2. The writer (`le_writer.pl`)

```prolog
le_write(+IR, -Text).
le_write(+IR, -Text, -Issues).        % issue(Severity, Code, Message)
kb_to_ir(+KBModule, -IR).             % a loaded knowledge base, back to IR
le_write_kb(+KBModule, -Text).
prolog_file_to_ir(+File, +Options, -IR).   % plain Prolog or s(CASP), §5.7
prolog_to_ir(+Terms, +Options, -IR).
render_ground_literal(+Dicts, +Literal, -Text).   % an expected answer
template_text_dict(+Text, -Dict).
```

What it writes is the current language: decision tables, `otherwise`
cascades, provenance trailers, rule labels, numbered outlines, the ontology
section — never comments standing in for them. What it cannot write it
reports in `Issues` (a literal with no template, a nested group that needs the
InsurLE blocks when they are unavailable, a constant it had to quote).

**Nesting.** A body is written as a tree of lines the way LE reads it back:
sibling lines fold left to right with their connectives, and a line's nested
lines fold onto that line's literal — `and(a, or(b, c))` is `a` / `and b` /
`    or c`. A group whose first condition needs lines of its own (a negation
block, a universal, an aggregate) is written as an `all of` / `either` block.

**Variables** are named from the type of the template place each first fills
(`a person`, `a second person`, `the person`); one that takes part in
arithmetic, a comparison or an aggregate also gets an id (`an amount A`, then
`A`); in a query the first mention is `which person`. A variable is never
given the name of a definite constant of its clause (`the policy` a constant:
the policy variable is `a second policy`). Articles, ordinals and `which` come
from `i18n/writer_words.csv`, so the writer writes Portuguese, Spanish, French
and Italian programs in their own words.

**Constants** are written as LE reads them back: numbers (with the language's
decimal separator), ISO dates, strings in double quotes, lists, and atoms bare
unless LE would read the bare atom as something else — an indefinite phrase,
a number, a connective, an id in a rule — in which case they are quoted.

**The round trip** is the writer's claim, tested on the whole example corpus:

```
./myswipl.sh -q -g "consult('testing/le_writer_roundtrip.pl')" -g "le_writer_roundtrip:main" -t halt
```

LE → knowledge base → IR → LE → knowledge base must give the same clauses,
scenario facts, expectations, queries and table rows up to variable names
(113 of 115 programs; the two exclusions are stated with their reasons in the
file). `testing/test_le_writer.pl` runs a sample of it, the IR forms one by
one, and the Prolog path.

**Plain Prolog and s(CASP) (§5.7).** `prolog_file_to_ir/3` reads a Prolog file
(or an s(CASP) file: `#pred p(X) :: '@(X) is ...'` annotations give the
wording) and verbalises the rest naively: `parent(X, Y)` becomes `*a person*
is the parent of *a child*`, `age(X, N)` with numbers in the second place
`the age of *a person* is *a number*`, the places named after the variables of
the clauses. Built-in goals become `prolog` goals. The test
(`prolog_to_le` in `test_le_writer.pl`) runs the source in Prolog, turns its
answers into expectations and checks the LE program reproduces them.

## 3. The ledger, the source tests and fidelity (`le_migration.pl`)

```prolog
migration(Meta, IR, Ledger, Tests)
Meta   = [source(System), artifacts([...]), translator(Name), program(Name),
          date(D), licence(L)]
Ledger = [entry(Element, Kind, Verdict, Mapping, InProgram, Note), ...]
          Verdict: encoded | approximated | residue
Tests  = [test(Id, Document, Locator, Facts, Expectations), ...]

write_migration(+Migration, +Dir, +Base, -Report).
    % writes Dir/Base.le, runs its source tests, writes Base.ledger.md
    % and Base.ledger.json
migration_text/3, source_tests_scenarios/2, ledger_markdown/3,
ledger_dict/3, ledger_counts/2, migration_fidelity/3, copy_library/2.
```

**Pending expectations.** An expectation whose query depends on what an
untranslated residue block must conclude cannot hold yet: when the residue
item declares `concludes([F, ...])` (IR functors), `le_migration` follows the
IR's rules from each query and turns every expectation that reaches one of
them into `pending(Why, Expectation)` — written as a comment in its scenario
(`% pending — waits for residue r1:`), counted in the ledger, restored when the
block is translated. A reader may also mark an expectation pending itself —
`pending('approximated — ...', expects(...))` for a documented departure from
the source — instead of leaving a test the twin fails by design.

Each source test becomes a scenario whose header cites it
(`scenario t3 is, as stated in "tests.xlsx" at case 3:`), so every fact of it
carries that provenance into explanations. `migration_fidelity/3` runs the
written program's tests with `runTestsFor/2` and reports each source test as
reproduced or not; the ledger shows the counts of encoded / approximated /
residue elements beside that pass rate, one row per source element, and a
Residue section for what was left to the assistant.

## 4. Residue: the assistant translates only what the translator could not

A translator writes what it could not translate as a residue block:

```le
% RESIDUE r3 BEGIN: the collision rating plugin
%   source: plugins/rating.js lines 40-61
%   javascript:
%   | if (vehicle.age > 10) { premium = premium * 1.2; }
% RESIDUE r3 END
```

The Contract Assistant's `residue` mode (request field `mode: "residue"`,
`program`: the skeleton; optional `text`: background) asks the model for one
fenced block per residue (```` ```le residue r3 ````), splices each between
its markers itself — so no reply can change the skeleton — verifies the whole
program and runs its scenarios (the source's tests), and repairs the residue
until they pass: a skeleton test that passed and fails after the splice is a
`regression` error. An optional `% RESIDUE TEMPLATES BEGIN` / `END` region in
the templates section receives the templates a residue needs (```` ```le
residue templates ````). The job's ledger lists each residue as translated,
declined (only a comment saying why) or open. Tests:
`testing/test_residue_mode.pl`.

## 5. The defects fixed before the readers (Appendix A of the report)

- **D1** — `either`/`any of`/`at least one of` in a plain body joined every
  `and` below it with `or`, so a nested `all of` became a disjunction. Each
  direct child is now one alternative with its own structure.
- **D2** — `it is not the case that ...` in a numbered item was read through
  the generic "is" form. It is now a negation, with the goal on the item's
  line or as sub-items.
- **D3** — an `; opposite:` form used as a condition: documented (§2 of
  `le_summary.md`) and diagnosed (`opposite_as_condition` instead of
  `undefined_predicate`).
- **D4** — `verify/1` failed on every `lps`-target document because the LPS
  parsing hooks were not loaded; `le_kbs` loads them, and `verify/1` also
  prints the LPS emitter's own diagnostics. Propositional LPS templates are no
  longer reported as unused.

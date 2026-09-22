# Migrating programs into Logical English: the shared machinery

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

This is the reference for the infrastructure every translator into Logical
English shares — Phase 0 of the roadmap in
`lpsPlus/docs/migration/roadmap.md` (§4 and §8). The source-specific
readers (Socotra, Oracle Intelligent Advisor, Bitcoin Miniscript, Solidity)
live in the lpsPlus repository (`lpsPlus/migration/`) and are described
there; everything here is core LE and has no knowledge of any source system.
The twins they write live with the language they are written in: timeless LE
twins in this repository's `examples/migration/<source>/` (Blawx, LegalRuleML,
Miniscript, s(CASP)), LE-for-LPS twins in `lps2/examples/migration/<source>/`
(Daml, Drools, Solidity), and those whose sources are not cleared for
publication in `lpsPlus/examples/migration/` (`le2_paths:twins_dir/2` there
says which).

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
| Obligations, permissions, prohibitions, violations (the deontic pattern library) and `*a sentence* is the case` | `lib/deontic.le`, `reasoner.pl` (`le_holds/1`) | N4 |
| Integer division `//` and remainder `mod` | `le_grammar.pl` | E4 |
| `either`/`any of` with nested `all of`; negation in numbered items | `le_extensions.pl` (InsurLE) | D1, D2 |
| `; opposite:` forms are not negation in a condition — documented, and diagnosed (`opposite_as_condition`) | `le_verifier.pl`, `docs/user/reference/language.md` §2 | D3 |
| `verify/1` on LPS documents, with the LPS emitter's own diagnostics | `le_kbs.pl` | D4 |

## 0. Opening another system's file (`le_import.pl`)

`File > Open` in the editor, and the LPS2 IDE's `File > Open` for a `.sol`,
send a file that is not Logical English to the operation `importForeign`,
which hands it to the translator registered for it. A translator registers
itself with one clause (the proprietary translators are listed in
`lpsPlus/migration/le_importers.pl`, which `le_kbs.pl` loads through the
`le_importers.pl` link in this directory):

```prolog
le_import:importer(Id, Title, Extensions, File, Module:Import, Module:Detect).
%   call(Import, +Input, +OutDir, -imported(LEFile, Notes))
%   call(Detect, +Input)       % decides for shared extensions (zip, xml, json, txt)
```

The upload is kept under `tmp/imports/<id>/` for a day: an archive is
extracted there (members leaving the tree are skipped), the translation is
written beside it, and the program opens as the example
`imported/<id>/<name>` (le_example_relpath/2), so its includes and cited
documents resolve. A fragment the translator cannot translate is written
into the program as a residue block, whose first line is `% TODO: …`
(`le_writer:write_residue/2`); a file no translator reads, or one whose
translator fails, still opens: its text as a TODO comment, with the reason.
`importFormats` lists the registered translators (the editor's file picker
offers their extensions; `File > Import from Another System…` offers only
theirs). Tests: `testing/test_le_import.pl`,
`editor/tests/import-foreign.spec.ts`.

**The originals: `sources/` beside the program.** What a program was
converted from is kept in a `sources/` folder beside it, and the editor's
`File > Show the Original…` (operation `originals`, which lists that folder's
text files; each opens in the source viewer through `documentText`) shows
it. `le_import.pl` copies an upload there unless the translator has already
put the files its citations use there itself (the Socotra adapter does, under
the product's own paths); a migration writing twins does the same (the
Solidity twins' contracts, the Socotra products' configuration files, the OIA
projects' text files, the documents the miniscript twins quote). A document
the program cites with `the text of D is at "sources/…"` is then one of
those files. The LPS2 IDE's *View ▸ The original this was converted from*
reads the same folder for a program opened from its server. The editor's
example list does not descend into a `sources/` folder: it holds originals,
not programs.

**The other way: exporting (`exporter/6`).** `File > Export to Another
System…` in the editor (and the LPS2 IDE's Misc ▸ Export to another
system…, through `le_service:le_export/4`) writes the loaded program in
another system's format. An exporter registers itself with one clause:

```prolog
le_import:exporter(Id, Title, Extension, File, Module:Export, Module:Applies).
%   call(Applies, +KB)                      % is it a program of this kind?
%   call(Export, +KB, +Options, -Result)    % exported(FileName, Text, Notes, Links)
%                                           % or refused(Problems)
%       Options: text(Doc), base(Dir); Links: [link(Title, Url)] — a public
%       sandbox or playground the result opens in
le_import:export_check(Id, Module:Check).
%   call(Check, +KB, +Options, -Problems)   % [problem(Where, Message)], Where
%                                           % at(Start, End) | line(N) | none
```

KB is the loaded knowledge base, so an exporter reads the program through
`le_writer:kb_to_ir/2` (or the LPS translation), never its text. Operations
`exportFormats` (the exporters that apply to a program) and `exportForeign`
(the text, notes and links); the editor lists only the exporters that apply,
and shows the result to copy or save, with its notes and a button per link.
Tests: `testing/test_le_import.pl` (a made-up exporter with a check),
`editor/tests/import-foreign.spec.ts` (both ways, and a refusal). The
lpsPlus exporters and their checks are registered in
`lpsPlus/migration/le_importers.pl` beside the importers.

**Exporting: the check before the text.** What an exporter cannot express
is never dropped silently, and there are two kinds of it. A *problem* loses
meaning — a rule, fact, condition or declaration the target has no faithful
form for — and the program is **refused**: nothing is written, and the
reply (`le_import:export_refusal/4`) is `{error, exporter, problems}`, each
problem `{line, message, text}` (the line and the program's own words
there). The editor shows the list, each line a link to it (`#export-refused`);
the LPS2 IDE the same in its dialog. A *note* loses no meaning (comments,
queries and expected answers, layout, a key named after its role) and
travels with the written text. `export_kb/4` runs the exporter's
`export_check` before `Export` (and passes `checked(true)` so it need not
check again); an `Export` that meets a problem only while translating
answers `refused(Problems)`. `Applies` and the check are two things on
purpose: Applies decides what the menu offers (a program of the kind), the
check whether this one can be written — an offered exporter may refuse, and
its list says what to change. LE's integrity constraints (`it must not be
true that …`) are not in the Migration IR: an exporter to a target without
constraints asks `le_import:kb_constraint_problems/3` for them.

Every other conversion of an LE or LPS program into another language
refuses the same way, with the same reply:

| conversion | where | the check |
|---|---|---|
| LE → Miniscript, LegalRuleML, Daml | `lpsPlus/migration/{miniscript,legalruleml,daml}` | `check_miniscript/3`, `check_lrml/3`, `check_daml/3` |
| LE → s(CASP) (See s(CASP), the s(CASP) engine) | `le_scasp.pl` | `le_scasp_check/3`: an emitter issue that loses meaning (docs/user/reference/scasp.md §8) |
| LE for LPS → LPS (`getLps`, LPS2's `le_compile`, Deploy as Solidity, the LPS exporters) | `le_lps.pl` | any error issue, including `not_lps` (lps2's docs/user/reference/le-for-lps.md §8): no LPS text |
| LPS → Solidity | `lpsPlus/migration/solidity/lps_solidity.pl` (LPS2's Deploy as Solidity, loaded by its `src/syntax/lps_plus.pl`) | `lps_to_solidity/3`'s refusal (reactive rules, Prolog, enumeration, …) |
| LPS → LE (a document) | `le_lps_write.pl` | `le_lps_check/3`; `residue(true)` (a translator into LE) writes a comment instead |

Out of scope, and why: LE → Prolog is LE's own compilation, not a
translation; the Mermaid export is a diagram of the program, not a program;
Deploy as WASM bundles the same LPS program with its engine; the legal view
(`le_lps_legal.pl`) is an explanatory reading of a run, not a program meant
to be equivalent; PDDL, Inform 7 and DRL are read into LPS, never written.

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
| `extends([Base, ...])` | `the knowledge base N extends Base, ....` (target `lps`, le_lps_surface.md §1.1) |
| `services([service(Name, Address, Kind), ...])` | `... includes these services:` |
| `provenance_required` | `scenario facts require provenance.` |
| `extensions(true\|false\|auto)` | whether the document may use the InsurLE extensions — `all of`/`either` blocks, numbered outlines. Default **false**: the writer produces core LE, which reads on a server without `le_extensions.pl`; `auto` allows them when the module is loaded |
| `setting(max_time, N)` etc. | LPS settings |

### Items

| Item | Written as |
|---|---|
| `template(F, Text, Additions)` | a line of `the templates are:`. `F` is the translator's name for the predicate (its literals use it, with as many arguments as `Text` has places); LE derives its own functor from the words, and the two never need to agree. `Text` is the declaration, `"*a person* is born in *a place* on *a date*"`. Additions: `undefined`, `assumable`, `judged`, `prepositional`, `opposite(Text)`, `synonym(Text)`, `via_service(S)`, `known_as(F)`, `default(V)` (a fluent's `; V by default`), `included` (declared by an included resource or a base: known for writing, not written) |
| `constant(F, Name, Value)` | a line of `the constants are:` (`Name is Value.`, le_summary.md §2.2); `F` is the functor of its template `the value of Name is *a type*` (`the_value_of_<name words>_is`), whose one-place goal a body uses where the value is read — the writer writes the name there |
| `function(F, Text)` / `function(F, Text, Additions)` | a line of `the functions are:` (docs/user/reference/language.md §2.3): a template of the form `... is *a value*` whose value may be written without that last place. Emit it for a relation the source says is functional (a rate, a lookup, a computed field), and the writer writes the compact form — `and the price of the cup > 10` rather than a condition binding the value and another using it — wherever the value is used and its inputs are already known |
| `fluent/event/action(F, Text, Additions)` | the LPS declaration sections |
| `rule(Head, Body, Options)` | a rule. Options: `label(L)` (`rule L:`), `provenance(P)` (with a label: `rule L with provenance ...:`), `numbered(true)` (a numbered outline, docs/user/reference/extensions.md §15.5 — written only with `extensions(true)` in the header, a plain body otherwise), `comment(Text)` |
| `fact(Head, Options)` | a fact; Options `provenance(P)` (trailers), `ontology` (in `the ontology is:`) |
| `constraint(Body, Options)` | an integrity constraint, `it must not be true that` and the conditions (le_summary.md §3.3); Options `comment(Text)` |
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
literals of the IR's templates. `max(A, B)` and `min(A, B)` inside a formula
or a comparison (`Z is max(X, Y) + 1`) are written as the conditions `the
maximum of X and Y is M` before it (LE has no min/max functions); any other
function LE has no form for (`**`, `^`) makes the rule an error issue
(`rule_not_written`) and a `%` comment naming it — a rule, or constraint, the
writer cannot write is never dropped without both. LE's own internal forms (`le_at/3`, the
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
`    or c`. A group with no line of its own to open with is written under one
of its plain conditions: an `otherwise` cascade nested under a connective
under the first condition of its first alternative (a line opening with
`otherwise` starts a new alternative of the block it is in, so the guard is
the whole alternative, language.md §17.2); a group whose first condition is
a negation block, a universal or an aggregate under the first plain
condition that can be moved in front of it — one whose variables shared
with the conditions jumped over are bound by then (`core_single/4`). Only
when no such condition exists is the group an `all of` / `either` block of
the extensions, and the writer reports it (`needs_extensions`).

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

**s(CASP), in detail (Phase 2c).** The reader is LE's s(CASP) target read
backwards (`docs/user/reference/scasp.md` §4, §13): `-p(X)` is p's opposite form
(`; opposite:`, its wording from `#pred -p(X) :: …` or made from p's);
`#abducible` (or the target's `le_unknown/1` records) `; unknown`; `:- B.` and
`false :- B.` denials become integrity constraints, `it must not be true that
B` (le_summary.md §3.3: as in s(CASP), a case whose facts meet them answers
nothing, and no answer may assume what would meet them — before LE had
timeless constraints they were queries `denial_<n>` the scenarios expected to
have no answer, convention N1); `#>`, `#>=`,
`#<`, `#=<`, `#<>` comparisons and `#=` an assignment; `?- Q.` queries
`query_<n>`; the target's `le_forall_K` helpers fold back into universals;
several `#pred` wordings of one predicate are its synonyms; `is_a/2` is LE's
own form; a clause that takes a list apart (`[H|T]`) is a residue block; a
template whose words would read as one of LE's own forms (`X is Y`, `X is in
Y`) changes a word. Option `language(L)` writes in the program's language.
The target is `scasp` when the source has abducibles, classical negation or
denials. The round trip `testing/scasp_roundtrip.pl` (83 of 88 programs
exact) and `testing/test_scasp_reader.pl` test it.

**Plain Prolog and s(CASP) (§5.7).** `prolog_file_to_ir/3` reads a Prolog file
(or an s(CASP) file: `#pred p(X) :: '@(X) is ...'` annotations give the
wording) and verbalises the rest naively, each place named after the first
variable found in it in the clauses (a one-letter variable, or none, says
nothing: `*a thing*`, `*a second thing*`): `parent(X, Y)` becomes `*a thing*
is the parent of *a second thing*`, `parent(Parent, Child)` `*a parent* is the
parent of *a child*`. A two-place predicate with a number in its second place
in some fact (`age(bob, 55)`) is worded as a value, `the age of *a thing* is
*a second thing*`; the place is not typed `number` (its name still comes from
the variables). Built-in goals become `prolog` goals. The test
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
          Facts: literals, fact(L, Provenance), unknown(L), rule(H, B) (a
          rule of the scenario), comment(Text)

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

# Blawx and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Blawx is a web-based tool for Rules as Code, written by Jason Morris of
Lexpedite. An author pastes legislation into Blawx, in a light markdown that
numbers its sections. The author encodes each section with visual blocks:
categories, attributes, relationships, rules, exceptions ("section 4 overrides
section 3"), and tests. Blawx compiles the blocks into s(CASP) and answers the
tests with s(CASP). The integration goes one way, into Logical English.
**File ▸ Open…** (or **File ▸ Import from Another System…**) reads a Blawx
project, as a `.blawx` export or as the YAML of one of Blawx's example projects,
alone or zipped. The result is a Logical English program in the Act's own words.
Each rule cites its section, the Act's text is kept beside the program, and the
project's tests are scenarios whose expectations are Blawx's own answers. There
is no export to Blawx. The translator is part of the InsurLE extensions, so it
is available only on installations that have them, such as the hosted service.
The twins of Blawx's example projects are in every installation.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a Blawx project](#opening-a-blawx-project)
  - [The sections, cited](#the-sections-cited)
  - [The tests, as scenarios](#the-tests-as-scenarios)
  - [The Act's view](#the-acts-view)
  - [The example twins](#the-example-twins)
- [How Blawx maps to Logical English](#how-blawx-maps-to-logical-english)
  - [Exceptions: Blawx's defeasibility](#exceptions-blawxs-defeasibility)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Blawx → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.blawx`, `.yaml`, `.yml`, or a `.zip` holding one | the Act's rules in the words of Blawx's sentence forms, each citing its section; facts citing theirs; constraints; the project's tests and cases written from each rule as scenarios; a view; a ledger; the Act's text in `sources/` | Blawx's own answers: its reasoner, run on the project, answers every test and generated case |
| Logical English → Blawx | none | — | — | — |

## How to use it

### Opening a Blawx project

1. In Blawx, export the project (a `.blawx` file). The YAML files of Blawx's
   example projects work as they are. A `.zip` holding the file works too.
2. Choose **File ▸ Open…** and pick the file. The file is read as Blawx when it
   holds a `blawx.ruledoc`, Blawx's rule document.
3. The program opens in a new tab. The note gives the ledger's counts and the
   check against Blawx, for example *rps: 17 ledger elements encoded, 3
   approximated, 0 residue; 0 writer errors; Blawx's tests and the generated
   cases: 11 pass, 0 fail, 0 errors.*
4. The program's header names the project and how many sections it has.
   **Misc ▸ Run the Program's Tests…** runs the scenarios.
5. **File ▸ Show the Original…** lists the project file and the Act's text,
   `sources/<name>.md`. The ledger, `<name>.ledger.md`, has one row per element
   of the encoding (category, rule, test, the clock, Blawx's boilerplate) and
   says whether it was *encoded*, *approximated* or left as *residue*.

The expectations come from running Blawx's reasoner on the project. That needs
the reasoner on the server. When it cannot run, the scenarios carry no
expected answers. A note may say so, or the counts in the note are all zero.

### The sections, cited

The program cites two documents, the Act and the project:

```le
the text of the Rock Paper Scissors Act is at "sources/rps.md".

the text of the Blawx project is at "sources/rps.yaml".
```

Each rule is labelled after its section and cites it. Each fact encoded in a
section cites that section:

```le
rock beats scissors, as stated in the Rock Paper Scissors Act at section 3 a.

rule section_4 with provenance the Rock Paper Scissors Act at section 4:
the winner of a game is a player if
    the game is a game
    and the player is a player
    ...
    and the sign beats the second sign.
```

A right-click on a citation in the editor offers **Show original text**, which
opens the Act's text. In an explanation, and in the executive view, a cited
step shows its section with a § badge that opens the passage. A rule you read
in Logical English is always one click from the words it encodes.

### The tests, as scenarios

Each Blawx test becomes a scenario named after it, with the test's facts and
its comments. Its query expects what Blawx answered:

```le
scenario pingu_on_plane_can_fly is, as stated in the Blawx project at test pingu_on_plane_can_fly:
    % Pingu can fly, because section 2 applies, because
    % section 3 would defeat it, but section 4 defeats
    % section 3. Also, section 4 applies on its own.
    pingu is on a plane.
    pingu_on_plane_can_fly expects answers ["pingu can fly"].
```

Most example tests state no facts: they are starting points for Blawx's
scenario editor. So the translator also writes cases from the rules, answered
by Blawx the same way (`case_1`, `case_4_without_fact_1`, …). For each rule
there is a case that meets every condition, with individuals named after their
types (`penguin_a`) and numbers at the boundary of their comparisons. Each near
miss leaves one fact out or misses one comparison by one. A rule with
exceptions also gets a case with each exception added. There are at most 10
cases per rule and 90 per project. These scenarios cite `the case analysis of
the encoding at section …`.

When the translator knows a test does not do what its name or comment says,
the scenario says so in a `NOTE` and still expects Blawx's answer (see
[Traps](#traps)).

### The Act's view

Each program ends with a view, `the act`. Open it with **Misc ▸ Open Executive
View** and pick it from the **Views:** strip. It shows the facts of the case,
the answer to the question most sections conclude (for the Bird Act, *which
thing can fly*), its reasons and its citations, and a flip. When the answer is
no, *Why not* lists the conditions the case did not meet, each with its
section.

### The example twins

Blawx's fifteen example projects (Blawx v1.6.22-alpha, MIT licence) have been
translated. The results, *twins*, are among the examples under
`migration/blawx/`. Open them with **File ▸ Open copy from server…**:

| Twin | Project |
|---|---|
| `bird` | the New Bird Act: sections that defeat one another |
| `rps` | the Rock Paper Scissors Act |
| `r34` | Rule 34 of the Legal Profession Professional Conduct Rules: 42 rules, 17 defeats |
| `oasa` | the Old Age Security Act |
| `beard_tax`, `covid_test`, `mortality`, `net30`, `siblings`, `wills`, `wills_tutorial` | smaller examples: categories, dates, relationships |
| `logical_constraints`, `numerical_constraints` | Blawx's constraints |
| `life_act`, `list_demo` | events and lists, kept as residue |

All the active expectations pass (163 on 15 September 2026). Twenty-one more
are kept as comments, each with its reason.

## How Blawx maps to Logical English

| Blawx generates | Logical English |
|---|---|
| a category, `#pred C(X) :: '@(X) is a C'` | `*a thing* is a C` |
| an attribute or relationship with its `#pred` sentence | a template in the sentence's words, with places typed and in the sentence's order; Blawx's possessive `@(X) 's facial hair is …` becomes `the facial hair of *a person* is …` |
| `according_to(Section, P, …) :- Body` | a rule concluding P, labelled and cited: `rule section_4 with provenance the … Act at section 4:` |
| `holds`, `according_to` plumbing and its `% BLAWX CHECK DUPLICATES` copies | nothing: folded into the rules |
| a rule that other sections defeat | the rule with a guard: `and it is not the case that the thing cannot fly under section_3` |
| a conclusion another rule reads per section | a template of its own, `*a thing* can fly under *a provision*`, and a rule linking it to the plain conclusion |
| `-P(…)`, classical negation | P's opposite form: `; opposite: *a thing* cannot fly` |
| facts in a section | facts citing it |
| `#abducible` in a section | `; assumable` |
| `false :- Body` | an integrity constraint, `it must not be true that …` |
| comparisons of numbers, dates, durations | comparisons |
| `date_add` | an assignment (`M = T - N`) |
| `date(T)`, `datetime(T)`, `duration(T)` | the number T: seconds since 1970, as Blawx stores them |
| `blawx_today`, `blawx_now` | a fact of the day the twin was built (*approximated*) |
| `blawx_as_of`, `blawx_during`, `blawx_not_interrupted` boilerplate | left out, counted in the ledger |
| events: `blawx_becomes`, `blawx_initially`, `blawx_ultimately` | a residue block per section |
| `findall` over Blawx's lists | residue |
| a test's facts and `?- query.` | a scenario and a query, expecting Blawx's answer |

### Exceptions: Blawx's defeasibility

Blawx lets one section override another. The translator writes the override
as plain Logical English rules. The defeated rule carries its defeaters'
failure as a condition, and each defeater's conclusion is held per section.
Here is the New Bird Act:

```le
rule section_2 with provenance the New Bird Act at section 2:
a thing can fly if
    the thing is a bird
    and it is not the case that the thing cannot fly under section_3.

rule section_3 with provenance the New Bird Act at section 3:
a thing cannot fly under section_3 if
    the thing is a penguin
    and it is not the case that the thing can fly under section_4
    and it is not the case that the thing can fly under section_5.

% What section 3 concludes holds.
rule section_3_conclusion with provenance the New Bird Act at section 3:
a thing cannot fly if
    the thing cannot fly under section_3.
```

In Blawx's examples the overriding sections always conclude different things
(`can fly` against `cannot fly`), never rival values of one conclusion. The
defeats never form a cycle, so the negation is stratified. The twins answer as
Blawx does with LE's ordinary Prolog engine, and need no s(CASP). A project with
a cycle of defeats would need `the target language is: scasp.`
([s(CASP)](scasp.md)).

## Traps

- **The expectations are Blawx's answers, bugs included.** The twin follows
  the encoding, not what the Act means. In the New Bird Act, section 5 says
  "…, except for pingu", but Blawx never wires the exception into the rule. So
  Blawx answers that pingu with a jetpack can fly, although the test is named
  `pingu_with_jetpack_cant_fly`. The twin expects Blawx's answer and says so
  in a `NOTE`. Its fact `section_5 does not apply to pingu under
  section_5_pingu` is one that no rule reads, and the verifier warns about it.
- **Without Blawx's reasoner there are no expectations.** A project opened on a
  server that cannot run it gets scenarios with facts but no `expects answers`
  lines, and no generated-case expectations. Check the note's counts.
- **Abductive tests and symbolic answers are pending.** A test that lets
  s(CASP) assume facts (`#abducible`) gets hypotheses from Blawx. An LE
  scenario states facts or does not. Such expectations, and answers that are a
  variable or a constraint, are kept as `% pending —` comments with the reason.
- **Dates are numbers of seconds.** Blawx stores dates as seconds since 1970,
  and the twins keep them (`bob was born on 946710000`). They are instants, not
  days. A date written in another form (`datetime(2000,1,5,0,0,0)`) is not a
  number to Blawx's date rules, and fails in both.
- **Today is fixed.** `blawx_today` becomes a fact of the day the twin was built.
  Blawx answers with the day it runs. Update that fact to re-run a
  date-dependent test.
- **Events and lists are residue.** Blawx's event calculus (the Life Act) and its
  list aggregates (the Lists Demonstration) are kept verbatim as `% RESIDUE`
  blocks. A value that events change belongs in a program in Logical English
  for LPS, or in periods from the temporal library.
- **Rules Blawx's reasoner never applies.** Rules that call predicates Blawx
  v1.6.22 does not define (the OAS Act's `datetime_add`, `not_after`), and
  clauses Blawx's generator wrote so that they do not parse (Rule 34's
  paragraphs 4 and 5), are residue. Their blocks say that they never apply in
  Blawx. The answers stay those of the Act without them, as in Blawx.
- **A circular rule is left out.** Rule 34 section 9(a) defines `business` from
  itself. It adds nothing, and in s(CASP) it empties the predicate. The twin
  leaves it out, and the ledger says so.
- **Constants ending in `_<digits>`.** s(CASP) reads `bob_1` back as `bob`. In
  Blawx, `bob_1` and `bob_2` are one individual. The generated cases use
  `person_a`, `person_b` for that reason. Use such names in your own scenarios
  if you compare with Blawx.
- **Constraints make a case inconsistent.** The Logical Constraints example
  gives Bob two ages and forbids it. As in Blawx, the case answers nothing, and
  the explanation of the empty answer is the constraint.
- **Wording follows Blawx's sentence forms.** They are the author's words in the
  blocks, and sometimes clumsy: Rule 34's category guards are lines of their
  own, and its template text *the EA* leaks into sentences. Section constants
  keep underscores (`section_3`, `s3_1_a`), because LE would split a
  parenthesis.
- **Not read:** Blawx's scenario-editor data, its interview, and its Akoma
  Ntoso output. The Act is cited as markdown, with sections as locators.
- **No way back.** Nothing writes Blawx blocks. **See s(CASP)** writes the
  program as s(CASP), which is what Blawx generates, but not a Blawx project.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [opening a file](index.md#opening-another-systems-file), [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [the twins](index.md#the-migration-twins-among-the-examples);
  - [s(CASP), Prolog and Logical English](scasp.md), the language Blawx generates; [LegalRuleML](legalruleml.md), whose defeasibility is written out the same way;
  - the language reference: [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance), [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [views](../reference/language.md#1710-views-how-a-screen-shows-a-program), [testing and expectations](../reference/language.md#12-testing-and-expectations);
  - [the executive view](../guide/executive-view.md#views) and [why not](../guide/executive-view.md#when-there-is-no-answer-why-not); [LE Views](../tutorials/views.md);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant), whose residue mode translates residue blocks;
  - [s(CASP) on Logical English](../reference/scasp.md).
- In the LPS2 IDE: [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- Blawx's own documentation: [Blawx on GitHub](https://github.com/Lexpedite/blawx) (source, README and the example projects).

# Blawx and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Blawx is a tool that runs in a web browser for writing law as rules a computer
can follow, and it was written by Jason Morris of Lexpedite. An author pastes
the legislation into Blawx, written in a simple marked-up text that numbers the
sections. The author then encodes each section by dragging blocks together on
the screen: categories, attributes, relationships, rules, exceptions ("section
4 overrides section 3"), and tests. Blawx turns those blocks into s(CASP), and
answers the tests with s(CASP).

The translation goes one way only, into Logical English. **File ▸ Open…** (or
**File ▸ Import from Another System…**) reads a Blawx project, either as a
`.blawx` file exported from Blawx or as the YAML file of one of Blawx's own
example projects; YAML is a plain-text way of writing structured data, and
either file may be uploaded on its own or inside a zip. What comes out is a
Logical English program in the Act's own words. Each rule cites the section it
came from, the Act's text stays beside the program, and the project's tests
become scenarios that expect the answers Blawx itself gives. Nothing writes a
Blawx project back out. The translator is part of the InsurLE extensions, so
only installations that have the extensions, such as the hosted service, offer
it. The translations of Blawx's example projects, the *twins*, come with every
installation.

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

1. In Blawx, export the project as a `.blawx` file. The YAML files of Blawx's
   own example projects work just as they are. A `.zip` holding either kind of
   file works too.
2. Choose **File ▸ Open…** and pick the file. The editor reads a file as Blawx
   when the file holds a `blawx.ruledoc`, which is Blawx's own rule document.
3. The program opens in a new tab. A note gives the counts from the ledger, the
   record of how each piece of the project was translated, together with the
   comparison against Blawx — for example *rps: 17 ledger elements encoded, 3
   approximated, 0 residue; 0 writer errors; Blawx's tests and the generated
   cases: 11 pass, 0 fail, 0 errors.*
4. The program's header names the project and says how many sections the
   project has. **Misc ▸ Run the Program's Tests…** runs the scenarios.
5. **File ▸ Show the Original…** lists the project file and the Act's text,
   `sources/<name>.md`. The ledger, `<name>.ledger.md`, has one row for each
   piece of the encoding — each category, rule and test, the clock, and the
   lines Blawx adds to every project — and says whether that piece was
   *encoded* (translated with its meaning intact), *approximated* (translated,
   with a note on what changed) or left as *residue* (not translated).

The answers the scenarios expect come from running Blawx's own reasoner on the
project. Running that reasoner needs three things on the server: Blawx's
preamble, the block of rules Blawx puts in front of every project, which the
server fetches; Python with the PyYAML package; and SWI-Prolog's s(CASP)
library. Where the reasoner cannot run, the scenarios
carry no expected answers at all, and a second note says which of the three
things is missing.

### The sections, cited

The program cites two documents, the Act and the project:

```le
the text of the Rock Paper Scissors Act is at "sources/rps.md".

the text of the Blawx project is at "sources/rps.yaml".
```

Each rule is named after its section and cites that section. Each fact encoded
in a section cites the section too:

```le
rock beats scissors, as stated in the Rock Paper Scissors Act at section 3 a.

rule section_4 with provenance the Rock Paper Scissors Act at section 4:
the winner of a game is a player if
    the game is a game
    and the player is a player
    ...
    and the sign beats the second sign.
```

Right-click a citation in the editor and the menu offers **View Original
Text**, which opens the Act's text. In an explanation, and in the executive
view, a step that cites a section shows a § badge, and the badge opens the
passage. A rule you are reading in Logical English is always one click away
from the words of the Act it encodes.

### The tests, as scenarios

Each Blawx test becomes a scenario of the same name, holding the test's facts
and the test's comments. The scenario's query expects whatever Blawx
answered:

```le
scenario pingu_on_plane_can_fly is, as stated in the Blawx project at test pingu_on_plane_can_fly:
    % Pingu can fly, because section 2 applies, because
    % section 3 would defeat it, but section 4 defeats
    % section 3. Also, section 4 applies on its own.
    pingu is on a plane.
    pingu_on_plane_can_fly expects answers ["pingu can fly"].
```

Most of the example tests state no facts at all, because they are meant as
starting points for someone working in Blawx's own scenario editor. The
translator therefore writes cases of its own from the rules, and Blawx answers
those cases in the same way (`case_1`, `case_4_without_fact_1`, and so on). For
each rule there is one case that meets every condition of the rule, with the
individuals named after their types (`penguin_a`) and the numbers set right at
the edge of the comparisons the rule makes. Beside it are the near misses, each
leaving one fact out or missing one comparison by one. A rule that has
exceptions also gets one case for each exception, with that exception added.
There are at most 10 cases for a rule and 90 for a project. Each of these
scenarios cites `the case analysis of the encoding at section …`.

Where the translator can tell that a test does not do what its name or its
comment claims, the scenario says so in a `NOTE` and still expects the answer
Blawx gives (see [Traps](#traps)).

### The Act's view

Each program ends with a view named `the act`. Open the view with **Misc ▸
Open Executive View**, then pick the view from the **Views:** strip. The view
shows the facts of the case and the answer to the question most of the sections
conclude — for the Bird Act, *which thing can fly* — with the reasons for the
answer, the sections cited, and a flip, which shows what would have to change
for the answer to change. When the answer is no, *Why not* lists the conditions
the case failed to meet, each with the section it comes from.

### The example twins

Blawx's fifteen example projects (Blawx v1.6.22-alpha, MIT licence) have all
been translated. The translations, the twins, sit among the examples under
`migration/blawx/`. Open a twin with **File ▸ Open example from server…**:

| Twin | Project |
|---|---|
| `bird` | the New Bird Act: sections that defeat one another |
| `rps` | the Rock Paper Scissors Act |
| `r34` | Rule 34 of the Legal Profession Professional Conduct Rules: 42 rules, 17 defeats |
| `oasa` | the Old Age Security Act |
| `beard_tax`, `covid_test`, `mortality`, `net30`, `siblings`, `wills`, `wills_tutorial` | smaller examples: categories, dates, relationships |
| `logical_constraints`, `numerical_constraints` | Blawx's constraints |
| `life_act`, `list_demo` | events and lists, kept as residue |

Every expected answer that runs passes: 163 of them on 15 September 2026.
Twenty-one further expected answers are kept as comments rather than run, each
with the reason beside it.

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

Blawx lets one section override another. The translator writes an override out
as plain Logical English rules. The rule that can be defeated gains a condition
saying that the rules which would defeat it do not hold. Each defeating rule
concludes under its own section, so the program can say which section a
conclusion comes from. Here is the New Bird Act:

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

In Blawx's examples the overriding sections always conclude different things,
`can fly` against `cannot fly`, and never two rival values for one conclusion.
No defeat ever comes round in a circle, so the rules can be put in layers,
where each layer only negates a layer below. The twins therefore answer just as
Blawx does under Logical English's ordinary Prolog engine, and need no s(CASP)
at all. A project in which the defeats did come round in a circle would need
`the target language is: scasp.` ([s(CASP)](scasp.md)).

## Traps

- **The expected answers are Blawx's answers, mistakes included.** A twin
  follows the encoding, not what the Act means. In the New Bird Act, section 5
  says "…, except for pingu", but Blawx never connects that exception to the
  rule. So Blawx answers that pingu with a jetpack can fly, even though the
  test is named `pingu_with_jetpack_cant_fly`. The twin expects Blawx's answer
  and says so in a `NOTE`. The twin's fact `section_5 does not apply to pingu
  under section_5_pingu` is a fact no rule ever reads, and the verifier warns
  about it.
- **Without Blawx's reasoner there are no expected answers.** Open a project on
  a server that cannot run the reasoner and the scenarios arrive with their
  facts but with no `expects answers` lines, and the generated cases expect
  nothing either. The counts are then all zero, and the second note says why:
  the preamble was not fetched, or PyYAML is missing, or s(CASP) is.
- **Abductive tests and answers that are not values wait rather than run.** A
  test that lets s(CASP) assume facts of its own (`#abducible`) gets those
  assumptions back from Blawx. A Logical English scenario, by contrast, either
  states a fact or does not. Such expected answers, and answers that come back
  as a variable or a constraint rather than a value, are kept as `% pending —`
  comments, each with its reason.
- **Dates are counts of seconds.** Blawx stores a date as the number of seconds
  since 1970, and the twins keep the dates in that form (`bob was born on
  946710000`). Such a date is an instant in time, not a day. A date written any
  other way (`datetime(2000,1,5,0,0,0)`) is not a number to Blawx's date rules,
  and fails in Blawx and in the twin alike.
- **Today is fixed.** `blawx_today` becomes a fact stating the day the twin was
  built, whereas Blawx answers with the day you run it. Change that fact before
  running a test that depends on the date.
- **Events and lists are left as residue.** Blawx's event calculus (the Life
  Act) and its aggregates over lists (the Lists Demonstration) are kept word
  for word inside `% RESIDUE` blocks. A value that events change belongs in a
  program written in Logical English for LPS, or in the periods of the temporal
  library.
- **Rules Blawx's own reasoner never applies.** Two kinds of rule are left as
  residue: rules that call predicates Blawx v1.6.22 never defines (the OAS
  Act's `datetime_add` and `not_after`), and clauses Blawx wrote in a form its
  own reasoner cannot read (paragraphs 4 and 5 of Rule 34). Each block says
  that the rule never applies in Blawx either. The answers remain those the Act
  gives without those rules, exactly as in Blawx.
- **A rule that defines a thing from itself is left out.** Section 9(a) of Rule
  34 defines `business` in terms of `business`. The definition adds nothing,
  and in s(CASP) it empties the predicate altogether. The twin leaves that
  definition out, and the ledger says so.
- **Constants ending in `_<digits>`.** s(CASP) reads `bob_1` back as `bob`, so
  `bob_1` and `bob_2` are one and the same individual. The generated cases use
  `person_a` and `person_b` for that reason. Use names of that shape in your
  own scenarios whenever you mean to compare answers with Blawx.
- **Constraints can leave a case with no answer.** The Logical Constraints
  example gives Bob two ages at once and forbids exactly that. As in Blawx, the
  case answers nothing at all, and the explanation of the empty answer is the
  constraint itself.
- **The wording follows Blawx's sentence forms.** Those forms are the author's
  own words in the blocks, and they are sometimes clumsy: the category guards
  of Rule 34 sit on lines of their own, and the words *the EA* from its
  template leak into the sentences. Constants naming sections keep their
  underscores (`section_3`, `s3_1_a`), because Logical English would otherwise
  break the name apart at the bracket.
- **Not read:** the data of Blawx's scenario editor, its interview, and the
  Akoma Ntoso documents it writes. The Act is cited as marked-up text, and the
  sections are what the citations point at.
- **No way back.** Nothing writes Blawx blocks. **See s(CASP)** writes the
  program out as s(CASP), the language Blawx itself generates, but an s(CASP)
  program is not a Blawx project.

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

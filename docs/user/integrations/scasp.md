# s(CASP), Prolog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

s(CASP) is a reasoner: you give it a question, and it works backwards from the
question through the rules to the facts. s(CASP) reasons in Answer Set
Programming with constraints, a form of logic programming in which a program
may have several consistent sets of conclusions rather than one. People run
s(CASP) from SWI-Prolog, and Blawx runs it too. An s(CASP) program looks like
Prolog with more in it: classical negation (`-flies(X)`), abducibles (facts the
reasoner may assume), global constraints (`false :- …`), comparisons written
as constraints (`#>`), and `#pred` lines that say how each predicate reads in
English. LE1, the first Logical English, turned its documents into programs of
exactly that kind.

Logical English 2 meets s(CASP) and Prolog in both directions, and the two
directions work quite differently. Coming in, **File ▸ Open…** (or **File ▸
Import from Another System…**) translates a `.pl`, `.scasp` or `.lp` file into
a Logical English program; a file LE1 wrote in s(CASP) is one such file. That
translator is part of the InsurLE extensions, so only installations that have
the extensions, such as the hosted service, offer it. Going out there is no
export menu at all, because every installation can show you the program's other
forms directly. **See s(CASP)**, which you reach by right-clicking in the
editor, shows the whole program written in s(CASP). The **Engine** picker
answers a query with s(CASP) rather than with Prolog. **See PROLOG** shows the
Prolog clause that Logical English turns a rule into. Answering with s(CASP)
needs SWI-Prolog's s(CASP) pack installed on the server, which the hosted
service has.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening an s(CASP) or Prolog file](#opening-an-scasp-or-prolog-file)
  - [LE1's s(CASP) translations](#le1s-scasp-translations)
  - [The example twins](#the-example-twins)
  - [See s(CASP): the program in s(CASP)](#see-scasp-the-program-in-scasp)
  - [The s(CASP) engine](#the-scasp-engine)
  - [See PROLOG: the PROLOG Equivalent panel](#see-prolog-the-prolog-equivalent-panel)
- [How s(CASP) and Prolog map to Logical English](#how-scasp-and-prolog-map-to-logical-english)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| s(CASP) or Prolog → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.pl`, `.scasp`, `.lp` | templates from `#pred` (else a wording made from the names), opposite forms, `unknown` templates, integrity constraints, LE1's scenarios and `?-` queries as scenarios and queries, a ledger | s(CASP)'s own answers on the source, as the scenarios' expectations (when the server has s(CASP)) |
| Logical English → s(CASP) | right-click in the editor ▸ **See s(CASP)**; the **Engine** picker | shown in the **PROLOG Equivalent** panel, with **Copy** | the whole program in s(CASP), or the list of what s(CASP) cannot state | the round trip LE → s(CASP) → LE → s(CASP) over LE2's examples |
| Logical English → Prolog | right-click in the editor ▸ **See PROLOG** | shown in the **PROLOG Equivalent** panel, with **Copy** | the Prolog clause of the rule or fact under the cursor | the Prolog engine itself: it is what runs |

## How to use it

### Opening an s(CASP) or Prolog file

1. Choose **File ▸ Open…** and pick a `.pl`, `.scasp` or `.lp` file. The file
   must hold Prolog clauses, s(CASP)'s own operators included, and at least one
   of those clauses must be a rule or a fact rather than a directive.
2. The program opens in a new tab. A note gives the counts from the ledger, the
   record of how each piece of the file was translated, together with the
   comparison against s(CASP) — for example *birds: 16 source elements encoded,
   0 approximated, 0 residue; 0 writer errors; the source's own answers
   (s(CASP)): 1 expectations pass, 0 fail, 0 errors.*
3. Every `?-` query in the file becomes a query named `query_1`, `query_2` and
   so on, and every scenario asks all of them. A file with no scenarios in it
   gets one scenario, `the_program`, which asks the queries of the program's
   own facts. The answer each query is expected to give is the answer s(CASP)
   gave on the original file.
4. A clause that Logical English cannot state becomes a `% RESIDUE … BEGIN`
   block, holding the clause word for word together with the reason it was
   left alone. Two kinds of clause end up there: a clause that takes a list
   apart, and a statement written the way clingo, another Answer Set
   Programming system, writes statements (see Traps, below):

   ```le
   % RESIDUE list_pattern_1 BEGIN: a clause that takes a list apart
   % TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
   % Logical English has no list patterns (a list's first element and the rest, [H|T]); a recursive definition over a list is written with an included Prolog resource, or restated with aggregates
   ```

5. **File ▸ Show the Original…** shows the original file, which the editor
   keeps in the program's `sources/` folder and the program cites: `the text of
   the source program is at "sources/…"`. The ledger is `<name>.ledger.md`.
6. Check the templates before anything else. Where the file has `#pred` lines,
   the translator uses their words. Everywhere else the translator builds a
   wording out of the predicate's name, so that `parent(X, Y)` becomes `*a
   thing* is the parent of *a second thing*`. Rename those templates to say
   what the predicates actually mean.

**Misc ▸ Run the Program's Tests…** then checks those expected answers.

You can also go out and back again. Copy the text that **See s(CASP)** shows
(described below) into a `.scasp` file, and open that file with **File ▸
Open…**. The rules come back as Logical English. A rule containing `or` comes
back as several rules, because the s(CASP) text writes each alternative out
separately. The scenarios and the queries are not in that text, so they do not
come back with the rules.

### LE1's s(CASP) translations

LE1 wrote each of its documents out as an s(CASP) program: the sentences became
rules with `#pred` lines, the scenarios became blocks of comments, and the
queries came after the program:

```
/* Scenario alice
is_born_in_on('John', the_UK, 1633737600.0).
...
% */
```

The translator reads all of these. Each of LE1's scenarios becomes a scenario,
whether LE1 wrote it inside a comment or as live clauses between
`/* Scenario x */` and `/* % */`. A rule written inside a scenario becomes a
rule of that scenario. The lines LE1 wrote about the program rather than about
the law — `source_lang/1`, the module line, the loader's directives — are left
out. LE1 wrote a date as a Unix time, the count of seconds since 1970, such as
`1633737600.0` in a place whose type is `date`; the translator turns such a
number into a date, `2021-10-09`. LE1 programs call `is_days_after/3` without
ever defining it, and the translator turns each call into LE2's `*a date* is *a
number* days after *a date*`. An LE1 program therefore reaches LE2 through its
s(CASP) translation, bringing its scenarios with it and using s(CASP)'s answers
as its tests:

```le
a person acquires British citizenship on a date if
    the person is born in the_UK on the date
    and the date isafter commencement
    and a second person is a parent of the person
    and the second person is citizen or settled the date.
```

### The example twins

Seventeen programs have been translated already. The translated programs,
called *twins*, sit among the examples under `migration/scasp/`. Open a twin
with **File ▸ Open copy from server…**:

- LE1's translations (from the s(CASP) pack's tests): `citizenshiptrust`,
  `criminaljustice`, `family_le`, `impossibleancestor` (a rule in a scenario),
  `isdapermissioncorrected` (sentences as values), `itispermittedthat`,
  `list` (its own universal, and a list pattern as residue), `loanwithcure`
  and `obligation` (dates), `minicontract`, `simplerps`, `subset`,
  `turingcomplete` (embedded `prolog` goals for s(CASP)'s list built-ins);
- classics of s(CASP)'s own examples: `birds` (classical negation), `family`,
  `classic_negation_inconstistent`, `abdbirds` (abducibles).

Every answer a twin expects is the answer s(CASP) gave on the original file.
Two of those expected answers are kept as comments rather than as live tests,
each with the reason beside it. In `obligation`, s(CASP) answers with a
constraint instead of a value. In `loanwithcure`, s(CASP) says that the
borrower defaults, while the program's own cure rule holds on that date; the
twin follows the rules.

### See s(CASP): the program in s(CASP)

Right-click anywhere in the editor and choose **See s(CASP)**. The **PROLOG
Equivalent** panel opens, holding the whole program as s(CASP) writes it: a
`#pred` line for each template, the rules themselves, classical negation for
the opposite forms, `false :- …` for the constraints, and, at the end, any
problem found while writing the program, as a comment. **Copy** copies the
whole text. Here is the program `birds`:

```
#pred can_fly(A) :: '@(A:thing) can fly'.
...
can_fly(A) :-
    is_a_bird(A),not(is_an_ab(A)).
-can_fly(A) :-
    is_an_ab(A).
```

When the program uses something that s(CASP) cannot say faithfully — an
aggregate, a `prolog` goal, a decision table, `is in`, date arithmetic,
`according to`, and so on — the editor shows no program at all. Instead the
same *Not translated* window that a refused export uses lists each problem
beside the line it is on. The full list of what s(CASP) cannot say is in
[the s(CASP) reference, §8](../reference/scasp.md#8-unsupported-constructs--issues-errors).
There is no **File ▸ Export** to s(CASP): **See s(CASP)** is the way out.

### The s(CASP) engine

The **Engine** picker beside **Query** chooses which reasoner answers the query,
Prolog or s(CASP). **Misc ▸ ENGINE PICKER** decides whether the picker is shown
for every program or only for programs whose target language is not Prolog. A
program that declares `the target language is: scasp.` chooses s(CASP) as soon
as the program loads, and the translator writes that declaration whenever the
original file has abducibles, classical negation or constraints in it. The
editor keeps your choice in the page's web address, as `engine=scasp`.

s(CASP) gives you three things Prolog does not: answers that are constraints
rather than values, several possible worlds for one question, and abduction,
which is the assuming of facts that would make the answer hold. Each world of
an abductive query lists what that world assumes (*assuming tweety is a
penguin*). **Trace** works with Prolog only. A program s(CASP) cannot state is
refused, just as **See s(CASP)** refuses it. The
[s(CASP) reference](../reference/scasp.md) describes the reasoner in full, and
this guide does not repeat what the reference says.

### See PROLOG: the PROLOG Equivalent panel

Logical English is turned into Prolog, and the Prolog engine runs the Prolog.
Put the cursor in a rule, a fact or a scenario fact, right-click, and choose
**See PROLOG**. The **PROLOG Equivalent** panel shows that one clause, with a
**Copy** button:

```
is_a_parent_of(A, B) :-
    le_at(is_the_mother_of(A, B), 1225, 1270).
```

The clause carries the positions of the words in the Logical English document
(`le_at(Goal, Start, End)`), and those positions link each step of an
explanation back to the sentence it came from. The clause is what Logical
English's own reasoner runs, not a Prolog program that would run on its own.
There is no export to Prolog, because Prolog is what Logical English turns
itself into rather than another system to translate to. To use Prolog code
*inside* a program, include a `.pl` resource
([Prolog resources](../reference/language.md#141-prolog-resources-pl)).

## How s(CASP) and Prolog map to Logical English

| s(CASP) or Prolog | Logical English |
|---|---|
| `#pred p(X,Y) :: '@(X:person) is born in @(Y:place)'` | the template `*a person* is born in *a place*`; several wordings of one predicate are synonyms |
| an unannotated predicate | a wording made from its name and the variables of its clauses: `parent(X, Y)` → `*a thing* is the parent of *a second thing*`; `flies(X)` → `*a thing* flies` |
| a fact, a rule | a fact, a rule |
| `not p(X)` (negation as failure) | `it is not the case that` |
| `-p(X)` (classical negation), with `#pred -p(X) :: …` | p's opposite form: `*a thing* can fly; opposite: *a thing* can not fly` |
| `#abducible p(X)` | `; unknown` on the template |
| `:- Body.` or `false :- Body.` | an integrity constraint: `it must not be true that …` |
| `X #> Y`, `#>=`, `#<`, `#=<`, `#<>` | comparisons; `#=` an assignment |
| `?- Goal.` | a query `query_<n>` |
| `is_a/2` | LE's own `is a` |
| a program's own `forall/2` | a universal, `for all cases in which … it is the case that …` |
| LE's s(CASP) helpers `le_forall_K` | the universal again |
| a Prolog built-in goal | a `prolog` goal |
| `[H|T]` patterns | a residue block |
| LE1: `/* Scenario x … % */`, Unix-time dates, `is_days_after/3` | a scenario, ISO dates, `… is … days after …` |

Here is the twin `birds`, from s(CASP)'s own examples:

```le
the target language is: scasp.

the templates are:
    *a thing* is a penguin; opposite: *a thing* is not a penguin.
    *a thing* can fly; opposite: *a thing* can not fly.

a thing can fly if
    the thing is a bird
    and it is not the case that the thing is an ab.

a thing can not fly if
    the thing is an ab.
```

and here is a denial with abducibles, from a small file:

```le
    *a person* votes; unknown; opposite: it is false that *a person* votes.

% Constraint 1 of the source: no case, and nothing assumed, may meet these conditions.
it must not be true that
    a person is an adult
    and the person is a minor.
```

Writing s(CASP) out and reading s(CASP) in are two directions of one and the
same correspondence. Over LE2's examples, going from Logical English to s(CASP)
to Logical English and out to s(CASP) again gives back the very same s(CASP)
program for 83 of the 88 programs s(CASP) can state (14 September 2026;
[§14 of the reference](../reference/scasp.md#14-reading-scasp-back-september-2026)).

## Traps

- **The expected answers need s(CASP) on the server.** The translator works
  each expected answer out by running the original file with SWI-Prolog's
  s(CASP) library. Where the server has no such library, the translator keeps
  each expected answer as a comment, `% pending — s(CASP) did not answer on
  the source (…)`, and a note says that s(CASP) is not installed and how many
  answers are waiting. Write your own `expects answers` lines, or open the file
  on an installation that has s(CASP).
- **Only s(CASP) and Prolog syntax.** Answer Set Programming has several
  dialects, and a `.lp` file in one of the others is not s(CASP). Each
  statement that only clingo understands becomes a `% RESIDUE not_scasp_<n>`
  block, holding the statement's text and its line and counted as residue: a
  choice rule `{a;b}.`, a head offering alternatives `a ; b.`, cardinality
  bounds `1 { … } 1`, `#count` aggregates, ranges `1..n`, weak constraints
  `:~`, and `#const`. Any line the translator cannot read at all goes the same
  way. An expected answer whose query depends on what such a block would
  conclude is left waiting. When a block concludes nothing that can be named at
  all, as a weak constraint or a `#const` does, every expected answer is left
  waiting, because s(CASP) ran without that block. Restate the choices in
  s(CASP) or in Logical English.
- **Wordings built from names read oddly.** `old(X)` becomes `*a thing* is an
  old`, and `s(C)` becomes `*a thing* is a s`. The translator keeps a `#pred`
  wording exactly as written, typos and all (`isafter commencement`), and a
  quoted constant keeps its underscores (`the_UK`). Edit the templates; the
  ledger lists every one of them.
- **Lists.** A clause that takes a list apart is left as residue. Restate the
  clause with an aggregate or with `is in`, or keep the clause in an included
  Prolog resource.
- **Constraint answers are not values.** When s(CASP) answers with a constraint
  such as `A #> 3` rather than with a value, the expected answer is left
  waiting. A Logical English scenario compares answers as pieces of text.
- **The two reasoners treat negation differently.** Negation as failure, which
  Logical English writes `it is not the case that`, and classical negation,
  the opposite form, are two different things. Take a program in which a rule
  negates a conclusion that depends on the rule itself. Run with Prolog, such a
  program may go round in circles or give an unsound answer, where s(CASP)
  works out the stable models instead. The verifier warns about such a program.
  Run it with `the target language is: scasp.`
- **An opposite form in a condition is not a negation.** `the thing can not
  fly` asks for the opposite form to be proved, and some rule has to conclude
  it. The opposite form does not mean the same as `it is not the case that the
  thing can fly`.
- **Constraints were queries before 15 September 2026.** A twin built before
  that date carried a query `denial_<n>` that every scenario expected to have
  no answer. A denial is now an integrity constraint instead: a case whose
  facts meet the constraint answers nothing, and nothing the reasoner assumes
  may meet it either.
- **s(CASP) and Logical English can disagree.** The twin `loanwithcure` is one
  such disagreement, and it arises from the way s(CASP) negates a condition
  that holds an anonymous variable. The twin follows the rules and keeps
  s(CASP)'s answer as a comment, waiting. The twin is never the final word on
  what the rules mean.
- **Constants ending in `_<digits>`.** The s(CASP) library reads `x_1` back as
  `x`, so `x_1` and `x_2` are one and the same individual to s(CASP). Name your
  individuals `person_a` and `person_b` instead.
- **Abducibles with an `is different from` constraint whose values are not yet
  fixed** can be answered unsoundly by the s(CASP) library (version 1.1.4). A
  constraint between values that are already fixed is answered soundly.
- **See s(CASP) refuses rather than approximates.** A program that uses an
  aggregate or a `prolog` goal has no form in s(CASP) at all. Answer such a
  program with the Prolog engine: the two reasoners complement each other.
- **See PROLOG shows one clause, and is not an export.** **See PROLOG** shows
  the clause under the cursor, with the positions of the words it came from.
  Nothing on the menus writes the whole program out as a Prolog file.

## See also

- In this documentation:
  - [s(CASP) on Logical English](../reference/scasp.md): [choosing the engine](../reference/scasp.md#1-choosing-the-engine), [the mapping](../reference/scasp.md#4-le-construct--scasp-mapping), [constraints, worlds and abduction](../reference/scasp.md#5-answers-constraints-multiple-models-abduction), [what is refused](../reference/scasp.md#8-unsupported-constructs--issues-errors), [reading s(CASP) back](../reference/scasp.md#14-reading-scasp-back-september-2026);
  - [Other systems: importing and exporting](index.md): [opening a file](index.md#opening-another-systems-file), [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [refusals](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [Blawx](blawx.md), which generates s(CASP) and has a translator of its own;
  - the language reference: [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [aggregates](../reference/language.md#5-aggregates), [Prolog resources](../reference/language.md#141-prolog-resources-pl), [testing and expectations](../reference/language.md#12-testing-and-expectations);
  - [the editor guide](../guide/editor.md#advanced-features) (the engine picker, See s(CASP), See PROLOG, the debugger);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant), whose residue mode translates residue blocks.
- In the LPS2 IDE: [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- s(CASP)'s and LE1's own documentation:
  - [s(CASP) for SWI-Prolog](https://github.com/SWI-Prolog/sCASP);
  - [LE1, the first Logical English](https://github.com/LogicalContracts/LogicalEnglish).

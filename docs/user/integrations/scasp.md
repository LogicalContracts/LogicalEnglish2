# s(CASP), Prolog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

s(CASP) is a goal-directed reasoner for Answer Set Programming with
constraints. It is used from SWI-Prolog and in Blawx. Its programs look like
Prolog with more: classical negation (`-flies(X)`), abducibles, global
constraints (`false :- …`), constraint comparisons (`#>`), and `#pred`
annotations that say how a predicate reads in English. LE1, the first Logical
English, compiled its documents into such programs. Logical English 2 meets
s(CASP) and Prolog both ways, and the two ways are different in kind. Into
Logical English, **File ▸ Open…** (or **File ▸ Import from Another System…**)
translates a `.pl`, `.scasp` or `.lp` file, LE1's s(CASP) translations
included, into a program. That translator is part of the InsurLE extensions,
available on installations that have them, such as the hosted service. Out of
Logical English there is no export menu, because every installation shows the
program's other forms directly. **See s(CASP)** (a right-click in the editor)
shows the whole program in s(CASP). The **Engine** picker runs a query with
s(CASP) instead of Prolog. **See PROLOG** shows the Prolog clause Logical
English compiles a rule into. Running with s(CASP) needs SWI-Prolog's s(CASP)
pack on the server; the hosted service has it.

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
   must hold Prolog clauses (s(CASP)'s operators allowed), at least one of them
   not a directive.
2. The program opens in a new tab. The note gives the ledger's counts and the
   check against s(CASP), for example *birds: 16 source elements encoded, 0
   approximated, 0 residue; 0 writer errors; the source's own answers
   (s(CASP)): 1 expectations pass, 0 fail, 0 errors.*
3. Each `?-` query of the file becomes a query `query_1`, `query_2`, …, asked
   in every scenario. A file with no scenarios gets one, `the_program`, which
   asks them of the program's own facts. Each expectation is the answer
   s(CASP) gave on the source file.
4. A clause Logical English cannot state becomes a `% RESIDUE … BEGIN`
   block, with the clause verbatim and the reason: the clauses that take a list
   apart, and the statements in clingo's syntax (below, Traps):

   ```le
   % RESIDUE list_pattern_1 BEGIN: a clause that takes a list apart
   % TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
   % Logical English has no list patterns (a list's first element and the rest, [H|T]); a recursive definition over a list is written with an included Prolog resource, or restated with aggregates
   ```

5. **File ▸ Show the Original…** shows the source file, kept in `sources/`,
   which the program cites: `the text of the source program is at
   "sources/…"`. The ledger is `<name>.ledger.md`.
6. Check the templates first. Where the file has `#pred` annotations their
   words are used. Elsewhere a wording is made from the predicate's name
   (`parent(X, Y)` becomes `*a thing* is the parent of *a second thing*`).
   Rename the templates to what the predicates mean.

**Misc ▸ Run the Program's Tests…** then runs the expectations.

A round trip works too. Copy the text of **See s(CASP)** (below) into a
`.scasp` file and open it with **File ▸ Open…**. The rules come back as
Logical English. A rule with `or` comes back as several rules, because the
s(CASP) text splits disjunctions. The scenarios and queries are not in that
text, so they do not come back.

### LE1's s(CASP) translations

LE1 wrote each document as an s(CASP) program with `#pred` annotations, its
scenarios as comment blocks and its queries after the program:

```
/* Scenario alice
is_born_in_on('John', the_UK, 1633737600.0).
...
% */
```

The translator reads all of these. Each scenario, either as a comment block or
as live clauses between `/* Scenario x */` and `/* % */`, becomes a scenario.
A rule inside a scenario becomes a rule of the scenario. LE1's metadata
(`source_lang/1`, the module line, the loader's directives) is left out. LE1's
dates, which are Unix times such as `1633737600.0` in a place typed `date`,
become dates (`2021-10-09`). Its `is_days_after/3`, which LE1 programs call but
do not define, becomes LE2's `*a date* is *a number* days after *a date*`. So an
LE1 program comes into LE2 through its s(CASP) translation, with its scenarios
and with s(CASP)'s answers as the tests:

```le
a person acquires British citizenship on a date if
    the person is born in the_UK on the date
    and the date isafter commencement
    and a second person is a parent of the person
    and the second person is citizen or settled the date.
```

### The example twins

Seventeen programs have been translated. The results, *twins*, are among the
examples under `migration/scasp/`. Open them with **File ▸ Open copy from
server…**:

- LE1's translations (from the s(CASP) pack's tests): `citizenshiptrust`,
  `criminaljustice`, `family_le`, `impossibleancestor` (a rule in a scenario),
  `isdapermissioncorrected` (sentences as values), `itispermittedthat`,
  `list` (its own universal, and a list pattern as residue), `loanwithcure`
  and `obligation` (dates), `minicontract`, `simplerps`, `subset`,
  `turingcomplete` (which needs the InsurLE extensions to load);
- classics of s(CASP)'s own examples: `birds` (classical negation), `family`,
  `classic_negation_inconstistent`, `abdbirds` (abducibles).

Every expectation in them is s(CASP)'s answer on the source. Two are kept as
comments, each with its reason. In `obligation`, s(CASP) answers with a
constraint rather than a value. In `loanwithcure`, s(CASP) says the borrower
defaults, while the program's own cure rule holds on that date; the twin
follows the rules.

### See s(CASP): the program in s(CASP)

Right-click anywhere in the editor and choose **See s(CASP)**. The **PROLOG
Equivalent** panel opens with the whole program as s(CASP) emits it. That is
`#pred` lines from the templates, the rules, classical negation for opposite
forms, `false :- …` for the constraints, and at the end any compile-time
issues as comments. **Copy** copies it. For `birds`:

```
#pred can_fly(A) :: '@(A:thing) can fly'.
...
can_fly(A) :-
    is_a_bird(A),not(is_an_ab(A)).
-can_fly(A) :-
    is_an_ab(A).
```

If the program uses a construct s(CASP) cannot state faithfully (an aggregate,
a `prolog` goal, a decision table, `is in`, date arithmetic, `according to`,
…), no program is shown. The same *Not translated* window as a refused export
lists each problem with its line. The full list is in
[the s(CASP) reference, §8](../reference/scasp.md#8-unsupported-constructs--issues-errors).
There is no **File ▸ Export** to s(CASP): See s(CASP) is the way out.

### The s(CASP) engine

The **Engine** picker beside **Query** chooses Prolog or s(CASP) for the query.
It is shown for every program, or only for programs whose target is not
Prolog (**Misc ▸ ENGINE PICKER**). A program that declares `the target language
is: scasp.` selects s(CASP) when it loads, and the importer writes that
declaration when the source has abducibles, classical negation or constraints.
The choice is kept in the address as `engine=scasp`. s(CASP) adds constraint
answers, possible worlds and abduction: each world of an abductive query lists
what it assumes (*assuming tweety is a penguin*). **Trace** is Prolog only. A
program s(CASP) cannot state is refused, as for See s(CASP). The
[s(CASP) reference](../reference/scasp.md) documents the engine; this guide does
not repeat it.

### See PROLOG: the PROLOG Equivalent panel

Logical English is compiled to Prolog, and the Prolog engine runs that. Put the
cursor in a rule, a fact or a scenario fact, right-click, and choose **See
PROLOG**. The **PROLOG Equivalent** panel shows that one clause, with **Copy**:

```
is_a_parent_of(A, B) :-
    le_at(is_the_mother_of(A, B), 1225, 1270).
```

The clause carries LE's source positions (`le_at(Goal, Start, End)`), which
link each step of an explanation back to the text. It is the clause as LE's
reasoner runs it, not a standalone Prolog program. There is no export to
Prolog: Prolog is LE's own compilation, not a translation. To use Prolog code
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

Here is `birds`, from s(CASP)'s examples:

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

and a denial with abducibles, from a small file:

```le
    *a person* votes; unknown; opposite: it is false that *a person* votes.

% Constraint 1 of the source: no case, and nothing assumed, may meet these conditions.
it must not be true that
    a person is an adult
    and the person is a minor.
```

LE's s(CASP) output and this reader are two directions of one mapping. Over
LE2's examples, LE → s(CASP) → LE → s(CASP) gives back the same s(CASP)
program for 83 of the 88 programs s(CASP) can state (14 September 2026;
[§14 of the reference](../reference/scasp.md#14-reading-scasp-back-september-2026)).

## Traps

- **The expectations need s(CASP) on the server.** The expected answers are
  computed by running the source with SWI-Prolog's s(CASP) library. Without it
  each expectation is kept as a comment, `% pending — s(CASP) did not answer on
  the source (…)`, and a note says that s(CASP) is not installed and how many
  expectations are pending. Write your own `expects answers`
  lines, or open the file on an installation with s(CASP).
- **Only s(CASP) and Prolog syntax.** A `.lp` file in another ASP dialect is
  not s(CASP). Each clingo-only statement (a choice rule `{a;b}.`, a
  disjunctive head `a ; b.`, cardinality bounds `1 { … } 1`, `#count`
  aggregates, ranges `1..n`, weak constraints `:~`, `#const`), and any line
  that does not read, becomes a `% RESIDUE not_scasp_<n>` block with its text
  and line, counted as residue. Expectations whose queries depend on what such
  a block concludes are pending; when a block concludes nothing nameable (a
  weak constraint, a `#const`) every expectation is pending, because s(CASP)
  ran without it. Restate the choices in s(CASP) or Logical English.
- **Wordings made from names read oddly.** `old(X)` becomes `*a thing* is an
  old`, and `s(C)` becomes `*a thing* is a s`. `#pred` wordings are kept as
  written, typos included (`isafter commencement`), and quoted constants keep
  their underscores (`the_UK`). Edit the templates; the ledger lists them.
- **Lists.** A clause that takes a list apart is residue. Restate it with an
  aggregate or `is in`, or keep it in an included Prolog resource.
- **Constraint answers are not values.** When s(CASP) answers with a
  constraint (`A #> 3`) the expectation is pending. LE's scenarios compare
  answers as text.
- **Negation differs between the engines.** Negation as failure
  (`it is not the case that`) and classical negation (the opposite form) are
  different things. With the Prolog engine, a program that loops through
  negation may loop or answer unsoundly, where s(CASP) computes the stable
  models. The verifier warns about such programs. Run them with
  `the target language is: scasp.`
- **Opposite forms are not negation in a condition.** `the thing can not fly`
  proves the opposite form, which must be concluded by a rule. It does not mean
  `it is not the case that the thing can fly`.
- **Constraints were queries before 15 September 2026.** Twins built before
  then had a query `denial_<n>` that every scenario expected to have no answer.
  Denials are now integrity constraints: a case whose facts meet one answers
  nothing, and nothing assumed may meet it.
- **s(CASP) and Logical English can disagree.** In `loanwithcure` they do,
  through s(CASP)'s constructive negation over an anonymous variable. The twin
  follows the rules and keeps s(CASP)'s answer as a pending comment. The twin is
  never the oracle.
- **Constants ending in `_<digits>`.** The s(CASP) library reads `x_1` back as
  `x`, so `x_1` and `x_2` are the same individual to the s(CASP) engine. Name
  individuals `person_a`, `person_b`.
- **Abducibles with a non-ground `is different from` constraint** can be
  answered unsoundly by the s(CASP) library (1.1.4). Ground constraints are
  sound.
- **See s(CASP) refuses rather than approximates.** A program with an aggregate
  or a `prolog` goal has no s(CASP) form. Use the Prolog engine for it: the two
  engines complement each other.
- **See PROLOG is one clause, and not an export.** It shows the clause under the
  cursor, with source positions. Nothing on the menus writes the program as a
  Prolog file.

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

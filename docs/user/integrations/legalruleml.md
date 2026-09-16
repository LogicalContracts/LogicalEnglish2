# LegalRuleML and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

LegalRuleML is an OASIS standard (LegalRuleML Core Specification 1.0, 2021):
an XML language for norms. It extends RuleML with what legal rules need. It has
*constitutive* statements, which define concepts, and *prescriptive* ones, which
state obligations, permissions and prohibitions of a bearer. It has
defeasible rules, defeaters and overrides, reparations and penalties for
violations, links to legal sources, and alternative interpretations. It is a
serialisation: it has no engine, and a document carries no tests. The
integration works both ways. **File ▸ Open…** (or **File ▸ Import from Another
System…**) reads a `.lrml` document, or an `.xml` whose root is
`lrml:LegalRuleML`, into a Logical English program that uses the deontic
library. **File ▸ Export to Another System…** writes a Logical English program
as a LegalRuleML document in the compact serialisation. It refuses, with the
lines, a program that uses what LegalRuleML cannot state. The translators are
part of the InsurLE extensions, so they are available only on installations
that have them, such as the hosted service. The twins of the specification's
examples are in every installation.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a LegalRuleML document](#opening-a-legalruleml-document)
  - [The specification's examples](#the-specifications-examples)
  - [Exporting a program to LegalRuleML](#exporting-a-program-to-legalruleml)
  - [When the export is refused](#when-the-export-is-refused)
  - [Programs in Logical English for LPS: norms](#programs-in-logical-english-for-lps-norms)
- [How LegalRuleML maps to Logical English](#how-legalruleml-maps-to-logical-english)
  - [Defeasibility](#defeasibility)
  - [The way back](#the-way-back)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| LegalRuleML → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.lrml`, or `.xml` with a `lrml:LegalRuleML` root; compact or normalized serialisation | rules, facts, obligations, permissions and prohibitions (the deontic library, `deontic.le`, beside the program), exceptions as conditions, legal sources as documents, a ledger | for the specification's examples: SPINdle's answers (a defeasible deontic logic reasoner) on scenarios drafted from the examples |
| Logical English → LegalRuleML | **File ▸ Export to Another System…** | writes `<program>.lrml` | a Statements block of rules (constitutive or prescriptive, each with its Logical English as the paraphrase), the facts, legal sources, each scenario's facts | the round trip over LE2's English examples: a program exported and opened again gives the same rules, facts and scenario facts |

The LPS2 IDE's **File ▸ Open…** and **Misc ▸ Export to another system…** use
the same translators, when the Logical English installation beside it has them.

## How to use it

### Opening a LegalRuleML document

1. Choose **File ▸ Open…** and pick the `.lrml` file. An `.xml` file is read as
   LegalRuleML when its root element is `lrml:LegalRuleML`. Both serialisations
   of the standard are read alike.
2. The program opens in a new tab, with `deontic.le` beside it. The note gives
   the ledger's counts, for example *ex5_section29new: 13 source elements
   encoded, 0 approximated, 4 residue; 0 writer errors; …*.
3. **File ▸ Show the Original…** shows the document, kept in `sources/`. The
   ledger, `<name>.ledger.md`, lists every element of the document as
   *encoded*, *approximated* (with a note on what changed) or *residue*.
4. A document has no tests, so the program has no scenarios. Write one with
   the facts of a case, and query it. The deontic library's templates answer
   the usual questions:

   ```le
   query prohibitions is:
       which party is forbidden that which sentence.

   query violated_prohibitions is:
       the prohibition of which party that which sentence is violated.

   query breaches is:
       which party is in breach.
   ```

A document you write yourself gets a wording from its relations. The text of a
`ruleml:Rel` element is used when there is one; otherwise a wording is made
from the relation's name (`engageCreditActivity` becomes `*a thing* engages
credit activity`). The ledger marks such a wording as *approximated*: edit the
templates to say what the relation means.

### The specification's examples

The examples of the LegalRuleML Core Specification have been translated. The
results, *twins*, are among the examples under `migration/legalruleml/`. Open
them with **File ▸ Open copy from server…**:

| Twin | What it shows |
|---|---|
| `ex5_section29new` | section 29 of Australia's National Consumer Credit Protection Act 2009: a prohibition, a permission overriding it, penalties, a chain of reparations |
| `ex12_usc_17_504_context` | 17 USC 504 in three historical versions: a prohibition, statutory, increased and reduced damages, overrides |
| `ex3_deontic` | obligations, permissions, reparations, compliance, overrides between statements |
| `ex8_defeasible`, `ex8b_defeasible`, `ex8c_defeasible` | defeaters, strict and defeasible strength |
| `ex9b_alternatives` | alternative readings of one provision |
| `ex1_curies`, `ex2_references`, `ex9_alternatives`, `ex10_mix`, `ex11_maternity_alternatives` | structure only: CURIEs, references, metadata, the Italian maternity benefit's alternatives |

The specification ships no tests, so the scenarios of the twins were written
from the examples' paraphrases and the law they encode. Their expected answers
are SPINdle's on the source document. **Misc ▸ Run the Program's Tests…** shows
that the twins reproduce them. A document of this corpus opened with **File ▸
Open…** gets the same wording and scenarios as its twin.

### Exporting a program to LegalRuleML

1. Open the program, for example `citizenship` or one of the LegalRuleML twins.
2. Choose **File ▸ Export to Another System…**. LegalRuleML is offered for any
   program with a rule or a fact.
3. The window shows the document, with **Copy** and **Save…**. The notes say
   what does not carry over without loss of meaning: *the scenarios' facts are
   exported (Statements blocks `scenario-<name>`); their queries and expected
   answers are not: LegalRuleML has no queries*. The same notes are written
   into the document as `lrml:Comment` elements.
4. The document opens again with **File ▸ Open…**. Each relation's text is its
   Logical English template, so the words come back.

There is no public sandbox for LegalRuleML, so the window has no sandbox button.

### When the export is refused

When the program uses something LegalRuleML cannot state, nothing is written.
The window, *Not translated to LegalRuleML …*, lists each problem with its line
([refusals](index.md#when-an-export-is-refused)). These are refused:

| In the program | Message (abridged) |
|---|---|
| an aggregate (`the count of each …`, `the sum of each …`) | *a rule for "…" uses count/3, which LegalRuleML cannot state* |
| a universal (`for all cases in which …`) | *… uses a universal (for all cases in which)* |
| an `otherwise` cascade | *… uses an otherwise cascade* |
| a decision table | *the decision table …: LegalRuleML has no tables (write its rows as rules to export them)*, with no line |
| an integrity constraint (`it must not be true that …`) | a problem at the constraint |
| a value made of parts (a structured term) | *a structured value (…): LegalRuleML could only name it* |
| any other condition with no LegalRuleML form: `prolog` goals, LE's date built-ins, `according to` | *… uses <name>/<arity>, which LegalRuleML cannot state* |
| a fact it cannot state | *a fact LegalRuleML cannot state: …* |

Two you can reproduce:

- `migration/miniscript/core_2of3_multisig`: its spending rule counts
  signatures. The Miniscript exporter writes the same program.
- `regulatory/eu261_integration`: its decision table `article_7`, and a rule
  whose condition `it is not the case that the cancellation of the flight is
  due to extraordinary circumstances according to the carrier` uses a
  source-scoped proof. The message names `not/1`, the negation around the
  `according to`, and gives the line of the rule's first condition. Negation
  itself is exported, as `Naf`.

### Programs in Logical English for LPS: norms

The translator also has a reading of a program in Logical English for LPS
(`the target language is: lps.`) as norms. A reactive rule becomes an obligation
of the one who acts. A constraint on an action becomes a prohibition of it. A
causal law becomes a constitutive rule from the event to its effect. The
initial state becomes facts. LegalRuleML has no time, so a note would say that
when each norm holds is not carried. The reading refuses what has no norm: a
composite event, a goal, a fluent's default, a constraint relating two actions
or none, a consequence that is not an action.

At the time of writing, neither IDE's export menu offers LegalRuleML for such
a program. The menus list an exporter only when it applies, and the check sees
no timeless rule or fact in an LPS program. For LPS programs the menus offer
Daml. The editor's **Legal View** is another reading of an LPS program as
permissions and effects, in Logical English
([the editor guide](../guide/editor.md#advanced-features)).

## How LegalRuleML maps to Logical English

| LegalRuleML | Logical English |
|---|---|
| `ConstitutiveStatement` | a rule, labelled with the statement's key: `rule ps1:` |
| `FactualStatement` | a fact |
| `PrescriptiveStatement` with `Obligation`, `Permission`, `Prohibition` (a `Right` is a permission) | a rule concluding the library's `*a party* is obliged / permitted / forbidden that *a sentence*`; the party is the `Bearer`, else the one the sentence is about |
| `Naf` | `it is not the case that` |
| `Neg` of a relation a rule concludes | a relation of its own, worded negatively (`*a thing* is not a rel3`) |
| `Neg` of a fact of the case | `it is not the case that` |
| `SuborderList` | a chain: each element is concluded once the one before is violated |
| `Violation`, `Compliance` of a statement | the library's `the obligation (prohibition) of … that … is violated`, `… complies with the obligation that …` |
| `Reparation` with its `PenaltyStatement` | rules concluding the penalty's obligations from the violation it repairs |
| `Override`, defeasible strength, `Defeater` | conditions on the defeated rule (below) |
| `LegalSources`, `References` | documents: `ls1 is published at "http://www.comlaw.gov.au/…"` |
| `Association`, `Context` | the rules of its targets cite the source: `rule ps1 with provenance ls1:` |
| `Paraphrase` | a comment above the rule |
| `Authority`, `Jurisdiction` | a comment in the header |
| `TemporalCharacteristics` (start and end of a status) | `the relevant date is a date D and D is on or after the start and before the end` |
| `Alternatives` | each alternative's rules hold when `the interpretation adopted is` it |

Here is section 29, from `ex5_section29new`. The reparation chain is a rule per
step:

```le
rule ps1:
a party is forbidden that the party engages in a credit activity if
    the party is a person
    and it is not the case that the party holds a credit licence.

rule reparation_1_2:
a party is obliged that the party is imprisoned for 2 years if
    the prohibition of the party that the party engages in a credit activity is violated
    and the obligation of the party that the party pays 200 penalty units is violated.
```

The deontic library (`deontic.le`, included by every program) says when a
statement is violated. An obligation is violated when its sentence is not the
case, and a prohibition when its sentence is the case. A party is in breach
when one of its obligations or prohibitions is violated. The library is also
in LE2's `lib/`
([shipped libraries](../reference/language.md#142-shipped-libraries-lib)), and
any program can include it.

### Defeasibility

Logical English has no defeasible rules, so defeat is written out as
conditions. A defeasible rule that another statement overrides, or attacks
with a conflicting conclusion and no order between them, holds only when the
attacker does not apply. When the attacker is about particular individuals, it
is named, and its conditions are said once. Here is `ex3_deontic`:

```le
rule ps1:
y is forbidden that x is not a rel3 if
    ...
    and it is not the case that the statement ps2_1 applies
    and it is not the case that the statement ps2_2 applies.

% when ps2_1 applies, the rules it overrides or attacks do not
the statement ps2_1 applies if
    ...
```

A defeater concludes nothing of its own. It is a sentence of that form,
`the statement cs2 applies if …`, which the rules it attacks negate. Strict
rules are never attacked. A rule whose strength the document does not give is
defeasible when an Override names it, and strict otherwise. An attacker with
variables (17 USC 504's tiers of damages) keeps its conditions inline in the
exception.

### The way back

The exporter writes each rule as a `ConstitutiveStatement`, or as a
`PrescriptiveStatement` when it concludes an obligation, permission or
prohibition of the library. Each relation is `<ruleml:Rel iri="le:<name>">`
whose text is the template. Conditions are `And`, `Or` and `Naf`. Comparisons
and arithmetic are RIF's built-ins (`pred:numeric-less-than`,
`func:numeric-add`). `is a` becomes `rdf:type`, lists `Plex`, and a sentence
used as a value `Reify`. A rule's label is the statement's key, and its
provenance a `LegalSource` with an `Association`. Each scenario is a
`Statements` block named `scenario-<name>`.

Rules are strict, with one exception: the named form above (`the statement …
applies`). It goes back as an `Override` between defeasible rules, a defeater
as a `Defeater` statement concluding the complement of what it attacks, and
two statements that defeat each other as a conflict with no Override. So a
twin exported and opened again gives the same program.

## Traps

- **A document is not a test suite.** LegalRuleML has no queries and no
  expected answers. A document you open has no scenarios, and the
  specification's twins have scenarios drafted by hand, answered by SPINdle.
- **The closed world of a case.** A fact the scenario does not state is false.
  So `Neg` of an unstated fact holds. SPINdle was run with the same reading, but
  another LegalRuleML consumer may read `Neg` as strong negation that must be
  proved.
- **Defeasibility becomes explicit negation.** The exceptions are `it is not the
  case that` conditions. This gives the same answers as SPINdle on the corpus.
  A cycle of defeats would make the negation non-stratified. The Prolog engine
  may then loop, and the verifier warns
  ([s(CASP)](../reference/scasp.md#1-choosing-the-engine)).
- **Exported rules are strict.** An exception written as a plain `it is not the
  case that` condition goes out as a `Naf` in a strict rule, not as an Override.
  Only the named form (`the statement … applies`) goes back as defeasibility.
- **Queries and expected answers are not exported.** The scenarios' facts are,
  as `Statements` blocks. A scenario fact `X is Y` is test data and is left out,
  with a note.
- **Negation is exported, `according to` is not.** A refusal message that names
  `not/1` may be about a construct inside the negation (a source-scoped proof,
  say). Look inside the `it is not the case that` block at that rule.
- **A decision table's problem has no line.** Find the table by its name. Write
  its rows as rules to export them.
- **LE for LPS programs are not offered.** See
  [above](#programs-in-logical-english-for-lps-norms).
- **Wording of your own documents is naive.** Relations without text are worded
  from their names (`rel1` gives `*a thing* is a rel1`). An individual named
  like a variable (`X`) is lower-cased, since LE would read `X` as a variable.
  A one-letter constant such as `C` comes back as `c` on a round trip.
- **Numbers inside words.** In `ex12_usc_17_504_context` the damages read
  `between $250 and "$10,000"`: a figure with a thousands separator is written
  as quoted text.
- **The specification's examples do not always hold together.** `ex12` names
  rule keys it does not define, so its temporal characteristics and strengths
  apply to nothing (*residue* in the ledger). `ex3` violates a statement `ps0`
  that does not exist (*approximated*). `ex12` misspells a relation in two of
  its three versions. Its `rule0`, an Infringer with no conditions, becomes
  `a person is an infringer.`: everyone is an infringer, faithfully translated.
- **Associations inside a rule** (on an atom or a deontic formula) are not
  carried: LE cites sources per rule (*approximated* in the ledger).
- **Metadata-only documents** (the specification's ex4, ex6, ex7) are read, but
  give no rules.
- **Multi-word constants with `and`** in them come back as texts on a round
  trip, since LE reads a quoted constant as a text.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [opening a file](index.md#opening-another-systems-file), [Show the Original](index.md#show-the-original), [exporting](index.md#exporting-to-another-system), [refusals](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [Bitcoin Miniscript](miniscript.md), the other exporter for timeless programs; [Blawx](blawx.md), whose defeasibility is written as conditions the same way;
  - the language reference: [shipped libraries (deontic.le)](../reference/language.md#142-shipped-libraries-lib), [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance), [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates), [decision tables](../reference/language.md#173-decision-tables), [`according to`](../reference/language.md#175-source-scoped-proof-according-to-in-a-rule), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-);
  - [Logical English for LPS](../reference/lps-target.md).
- In the LPS2 IDE: [the IDE guide](https://lps2.logicalcontracts.com/docs/user/guide/ide), [LE for LPS](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps), [Daml](https://lps2.logicalcontracts.com/docs/user/integrations/daml).
- LegalRuleML's own documentation:
  - [LegalRuleML Core Specification Version 1.0](https://docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/legalruleml-core-spec-v1.0.html) (OASIS Standard, 30 August 2021), with its examples;
  - [the OASIS LegalRuleML Technical Committee](https://www.oasis-open.org/committees/legalruleml/).

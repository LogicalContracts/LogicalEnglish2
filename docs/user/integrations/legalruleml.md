# LegalRuleML and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

LegalRuleML is a published standard for writing legal rules down (LegalRuleML
Core Specification 1.0, 2021, from the OASIS standards body). A LegalRuleML
document is written in XML, a way of marking up text so that a program can read
it. LegalRuleML adds to an older rule language, RuleML, the things legal rules
need. LegalRuleML has *constitutive* statements, which define concepts, and
*prescriptive* statements, which state the obligations, permissions and
prohibitions of a bearer, the party who must, may or may not do something.
LegalRuleML also has defeasible rules, which another rule may override; it has
defeaters and overrides, reparations and penalties for violations, links to
legal sources, and alternative readings of one provision. LegalRuleML is only a
way of writing rules down. Nothing runs a LegalRuleML document, and a document
carries no tests of its own.

Logical English both reads LegalRuleML and writes it. **File ▸ Open…** (or
**File ▸ Import from Another System…**) reads a `.lrml` document, or an `.xml`
document whose outermost element is `lrml:LegalRuleML`, and turns the document
into a Logical English program. The program uses the deontic library, the set of
sentences that ships with Logical English for speaking about obligations,
permissions and prohibitions. **File ▸ Export to Another System…** writes a
Logical English program back out as a LegalRuleML document, in the shorter of
the standard's two layouts. When the program says something LegalRuleML cannot
say, the editor refuses to write the document and reports each problem with the
line it is on. Both translators are part of the InsurLE extensions, so only
installations that have the extensions, such as the hosted service, offer them.
The translations of the specification's own examples, called *twins*, come with
every installation.

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

The LPS2 IDE — the integrated development environment, or editor, for LPS
(Logic Production System) — has the same two menu items, **File ▸ Open…**
and **Misc ▸ Export to another system…**. Those items use these same two
translators whenever the Logical English installation beside the LPS2 editor
has them.

## How to use it

### Opening a LegalRuleML document

1. Choose **File ▸ Open…** and pick the `.lrml` file. The editor reads an
   `.xml` file as LegalRuleML when the file's outermost element is
   `lrml:LegalRuleML`. The standard allows two layouts for a document, and the
   translator reads both alike.
2. The program opens in a new tab, with the deontic library `deontic.le` beside
   it. A note gives the counts from the ledger, the record of how each piece of
   the document was translated — for example *ex5_section29new: 13 source
   elements encoded, 0 approximated, 4 residue; 0 writer errors; …*.
3. **File ▸ Show the Original…** shows the LegalRuleML document itself, which
   the editor keeps in the program's `sources/` folder. The ledger,
   `<name>.ledger.md`, lists every element of the document as *encoded*
   (translated with its meaning intact), *approximated* (translated, with a
   note on what changed) or *residue* (not translated).
4. A LegalRuleML document holds no tests, so the new program has no scenarios.
   Write a scenario yourself, holding the facts of a case, and then ask the
   program a question. The deontic library's templates answer the usual
   questions:

   ```le
   query prohibitions is:
       which party is forbidden that which sentence.

   query violated_prohibitions is:
       the prohibition of which party that which sentence is violated.

   query breaches is:
       which party is in breach.
   ```

A document you wrote yourself gets its English wording from the relations in it.
Where a `ruleml:Rel` element carries text, the translator uses that text. Where
it carries none, the translator builds a wording out of the relation's name, so
that `engageCreditActivity` becomes `*a thing* engages credit activity`. The
ledger marks a wording built that way as *approximated*. Edit those templates
so that they say what the relation really means.

### The specification's examples

The examples of the LegalRuleML Core Specification have all been translated
already. The translated programs, the twins, sit among the examples under
`migration/legalruleml/`. Open a twin with **File ▸ Open example from
server…**:

| Twin | What it shows |
|---|---|
| `ex5_section29new` | section 29 of Australia's National Consumer Credit Protection Act 2009: a prohibition, a permission overriding it, penalties, a chain of reparations |
| `ex12_usc_17_504_context` | 17 USC 504 in three historical versions: a prohibition, statutory, increased and reduced damages, overrides |
| `ex3_deontic` | obligations, permissions, reparations, compliance, overrides between statements |
| `ex8_defeasible`, `ex8b_defeasible`, `ex8c_defeasible` | defeaters, strict and defeasible strength |
| `ex9b_alternatives` | alternative readings of one provision |
| `ex1_curies`, `ex2_references`, `ex9_alternatives`, `ex10_mix`, `ex11_maternity_alternatives` | structure only: CURIEs, references, metadata, the Italian maternity benefit's alternatives |

The specification comes with no tests, so the scenarios in the twins were
written by hand, from the plain-English paraphrases in the examples and from
the law the examples encode. The answer each scenario expects is the answer
SPINdle gives on the original document; SPINdle is a reasoner for defeasible
deontic logic, that is, for rules about duties that other rules can override.
**Misc ▸ Run the Program's Tests…** shows that the twins give those same
answers. Open one of the specification's documents yourself with **File ▸
Open…** and you get the same wording and the same scenarios as its twin.

### Exporting a program to LegalRuleML

1. Open the program, for example `citizenship` or one of the LegalRuleML twins.
2. Choose **File ▸ Export to Another System…**. LegalRuleML is offered for any
   program with a rule or a fact.
3. A window shows the document, with **Copy** and **Save…** buttons. Notes in
   the window say what does not carry over with its meaning intact. The first
   note says: *the scenarios' facts are exported (Statements blocks
   `scenario-<name>`); the queries (flip queries included) and expected answers
   are not: LegalRuleML has no queries*. Further notes cover three more things.
   A `; judged` or assumable template leaves an instance the case does not
   state open in Logical English, where a program reading the LegalRuleML
   document would take the same instance as false. The provenance trailers,
   which say where a fact came from, are the second. The sections of the
   decision skeleton are the third. None of those three changes what the rules
   conclude from the facts the case states. The exporter also writes the same
   notes into the document itself, as `lrml:Comment` elements.
4. Open the exported document again with **File ▸ Open…**. The exporter writes
   each relation's text as the Logical English template it came from, so the
   original wording comes back.

No public web site runs LegalRuleML documents, so this window offers no button
for trying the document out elsewhere.

### When the export is refused

When the program says something LegalRuleML cannot say, the editor writes no
document at all. A window headed *Not translated to LegalRuleML …* lists each
problem beside the line it is on
([refusals](index.md#when-an-export-is-refused)). The editor refuses these:

| In the program | Message (abridged) |
|---|---|
| an aggregate (`the count of each …`, `the sum of each …`) | *a rule for "…" uses count/3, which LegalRuleML cannot state* |
| a universal (`for all cases in which …`) | *… uses a universal (for all cases in which)* |
| a decision table | *the decision table …: LegalRuleML has no tables (write its rows as rules to export them)*, at the table's line |
| an integrity constraint (`it must not be true that …`) | a problem at the constraint |
| a template answered by a service (`; via service …`), or a built-in semantic template | *the template "…" is answered by the service … at run time: LegalRuleML has no services*, at the template's line; *… uses a semantic template answered by a service*, at the condition |
| a value made of parts (a structured term) | *a structured value (…): LegalRuleML could only name it* |
| `according to` in a condition (a source-scoped proof), also inside `it is not the case that` | *… uses `according to` (who holds a condition true), which LegalRuleML cannot state*, at the `according to` |
| any other condition with no LegalRuleML form: `prolog` goals, LE's date built-ins | *… uses <name>/<arity>, which LegalRuleML cannot state*, at that condition |
| a fact it cannot state | *a fact LegalRuleML cannot state: …*, at the fact |
| in a program for LPS, a fluent's default (`; 0 by default`) | *a fluent's default value: LegalRuleML has no defaults*, at the template |

Two refusals you can reproduce for yourself:

- `migration/miniscript/core_2of3_multisig`: its spending rule counts
  signatures. The Miniscript exporter writes the same program.
- `regulatory/eu261_integration`: its decision table `article_7`, and a rule
  whose condition `it is not the case that the cancellation of the flight is
  due to extraordinary circumstances according to the carrier` uses a
  source-scoped proof, which is a proof that holds only for the party named.
  The message names the `according to` and points at the line the `according
  to` is on; the message about the table points at the table's own line. Plain
  negation is exported, as `Naf`. The problem reported is always the innermost
  piece that LegalRuleML cannot state.

### Programs in Logical English for LPS: norms

The translator can also read a program written in Logical English for LPS as a
set of norms; such a program begins `the target language is: lps.`. A reactive
rule becomes an obligation of the one who acts. A constraint on an action
becomes a prohibition of that action. A causal law becomes a constitutive rule
leading from the event to its effect. The initial state becomes facts.
LegalRuleML says nothing about time, so a note points out that when each norm
holds is not carried over. The translator refuses whatever has no norm to
correspond to: a composite event, a goal, a fluent's default value, a
constraint relating two actions or none at all, and a consequence that is not
an action.

Both editors offer LegalRuleML for such a program, whenever the program has
something besides declarations to read as norms. In the LPS2 editor the menu
item is **Misc ▸ Export to another system…**, beside Daml. The **Legal View**
is a second way of reading an LPS program: the Legal View shows the program's
permissions and effects in Logical English
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

Here is section 29, from the twin `ex5_section29new`. The chain of reparations
becomes one rule for each step:

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

The deontic library, `deontic.le`, which every translated program includes,
says when a statement is violated. An obligation is violated when its sentence
is not the case. A prohibition is violated when its sentence is the case. A
party is in breach when one of that party's obligations or prohibitions is
violated. The same library sits in LE2's `lib/` folder
([shipped libraries](../reference/language.md#142-shipped-libraries-lib)), and
any program at all can include the library.

### Defeasibility

Logical English has no defeasible rules, so the translator writes defeat out as
ordinary conditions. Take a defeasible rule that another statement overrides,
or that another statement attacks by concluding the opposite with no order
settled between the two. Such a rule holds only when the attacking statement
does not apply. When the attacking statement speaks about particular
individuals, the translator gives the statement a name and states its
conditions once. Here is the twin `ex3_deontic`:

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

A defeater concludes nothing of its own. A defeater is written in that same
shape, `the statement cs2 applies if …`, and every rule the defeater attacks
carries the negation of that sentence. Strict rules are never attacked. Where
the document does not say how strong a rule is, the translator makes the rule
defeasible if an Override names it, and strict otherwise. An attacker that
speaks about variables rather than named individuals — the tiers of damages in
17 USC 504, for instance — keeps its conditions inside the exception itself.

### The way back

Going the other way, the exporter writes each rule as a
`ConstitutiveStatement`. A rule that concludes an obligation, a permission or a
prohibition of the deontic library becomes a `PrescriptiveStatement` instead.
Each relation becomes `<ruleml:Rel iri="le:<name>">`, whose text is the Logical
English template. Conditions become `And`, `Or` and `Naf`.

A negation may bring in a variable of its own, one that nothing earlier in the
rule has already fixed. Such a negation becomes `Naf` of an `Exists` that
declares the variable. The reason is that a rule's variables otherwise range
over the whole rule: a bare `Naf(p(X1, X2))` would read "for some X2, not p",
whereas `it is not the case that` means "for no X2".

An `otherwise` cascade (`A otherwise B`) goes out as the form Logical English
itself turns the cascade into, `Or(A, And(Naf(A), B))`, with each guard given
the same treatment as the negation above. The paraphrase still shows the `otherwise`, and the document
opens again as the same rule. Comparisons and arithmetic become the built-in
operations of RIF, the Rule Interchange Format (`pred:numeric-less-than`,
`func:numeric-add`). `is a` becomes `rdf:type`, a list becomes a `Plex`, and a
sentence used as a value becomes a `Reify`. A rule's label becomes the
statement's key, and the source the rule cites becomes a `LegalSource` with an
`Association`. Each scenario becomes a `Statements` block named
`scenario-<name>`.

Exported rules are strict, with one exception: the named form shown above,
`the statement … applies`. The named form goes back out as an `Override`
between defeasible rules. A defeater goes back as a `Defeater` statement, which
concludes the opposite of what the defeater attacks. Two statements that defeat
each other go back as a conflict with no Override. A twin exported and then
opened again therefore gives back the same program.

## Traps

- **A document is not a test suite.** LegalRuleML has no queries and no
  expected answers. A document you open therefore arrives with no scenarios.
  The specification's twins do have scenarios, written by hand, whose expected
  answers come from SPINdle.
- **The closed world of a case.** A fact the scenario does not state is false.
  So `Neg` of a fact nobody stated holds. SPINdle was run with that same
  reading, but another program that reads LegalRuleML may take `Neg` as strong
  negation, which has to be proved rather than merely left unstated.
- **Defeasibility becomes explicit negation.** The exceptions come out as
  `it is not the case that` conditions. Writing the exceptions that way gives
  the same answers as SPINdle over the whole set of examples. A cycle of
  defeats, where a rule defeats a rule that defeats it back, would leave the
  negation non-stratified: the rules could no longer be put in layers where
  each layer only negates a layer below. The Prolog engine may then run round
  in circles, and the verifier warns about such a program
  ([s(CASP)](../reference/scasp.md#1-choosing-the-engine)).
- **Exported rules are strict.** An exception written as a plain `it is not the
  case that` condition goes out as a `Naf` in a strict rule, not as an Override.
  Only the named form (`the statement … applies`) goes back as defeasibility.
- **Queries and expected answers are not exported.** The scenarios' facts are
  exported, as `Statements` blocks. A scenario fact of the form `X is Y` is
  test data rather than a fact of the case, so the exporter leaves that fact
  out and says so in a note.
- **Negation is exported, `according to` is not.** When a rule's `it is not the
  case that` block holds an `according to`, the editor refuses the export at
  the `according to`.
- **An `otherwise` cascade that sets an output** (`… and the rate is 20`)
  is refused, but the refusal is about the assignment (`le_is/2`), not about
  the cascade. An alternative that only tests conditions is exported.
- **A decision table is refused whole.** Write its rows as rules to export them.
- **Wording of your own documents is naive.** The translator words a relation
  that carries no text from the relation's name, so `rel1` gives `*a thing* is
  a rel1`. An individual named like a variable, `X`, is written in lower case,
  because Logical English would otherwise read `X` as a variable. So a
  one-letter constant such as `C` comes back as `c` when the document is
  exported and opened again.
- **Numbers inside words.** In `ex12_usc_17_504_context` the damages read
  `between $250 and "$10,000"`: a figure with a thousands separator is written
  as quoted text.
- **The specification's examples do not always hold together.** `ex12` names
  rule keys that `ex12` itself never defines, so its temporal characteristics
  and its strengths apply to nothing (*residue* in the ledger). `ex3` violates
  a statement `ps0` that does not exist (*approximated*). `ex12` misspells a
  relation in two of its three versions. The `rule0` of `ex12`, an Infringer
  with no conditions at all, becomes `a person is an infringer.` — everyone is
  an infringer, faithfully translated.
- **Associations inside a rule**, on an atom or on a deontic formula, are not
  carried over. Logical English cites a source once per rule, so the ledger
  marks such a rule *approximated*.
- **Documents that hold only metadata** — the specification's ex4, ex6 and ex7,
  which describe the document rather than state rules — are read, but give no
  rules.
- **Multi-word constants with `and`** in them come back as pieces of text when
  the document is exported and opened again, because Logical English reads a
  quoted constant as text.

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

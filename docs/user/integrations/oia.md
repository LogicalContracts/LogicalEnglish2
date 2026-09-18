# Oracle Intelligent Advisor and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Oracle Intelligent Advisor (OIA, formerly Oracle Policy Automation) is
Oracle's product for writing eligibility and entitlement rules in Word and
Excel documents, compiling them into a rulebase, and serving interviews and
determinations from it. The editor translates an OIA project into Logical
English: the rules as rules, in the words of the Word documents, with their
rule tables as decision tables, the project's Excel test cases as scenarios,
and an interview as a view. The translation goes one way only, from OIA into
Logical English; there is no exporter back to OIA. It is reached through
**File ▸ Open…** or **File ▸ Import from Another System…**, and needs the
InsurLE extensions, which installations such as the hosted service have.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original](#show-the-original)
  - [Examples to try](#examples-to-try)
- [How OIA maps to Logical English](#how-oia-maps-to-logical-english)
  - [Roles of the global entity](#roles-of-the-global-entity)
  - [Rule tables](#rule-tables)
  - [Entities](#entities)
  - [Tests, or the analysis of the rules](#tests-or-the-analysis-of-the-rules)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| OIA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | a compiled rule document (`<doc>.docx.xgen`); a deployed `rulebase.xml`, with its `rulebase.stxt`; a `.zip` of a Policy Modeling project folder or of a deployed rulebase | a program with templates, rules citing the Word document and paragraph, decision tables, scenarios, queries and an interview view; a migration ledger; the documents' paragraphs in `sources/` | the project's Excel test cases (whose results Policy Modeling records in `testResults.xml`); for a project with no test files, an evaluator of the OIA rules with OIA's own semantics |

## How to use it

### What to upload

The translator reads OIA's compiled forms, not the Word or Excel documents
themselves:

- **One rule document.** Policy Modeling compiles each Word or Excel rule
  document into `bin/<Document>.docx.xgen`. Upload that file. It carries the
  sentences as authored, Oracle's parse of each sentence, the rules with their
  levels, and the document's paragraphs.
- **A deployed rulebase.** Upload `rulebase.xml`. Zip it together with
  `rulebase.stxt` if you have it: the `.stxt` holds each attribute's authored
  sentence forms (the negative form and the interview question). An `.xml`
  file is taken as a rulebase when its root element is `rulebase`, whatever
  its name.
- **A whole project.** Zip the Policy Modeling project folder: the `.xprj`,
  the `bin` folder with its `.xgen` files, `projectDataModel.xml` (the types
  of the attributes), the Excel test files and `testResults.xml`. The zip may
  hold the folder itself or its contents. Compile the project in Policy
  Modeling first: a project without `.xgen` files is refused with a message
  saying so.

Excel test files are read only when the server has `python3` with the
`openpyxl` package. Without it they are skipped, and the note says how many.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the file.
2. The server recognises the material as OIA's, translates it and opens the
   program in a new tab. The program's name comes from the project (its
   `.xprj`, its folder, or the uploaded file): `Synthetic Rules.docx.xgen`
   opens as `synthetic_rules.le`.
3. A note under the menu bar says that the Oracle Intelligent Advisor
   translator was used, and gives the translator's counts (below). Close it
   with its `×`.

The upload and its translation are kept on the server for a day. Save the
program with **File ▸ Save As…** to keep it. The general behaviour of
importing is described in [Opening another system's file](index.md#opening-another-systems-file).

### The note and the ledger

The note reads, for instance:

```
ledger: 8 encoded, 1 approximated, 0 residue (TODO in the program)
10 scenario(s) generated from the rules' own analysis (no test files)
the scenarios run: 20 pass, 0 fail, 0 error
approximated: OIA's unknown and uncertain states are read with LE's closed world (see the ledger)
```

- The **ledger** is written beside the program as `<name>.ledger.md` (and
  `.json`). It has one row per source element: each attribute, role, entity,
  rule and test file. Each row says whether the element was *encoded* (its
  meaning unchanged), *approximated* (with a note on how the meaning changed)
  or left as *residue*. The ledger also lists every source expectation with
  its outcome, so a failure there shows what was expected and what came
  instead.
- A note may also say that `rulebase.stxt` was not uploaded (the sentences
  are then the rulebase's own text, without authored negative forms or
  questions), that Excel test files were not read, or that a rule document
  could not be read.

### Running the translation

The result is an ordinary Logical English program. Pick a scenario and a
query and run it, as for any program. Each step of an explanation cites the
rule's Word document and paragraph, and the § badge opens the paragraph.

- **Misc ▸ Run the Program's Tests…** runs every expectation of the
  scenarios and lists each, failures first.
- The **interview** view (`the view interview is: …`) asks the facts of the
  case one at a time, only those the result still depends on, and gives the
  top conclusion with its reasons and what would change it. Open it from the
  editor or the executive view; see [Views](../tutorials/views.md).

### Show the Original

**File ▸ Show the Original…** lists the files in the program's `sources/`
folder. For an `.xgen` or a project, that folder holds the text of each rule
document, one paragraph per line; the rules' `confer "…"` citations quote
it. For a rulebase, which has no Word text, it holds the uploaded files.

### Examples to try

Five translated OIA projects are among the lpsPlus examples, visible only on
installations that have them, to users with access. Open them with **File ▸
Open example from server…**:

- `lpsPlus/migration/oia/warranty_claims`: three rules, the smallest;
- `lpsPlus/migration/oia/mom_paternity_leave`: Singapore's Government Paid
  Paternity Leave, with mixed `and`/`or` levels and date arithmetic;
- `lpsPlus/migration/oia/gst_at_settlement`: five Word documents of
  Australian GST withholding, with 55 Excel test cases;
- `lpsPlus/migration/oia/vibect`: a deployed rulebase with a 383-row rule
  table and 97 Excel test cases;
- `lpsPlus/migration/oia/dctad`: a deployed rulebase with entities and five
  rule tables.

Each comes with its ledger and its `sources/` folder. The public projects
they come from state no licence, so the twins are not published elsewhere.

## How OIA maps to Logical English

| OIA | Logical English |
|---|---|
| a boolean attribute of the global entity | a template; `; opposite:` when a rule concludes it false; `; scenario element` when no rule concludes it: `*a customer* is a gold member; scenario element.` |
| a value attribute | a template with a place for the value: `the fee is *a fee*.`; `the value of … is …` when the text begins with a word Logical English reserves (`the value of the contract price is a price P`) |
| a role of the global entity ("the claim", "the Father") | a typed place of the templates that speak about it, and a named constant standing for the case's one individual: `the constants are:` with `the Father is "the Father".` |
| a rule `… if` with conditions | a rule, labelled and cited: `rule warranty_claims_intro_rules_r0 with provenance "Warranty Claims (Intro) Rules.docx", confer "The claim is covered by warranty if":` |
| Word levels mixing `and` and `or` | a numbered outline, as the Word document shows it: `5. either:` / `5.1. …; or` / `5.2. …` |
| the automatic *otherwise false* | negation as failure: what no rule concludes is false |
| `not` | `it is not the case that …` (approximated) |
| a value conclusion `the fee = the price * 0.07` | relational arithmetic, decimals as fractions: `the price is a price P and F = P * 7 / 100` |
| `otherwise <value>` | an `otherwise` alternative: `otherwise F is equal to 0.` |
| a rule table whose cells are all attribute = constant | a decision table `with first match`; the `Else` row becomes an `any` row |
| a rule table of other shapes (expressions in cells) | an `otherwise` cascade, rows in order |
| a citation written before a line (`[s 6]`) | a comment on the rule: `% cites: s 6; s 9; …` |
| `add-months`, `add-years`, `add-days` | the shipped `temporal` library, copied beside the program: `a later date L is -3 calendar months after the second date` |
| `current-date` | case data: `the current date is *a date*; scenario element.` |
| `known(x)`, `unknown(x)` | for a value, `x is a value` and its negation; for a boolean, `x` or its opposite form, and the negation of that (approximated) |
| `uncertain(x)` | `it is uncertain whether x`, a fact a test states (approximated) |
| an `Error("…")` or `Warning` event | `the rulebase raises the error "The purchaser cannot be under 18 years of age" if …` |
| an entity with an identifying attribute | an instance is its identifying value: `*a code* identifies the error.` |
| a table that infers entity instances | a rule whose rows are alternatives (each matching row adds an instance), and a query listing them |
| an Excel test case | a scenario `as stated in "Witholding_Amount.xlsx" at test case 1:` with the inputs as facts and the expected values as `expects answers` |
| the interview | a view: the attributes no rule concludes, asked one at a time; the top conclusion as the result |
| a rule the translator cannot map | a `% RESIDUE` block holding the rule's XML |

### Roles of the global entity

OIA's rules about one case speak of its people and things by name: "the
Father", "the Child", "the claim". A phrase that Oracle's parse gives as the
subject of two or more attributes becomes a **role**. The templates get a
typed place for it, and a named constant (the language reference §2.2) says
which individual of the case it is, so the rules keep reading as written:

```le
the constants are:
    the Father is "the Father".
```

A sentence a rule concludes in its negative form, or one that would read
like another role's once the role is a place, keeps its words. Roles are
found only in `.xgen` documents, since a rulebase's `.stxt` has no parse.

### Rule tables

A decision table is named after what it concludes, and its columns after the
attributes it tests and concludes:

```le
the table notification_type_table is, with first match, with provenance "rulebase.xml":
    row  | branch id | country match flag | business event type    | notification type
    r1   | 20        | "Y"                | "CHARGE_CLFEE"         | "Alert"
```

The rules that read it say `table notification_type_table for … gives …`.
A table whose cells hold conditions or expressions becomes an `otherwise`
cascade instead, in the order of its rows. See
[Decision tables](../reference/language.md#173-decision-tables) and
[`otherwise` cascades](../reference/language.md#172-otherwise-cascades).

### Entities

An instance of an entity is written as its identifying value, and entity
attributes as templates with a place for the instance:
`the aggregation decision flag of a decision is a flag if the decision
identifies the aggregation decision details and …`. A table that infers
instances (a relationship) adds one instance per matching row.

### Tests, or the analysis of the rules

A project with Excel test files gets one scenario per test case. Inputs are
facts (a `false` input only when the sentence has an opposite form), and
expected values are `expects answers` lines; an expected false, `(unknown)`
or `(uncertain)` is an empty answer.

A project with no test files gets scenarios from **the analysis of its
rules**: for each goal, each way the rules reach it, and its near misses (one
input changed so that its condition fails). Their expected outcomes are
computed by an evaluator of the OIA rules with OIA's semantics, not by the
translated program, so the two are checked against each other. The evaluator
computes in decimal, as OIA does, and writes each expected number as Logical
English prints it: a whole number without a decimal point (`the fee is 70`). Such
scenarios say `as stated in the analysis of the rules`.

## Traps

- **Unknown is false.** OIA has three values: an input nobody answered is
  *unknown*, and unknown propagates. Logical English reads the case with a
  closed world: an unanswered input is false, and a conclusion that would be
  unknown is not derived. The ledger marks every rule whose meaning this can
  change (`not`, not-equals, `known`/`unknown`, `uncertain`, the current date)
  as *approximated*. On the published GST project it costs one expectation in
  207: a test whose "between associates" question is unanswered, where OIA's
  rule table stops and the translation falls through to the `Else` row. In the
  example it is kept as a *pending* expectation, a comment in its scenario;
  in your own import such a test simply fails.
- **Uncertain is a fact.** `uncertain(x)` becomes a template `it is uncertain
  whether x` that a scenario must state. Nothing derives it.
- **No temporal reasoning.** The current date is case data. Change points,
  `ValueAt`, `WhenLast` and interval sums are not translated; a rule that uses
  them is residue.
- **Not read:** `.tsc` test scripts, Excel entity-instance sheets, interview
  screens (`.xint`: the view is generated from the rules instead), and the
  Word and Excel documents themselves (only their compiled `.xgen`).
  Entity-level conclusions in Word, `ForAll`/`Exists`/`InstanceCount` over
  relationships, and relationship-valued inputs would be residue.
- **The words change a little.** Sentences are kept as written, but made
  safe for Logical English: punctuation is dropped, `%` becomes `percent`,
  `/` becomes `or`, and words Logical English reserves are replaced (`if`
  becomes `in case`; `unless`, `either`, `otherwise`, `only if`, `any of`,
  `all of` likewise). Look for `the value of …` prefixes where a sentence
  began with a section word such as `the contract`.
- **Typos and oddities are faithful.** The translation does not correct the
  rulebase: "the product is faculty", "have been engaged", Word headings that
  Policy Modeling compiled as unconditional conclusions (kept as facts), and
  a condition that repeats what its sub-levels define all come through as
  OIA compiled them.
- **A document that cannot be read** does not stop the import: it becomes a
  TODO comment holding the start of its XML, and its rules are missing from
  the program. The note says how many.
- **Without `rulebase.stxt`** a rulebase has no authored negative forms and
  no interview questions.
- **Only one project per upload.** A zip is read as one project. Its `out`
  folder and `__MACOSX` entries are ignored.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md), including
    [what could not be translated](index.md#what-could-not-be-translated) and
    [Show the Original](index.md#show-the-original)
  - [Decision tables](../reference/language.md#173-decision-tables),
    [`otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [the `temporal` library](../reference/language.md#142-shipped-libraries-lib),
    [testing and expectations](../reference/language.md#12-testing-and-expectations)
  - [LE Views](../tutorials/views.md), for the interview
  - [The assistants](../guide/assistants.md#the-contract-assistant): the Contract
    Assistant's *Migration residue* mode translates residue blocks
- Oracle Intelligent Advisor's own documentation:
  [Oracle Intelligent Advisor](https://docs.oracle.com/en/cloud/saas/intelligent-advisor/index.html)

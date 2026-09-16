# Oracle Insurance Policy Administration and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Oracle Insurance Policy Administration (OIPA) is Oracle's system for
administering life, annuity and health policies. Its products are configured,
not programmed: in the Rules Palette, a *transaction* (a deposit, a
withdrawal, an issue) is an XML document whose Math section computes values
from the activity's fields, the policy and the plan, and whose attached
business rules validate the activity, spawn other transactions and copy
values back to the policy. The editor translates one transaction's XML into
Logical English: one rule per MathVariable, citing it, with rate lookups as
decision tables and a view that prices an activity. The translation goes one
way only, from OIPA into Logical English; there is no exporter back to OIPA.
It is reached through **File ▸ Open…** or **File ▸ Import from Another
System…**, and needs the InsurLE extensions, which installations such as the
hosted service have.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original](#show-the-original)
  - [Examples to try](#examples-to-try)
- [How OIPA maps to Logical English](#how-oipa-maps-to-logical-english)
  - [The activity, the policy it finds and the plan](#the-activity-the-policy-it-finds-and-the-plan)
  - [Reassignment and MathIF](#reassignment-and-mathif)
  - [Rates](#rates)
  - [Checks, spawns and copies](#checks-spawns-and-copies)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| OIPA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | one transaction's Rules Palette XML (`.xml`, root element `<Transaction>` with a `Math` or `Fields` section) | a program with a template per field and MathVariable, a rule per MathVariable citing it, decision tables for rates, queries for the logged values, a view; a migration ledger; the XML in `sources/` | for the example twins, an independent interpreter of OIPA transaction math playing each plan's policy lives; an uploaded transaction has no tests |

## How to use it

### What to upload

Upload the XML of one transaction, as the Rules Palette shows it: a
`<Transaction>` element with its `<Fields>` and its
`<Math>`/`<MathVariables>`. The file name becomes the transaction's name
(`Withdrawal.xml` gives the transaction `Withdrawal`). A file called
`Transaction.xml` has no name of its own, and becomes `Transaction1`; rename
the file before uploading it.

Only `.xml` is read. A zip of a plan folder is not recognised as OIPA
material, and neither are the attached rules on their own
(`ValidateExpressions.xml`, `SpawnActivities.xml`,
`CopyToPolicyFields.xml`), whose root is not a `<Transaction>`.

Several translators read `.xml` (Oracle Intelligent Advisor, LegalRuleML,
OIPA). Each looks at the file, and the OIPA translator takes it when its root
is a `<Transaction>` element.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the transaction's `.xml` file.
2. The server translates it and opens the program in a new tab, named
   `oipa_<transaction>.le` (for instance `oipa_withdrawal.le`).
3. A note under the menu bar names the translator (*Oracle Insurance Policy
   Administration transaction (Rules Palette XML)*) and gives the counts.

The upload and its translation are kept on the server for a day. Save the
program with **File ▸ Save As…** to keep it.

### The note and the ledger

The note reads, for example:

```
oipa_withdrawal: 16 MathVariables and rules encoded, 0 approximated, 0 residue; 0 writer errors. Attached rules (ValidateExpressions, SpawnActivities, CopyToPolicyFields) are read when they sit beside the transaction in a plan directory.
```

The ledger, `oipa_<transaction>.ledger.md`, is written beside the program.
It has one row per MathVariable (and, in the example twins, per validation,
spawn and copy), with the mapping used: `FIELD -> the activity field
GrossAmount, a fact of the case`, `RATE -> a decision table loaded from the
plan's rates, DEFAULT as the last line`, and so on. A row marked
*approximated* says how the meaning changed. Something the translator could
not read is a ledger row of kind `note`, also marked *approximated*, such as
`a MathVariable of TYPE SQL is not translated`.

The last sentence of the note concerns the example twins, which were
translated from plan folders. An upload through the editor is one file, so
its attached rules are not read: the program has no checks, spawns or copies
(see [Traps](#traps)).

### Running the translation

An uploaded transaction comes with no scenarios. Until you add one, the
verifier warns that the activity's and the policy's fields (such as
`the_gross_amount_of_is/2`) are undefined; this is expected, since they are
the facts of a case. Write a scenario that gives the activity's fields, its
effective date and the policy it finds, as the example twins do:

```le
scenario steady_saver_w1 is:
    the gross amount of w1 is 10000.
    the effective date of w1 is 2022-06-01.
    the account value of the policy before w1 is 168836.850000000005821.
    the issue date of the policy before w1 is 2020-03-15.
```

Then run a query. The translator writes one query per MathVariable marked
`LOG="Yes"` (`query net_amount is: the net amount of which activity is which
amount.`), and, when there are attached rules, `checks`, `spawns` and one
`policy_after_…` query per copied field. The explanation of an answer follows
the math: the net amount because of the gross amount and the surrender
charge, the surrender charge because of the policy year, down to the fields.

The view (`the view withdrawal is: …`) is a test activity: the activity's
fields and the policy it finds as inputs, the first logged value as the
result, the checks listed, and one citation per MathVariable. Open it from
the editor or the executive view (see [views](../guide/executive-view.md#views)).

In the example twins, each scenario carries `expects answers` lines, and
**Misc ▸ Run the Program's Tests…** shows that the program reproduces them.

### Show the Original

**File ▸ Show the Original…** lists the uploaded XML, kept under `sources/`
beside the program (for an upload, `sources/oipa/<Transaction>/Transaction.xml`).
In the example twins, `sources/` holds the transaction's XML, its attached
rules and the plan's `Rates.csv` and `PlanFields.csv`, and each rule's
provenance (`with provenance "Withdrawal/Transaction.xml" at MathVariable
NetAmountMV`) cites the MathVariable it states.

### Examples to try

Six translated transactions are among the InsurLE examples, visible only on
installations that have them, to users with access. Open them with **File ▸
Open copy from server…**. They come from two plans, a deferred annuity and a
level term life policy:

- `insureLE2/migration/oipa/annuity_deposit`: premium tax, a bonus by size
  (an IIF), the new account value; two checks;
- `insureLE2/migration/oipa/annuity_withdrawal`: policy year, free amount, a
  surrender charge rate by policy year (a RATE), a MathIF, the net amount;
  two checks; spawns FullSurrender; copies the account value;
- `insureLE2/migration/oipa/annuity_full_surrender`: the surrender value of
  the spawned transaction; copies the value and the status;
- `insureLE2/migration/oipa/termlife_issue`: issue age at the nearest
  birthday, a premium rate by age, gender and tobacco (192 rows), annual and
  modal premiums; two checks; six copies;
- `insureLE2/migration/oipa/termlife_premium_payment`: whole modes paid and
  the new paid-to date; one check;
- `insureLE2/migration/oipa/termlife_grace_check`: days past due, in grace;
  spawns Lapse.

No public OIPA configuration exists, so the two plans are synthetic, written
from the forms of Oracle's public OIPA XML Configuration Guide; they are not
Oracle's. Their scenarios are the activities of several policy lives (a
deposit refused for being zero, a withdrawal that spawns the full surrender,
a lapse spawned 44 days past due, an issue refused for age and face amount,
and more), and their expected values were computed by an interpreter of OIPA
math that shares no code with the translator. The six twins reproduce all
103 of them.

## How OIPA maps to Logical English

| OIPA | Logical English |
|---|---|
| activity field, `FIELD` `Activity:GrossAmount` | a fact of the case: `the gross amount of *an activity* is *an amount*.` |
| the transaction itself | `an activity is a withdrawal if the effective date of the activity is a date.` |
| policy field, `POLICYFIELD` `AccountValue` | a fact of the case, the policy as the activity finds it: `the account value of the policy before *an activity* is *an amount*.` |
| plan field, `PLANFIELD` | a fact of the program, cited: `the minimum balance of the plan is 2000, as stated in "PlanFields.csv" at MinimumBalance.` |
| `EXPRESSION` MathVariable | a rule, the MathVariables it reads as conditions: `rule policy_year with provenance "Withdrawal/Transaction.xml" at MathVariable PolicyYearMV:` / `the policy year of an activity is a number N if the duration of the activity is a number M and N = M + 1.` |
| `ROUND="2"` | `N = round((M - K) * 100) / 100` |
| `INTEGER` result of a division | `truncate(…)` |
| `VALUE` set once | the constant, written in place |
| `IIF`, and a `MathIF` that reassigns a variable | an `otherwise` cascade, the latest assignment first |
| `RATE` | a decision table loaded from a CSV beside the program, `with unique match`; its `DEFAULT` the cascade's last line |
| `DurationOf` | `the age on *a date* of someone born on *a date*` (lib/temporal) |
| `ANBAgeOf` (age at the nearest birthday) | the age six calendar months later (approximated) |
| `DaysDiffOf`, `MonthsAdd` | `*a date* is *a number* days after *a date*`, `… months after …` (lib/temporal) |
| `TruncateNumber`, `MinOf`, `MaxOf`, `AbsOf` | `truncate`, `the minimum/maximum of`, `abs` |
| `ValidateExpressions` `Expression` | `*an activity* fails the check *a code*`, the message as the rule's comment |
| `SpawnActivities` `Spawn` | `*an activity* spawns *a transaction*`, only for an activity that fails no check |
| `CopyToPolicyFields` `Field` | `the account value of the policy after *an activity* is *a value*`, only for an activity that fails no check |
| `LOG="Yes"` | a query for that value; the first one is the view's result |

### The activity, the policy it finds and the plan

The program is the *timeless* reading of one transaction: given an activity
and the policy as the activity finds it, what the math computes. Activity
fields and policy fields are the facts of a scenario. Plan fields are facts of
the program: the plan's value from `PlanFields.csv` when the plan folder has
one, otherwise the MathVariable's `DEFAULT`, cited as such:

```le
the free withdrawal percent of the plan is 10, as stated in "Withdrawal/Transaction.xml" at MathVariable FreePercentMV DEFAULT.
```

A program is one transaction, so it says once what its activities are. The
rules that read nothing of the activity (a cascade's fallback, a copy of a
constant) test that sentence:

```le
% An activity of this program is a withdrawal: the Withdrawal transaction it processes.
an activity is a withdrawal if
    the effective date of the activity is a date.
```

### Reassignment and MathIF

OIPA evaluates the Math section from top to bottom, and the last assignment to
a variable wins. The translator writes a variable that a `MathIF` reassigns as
one `otherwise` cascade, the latest assignment first. The Withdrawal's
surrender charge is `ChargeableAmountMV * SurrenderChargeRateMV`, and then 0
under `<MathIF IF="PolicyYearMV > 7">`:

```le
rule surrender_charge with provenance "Withdrawal/Transaction.xml" at MathVariable SurrenderChargeMV:
the surrender charge of an activity is an amount N if
    the policy year of the activity is a number M
    and M > 7
    and N = 0
    otherwise the chargeable amount of the activity is an amount K
    and the surrender charge rate of the activity is a number P
    and N = round(K * P * 100) / 100.
```

An `IIF` is the same: its first value under its condition, otherwise its
second.

### Rates

A `RATE` MathVariable looks a value up in the plan's rate table (OIPA's
AsRate) by exact criteria. The translator writes the rates of that
description into a CSV beside the program and a decision table over it; the
criteria stay codes (`02`, `N`):

```le
the table term_premium is loaded from term_premium.csv, with unique match:
    issue age | gender | tobacco | rate
```

The rule that reads it has the `DEFAULT` as its last alternative
(`otherwise the activity is an issue and N = 0`).

### Checks, spawns and copies

A validation becomes a rule concluding `fails the check`, with the message as
a comment; `$$$…MV$$$` placeholders are named after the value they stand for.
An `ErrorOnFalse` expression is negated:

```le
% A withdrawal of [the gross amount] exceeds the account value of [the account value].
rule w002 with provenance "Withdrawal/ValidateExpressions.xml" at Expression W002:
an activity fails the check "W002" if
    the gross amount of the activity is an amount N
    and the account value of the policy before the activity is an amount M
    and N > M.
```

OIPA refuses an activity that fails a check, so spawns and copies carry the
condition `it is not the case that the activity fails the check a code`. The
values the math computes are still answered for a refused activity.

## Traps

- **An upload has no attached rules, rates or plan fields.** The editor
  receives one file, so `ValidateExpressions.xml`, `SpawnActivities.xml`,
  `CopyToPolicyFields.xml`, `Rates.csv` and `PlanFields.csv` are not read.
  The consequences: no checks, spawns or copies; each rate table is an empty
  CSV (header only), so a `RATE` always gives its `DEFAULT`, or no answer when
  it has none; each plan field is its MathVariable's `DEFAULT`, or has no
  value at all. The note's last sentence does not change this. Add the rates
  to the CSV and the plan fields as facts yourself.
- **No scenarios, no tests.** An upload has no policy lives, so nothing
  checks the program against OIPA. Test it against activities whose values you
  know from a test environment, as scenarios with `expects answers`.
- **The effective date is part of every case.** The fallbacks of the
  cascades and the copies test `the activity is a withdrawal`, which holds
  when the activity has an effective date. A scenario without one gets no
  default values.
- **A variable read between two assignments.** The cascade has one value per
  variable: its final one. If a MathVariable reads a variable *before* a later
  `MathIF` reassigns it, OIPA uses the earlier value, but the program uses the
  final one, and no note or ledger row says so. Check the ledger's
  `reassigned (MathIF)` rows against the order of the Math section.
- **`MathLoop` is dropped.** A `MathLoop` and the MathVariables inside it are
  not translated, and neither the program nor the ledger mentions them. Check
  the XML for loops before trusting the counts.
- **Untranslated MathVariable types are not residue.** `SQL`, `MULTIFIELD`,
  `OBJECT`, `COLLECTION` and other types the translator does not read become
  a rule whose value is the word `unknown` (`and the amount is equal to
  unknown`), a ledger row `a MathVariable of TYPE SQL is not translated` of
  kind note, and in the counts one *approximated*. The rule's own ledger row
  says `encoded`. There is no `% RESIDUE` block to find: search the program
  for `unknown`. Arithmetic on such a value has no answer. A `FIELD`
  MathVariable set inside a `MathIF`, a function the translator does not know
  (anything but DurationOf, ANBAgeOf, DaysDiffOf, MonthsAdd, TruncateNumber,
  MinOf, MaxOf and AbsOf) and a reference to a variable the transaction does
  not set are also only a note row: look for them in the ledger.
- **Not in the translation at all:** assignments to funds, valuation,
  suspense, reversals and the activity lifecycle. A copy says what the policy
  field would be after the activity; it does not change the policy for the
  next activity, and a spawn does not run the spawned transaction. Each
  scenario states the policy the activity finds.
- **ANBAgeOf is approximated.** The age at the nearest birthday is written as
  the age six calendar months later. The two can differ by a day at the
  half-year. The ledger marks the MathVariable *approximated* and adds a note
  row, so one approximation counts twice.
- **Numbers are not decimal.** OIPA computes in decimal; the program computes
  in floating point, rounded where OIPA rounds (`ROUND`). Between rounding
  points, binary fractions can show in values, such as
  `168836.850000000005821` in the Withdrawal scenarios. Compare amounts after
  rounding.
- **Rounding reads as arithmetic.** `ROUND="2"` is `round(E * 100) / 100`,
  which is correct but easy to misread.
- **Codes are values.** Text fields and criteria (gender `02`, tobacco `N`,
  billing mode `12`) are of type *a value*, and must match the rate CSV
  exactly. Write them in scenarios as the example twins do
  (`the insured gender of the policy before i1 is "02".`).
- **The citation of an upload does not open.** The program says `the text of
  "Withdrawal/Transaction.xml" is at "sources/Withdrawal/Transaction.xml"`,
  but an upload keeps the file at `sources/oipa/Withdrawal/Transaction.xml`,
  so **Show original text** on a citation finds nothing. **File ▸ Show the
  Original…** lists the file.
- **Wording follows OIPA's names.** Templates come from the MathVariable
  names (`NetAmountMV` → `the net amount of *an activity*`), so a name like
  `SqlMV` reads `the sql of *an activity*`. Rename templates in the program if
  the words matter to its readers.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md), including
    [opening another system's file](index.md#opening-another-systems-file),
    [what could not be translated](index.md#what-could-not-be-translated),
    [Show the Original](index.md#show-the-original) and
    [the migration twins](index.md#the-migration-twins-among-the-examples)
  - [Decision tables](../reference/language.md#173-decision-tables),
    [`otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [provenance trailers](../reference/language.md#171-provenance-trailers-and-judged-templates),
    [the `temporal` library](../reference/language.md#142-shipped-libraries-lib),
    [arithmetic](../reference/language.md#7-arithmetic-and-comparisons),
    [testing and expectations](../reference/language.md#12-testing-and-expectations)
  - [LE Views](../tutorials/views.md) and
    [views in the executive view](../guide/executive-view.md#views)
- Oracle's documentation of OIPA configuration:
  - [OIPA XML Configuration Guide](https://docs.oracle.com/cd/F25688_01/xml_guide/Content/introduction/index.htm)
  - [MathVariable Element](https://docs.oracle.com/cd/E59346_01/xml_guide/content/math_elements/mathvariable_element.htm)
    (XML Configuration Guide, release 10.1.2.0)
  - [Math Pane](https://docs.oracle.com/cd/E40981_01/rules_palette/Content/Transactions/Math_Pane.htm)
    (Rules Palette 10.0)

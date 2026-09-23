# Oracle Insurance Policy Administration and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Oracle Insurance Policy Administration (OIPA) is Oracle's system for
administering life, annuity and health policies. An OIPA product is
configured rather than programmed. In the Rules Palette, OIPA's configuration
tool, a *transaction* (a deposit, a withdrawal, an issue) is an XML document
(eXtensible Markup Language, a plain-text way of writing down structured
documents). The Math section of the document computes values from the
activity's fields, from the policy and from the plan. The business rules
attached to the document check the activity, spawn — that is, start — other
transactions, and copy values back to the policy. The editor translates one
transaction's XML into Logical English (LE): one rule for each MathVariable,
citing it, with rate lookups as decision tables and a view that prices an
activity. The translation goes one way only, from OIPA into Logical English;
there is no exporter back to OIPA. You reach the translator through
**File ▸ Open…** or **File ▸ Import from Another System…**. The translator
needs the InsurLE extensions, which installations such as the hosted service
have.

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
  - [What is not translated](#what-is-not-translated)
  - [Rates](#rates)
  - [Checks, spawns and copies](#checks-spawns-and-copies)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| OIPA → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | one transaction's Rules Palette XML (`.xml`, root element `<Transaction>` with a `Math` or `Fields` section), or a `.zip` of a plan folder or of a transaction's folder | a program with a template per field and MathVariable, a rule per MathVariable citing it, decision tables for rates, checks, spawns and copies from the attached rules, queries for the logged values, a view; a migration ledger; the XML and the plan's CSV files in `sources/` | for the example twins, an independent interpreter of OIPA transaction math playing each plan's policy lives; an uploaded transaction has no tests |

## How to use it

### What to upload

Upload one of:

- **A zip of a plan folder**, laid out as the Rules Palette's configuration
  is: one folder per transaction, each holding its `Transaction.xml` and its
  attached rules (`ValidateExpressions.xml`, `SpawnActivities.xml`,
  `CopyToPolicyFields.xml`), with the plan's `Rates.csv` (AsRate) and
  `PlanFields.csv` (AsPlanField) beside those folders. The translator reads
  everything, and translates the first transaction in name order; the note
  names the others. The program is named after the plan and the transaction
  (`annuity_withdrawal.le`). To translate another transaction, zip that
  transaction's folder together with the plan's two CSV files.
- **A zip of one transaction's folder** (with or without the plan's CSV
  files beside it). The folder's name is the transaction's name.
- **The XML of one transaction**, as the Rules Palette shows it: a
  `<Transaction>` element with its `<Fields>` and its
  `<Math>`/`<MathVariables>`. The name of the file becomes the name of the
  transaction, so `Withdrawal.xml` gives the transaction `Withdrawal`. A file
  called `Transaction.xml` takes its name from the `NAME` attribute of its
  root element when there is one, and is called `Transaction` otherwise. When
  you upload a single file, nothing comes with it, so the transaction's
  attached rules and the plan's CSV files are not read, and the note says so
  (see [the note](#the-note-and-the-ledger)).

An attached rule file on its own (`ValidateExpressions.xml`, and the others)
has a root element that is not `<Transaction>`, so the translator does not
recognise the file as OIPA material.

Three translators read `.xml` files: Oracle Intelligent Advisor, LegalRuleML
and OIPA. Each of the three looks at the file, and the OIPA translator takes
the file when its root element is `<Transaction>`.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the zip or the transaction's `.xml` file.
2. The server translates it and opens the program in a new tab, named
   `<plan>_<transaction>.le` for a zipped plan folder (`annuity_withdrawal.le`)
   and `oipa_<transaction>.le` otherwise (`oipa_withdrawal.le`).
3. A note under the menu bar names the translator (*Oracle Insurance Policy
   Administration transaction (Rules Palette XML)*) and gives the counts.

The upload and its translation are kept on the server for a day. Save the
program with **File ▸ Save As…** to keep it.

### The note and the ledger

The note reads, for a single `Withdrawal.xml`:

```
oipa_withdrawal: 16 MathVariables and rules encoded, 0 approximated, no residue; 0 writer errors.
Read: Transaction.xml. Not found beside the uploaded XML file (an upload of one file has nothing beside it), so not read: ValidateExpressions.xml, SpawnActivities.xml, CopyToPolicyFields.xml, Rates.csv, PlanFields.csv — hence no checks; no spawns; no copies to policy fields; each rate table is empty, so a RATE gives its DEFAULT or no value; each plan field is its MathVariable's DEFAULT or has no value. To have them read, zip the plan's folder (Withdrawal/ with its attached rules, and Rates.csv and PlanFields.csv) and open the zip.
The XML is kept in sources/Withdrawal/ (the plan's CSV files in sources/), where the rules' citations point; File > Show the Original lists it.
```

For a zipped plan folder, the second line of the note lists what was read
(`Read: Transaction.xml, ValidateExpressions.xml, SpawnActivities.xml,
CopyToPolicyFields.xml, PlanFields.csv, Rates.csv.`), and says which attached
rules the transaction has none of. A last line names the plan's other
transactions.

The translator writes a ledger, `<name>.ledger.md`, beside the program. The
ledger has one row for each MathVariable, for each validation, spawn and copy,
and for each `MathLoop`. Every row gives the mapping used: `FIELD -> the
activity field GrossAmount, a fact of the case`, `RATE -> a decision table
loaded from the plan's rates, DEFAULT as the last line`, and so on. A row
marked *approximated* says how the meaning changed. A row marked *residue* is
something the translator could not read, which stays in the program as a
`% RESIDUE` block (see
[what is not translated](#what-is-not-translated)).

### Running the translation

An uploaded transaction comes with no scenarios. Until you add one, the
verifier warns that the fields of the activity and of the policy (such as
`the_gross_amount_of_is/2`) are undefined. Those warnings are expected,
because such fields are the facts of a case. Write a scenario that gives the
activity's fields, its effective date and the policy it finds, as the example
twins do:

```le
scenario steady_saver_w1 is:
    the gross amount of w1 is 10000.
    the effective date of w1 is 2022-06-01.
    the account value of the policy before w1 is 168836.850000000005821.
    the issue date of the policy before w1 is 2020-03-15.
```

Then run a query. The translator writes one query for each MathVariable marked
`LOG="Yes"` (`query net_amount is: the net amount of which activity is which
amount.`). When the transaction has attached rules, the translator also writes
the queries `checks` and `spawns`, and one `policy_after_…` query for each
copied field. The explanation of an answer follows the math: the net amount
because of the gross amount and the surrender charge, the surrender charge
because of the policy year, and so on down to the fields.

The view (`the view withdrawal is: …`) is a test activity. The activity's
fields, and the policy the activity finds, are the inputs. The first logged
value is the result. The checks are listed, and each MathVariable brings one
citation. Open the view from the editor or from the executive view (see [views](../guide/executive-view.md#views)).

In the example twins, each scenario carries `expects answers` lines, and
**Misc ▸ Run the Program's Tests…** shows that the program reproduces them.

### Show the Original

**File ▸ Show the Original…** lists the files kept under `sources/` beside
the program, as the example twins keep them. The transaction's XML and the
attached rules that were read sit in `sources/<Transaction>/`, and the plan's
`Rates.csv` and `PlanFields.csv` sit in `sources/`. Each rule's provenance
(`with provenance "Withdrawal/Transaction.xml" at MathVariable NetAmountMV`)
cites the MathVariable the rule states, and the program says where that file
is (`the text of "Withdrawal/Transaction.xml" is at
"sources/Withdrawal/Transaction.xml"`). **View Original Text** on a citation
therefore opens the file at that MathVariable.

### Examples to try

Six translated transactions are among the lpsPlus examples, visible only on
installations that have those examples, and only to users with access. Open
them with **File ▸ Open example from server…**. The six come from two plans:
a deferred annuity and a level term life policy:

- `lpsPlus/migration/oipa/annuity_deposit`: premium tax, a bonus by size
  (an IIF), the new account value; two checks;
- `lpsPlus/migration/oipa/annuity_withdrawal`: policy year, free amount, a
  surrender charge rate by policy year (a RATE), a MathIF, the net amount;
  two checks; spawns FullSurrender; copies the account value;
- `lpsPlus/migration/oipa/annuity_full_surrender`: the surrender value of
  the spawned transaction; copies the value and the status;
- `lpsPlus/migration/oipa/termlife_issue`: issue age at the nearest
  birthday, a premium rate by age, gender and tobacco (192 rows), annual and
  modal premiums; two checks; six copies;
- `lpsPlus/migration/oipa/termlife_premium_payment`: whole modes paid and
  the new paid-to date; one check;
- `lpsPlus/migration/oipa/termlife_grace_check`: days past due, in grace;
  spawns Lapse.

No public OIPA configuration exists, so the two plans were written for this
purpose, following the forms in Oracle's public OIPA XML Configuration Guide.
The two plans are not Oracle's. Their scenarios are the activities of several
policy lives: a deposit refused for being zero, a withdrawal that spawns the
full surrender, a lapse spawned 44 days past due, an issue refused for age and
face amount, and more. The expected values were computed by a separate program
that works OIPA's math out and shares no code with the translator. The six
twins reproduce all 103 of those expected values.

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
| a variable read between two of its assignments | the value it had then, a rule of its own: `the first value of the charge of *an activity*` |
| `SQL` and other unread MathVariable types, `MathLoop` | a `% RESIDUE` block with the XML, a ledger row *residue* |
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

The program is the *timeless* reading of one transaction: given an activity,
and the policy as the activity finds it, the program says what the math
computes. The activity's fields and the policy's fields are the facts of a
scenario. The plan's fields are facts of the program itself. Each plan field
takes the plan's value from `PlanFields.csv` when the plan folder has one, and
the MathVariable's `DEFAULT` otherwise, cited as such:

```le
the free withdrawal percent of the plan is 10, as stated in "Withdrawal/Transaction.xml" at MathVariable FreePercentMV DEFAULT.
```

A program covers one transaction, so the program says once what its
activities are. The rules that read nothing from the activity (the fallback of
a cascade, a copy of a constant) test that one sentence:

```le
% An activity of this program is a withdrawal: the Withdrawal transaction it processes.
an activity is a withdrawal if
    the effective date of the activity is a date.
```

### Reassignment and MathIF

OIPA works through the Math section from top to bottom, and the last
assignment to a variable wins. When a `MathIF` assigns a variable again, the
translator writes that variable as a single `otherwise` cascade, with the
latest assignment first. In the Withdrawal transaction the surrender charge is
`ChargeableAmountMV * SurrenderChargeRateMV`, and then 0 under
`<MathIF IF="PolicyYearMV > 7">`:

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

A MathVariable that reads a variable *between* two of its assignments gets the
value that variable held at that point, as OIPA computes it. The translator
writes the earlier value as a rule of its own, holding the cascade of the
assignments made so far:

```le
rule charge_first_value with provenance "Payout/Transaction.xml" at MathVariable ChargeMV:
the first value of the charge of an activity is an amount N if
    the activity is a payout
    and N = 100.

rule first_net with provenance "Payout/Transaction.xml" at MathVariable FirstNetMV:
the first net of an activity is an amount N if
    the gross amount of the activity is an amount M
    and the first value of the charge of the activity is an amount K
    and N = M - K.
```

The ledger row of the reassigned variable says which of its earlier values
are rules. A `MathIF`'s condition reads the values set before the `MathIF`.

### What is not translated

A MathVariable the translator cannot read becomes a residue block. The block
holds the variable's XML (every assignment of the variable), the reason the
variable was not translated, and the template the missing rule must conclude.
The rules that read such a variable are translated, but they have no answer
until the block itself is translated. The ledger row for the variable reads
*residue*:

```le
% RESIDUE r1 BEGIN: Payout/Transaction.xml MathVariable BalanceMV
% TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
%   source: Payout/Transaction.xml
% Not translated: a MathVariable of TYPE SQL, which the translator does not read.
% Conclude: the balance of *an activity* is *an amount*.
%   OIPA XML:
%   | <MathVariable VARIABLENAME="BalanceMV" TYPE="SQL" DATATYPE="DECIMAL">SELECT Balance FROM AsPolicy</MathVariable>
% RESIDUE r1 END
```

Several things end up as residue in this way. The MathVariable types other
than FIELD, POLICYFIELD, PLANFIELD, VALUE, EXPRESSION, FUNCTION, IIF and RATE
(`SQL`, `MULTIFIELD`, `OBJECT`, `COLLECTION`, and so on) become residue, and
so does a `FIELD` MathVariable set inside a `MathIF`. So does any function
other than DurationOf, ANBAgeOf, DaysDiffOf, MonthsAdd, TruncateNumber, MinOf,
MaxOf and AbsOf, and so does a reference to a variable that the transaction
does not set, or has not set yet. A `MathLoop` becomes a single residue block
holding the loop's XML, and that block must conclude the MathVariables set
inside the loop; the ledger then has a row for the loop and one row for each
of those variables. A check, a spawn or a copy that reads something
untranslatable is left out altogether, and the ledger says so.

### Rates

A `RATE` MathVariable looks a value up in the plan's rate table (OIPA's
AsRate), matching the criteria exactly. The translator writes the rates of
that description into a CSV file beside the program, and writes a decision
table that reads the file. The criteria stay as codes (`02`, `N`):

```le
the table term_premium is loaded from term_premium.csv, with unique match:
    issue age | gender | tobacco | rate
```

The rule that reads the table has the `DEFAULT` as its last alternative
(`otherwise the activity is an issue and N = 0`).

### Checks, spawns and copies

A validation becomes a rule that concludes `fails the check`, with the
validation's message written above it as a comment. Each `$$$…MV$$$`
placeholder in the message is replaced by the name of the value it stands for.
An `ErrorOnFalse` expression is turned round into its negation:

```le
% A withdrawal of [the gross amount] exceeds the account value of [the account value].
rule w002 with provenance "Withdrawal/ValidateExpressions.xml" at Expression W002:
an activity fails the check "W002" if
    the gross amount of the activity is an amount N
    and the account value of the policy before the activity is an amount M
    and N > M.
```

OIPA refuses an activity that fails a check, so the spawns and the copies
carry the condition `it is not the case that the activity fails the check a
code`. The values the math computes are still answered for a refused
activity.

## Traps

- **An `.xml` upload has no attached rules, rates or plan fields.** The
  editor receives one file only, so `ValidateExpressions.xml`,
  `SpawnActivities.xml`, `CopyToPolicyFields.xml`, `Rates.csv` and
  `PlanFields.csv` are not read, and the note lists them. Three things follow.
  The program has no checks, no spawns and no copies. Each rate table is an
  empty CSV file, with its heading row and nothing else, so a `RATE` always
  gives its `DEFAULT`, or gives no answer when it has no `DEFAULT`. Each plan
  field falls back to its MathVariable's `DEFAULT`, or has no value at all.
  Upload a zip of the plan folder instead.
- **One transaction per upload.** A zipped plan folder translates its first
  transaction; the note names the others.
- **No scenarios, no tests.** An upload brings no policy lives with it, so
  nothing checks the program against OIPA. Test the program against
  activities whose values you know from a test environment, written as
  scenarios with `expects answers` lines.
- **The effective date is part of every case.** The fallbacks of the
  cascades and the copies test `the activity is a withdrawal`, which holds
  when the activity has an effective date. A scenario that states no effective
  date gets no default values.
- **Residue has no answers.** `SQL` and the other MathVariable types the
  translator does not read, and `MathLoop`s, are residue blocks (see
  [what is not translated](#what-is-not-translated)). Everything that reads
  them, down to the logged values, has no answer until the blocks are
  translated by hand or with the Contract Assistant's residue mode.
- **Not in the translation at all:** assignments to funds, valuation,
  suspense, reversals and the activity lifecycle. A copy says what the policy
  field would be after the activity. The copy does not change the policy for
  the next activity, and a spawn does not run the transaction it spawns. Each
  scenario states the policy the activity finds.
- **ANBAgeOf is approximated.** The age at the nearest birthday is written as
  the age six calendar months later. The two can differ by a day at the
  half-year. The ledger marks the MathVariable *approximated*.
- **Numbers are not decimal.** OIPA computes in decimal. The program computes
  in floating point, the approximate fractions a computer uses, and rounds
  where OIPA rounds (`ROUND`). Between two rounding points those approximate
  fractions can show in a value, such as `168836.850000000005821` in the
  Withdrawal scenarios. Compare amounts after rounding.
- **Rounding reads as arithmetic.** `ROUND="2"` is `round(E * 100) / 100`,
  which is correct but easy to misread.
- **Codes are values.** Text fields and criteria (gender `02`, tobacco `N`,
  billing mode `12`) are of type *a value*, and must match the rate CSV
  exactly. Write them in scenarios as the example twins do
  (`the insured gender of the policy before i1 is "02".`).
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

# Socotra and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Socotra is a cloud insurance core platform. A carrier describes a product in a
*product configuration*, which holds three kinds of file. JSON files
(JavaScript Object Notation, a plain-text way of writing down structured data)
declare the policy, its exposures (a vehicle, a dwelling, a pet) and their
perils. CSV files (comma-separated values, a plain-text table) hold the rate
tables. Scripts written in the Liquid template language compute premiums,
commissions, taxes, fees and the underwriting decision. The editor translates
a classic Socotra product configuration, JSON and Liquid together, into
Logical English (LE): the fields become templates, the Liquid scripts become
rules, the rate tables become decision tables, and the program gets a *quote
desk* view. The translation goes one way only, from Socotra into Logical
English; there is no exporter back to Socotra. You reach the translator
through **File ▸ Open…** or **File ▸ Import from Another System…**. The
translator needs the InsurLE extensions, which installations such as the
hosted service have.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [What to upload](#what-to-upload)
  - [Importing](#importing)
  - [The note and the ledger](#the-note-and-the-ledger)
  - [Running the translation](#running-the-translation)
  - [Show the Original and the rules' citations](#show-the-original-and-the-rules-citations)
  - [Examples to try](#examples-to-try)
- [How Socotra maps to Logical English](#how-socotra-maps-to-logical-english)
  - [Liquid scripts become rules](#liquid-scripts-become-rules)
  - [Rate tables](#rate-tables)
  - [Loops over exposures and perils](#loops-over-exposures-and-perils)
  - [Quotes as scenarios](#quotes-as-scenarios)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Socotra → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | a `.zip` of a product configuration (a folder with `policy/policy.json`); a lone `policy.json` or `exposure.json` for its fields only | a program with the product's rating, tax, fee and underwriting rules, its rate tables, generated quotes as scenarios, a quote desk view, a ledger, and the product's files under `sources/` | the product's own Liquid, run on generated quotes by a reference Liquid interpreter with Socotra's filters imitated |
| Logical English → Socotra | none | | | |

## How to use it

### What to upload

Upload a **zip archive** of the configuration. The translator looks inside the
archive, up to three folders deep, for a product folder, which is a folder
holding `policy/policy.json`. The translator finds both of these layouts:

- the layout of Socotra's public product library, `<Product>/policy/...`;
- the layout of a Socotra configuration, `products/<name>/policy/...`.

What the translator reads in the product folder:

- `policy/policy.json`, `policy/exposures/<exposure>/exposure.json` and the
  perils' JSON: the fields;
- `<peril>.premium.liquid`: the rating scripts;
- `policy/taxes/`: the tax scripts;
- `policy/underwriting.guidelines.liquid`: the underwriting decision and
  notes;
- `policy/policy.calculations.liquid` and `fees.json`: the fees;
- `policy/tables/<table>.csv`: the rate tables.

The document templates (`schedule.template.liquid`, `invoice.template.liquid`
and the like) lay out paperwork rather than make decisions, so the translator
leaves them out. The ledger lists those files and says so.

When the archive holds several products, the translator translates the first
product in name order, and the note names the others. To translate another
product, put it in an archive of its own and open that archive.

A single `.json` file is translated when the file is a product
configuration's `policy.json` or an `exposure.json` (a list of named `fields`,
each with its type). Such a file holds no rating. The program then declares
the file's fields as the facts of a quote (`the channel of *a policy* is *a
value*; scenario element.`), and has no rules, no queries and no view. The
note says that the rating, taxes, fees and underwriting live in the product
folder's scripts and tables. Zip the product folder to translate those. Any
other `.json` file opens as a program that holds the file's text in a `% TODO`
comment, with the reason.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the zip.
2. The server unpacks the archive, finds the product folder, and translates
   the product. The program opens in a new tab, named after the product
   (`pet.le` for a product called Pet).
3. A note under the menu bar says that the *Socotra product configuration*
   translator did the work, and gives the translator's remarks, described
   below. Close the note with its `×`.

The upload and its translation are kept on the server for a day. Save the
program with **File ▸ Save As…** to keep it.

### The note and the ledger

The note says, for example:

> Pet: 52 ledger elements encoded, 7 approximated, no residue; 0 writer errors.

The note then says where the quote scenarios came from, or why they were
skipped, how the quotes' expectations turned out when there are quotes, and
where the product's files were put:

> The product's Liquid, JSON and CSV files are copied into sources/Pet/ beside
> the program (File > Show the Original lists them); every rule cites its file
> and passage there.

The translator also writes a *ledger* beside the program
(`<product>.ledger.md`). Each row is one element of the configuration (a
script, a branch of a script, an output, a field, a table, a fee, a platform
value) with its verdict:

- **encoded**: translated with its meaning unchanged;
- **approximated**: translated, with a documented change of meaning (the note
  on the row says which);
- **residue**: not translated, and kept in the program as a residue block.

The ledger also records the arithmetic convention and, when the program has
quotes, how many of their expected values the program reproduces.

**Quotes need the reference run.** The scenarios come from running the
product's own Liquid on ten quotes the translator makes up. That run needs
Python 3 on the server, with the `python-liquid` package installed. When the
run cannot happen, the note says that the quote scenarios were skipped, and
why: no `python3`, no `python-liquid`, or an error in the run itself. The
comment at the top of the program says the same:

> Quote scenarios skipped: the reference run of the product's Liquid needs the
> python-liquid package (pip install python-liquid), which this server's
> python3 lacks. The program has no scenarios, so nothing checks its rules
> against the product's Liquid; state a quote in the Scenario Editor to run it.

The rules, tables, queries and view are the same either way.

### Running the translation

The program has one query per kind of output: `yearly_premiums`,
`yearly_technical_premiums`, `yearly_commissions`, `underwriting_decision`,
`underwriting_notes`, one per tax (`taxes_sales`), one per fee
(`fees_transaction`), and `declined`.

- Pick a scenario (a quote) and a query, and run the query as usual. The
  explanation of each answer walks down the rules to the fields of the quote.
- **Misc ▸ Run the Program's Tests…** runs every expectation of the quote
  scenarios and lists each one with its outcome.
- When the program has no quotes, state one yourself in the Scenario Editor: a
  policy, its exposures, which perils cover each exposure, and the fields the
  rules read. The quote desk view lists exactly those fields.
- The **quote desk** view shows the case grouped by policy, exposure and
  coverage. The yearly premiums are the result. Beside them stand the total
  premium, the technical premiums, the commissions, the taxes, the fees, and
  the underwriting decision with its notes. Amounts are shown with 2 decimals.
  When the decision is `reject`, a red banner reads "Declined by underwriting:
  this policy cannot be bound". A draft of the quote, as text, closes the
  view.

### Show the Original and the rules' citations

**File ▸ Show the Original…** lists the product's files, which are copied into
the program's `sources/` folder under the product's name: the Liquid, JSON and
CSV files. Pick one of them, and it opens in the source viewer.

Every rule cites the file it was translated from and, where the translator can
pin it down, the passage in that file. A short passage is quoted after
`confer`; a longer one is given by line numbers.

```le
rule accident_limit_factor_key_1 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid",
        confer "{% if peril_c.indemnity_per_item <= 500.00 %} {% assign limit_factor_key = 'A' %} {% else %} {% assign limit_factor_key = 'B' %} {% endif %}":
```

```le
rule accident_premium_2 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid" at lines 7 to 41:
```

Put the cursor on a provenance trailer and **Show definition** (F12, or the
right-click menu) opens the cited file in the source viewer, with the passage
highlighted. The editor checks the quotations against the copied files when
the program loads.

### Examples to try

The twins of the seventeen products of Socotra's public product library
(Pet, Personal Auto, Homeowners, Workers Compensation, Term Life, Cyber,
Drone and others) are among the lpsPlus examples. Those examples are visible
only on installations that have them, and only to users with access. Open a
twin with **File ▸ Open example from server…**:

- `lpsPlus/migration/socotra/pet/pet`: small (27 rules, three tables), with
  an underwriting rejection in the Lion and Elephant quotes;
- `lpsPlus/migration/socotra/personal_auto/personal_auto`: seven perils and
  the claims-history loadings;
- `lpsPlus/migration/socotra/term_life/term_life`: ages from dates of
  birth, with lib/temporal;
- `lpsPlus/migration/socotra/homeowners/homeowners`: a residue block, and
  expectations pending on it.

Each twin has its ledger, its quotes (`quotes.json`), and the product's files
in `sources/`. Across the seventeen products, every expectation that can run
passes: 992 of them. Another 100 expectations wait for the four residue blocks
to be translated. The twins differ from an ordinary import in one respect:
each file a twin cites is also linked to its page in the public product
library on GitHub.

## How Socotra maps to Logical English

| Socotra | Logical English |
|---|---|
| a policy field (`policy.json`) | a scenario-element template: `the channel of *a policy* is *a value*; scenario element.` |
| an exposure kind and its fields (`exposure.json`) | a type named after the kind, and templates: `the pet type of *a pet* is *a value*; scenario element.` A quote states both `pet 1 is a pet.` and `pet 1 is an exposure.` |
| a peril and its characteristics | `*an exposure* is covered for *a peril*; scenario element.` and `the indemnity per item for *a peril* on *an exposure* is *an amount*; scenario element.` |
| a field no script reads | not declared (the ledger says so) |
| `assign` in `<peril>.premium.liquid` | a quantity: `the accident premium for *a pet* is *a number*.`, one template per step when the variable is reassigned (`the accident premium at step two for *a pet* is *a number*.`); *a value* when a branch gives it a text (`the accident limit factor key for *a pet* is *a value*.`) |
| `round`, `round: 2` | `N = round(M)`; `N = round(M * 100) / 100.0` (half away from zero, as the reference Liquid) |
| `if` / `elsif` / `else` / `unless`, `case` / `when` | an `otherwise` cascade, first matching branch |
| `set_year_premium`, `set_year_technical_premium`, `set_month_premium`, `add_year_commission`, ... | the conclusions `the yearly premium for *a peril* on *an exposure* is *an amount*.` and the like, guarded by `the exposure is covered for accident` |
| `taxes/<tax>.premium.liquid` | `the sales tax for *a peril* on *an exposure* is *an amount*.` |
| `underwriting.guidelines.liquid` | `the underwriting decision for *a policy* is *a decision*.`, `the underwriting notes for *a policy* include *a note*.` |
| `add_fee` in `policy.calculations.liquid`, `fees.json` | `the transaction fee for *a policy* is *an amount*.` and its description |
| `gross_premium`, `gross_taxes` (computed by the platform) | derived rules: the sum of the perils' yearly premiums, or taxes |
| `"table" \| lookup: key` | a decision table loaded from the carrier's CSV, read through `the <table> lookup of *a key* is *a value*`, 0 for a missing key |
| `for` over the exposures or perils | an existential condition, or a `sum` aggregate for an accumulator |
| `timestamp_millis_print: "YYYY"` of a date | `the year of *a date* is *a number*` (lib/temporal, copied beside the program) |
| anything else | a residue block with the Liquid verbatim |

### Liquid scripts become rules

The translator reads each script without running it on actual figures. The
translator follows every branch, keeps track of what each variable holds, and
writes a rule for each value that an output filter receives. A variable that
different branches set differently becomes a cascade. The rule below comes
from the Pet product's accident script:

```le
rule accident_premium_1 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid" at lines 7 to 41:
the accident premium for a pet is a number N if
    the accident premium at step two for the pet is a number M
    and all of
        the pet type of the pet is "Cat"
        and N = round(M + 10.0)
        otherwise N is equal to M.
```

The output filter is the conclusion:

```le
rule death_yearly_premium_final with provenance "Pet/policy/exposures/Pet/perils/death.premium.liquid",
        confer "{{ premium | round | set_year_premium }}":
the yearly premium for death on an exposure is an amount N if
    the exposure is covered for death
    and the death premium for the exposure is a number M
    and N = round(M).
```

The underwriting script sets a decision, and a later setting in the script
overrides an earlier one. The translation therefore tries the last setting
first. The result is a cascade of *provisional* decisions, ending in
`the underwriting decision for a policy is a decision`. Notes behave
differently: a script adds a note instead of overriding the notes before it,
so each note becomes a rule of its own:

```le
rule underwriting_note_two_final with provenance "Pet/policy/underwriting.guidelines.liquid" at line 14:
the underwriting notes for a policy include "Policy does not meet guidelines for automatic acceptance as the pet is a Lion" if
    the policy is a policy
    and an exposure is insured under the policy
    and the pet type of the exposure is "Lion".
```

### Rate tables

A table that the scripts look values up in becomes a decision table with
unique match. The table is loaded from the carrier's own CSV file, which is
copied beside the program:

```le
the table pet_base_rates_table is loaded from pet_base_rates_table.csv, with unique match:
    key | value
```

A rule reads the table, and gives 0 for a key the table has no row for.
Liquid does the same, because a missing value (`nil`) counts as 0 in Liquid's
arithmetic:

```le
rule lookup_pet_base_rates_table with provenance "Pet/policy/tables/pet_base_rates_table.csv":
the pet base rates table lookup of a key is a value if
    the pet base rates table entry for the key is the value under table pet_base_rates_table
    otherwise the value is equal to 0.
```

### Loops over exposures and perils

A loop that decides something when an item meets a condition becomes a
condition about *some* exposure or peril. From Workers Compensation:

```le
    and an exposure is insured under the policy
    and the exposure is covered for a peril
    and the class code for the peril on the exposure is 3315
        or the class code for the peril on the exposure is 3316
```

A loop that adds values up becomes an aggregate. The gross premium, which
Socotra's platform computes rather than a script, is worked out the same way:

```le
rule gross_premium:
the gross premium of a policy is an amount N if
    the policy is a policy
    and N is the sum of each M such that
        an exposure is insured under the policy
        and the exposure is covered for a peril
        and the yearly premium for the peril on the exposure is an amount M.
```

### Quotes as scenarios

A product configuration carries no rating tests, so the translator makes
quotes of its own. First comes a base quote: the first value of each list
field, representative numbers, and a table's first key for a field looked up
in a table. Then come variants, each of which changes one list value, or
crosses a threshold that a script compares a number with. The translator keeps
ten quotes in all. The translator then runs the product's Liquid on each
quote, and every output becomes an expectation in that quote's scenario:

```le
scenario quote_exposure_Pet_pet_type_Lion is, as stated in Pet rating quotes at quote exposure_Pet_pet_type_Lion:
    policy 1 is a policy.
    the channel of policy 1 is "Direct".
    pet 1 is a pet.
    pet 1 is an exposure.
    pet 1 is insured under policy 1.
    the pet type of pet 1 is "Lion".
    ...
    underwriting_decision expects answers ["the underwriting decision for policy 1 is reject"].
```

The expected values are what the product's own scripts compute, not what the
translation computes. The values do not come from Socotra itself: the
reference run imitates Socotra's filters and arithmetic, without the
platform.

## Traps

- **A JSON file is only its fields.** A lone `policy.json` or `exposure.json`
  gives the fields and nothing else (see [What to upload](#what-to-upload)).
  Upload a zip of the product folder for the rules.
- **Classic configurations only.** The translator reads the JSON and Liquid
  configuration. Anything else in what you upload (plugins, claims forms,
  permissions, document templates) is left untranslated.
- **No quotes without python-liquid.** When the server lacks the
  `python-liquid` package, the program has no scenarios, so nothing checks the
  translation against the product's Liquid. The note says that the quote
  scenarios were skipped, and why. Test the program on quotes whose answers
  from the platform you already know.
- **Residue.** A script the translator cannot follow is kept whole as a
  residue block, and everything that depends on that script is left without a
  rule. The block says why the script was not translated, what the missing
  rules must conclude, and which fields the script reads:

  ```le
  % RESIDUE r1 BEGIN: Homeowners/policy/underwriting.guidelines.liquid
  % TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
  %   source: Homeowners/policy/underwriting.guidelines.liquid
  % Not translated: the variable dwelling_c is assigned inside a loop and read after it (Liquid keeps the last item's value).
  % Conclude: the underwriting decision for *a policy* is *a decision*; the underwriting notes for *a policy* include *a note*.
  ```

  These become residue: a filter that is neither Liquid's arithmetic nor one
  of Socotra's output filters (`get_30_360_day_count`, for example);
  arithmetic on dates or times;
  a variable set inside a loop and read after the loop; a loop over a
  repeatable group of fields; a Liquid tag the translator does not know. In a
  twin, the expectations that depend on a residue block are kept as comments,
  `% pending — waits for residue r1:`, so that the tests all pass while the
  gap stays visible. Translate the block by hand, or with the Contract
  Assistant's *Migration residue* mode, and then restore those lines.
- **Missing values are 0.** Liquid reads a missing table row, or a variable
  that a script never assigns, as `nil`: 0 in arithmetic, and false in a
  comparison. The program also reads 0 in arithmetic. A field that a quote
  does not state behaves differently: the rules that read the field find
  nothing, so the output those rules compute may have no answer at all, where
  Liquid would have computed with `nil`. A
  script that relies on a missing row *comparing* false can therefore behave
  differently in the program. The ledger marks each lookup *approximated*, and
  lists every variable that some script reads but no script ever assigns. Such
  a variable is a fault in the source, which the program copies.
- **Numbers are the source's floating point.** Amounts are computed as the
  Liquid computes them, in the approximate fractions computers use for decimal
  numbers, and the program rounds nothing of its own accord. An expectation
  can therefore read `0.8500000000000001` or `686.0`. The quote desk shows 2
  decimals; queries and tests show the exact value. Liquid's `round` and
  `round: 2` round half away from zero, and so does the program; `round: 2`
  gives a floating-point number (`70.0`), as the reference Liquid does.
- **Integer division.** Liquid's `divided_by` divides one whole number by
  another and throws the remainder away. Where both numbers are known to be
  whole, the program writes `//` (`N = M // 100`), which is right for
  whole-number inputs only. Where the kinds of number cannot be known until
  the program runs, the translator writes `/`. The ledger marks both
  *approximated*.
- **Text and numbers.** A list value that reads as a number becomes a number,
  and a table key such as `0005` is read as 5. A value that starts with a
  comparison sign is spelled out: `<50%` becomes `under 50%`, in the rules, in
  the scenarios and in the copied table alike, because a Logical English table
  cell starting with `<` is read as a condition. When you state a quote by
  hand, write numbers without quotation marks:
  `the atfault claims past five years of policy 1 is "2"` never matches a rule
  that compares with the number 2. The verifier warns about a value that no
  rule can read where it stands.
- **Names come from the source's words.** Templates are named after
  Socotra's field and variable names ("the pet breed dog of a pet", "the
  accident premium at step two"). The type of a variable comes from the values
  its branches give it: *a number*, or *a value* when one of those values is a
  text. The wording may need editing.
- **The first exposure is any exposure.** `data.policy.exposures[0]` is read
  as "an exposure of the policy". That reading is right when the policy has a
  single exposure of that kind, and wrong when it has several.
- **Loops ignore order.** A decision written inside a loop is read as
  "written when some item satisfies the condition". The program does not
  record which item Liquid visited last.
- **Gross premium and taxes are sums.** Socotra's platform also counts
  endorsements and term changes. A single quote has neither, so the sum is
  exact for a quote and nowhere else.
- **Rating, not claims.** A product configuration is rating and underwriting.
  There is no claims logic (coverage for a loss, deductibles applied, limits,
  reserves) to translate.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md#opening-another-systems-file):
    what every importer does, [what could not be translated](index.md#what-could-not-be-translated),
    [Show the Original](index.md#show-the-original) and
    [the migration twins](index.md#the-migration-twins-among-the-examples);
  - [the `otherwise` cascades](../reference/language.md#172-otherwise-cascades),
    [decision tables](../reference/language.md#173-decision-tables),
    [aggregates](../reference/language.md#5-aggregates),
    [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance),
    [expectations](../reference/language.md#12-testing-and-expectations) and
    [lib/temporal](../reference/language.md#142-shipped-libraries-lib) in the
    language reference;
  - [views](../reference/language.md#1710-views-how-a-screen-shows-a-program)
    and the [views tutorial](../tutorials/views.md), for the quote desk;
  - [the Scenario Editor](../guide/editor.md#the-scenario-editor), to state a
    quote;
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant),
    whose residue mode translates residue blocks.
- Socotra's own documentation:
  - [Socotra](https://www.socotra.com)
  - [Socotra documentation](https://docs.socotra.com)
  - [socotra/product-library](https://github.com/socotra/product-library):
    the public product configurations the twins were made from
  - [socotra/public](https://github.com/socotra/public): code samples,
    example configurations and test utilities
  - [Liquid](https://shopify.github.io/liquid/): the template language of the
    scripts

# Socotra and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Socotra is a cloud insurance core platform. A carrier describes a product in
a *product configuration*: JSON files declare the policy, its exposures (a
vehicle, a dwelling, a pet) and their perils, CSV files hold the rate tables,
and scripts in the Liquid template language compute premiums, commissions,
taxes, fees and the underwriting decision. The editor translates a classic
Socotra product configuration (JSON and Liquid) into Logical English: the
fields as templates, the Liquid scripts as rules, the rate tables as decision
tables, and a *quote desk* view. The translation goes one way only, from
Socotra into Logical English; there is no exporter back to Socotra. It is
reached through **File ▸ Open…** or **File ▸ Import from Another System…**,
and needs the InsurLE extensions, which installations such as the hosted
service have.

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
| Socotra → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | a `.zip` of a product configuration (a folder with `policy/policy.json`) | a program with the product's rating, tax, fee and underwriting rules, its rate tables, generated quotes as scenarios, a quote desk view, a ledger, and the product's files under `sources/` | the product's own Liquid, run on generated quotes by a reference Liquid interpreter with Socotra's filters imitated |
| Logical English → Socotra | none | | | |

## How to use it

### What to upload

Upload a **zip archive** of the configuration. The translator looks in the
archive, up to three folders deep, for a product folder: a folder holding
`policy/policy.json`. Both layouts are found:

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
and the like) are presentation, not decisions, and are not translated; the
ledger lists them as such.

When the archive holds several products, the first (in name order) is
translated, and the note names the others: open each in its own archive.

A single `.json` file is not translated, even though the file picker offers
`.json` for Socotra. The translator needs the whole product folder, so a lone
JSON file opens as a program holding its text in a `% TODO` comment, with the
reason. Zip the product folder instead.

### Importing

1. Choose **File ▸ Import from Another System…** (or **File ▸ Open…**) and
   pick the zip.
2. The server extracts it, recognises the product folder, and translates it.
   The program opens in a new tab, named after the product (`pet.le` for a
   product called Pet).
3. A note under the menu bar says that the *Socotra product configuration*
   translator was used, and gives its remarks (below). Close it with its `×`.

The upload and its translation are kept on the server for a day. Save the
program with **File ▸ Save As…** to keep it.

### The note and the ledger

The note says, for example:

> Pet: 52 ledger elements encoded, 7 approximated, no residue; 0 writer errors.

followed by where the quotes came from, the result of the quotes'
expectations when there are quotes, and where the product's files were put.

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
product's own Liquid on ten generated quotes. That run needs Python 3 with
the `python-liquid` package on the server. When the server lacks it, the
note says so:

> No quotes: the reference run needs python3 with python-liquid, which this
> server lacks, so the program has no scenarios; state a quote in the Scenario
> Editor to run it.

The rules, tables, queries and view are the same either way.

### Running the translation

The program has one query per kind of output: `yearly_premiums`,
`yearly_technical_premiums`, `yearly_commissions`, `underwriting_decision`,
`underwriting_notes`, one per tax (`taxes_sales`), one per fee
(`fees_transaction`), and `declined`.

- Pick a scenario (a quote) and a query, and run it as usual. Each answer's
  explanation walks down the rules to the fields of the quote.
- **Misc ▸ Run the Program's Tests…** runs every expectation of the quote
  scenarios and lists each with its outcome.
- Without quotes, state one in the Scenario Editor: a policy, its exposures,
  which perils cover each, and the fields the rules read. The quote desk view
  lists exactly those fields.
- The **quote desk** view shows the case grouped by policy, exposure and
  coverage, the yearly premiums as the result, the total premium, technical
  premiums, commissions, taxes, fees and the underwriting decision and notes
  beside it, amounts with 2 decimals, a red banner "Declined by underwriting:
  this policy cannot be bound" when the decision is `reject`, and a draft of
  the quote as text.

### Show the Original and the rules' citations

**File ▸ Show the Original…** lists the product's files, copied into the
program's `sources/` folder (Liquid, JSON and CSV, under the product's name),
and opens the one you pick in the source viewer.

Every rule cites the file it was translated from, and where it can, its
passage there: a short passage is quoted with `confer`, a longer one is given
by lines.

```le
rule accident_limit_factor_key_1 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid",
        confer "{% if peril_c.indemnity_per_item <= 500.00 %} {% assign limit_factor_key = 'A' %} {% else %} {% assign limit_factor_key = 'B' %} {% endif %}":
```

```le
rule accident_premium_2 with provenance "Pet/policy/exposures/Pet/perils/accident.premium.liquid" at lines 7 to 41:
```

With the cursor on a provenance trailer, **Show definition** (F12, or the
right-click menu) opens the cited file in the source viewer, with the passage
highlighted. The quotations are checked against the copied files when the
program loads.

### Examples to try

The twins of the seventeen products of Socotra's public product library
(Pet, Personal Auto, Homeowners, Workers Compensation, Term Life, Cyber,
Drone and others) are among the InsurLE examples. They are visible only on
installations with the InsurLE examples, to users with access. Open them with
**File ▸ Open copy from server…**:

- `insureLE2/migration/socotra/pet/pet`: small (27 rules, three tables), with
  an underwriting rejection in the Lion and Elephant quotes;
- `insureLE2/migration/socotra/personal_auto/personal_auto`: seven perils and
  the claims-history loadings;
- `insureLE2/migration/socotra/term_life/term_life`: ages from dates of
  birth, with lib/temporal;
- `insureLE2/migration/socotra/homeowners/homeowners`: a residue block, and
  expectations pending on it.

Each twin has its ledger, its quotes (`quotes.json`), and the product's files
in `sources/`. Across the seventeen, every expectation that can run passes
(992); 100 more wait for the four residue blocks. The twins differ from an
import in one respect: each file they cite is also linked to its page in the
public product library on GitHub.

## How Socotra maps to Logical English

| Socotra | Logical English |
|---|---|
| a policy field (`policy.json`) | a scenario-element template: `the channel of *a policy* is *a value*; scenario element.` |
| an exposure kind and its fields (`exposure.json`) | a type named after the kind, and templates: `the pet type of *a pet* is *a value*; scenario element.` A quote states both `pet 1 is a pet.` and `pet 1 is an exposure.` |
| a peril and its characteristics | `*an exposure* is covered for *a peril*; scenario element.` and `the indemnity per item for *a peril* on *an exposure* is *an amount*; scenario element.` |
| a field no script reads | not declared (the ledger says so) |
| `assign` in `<peril>.premium.liquid` | a quantity: `the accident premium for *a pet* is *a number*.`, one template per step when the variable is reassigned (`the accident premium at step two for *a pet* is *a number*.`) |
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

The translator executes each script symbolically: it follows every branch,
keeps track of what each variable holds, and writes a rule for each value an
output filter receives. A variable that different branches set differently
becomes a cascade. From the Pet product's accident script:

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

The underwriting script sets a decision, and a later setting overrides an
earlier one, so the last setting in the script is tried first. The result is
a cascade of *provisional* decisions ending in `the underwriting decision for
a policy is a decision`. Notes are added, not overridden, so each note is a
rule of its own:

```le
rule underwriting_note_two_final with provenance "Pet/policy/underwriting.guidelines.liquid" at line 14:
the underwriting notes for a policy include "Policy does not meet guidelines for automatic acceptance as the pet is a Lion" if
    the policy is a policy
    and an exposure is insured under the policy
    and the pet type of the exposure is "Lion".
```

### Rate tables

A table the scripts look up is loaded from the carrier's own CSV file, copied
beside the program, as a decision table with unique match:

```le
the table pet_base_rates_table is loaded from pet_base_rates_table.csv, with unique match:
    key | value
```

A rule reads it and gives 0 for a key the table has no row for, as Liquid
reads a missing value (`nil`) in arithmetic:

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

A loop that accumulates becomes an aggregate. The gross premium, which the
platform computes, is derived the same way:

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

A product configuration carries no rating tests. So the translator makes
quotes: a base quote (the first value of each list field, representative
numbers, a table's first key for a lookup field), and variants that change
one list value, or cross a threshold a script compares a number with. It
keeps ten. It runs the product's Liquid on each, and every output becomes an
expectation of that quote's scenario:

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
translation computes. They are not Socotra's: the reference run imitates
Socotra's filters and arithmetic, without the platform.

## Traps

- **Upload a zip, not a JSON file.** A single `.json` is not recognised (see
  [What to upload](#what-to-upload)).
- **Classic configurations only.** The translator reads the JSON and Liquid
  configuration. Anything else in the upload (plugins, claims forms,
  permissions, document templates) is not translated.
- **No quotes without python-liquid.** Without it on the server the program
  has no scenarios, and nothing checks the translation against the product's
  Liquid. Test it on quotes you know the platform's answers for.
- **Residue.** A script the translator cannot follow is kept whole as a
  residue block, and whatever depends on it has no rule. The block says why,
  what it must conclude, and which fields it reads:

  ```le
  % RESIDUE r1 BEGIN: Homeowners/policy/underwriting.guidelines.liquid
  % TODO: translate the fragment below by hand, or with the Contract Assistant (residue mode); it was not translated automatically
  %   source: Homeowners/policy/underwriting.guidelines.liquid
  % Not translated: the variable dwelling_c is assigned inside a loop and read after it (Liquid keeps the last item's value).
  % Conclude: the underwriting decision for *a policy* is *a decision*; the underwriting notes for *a policy* include *a note*.
  ```

  What becomes residue: a filter that is not Liquid's arithmetic or one of
  Socotra's output filters (for example `get_30_360_day_count`, or `round`
  with a number of decimals, `round: 2`); arithmetic on dates or timestamps;
  a variable set inside a loop and read after it; a loop over a repeatable
  field group; a Liquid tag the translator does not know. In a twin, the
  expectations that depend on a residue block are kept as comments,
  `% pending — waits for residue r1:`, so that the tests run green while the
  gap stays visible. Translate the block by hand, or with the Contract
  Assistant's *Migration residue* mode, then restore those lines.
- **Missing values are 0.** Liquid reads a missing table row or a variable a
  script never assigns as `nil`: 0 in arithmetic, false in a comparison. The
  program reads 0 in arithmetic. A field a quote does not state is different:
  the rules that read it find nothing, so the output they compute may have no
  answer, where Liquid would compute with `nil`. A
  script that relies on a missing row *comparing* false can therefore behave
  differently. The ledger marks each lookup *approximated*, and lists every
  variable that is read but never assigned (a defect of the source, which the
  program copies).
- **Numbers are the source's floating point.** Amounts are computed as the
  Liquid computes them, with no rounding of its own, so expectations can read
  `0.8500000000000001` or `686.0`. The quote desk shows 2 decimals; queries
  and tests show the exact value. Liquid's `round` rounds half away from zero,
  as the program does.
- **Integer division.** Liquid's `divided_by` divides two whole numbers with
  integer division. Where both operands are known to be whole, the program
  writes `//` (`N = M // 100`), which is right for whole-number inputs only.
  Where the types are not known before run time, it writes `/`. The ledger
  marks both *approximated*.
- **Text and numbers.** A list value that reads as a number becomes a number,
  and a table key such as `0005` is read as 5. A value that starts with a
  comparison sign is spelled out (`<50%` becomes `under 50%`) in the rules,
  the scenarios and the copied table alike, because an LE table cell starting
  with `<` is a condition. When you state a quote by hand, write numbers
  unquoted: `the atfault claims past five years of policy 1 is "2"` never
  matches a rule that compares with the number 2. The verifier warns about a
  value no rule can read where it stands.
- **Type names come from the source's words.** Templates are named after
  Socotra's field and variable names ("the pet breed dog of a pet", "the
  accident premium at step two"), and a variable's type after its first use,
  so a key holding `"A"` can be typed *a number*. The meaning is right; the
  wording may need editing.
- **The first exposure is any exposure.** `data.policy.exposures[0]` is read
  as "an exposure of the policy": the same when the policy has one exposure of
  that kind, not when it has several.
- **Loops ignore order.** A decision written inside a loop is read as
  "written when some item satisfies the condition". Which item Liquid visited
  last is not modelled.
- **Gross premium and taxes are sums.** The platform also counts
  endorsements and term changes; a single quote has none, so the sum is exact
  there and nowhere else.
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

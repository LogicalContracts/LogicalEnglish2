# Authoring guide: a DME MAC policy in Logical English

How the policy programs of this directory are written, so that several
authors (people or agents) produce the same kind of program. Read
`dmepos.le` (the library every policy includes), `pap.le` and `pmd.le` (two
finished policies) and `pap_cases.le` / `pmd_cases.le` (their test cases)
before writing; `docs/le_summary.md` (§2, §3, §4, §7, §17.1, §17.3, §17.4,
§17.7) is the language reference; `examples/RulesRus/customs/README.md`
("Method") is the method this follows.

## What a policy program is

One file per LCD (or per small family: the three support-surface LCDs are
one program), named after the policy: `oxygen.le`, `hospital_beds.le`. It

1. **includes `dmepos.le`** (`the knowledge base <name> includes these resources: dmepos.`)
   and never redefines its templates;
2. **cites its documents**: `LCD L33820 is published at "<MCD url>".`,
   `the text of LCD L33820 is at "sources/lcd/L33820.txt".`, the same for the
   Policy Article (`Policy Article A52508`, `sources/article/A52508.txt`) and
   the NCD if there is one (`NCD 280 7` — no dot in a constant — at
   `sources/ncd/NCD_280.7.txt`);
3. in **`section applicability is:`** says which codes it decides and their
   benefit, and whether it has documentation requirements of its own:
   ```le
   rule beds_codes with provenance Policy Article A52508, confer "<passage>":
   the policy for code a code is hospital beds
       if the code is in ["E0250", "E0251", ...].          % ONE line per list
   rule beds_benefit with provenance Policy Article A52508, confer "<passage>":
   the benefit category of code a code is durable medical equipment
       if the policy for code the code is hospital beds.
   hospital beds has no specific documentation requirements.
   ```
   (or, in `section remedy is:`, rules for
   `the policy specific documentation requirements are met for a claim`
   guarded by `the policy of the claim is hospital beds`, as `pmd.le` does).
   Put the code-list rules (`the policy for code ...`) BEFORE the first
   section marker, not in `applicability`: in a program that includes
   several policies, another policy's guard `the policy of the claim is X`
   would otherwise charge a claim's documentation failure to applicability;
4. in **`section question is:`** states when **`a claim is reasonable and
   necessary`** — the LCD's "Coverage Indications, Limitations and/or Medical
   Necessity", criterion by criterion, each rule labelled and citing its
   passage:
   ```le
   rule beds_semi_electric with provenance LCD L33820,
           confer "A semi-electric hospital bed (E0260, E0261) is covered if":
   a claim is reasonable and necessary
       if the claim is for an item
       and the HCPCS code of the item is a code
       and the code is in ["E0260", "E0261"]
       and the item is furnished to a beneficiary
       and the beneficiary meets the criteria for a fixed height hospital bed
       and the finding needs frequent changes in body position about the beneficiary is established.
   ```
   Everything else in `dmepos.le` (orders, delivery, benefit, continued need)
   is already done: a policy states only its own criteria. Rules that are the
   model's own devices (not the text's) have no provenance and a comment
   saying so.

The scenario programs (`<policy>_cases.le`) include the policy and hold the
queries `pay`, `rn`, `stage`, `flip` exactly as `pap_cases.le` does, `pay`
first (so `stage` reads its checklist).

## The vocabulary

- **The claim**: `claim 1 is for the hospital bed.`, `the HCPCS code of the
  hospital bed is "E0260".`, `the hospital bed is furnished to Ann.`, `the
  date of service of claim 1 is 2026-03-01.`, `the rental month of claim 1 is
  1.` (omit for a purchase; `claim 1 is a refill.` for a refill of
  supplies). Items are constants with the definite article (`the hospital
  bed`, `the CPAP device`), beneficiaries first names (`Ann`).
- **What the record states** is a scenario fact: a template marked
  `; undefined` in the policy, phrased as the document would state it — a
  measurement (`the AHI of the sleep test of Ann is 22.`), a dated event
  (`Ann had an in-person clinical evaluation by the treating practitioner on
  2026-01-10.`), a documented condition (the shared template `the medical
  record of Ann documents hypertension.`), an attribute. Numbers, not
  categories, where the LCD gives a threshold, so the threshold is in the
  rule. Never `; assumable`: what is not stated is not met.
- **What someone finds** is the shared judged template
  `the finding <finding> about <beneficiary> is established` (or
  `unsupported`), with `according to <who>` and, for a Council's finding,
  `because "<why>"`: a clinical judgment the treating practitioner records
  and a reviewer accepts or rejects ("the mobility limitation cannot be
  resolved by a walker", "oxygen will improve the condition", "needs
  frequent changes in body position"). Name findings as short lowercase
  phrases **without** `and`, `or`, `not`, `no`, articles, capitals or
  digits — `walking aids insufficient`, `home accommodates scooter` — and
  list them, with the criterion each stands for, in the program's header
  comment. Where the LCD offers alternatives (criterion J *or* K), make ONE
  finding whose reasons are the alternatives, not one finding per
  alternative: a recorded finding closes its question, and an unrecorded
  one is *assumed* (a judgment needed), so two findings for one criterion
  give two conditional answers.
- **Derived predicates** for the criteria the LCD names, so explanations read
  like the LCD: `a beneficiary meets the criteria for a fixed height
  hospital bed`, `the sleep test of a beneficiary meets the AHI criterion`.
- **Codes are quoted strings**: `"E0260"`, in facts, rules, lists and table
  cells. A bare `E0260` is read as a VARIABLE (the ALL-CAPS id convention)
  and silently matches anything.
- **Lists on one line.** `the code is in ["E0250", "E0251", ...]` must not
  wrap: a list broken over lines does not parse and the rule is lost
  without an error.
- **Dates**: `2026-03-01`; day arithmetic with `the date is a number days
  after the other date` (the number is negative when the first date is
  earlier); `is before or equal to`, `is after`. Six months is 183 days,
  twelve months 365, ninety days 90 — say so in a comment.
- **`otherwise` splits the whole body**: everything before `otherwise`
  (bindings included) is the first alternative, so a variable bound there
  is unbound in the next one. Put the cascade in a helper rule whose head
  binds every variable it needs: `the quantity of a claim is allowed for a
  beneficiary if the claim is within the listed amount otherwise the finding
  excess quantity explained about the beneficiary is established.` Use it
  for "a finding only when the record's own facts do not already decide"
  (an excess quantity, a judgment behind a measurable criterion).
- **Negative numbers** (`the number >= -2`, a fact `... -1 hours after
  ...`) are read as numbers since 13 September 2026 (before, `-5` was a
  compound and comparisons with it were silently wrong). A record is still
  clearer with two templates (`N hours before`, `N hours after`).
- **Arithmetic** goes through `is`: `and a limit is the quantity * 3 and the
  billed number <= the limit`. A comparison does not evaluate an
  expression (`the number <= the quantity * 3` compares terms and passes).
- **ICD-10 code tables** of the Policy Article are data, not prose:
  `sources/icd10/A<article>_icd10_covered.csv` (columns
  `code,group,article,description`, every cell quoted; the group numbers
  are the article's "Group N" paragraphs — list which HCPCS codes each group
  serves in the policy's header comment, from the article text). Load one as
  a table (docs/le_summary.md §17.3, `examples/RulesRus/loaded_table.le`);
  the CSV columns bind to the template's arguments IN ORDER, so the template
  must name the code first, then the group, the article, the description:
  ```le
  the templates are:
      ICD10 code *a code* is in group *a group* of article *an article* as *a description* under table nebulizer_icd10.
  the table nebulizer_icd10 is loaded from sources/icd10/A52466_icd10_covered.csv, with all matches:
      code | group | article | description
  ```
  and read it in a rule with the code as a quoted string: `and the diagnosis
  code of the beneficiary is a code and ICD10 code the code is in group 3 of
  article "A52466" as a description under table nebulizer_icd10` (tested:
  `ICD10 code "J44.1" is in group which group ...` answers groups 2, 3, 6).
  Write "ICD10", not "ICD-10", in template words (a hyphen renders as
  "ICD - 10").

## Provenance

- Every rule: `rule <label> with provenance <document>, confer "<passage>":`.
  The passage is copied VERBATIM from the document's text file in
  `sources/` (the verifier checks it, whitespace and case aside — a
  `quote_not_found` warning means it is not there): copy from the `.txt`,
  not from memory, and keep it short (one clause).
- A knowledge-base fact cites the same way, as trailers:
  `hypertension is a qualifying symptom for PAP, as stated in LCD L33718, confer "Hypertension, ischemic heart disease, or history of stroke".`
  A labelled `rule x with provenance ...:` in front of a FACT (no `if`) does
  not parse — and everything after it in the file is silently lost. Use the
  trailer form for facts.
- Passages must not contain `%` (it starts a comment even inside quotes —
  cut the quotation before the sign).
- Document constants have no dots and no `and`/`or` (`NCD 280 7`, `the CMS
  required face-to-face list`).

## Pitfalls that cost time

- **Bind before negating.** `if it is not the case that the claim is a
  refill` with `the claim` not yet bound succeeds vacuously; write `if the
  claim is for an item and it is not the case that ...`. The same for a
  judged condition: bind the beneficiary first.
- **`the X` before `a X` is a constant, not a variable.** Introduce every
  variable with `a`/`an` before referring to it with `the`.
- **Type words in variable names**: `a number`, `an other number`, `a second
  number`, `a third number` are distinct variables of type number; `a
  quantity` and `a limit` are other types — fine in arithmetic.
- **Sections and `stage`.** `the query fails at which section` blames the
  earliest section (applicability, question, remedy) holding a rule for a
  goal the attempt tried and could not prove. Keep only the scope and
  benefit rules in `applicability`; put helper rules that may fail on a
  covered claim (what an accessory is, what a device is) BEFORE the first
  section marker (section `main`, blamed last).
- **Run from the repository root**, never from the medicare directory:
  ```
  ./myswipl.sh -g "use_module(le_kbs), verify('examples/RulesRus/medicare/<policy>_cases.le'), halt." 2>&1 | grep -v "untested_predicate\|Fix: add a query\|Position:" 
  ```
  A `failed_test` prints the expected and the actual answers; `PASS`/`FAIL`
  lines summarise. To see what an intermediate predicate answers, add a
  query for it with `expects answers []` and read the "Actual" line.
- Warnings to fix: `missing_template` (a sentence matches no template —
  usually a wording difference), `quote_not_found`, `unread_value` (a
  scenario value no rule reads — a spelling), `unconsumed_facts`,
  `unused_template`. `untested_predicate` on helpers is acceptable.
- `flip` needs the goal to hold OUTRIGHT after at most 3 changes: with
  unrecorded findings in the way it returns nothing. Test `flip` on a
  scenario where one documentation fact is missing.

## The cases

`<policy>_cases.le`: 8–15 synthetic scenarios, each a comment saying what it
tests: one complete, payable claim (every criterion and every documentation
requirement stated — copy the order/delivery block of `pap_cases.le`); one
scenario per coverage criterion that fails it (`rn expects answers []`); the
alternative paths of the LCD (each group, each qualifying route); a
continued-coverage or refill claim if the LCD has one; a claim that is
reasonable and necessary but fails a documentation requirement
(`pay expects answers []`, `stage expects answers ["the query fails at remedy"]`,
`flip expects changes [["add: ..."]]`); one with a Council-style
`unsupported` finding. Every `expects` is what the model answers — write the
expectation, run, and if the model is right and the expectation wrong fix
the expectation; if the model is wrong fix the rule.

## The Council decisions

`sources/council/` holds the text of the Medicare Appeals Council's
published DME and supplier decisions (2003–2016). A scenario transcribing one
is written like the customs rulings (`customs/cbp_61.le`): the program says
`scenario facts require provenance.`, declares
`Council decision dbc_partb is published at "https://www.hhs.gov/sites/default/files/static/dab/decisions/council-decisions/dbc_partb.pdf".`
and `the text of Council decision dbc_partb is at "sources/council/dbc_partb.txt".`,
and the scenario opens `scenario dbc_partb is, as stated in Council decision dbc_partb:`;
each fact quotes its passage (`confer "..."`), the Council's findings say
`according to the Council` with `because "..."`, and the practitioner's say
`according to the treating practitioner`. The Council's outcome is NEVER a
fact: it goes in the comment above the scenario (`% Council: not covered —
delivery not within 120 days of the face-to-face examination`), and the
expectation is what the model derives; where it differs from the Council's,
the comment says `DISAGREES` and why (a criterion of the LCD version the
Council applied that the current LCD no longer has; a fact the decision
does not state). Dates are transcribed as dates; a decision that gives a
duration ("119 days after") gets the dates it implies, with the passage.

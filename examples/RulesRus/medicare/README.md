# Medicare DMEPOS coverage in Logical English

Step 4 of the plan in RulesRUs §8 — §2.1 of that report is the plan, this
directory the implementation: the coverage criteria of the DME MAC policies
(Local Coverage Determinations, their Policy Articles and the National
Coverage Determinations they rest on) as Logical English, run on claims and
on the Medicare Appeals Council's published decisions. Built 12–13 September
2026, the customs model (`../customs/`) as the method.

**Phase A (done):** the shared DMEPOS library and 16 LCDs — the policies that
carry about 70% of DMEPOS claim lines and 45% of the payments (RulesRUs
§2.1) — with 207 synthetic scenarios and 13 Council decisions transcribed.
**Phase B (in progress):** the other 42 DME LCDs, one A/B policy across its
six jurisdictions, more Council decisions.

## Files

| File | What it is |
|---|---|
| `dmepos.le` | The library every policy includes: the claim and the item, the benefit category and the home (42 CFR 410.38, Benefit Policy Manual ch. 15), the standard written order, the written order prior to delivery and the face-to-face encounter (410.38, article A55426, the CMS Required Lists — 105 and 82 codes as one-line lists), proof of delivery, prior authorization, continued need and use, refills; the judged template every clinical finding uses. Sections `applicability` and `remedy`; the policies supply `question`. |
| `<policy>.le` | One program per LCD (table below): the codes it decides and their benefit, `a claim is reasonable and necessary` criterion by criterion, each rule labelled and quoting its passage; the documents' addresses and texts. |
| `<policy>_cases.le` | Synthetic claims: one complete payable claim, one failure per criterion, the alternative routes, a documentation failure with the stage and the flip, a Council-style unsupported finding. `pap_cases.le` and `pmd_cases.le` also declare a reviewer's view. |
| `dmepos_all.le` | The whole model: includes every policy, as `tariff.le` includes the chapters. `all_cases.le` runs claims of several policies through it. |
| `council_pmd.le` | 13 Medicare Appeals Council decisions on power mobility, transcribed with every fact quoting the decision, compared with the Council's outcome. |
| `GUIDE.md` | The authoring guide the policies follow (vocabulary, provenance, pitfalls, cases); written after the first three policies, used by the agents that wrote the rest. |
| `sources/` | The cited texts: `lcd/`, `article/`, `ncd/` from the Medicare Coverage Database export of 12 September 2026 (58 DME LCDs, 59 articles, 12 NCDs); `icd10/` the articles' ICD-10 covered-code tables as CSV (code, group, article, description), loaded as decision tables; `cfr/` 42 CFR 410.38, 405.1062, 424.57, 410.32 and the CMS Required Lists; `manuals/` PIM chapter 5, BPM chapter 15; `council/` the 48 DME and supplier decisions the Council published (2003–2016); `courts/` 8 federal opinions; `ab/` the six Vitamin D LCDs and articles (Phase B). |

Run a program's tests the usual way, from the repository root:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/RulesRus/medicare/pmd_cases.le', R), print_test_result(R), halt."
```

Queries: `pay` (which claim is payable), `rn` (which claim is reasonable and
necessary — the question the appeal record decides), `stage` (at which
section a claim fails: applicability, question, remedy), `flip` (the minimal
change that would make a claim payable).

## How a claim is read

A claim is for one item (a device, an accessory, a supply), coded with its
HCPCS code, furnished to a beneficiary, on a date of service, for a rental
month (absent for a purchase) or as a refill. Three things decide it:

- **Applicability** (`dmepos.le`): the item's code belongs to a modelled
  policy; the item is within a Medicare benefit — durable medical equipment
  used in a home (not a hospital or SNF), or a statutory benefit such as
  therapeutic shoes; an item no policy codes can still be DME by the
  Manual's four characteristics.
- **The question** (the policy): the LCD's coverage criteria. What the record
  states is a scenario fact — a measurement (`the AHI of the sleep test of
  Ann is 22`), a dated event, a documented condition (`the medical record of
  Ann documents hypertension`), a diagnosis code checked against the
  article's ICD-10 table. What someone finds is one judged template, `the
  finding walking aids insufficient about Ann is established` (or
  `unsupported`), with who found it and why: the treating practitioner in
  the face-to-face note, the reviewer, the Council. A finding nobody made
  leaves the answer conditional — a judgment needed — as in the customs
  model; where the LCD offers alternatives (criterion J *or* K), they are one
  finding, so a recorded finding closes its question.
- **The remedy** (`dmepos.le` and the policy's own): the order (its elements,
  its timing before delivery or before the claim, the face-to-face encounter
  within six months for the codes on the Required List), proof of delivery,
  the prior authorization for the codes on that list, continued need and use
  after the first month, the refill contact within 30 days, and what the
  Policy Article adds (a power mobility device: the order written by the
  practitioner who examined the beneficiary, the home assessment, delivery
  within six months of the authorization; oxygen: the 36-month cap;
  therapeutic shoes: the certifying physician's statement).

Every rule cites its passage (`rule pap_criterion_b1 with provenance LCD
L33718, confer "The apnea-hypopnea index (AHI) or Respiratory Disturbance
Index (RDI) is greater than or equal to 15 events per hour with a minimum of
30 events":`), the verifier checks each quotation against the text in
`sources/`, and the editor's § badge opens the passage. Six months is read as
183 days, twelve months as 365.

## The model

| Program | Policy | Texts | Lines of LE | Labelled rules | Tables | Findings | Scenarios | Expectations |
|---|---|---|---:|---:|---:|---:|---:|---:|
| `dmepos.le` | The shared library | — | 395 | 25 | 0 | 0 | 0 | 0 |
| `pap.le` | Positive airway pressure devices | L33718, A52467, NCD 240.4 | 336 | 22 | 2 | 0 | 12 | 20 |
| `rad.le` | Respiratory assist devices | L33800, A52517 | 569 | 45 | 0 | 4 | 18 | 24 |
| `oxygen.le` | Oxygen and oxygen equipment | L33797, A52514, NCD 240.2 | 437 | 39 | 0 | 1 | 14 | 20 |
| `nebulizers.le` | Nebulizers and inhalation drugs | L33370, A52466 | 722 | 57 | 6 | 5 | 16 | 31 |
| `pmd.le` | Power mobility devices | L33789, A52498, NCD 280.3 | 434 | 26 | 0 | 17 | 11 | 16 |
| `manual_wheelchairs.le` | Manual wheelchair bases | L33788, A52497, NCD 280.3 | 389 | 28 | 0 | 13 | 17 | 27 |
| `wheelchair_options.le` | Wheelchair options and accessories | L33792, A52504 | 611 | 49 | 0 | 11 | 15 | 24 |
| `wheelchair_seating.le` | Wheelchair seating | L33312, A52505 | 503 | 46 | 0 | 2 | 17 | 30 |
| `hospital_beds.le` | Hospital beds and accessories | L33820, A52508, NCD 280.7 | 350 | 20 | 0 | 8 | 17 | 32 |
| `walkers.le` | Walkers | L33791, A52503 | 264 | 19 | 0 | 5 | 13 | 22 |
| `seat_lifts.le` | Seat lift mechanisms | L33801, A52518, NCD 280.4 | 157 | 9 | 0 | 4 | 12 | 22 |
| `support_surfaces.le` | Pressure reducing support surfaces, groups 1–3 | L33830, L33642, L33692, A52489, A52490, A52468 | 525 | 31 | 0 | 4 | 16 | 29 |
| `glucose_monitors.le` | Glucose monitors and CGM | L33822, A52464, NCD 40.2 | 537 | 44 | 1 | 2 | 15 | 30 |
| `therapeutic_shoes.le` | Therapeutic shoes for diabetics | L33369, A52501 | 474 | 32 | 1 | 1 | 14 | 27 |
| **Total** | 15 programs, 16 LCDs | | **6,703** | **492** | **10** | | **207** | **354** |

Findings are the judged questions each policy asks (listed in its header
comment). Nebulizers, glucose monitors and therapeutic shoes read the
articles' ICD-10 tables as loaded decision tables (1,344, 461 and 428 rows
regenerated from the export, not typed). The whole model (`dmepos_all.le`)
loads in about 13 s; a policy's cases file runs in 5–30 s.

Every expectation passes (Phase A, 13 September 2026): 354 in the cases
files, 1 in `all_cases.le`, 26 in `council_pmd.le`.

## The Council decisions

`council_pmd.le`: the 13 power-mobility decisions of the 33 DME decisions the
Council published (2009–2015), each transcribed from its text with every
fact quoting its passage, the practitioner's findings as the record shows
them and the Council's findings as its own (`according to the Council,
because "..."`), the outcome never a fact. The model's answer against the
Council's:

| Decision | Council | Model |
|---|---|---|
| 11-705, allied_home, m-11-2121 (two claims), m_12_1315 | not covered: criteria A, B or C unsupported | not reasonable and necessary — agrees |
| dbc_partb | not covered: never delivered within 120 days of the examination | not reasonable and necessary (N unsupported), not payable (no proof of delivery) — agrees on the outcome; the 120-day rule is not in the current LCD |
| m_11_2642 | not covered, but payable under §1879 (limitation of liability) | not reasonable and necessary — agrees on coverage; §1879 is outside the model |
| 11-332 | covered; a countersigned PT evaluation is a valid face-to-face | reasonable and necessary, conditional on the home finding the record lacks |
| 11-1835, keelers | replacement within the useful lifetime (denied / allowed on weight) | conditional on the clinical findings the decisions do not revisit; the replacement rule (BPM ch. 15 §110.2) is not modelled |
| affordable_home_care, m_11_2511, extreme_mobility | covered | no answer: the decisions state no weight (the weight class is a gate in the model), no specialty evaluation or ATP, and findings the Council took as given |
| webb_medical | covered (an accessory) | outside `pmd.le` (wheelchair options) |

Seven outcomes agree, six differ, each difference explained in the file: a
fact the decision does not state (most often the beneficiary's weight, which
the current LCD's weight-class criterion needs and the Council never
treated as a gate), a rule of the old LCD the current one lacks (the 120-day
delivery rule), a rule outside the model (replacement within the useful
lifetime, limitation of liability), or a finding nobody made. The `pay`
question can never succeed on these decisions: the standard written order's
`quantity` element and the prior-authorization programme postdate them.

## What the scale-up taught

- **The judged finding is the right unit for a coverage criterion.** The
  LCDs' criteria are findings about the beneficiary ("cannot be resolved by a
  cane or walker"), recorded by one party and accepted or rejected by
  another; one template with the finding's name, the person and the reason
  serves every policy, and the extractor is offered the finding names.
- **Alternatives must be one question.** Two judged findings for one
  criterion (J or K) give two conditional answers; one finding whose reasons
  are the alternatives gives one.
- **The section checklist needed two refinements**, made in the engine: a
  failed sub-goal under a goal that succeeded by another clause is `moot`
  (`reasoner:goal_attempt/5`), and a failure is charged to the section of the
  rule that called the condition, not to the section of the predicate's own
  rules (`le_sections:failed_sections/4`). Without them any policy with
  alternative rules blamed `question` for a documentation failure, and a
  guard such as `the policy of the claim is pmd` in another policy's remedy
  rule blamed `applicability`.
- **Table cells with the word "and"** were read as conditions and dropped
  (`le_tables:parse_cell/2`): 144 ICD-10 descriptions of the nebulizer table.
  A conjunction now needs every part to be a condition.
- **LE gotchas** (all in `GUIDE.md`): a bare `E0601` is a variable (the
  all-caps id convention) — codes are quoted strings; a list broken over
  lines drops its rule silently; a labelled `rule ...:` in front of a fact
  loses the rest of the file; `and`/`or` inside a constant break the parse; a
  comparison does not evaluate an expression; loaded CSV columns bind to the
  template's arguments by position; negate after binding.
- **Effort.** The three policies of the first day (PAP, PMD, oxygen) took
  about six hours with the library and the guide; the other thirteen were
  written by ten parallel agents from the guide in about two hours each,
  every one passing its own cases on delivery, then consolidated (five
  shared templates moved into the library) and re-verified.

## Not modelled (Phase A)

Replacement within the reasonable useful lifetime and after loss or
irreparable damage (BPM ch. 15 §110.2), repairs, the limitation of liability
(§1879), beneficiaries entering Medicare with equipment, the KX/GA/GZ
modifiers and the coding-verification (PDAC) rules, payment amounts and the
capped-rental categories, the flow-rate and titration rules of oxygen with
PAP, the sleep-test provider qualifications, and each policy's smaller
exclusions listed in its header comment.

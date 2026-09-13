# Medicare DMEPOS coverage in Logical English

Step 4 of the plan in RulesRUs §8 — §2.1 of that report is the plan, this
directory the implementation: the coverage criteria of **all 58 Local
Coverage Determinations of the four DME MACs** (with their Policy Articles
and the National Coverage Determinations they rest on), one A/B policy
across its six jurisdictions, and the claims they decide, as Logical
English; run on synthetic claims and on 36 decisions of the Medicare Appeals
Council. Built 12–13 September 2026, with the customs model (`../customs/`)
as the method.

| Plan (RulesRUs §2.1) | Done |
|---|---|
| Phase A: the shared library and 16 LCDs (PAP, RAD, oxygen, nebulizers, power mobility, manual wheelchairs, options, seating, beds, walkers, seat lifts, support surfaces ×3, glucose monitors, therapeutic shoes) | yes |
| Phase B (1): the other 42 DME LCDs | yes — all 58 |
| Phase B (2): one A/B policy across its jurisdictions, ICD-10 tables generated from the export | yes — Vitamin D assay testing, six LCDs, six loaded tables |
| Phase B (3): versioned rules — a claim judged by the LCD version in effect on its date of service | yes, for two changes (CGM criteria 2017/2021/2023, the refill window before and after 2024), from the export's revision history |
| Council decisions, DME and supplier topics | 36 of the 48 transcribed and compared (the other 12 have no DME LCD) |
| Blind extraction ("facts from a document") on Council decisions | run on ten decisions with two open-weight models, measured against the hand transcriptions |

## Files

| File | What it is |
|---|---|
| `dmepos.le` | The library every policy includes: the claim and the item; the benefit category and the home (42 CFR 410.38, BPM ch. 15 §110.1); the standard written order, the written order prior to delivery and the face-to-face encounter (410.38, article A55426, the CMS Required List); proof of delivery; prior authorization (the CMS Required List); continued need and use; refills, with the rule in force before 2024; the judged template every clinical finding uses; shared record templates (weight, diagnosis code, specialty evaluation, ATP). |
| `<policy>.le` | One program per LCD (support surfaces: one for its three LCDs), table below: the codes it decides and their benefit, `a claim is reasonable and necessary` criterion by criterion, each rule labelled and quoting its passage, and what its Policy Article adds as a condition of payment. |
| `<policy>_cases.le` | Synthetic claims: a complete payable claim, one failure per criterion, the alternative routes, a documentation failure with its stage and flip, a Council-style unsupported finding. `pap_cases.le` and `pmd_cases.le` also declare a reviewer's view. |
| `dmepos_all.le`, `all_cases.le` | The whole model: all 56 DME programs in one, and claims across policies run through it. |
| `glucose_versions_cases.le` | The versioned rules: the same claim on different dates of service. |
| `council_pmd.le`, `council_other.le`, `council_more.le`, `council_supplies.le` | The Council decisions, every fact quoting the decision, compared with the Council's outcome. |
| `blind_extraction.le` | What the editor's extraction path wrote, unedited, for ten of those decisions. |
| `GUIDE.md` | The authoring guide every policy after the first three was written from (vocabulary, provenance, pitfalls, cases). |
| `sources/` | The cited texts (8 MB): `lcd/` (58 LCDs, 130k words), `article/` (59 Policy Articles), `ncd/` (12), `history/` (the revision history of 63 LCDs), `icd10/` (the articles' ICD-10 covered-code tables as CSV, loaded as decision tables), `ab/` (the six Vitamin D LCDs, articles and tables), `cfr/` (42 CFR 410.38, 405.1062, 424.57, 410.32, the CMS Required Lists), `manuals/` (PIM ch. 5, BPM ch. 15), `council/` (the 48 DME and supplier decisions the Council published, 2003–2016), `courts/` (8 federal opinions). All from the Medicare Coverage Database export and public HHS/CMS sites, 12 September 2026. |

Run a program's tests from the repository root:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/RulesRus/medicare/pmd_cases.le', R), print_test_result(R), halt."
```

Queries: `pay` (which claim is payable), `rn` (which claim is reasonable and
necessary — the question the appeal record decides), `stage` (the section a
claim fails at: applicability, question, remedy), `flip` (the minimal change
that would make a claim payable).

## How a claim is read

A claim is for one item (a device, an accessory, a supply, a drug), coded
with its HCPCS code, furnished to a beneficiary, on a date of service, for a
rental month (absent for a purchase) or as a refill. Three things decide it:

- **Applicability** (`dmepos.le`): the item's code belongs to a modelled
  policy; the item is within a Medicare benefit — durable medical equipment
  used in a home (not a hospital or SNF), or a statutory benefit such as
  prosthetic devices, braces, surgical dressings, therapeutic shoes, the oral
  drug benefits.
- **The question** (the policy): the LCD's coverage criteria. What the record
  states is a scenario fact — a measurement (`the AHI of the sleep test of
  Ann is 22`), a dated event, a documented condition (`the medical record of
  Ann documents hypertension`), a diagnosis code checked against the
  article's ICD-10 table. What someone finds is one judged template (`the
  finding walking aids insufficient about Ann is established`, or
  `unsupported`), with who found it and why: the treating practitioner, the
  reviewer, the Council. A finding nobody made leaves the answer conditional —
  a judgment needed.
- **The remedy** (`dmepos.le` and the policy's own): the order, its timing,
  the face-to-face encounter, proof of delivery, prior authorization,
  continued need and use, refills, and what each Policy Article adds (the
  home assessment and six-month delivery window of a power wheelchair, the
  36-month cap of oxygen, the certifying physician's statement of therapeutic
  shoes, the prosthetist's functional-level records of a lower-limb
  prosthesis, the month's-supply caps of supplies and drugs).

Every rule cites its passage; the verifier checks each quotation against the
text in `sources/`; the editor's § badge opens it. Six months is read as 183
days, twelve months as 365.

## The model

| Family | Program | Policy | LCD | Lines | Rules | Scenarios | Expectations |
|---|---|---|---|---:|---:|---:|---:|
| Breathing and sleep | `pap` | Positive airway pressure devices (OSA) | L33718 | 338 | 22 | 12 | 20 |
|  | `rad` | Respiratory Assist Devices | L33800 | 571 | 45 | 18 | 24 |
|  | `oxygen` | Oxygen and Oxygen Equipment | L33797 | 439 | 39 | 14 | 20 |
|  | `nebulizers` | Nebulizers | L33370 | 724 | 57 | 16 | 31 |
|  | `oral_appliances` | Oral Appliances for Obstructive Sleep Apnea | L33611 | 197 | 9 | 8 | 14 |
|  | `hfcwo` | High Frequency Chest Wall Oscillation Devices | L33785 | 218 | 15 | 8 | 16 |
|  | `ipv` | Intrapulmonary Percussive Ventilation System | L33786 | 84 | 4 | 5 | 14 |
|  | `mechanical_insufflation` | Mechanical In-exsufflation Devices | L33795 | 151 | 11 | 6 | 14 |
|  | `suction_pumps` | Suction Pumps | L33612 | 348 | 25 | 8 | 17 |
|  | `tracheostomy_supplies` | Tracheostomy Care Supplies | L33832 | 301 | 15 | 8 | 17 |
| Mobility | `pmd` | Power Mobility Devices | L33789 | 436 | 26 | 11 | 16 |
|  | `manual_wheelchairs` | Manual Wheelchair Bases | L33788 | 391 | 28 | 17 | 27 |
|  | `wheelchair_options` | Wheelchair Options/Accessories | L33792 | 613 | 49 | 15 | 24 |
|  | `wheelchair_seating` | Wheelchair Seating | L33312 | 505 | 46 | 17 | 30 |
|  | `walkers` | Walkers | L33791 | 266 | 19 | 13 | 22 |
|  | `canes_crutches` | Canes and Crutches | L33733 | 108 | 5 | 7 | 15 |
|  | `seat_lifts` | Seat Lift Mechanisms | L33801 | 159 | 9 | 12 | 22 |
|  | `patient_lifts` | Patient Lifts | L33799 | 153 | 9 | 8 | 16 |
|  | `commodes` | Commodes | L33736 | 207 | 14 | 10 | 18 |
| Beds and surfaces | `hospital_beds` | Hospital Beds And Accessories | L33820 | 352 | 20 | 17 | 32 |
|  | `support_surfaces` | Pressure reducing support surfaces, groups 1–3 | L33642, L33692, L33830 | 527 | 31 | 16 | 29 |
| Diabetes | `glucose_monitors` | Glucose Monitors | L33822 | 539 | 44 | 15 | 30 |
|  | `therapeutic_shoes` | Therapeutic Shoes for Persons with Diabetes | L33369 | 470 | 32 | 14 | 27 |
|  | `external_infusion_pumps` | External Infusion Pumps | L33794 | 512 | 36 | 9 | 19 |
| Orthotics and prosthetics | `afo_kafo` | Ankle-Foot/Knee-Ankle-Foot Orthosis | L33686 | 428 | 32 | 15 | 25 |
|  | `knee_orthoses` | Knee Orthoses | L33318 | 601 | 43 | 9 | 15 |
|  | `spinal_orthoses` | Spinal Orthoses: TLSO and LSO | L33790 | 212 | 14 | 8 | 16 |
|  | `orthopedic_footwear` | Orthopedic Footwear | L33641 | 263 | 19 | 8 | 15 |
|  | `lower_limb_prostheses` | Lower Limb Prostheses | L33787 | 448 | 31 | 8 | 14 |
|  | `breast_prostheses` | External Breast Prostheses | L33317 | 256 | 16 | 9 | 16 |
|  | `eye_prostheses` | Eye Prostheses | L33737 | 186 | 12 | 9 | 17 |
|  | `facial_prostheses` | Facial Prostheses | L33738 | 274 | 22 | 8 | 17 |
|  | `refractive_lenses` | Refractive Lenses | L33793 | 337 | 24 | 7 | 13 |
| Wounds, ostomy, continence, nutrition | `surgical_dressings` | Surgical Dressings | L33831 | 626 | 42 | 9 | 18 |
|  | `npwt` | Negative Pressure Wound Therapy Pumps | L33821 | 441 | 29 | 14 | 26 |
|  | `ostomy_supplies` | Ostomy Supplies | L33828 | 418 | 18 | 8 | 19 |
|  | `urological_supplies` | Urological Supplies | L33803 | 698 | 46 | 9 | 18 |
|  | `bowel_management` | Bowel Management Devices | L36267 | 97 | 4 | 8 | 22 |
|  | `enteral_nutrition` | Enteral Nutrition | L38955 | 411 | 23 | 10 | 22 |
|  | `parenteral_nutrition` | Parenteral Nutrition | L38953 | 318 | 23 | 8 | 17 |
| Drugs | `immunosuppressive_drugs` | Immunosuppressive Drugs | L33824 | 337 | 25 | 9 | 19 |
|  | `oral_anticancer` | Oral Anticancer Drugs | L33826 | 253 | 14 | 9 | 19 |
|  | `oral_antiemetic` | Oral antiemetic drugs | L33827 | 318 | 28 | 8 | 16 |
|  | `ivig` | Intravenous Immune Globulin | L33610 | 211 | 16 | 8 | 18 |
| Stimulators and other devices | `tens` | Transcutaneous Electrical Nerve Stimulators (TENS) | L33802 | 395 | 27 | 9 | 15 |
|  | `tejsd` | Transcutaneous Electrical Joint Stimulation Devices (TEJSD) | L34821 | 89 | 2 | 5 | 16 |
|  | `osteogenesis_stimulators` | Osteogenesis Stimulators | L33796 | 257 | 15 | 8 | 14 |
|  | `tremor_stimulator` | External Upper Limb Tremor Stimulator Therapy | L39591 | 289 | 18 | 8 | 15 |
|  | `tumor_treatment_field` | Tumor Treatment Field Therapy (TTFT) | L34823 | 284 | 19 | 8 | 14 |
|  | `aeds` | Automatic External Defibrillators | L33690 | 402 | 27 | 12 | 24 |
|  | `speech_generating_devices` | Speech Generating Devices (SGD) | L33739 | 294 | 19 | 7 | 13 |
|  | `cervical_traction` | Cervical Traction Devices | L33823 | 155 | 9 | 8 | 16 |
|  | `heating_pads` | Heating Pads and Heat Lamps | L33784 | 112 | 4 | 8 | 16 |
|  | `infrared_heating` | Infrared Heating Pad Systems | L33825 | 62 | 3 | 4 | 13 |
|  | `cold_therapy` | Cold Therapy | L33735 | 73 | 3 | 4 | 13 |
|  | `vacuum_erection` | Vacuum Erection Devices (VED) | L34824 | 57 | 1 | 5 | 16 |
| A/B MACs (Phase B) | `vitamin_d` | Vitamin D assay testing, six jurisdictions | six | 646 | 45 | 16 | 32 |
| | `dmepos` | The shared library | — | 398 | 25 | — | — |
| **Total** | **58 programs** | **58 DME LCDs + 6 A/B LCDs** | | **19,255** | **1,308** | **567** | **1,093** |

The whole model (`dmepos_all.le`, 56 programs) loads and runs its
cross-policy claims in under a minute. Every expectation passes (13
September 2026): 1,202 in 63 test files — the policies' cases, the Council
files, `all_cases.le` and `glucose_versions_cases.le`.

**Versions.** The export keeps one version of each LCD, but its revision
history quotes what each revision removed and added. Two changes are encoded
by date of service: the CGM criteria of L33822 (before 18 July 2021: insulin
three times a day or a pump, frequent self-adjustment, and testing four times
a day; from then until 16 April 2023 without the testing; since, any
insulin treatment or problematic hypoglycaemia, and training), and the refill
contact window of every DME LCD (before 2024: no sooner than 14 days before
shipping; since: within 30 days of the expected end of supply). A claim with
no date of service is read under the current version.

**One A/B policy, six jurisdictions** (`vitamin_d.le`): the six LCDs of
Vitamin D assay testing share a closed list of indications and exclude
screening, and differ in their frequency limits (First Coast three a year,
WPS one or four by diagnosis, the others "annual" once replaced), in two
prose indications beyond their tables, and in Noridian's and Wellpoint's
conditions on osteoporosis. The same claim is covered in some jurisdictions
and not in others; the ICD-10 tables (183 to 972 rows) are loaded from the
export, not typed.

## The Council decisions

36 of the 48 DME and supplier decisions the Council published (2003–2016),
each transcribed from its text with every fact quoting a passage, the
practitioner's findings as the record shows them and the Council's as its
own, the outcome never a fact:

| File | Decisions | Same outcome | Different | Not comparable |
|---|---:|---:|---:|---:|
| `council_pmd.le` — power mobility | 13 | 7 | 6 | 0 |
| `council_other.le` — beds, glucose testing, a nebulizer drug, wheelchair options | 8 | 4 (+1 in part) | 2 | 1 |
| `council_more.le` — joint stimulators, wound pumps, a defibrillator, an alert dog, wheelchairs | 9 | 7 | 2 | 0 |
| `council_supplies.le` — surgical dressings, insulin pods | 6 | 5 (+1 in part) | 0 | 0 |
| **Total** | **36** | **23 (+2)** | **10** | **1** |

Every difference is explained in its file. By kind: a fact the decision
does not state that the current LCD needs (a beneficiary's weight for the
weight class; an independent specialty evaluation and ATP for an
ultralightweight chair; the wound's exudate); a rule of the LCD version the
Council applied that the current one lacks or changed (the 120-day delivery
rule, the testing-log corroboration of 2010, the individual consideration of
2008), or the reverse; a rule outside the LCDs (replacement within the
useful lifetime, limitation of liability, the ESRD composite rate,
consolidated billing, pricing); an item the model does not code (a face-down
positioning system). About a third of "same outcome" rest on a different
ground from the Council's, which the files say. The 12 decisions not
transcribed concern chiropractic services (4), hearing, an ambulatory
surgical centre, oncology services, consolidated billing, an upper-limb
prosthesis and pneumatic compression devices (3), none of which is among the
58 current DME LCDs.

## Blind extraction

The editor's "facts from a document" path (docs/le_summary.md §17.9) run
headless on ten decisions already transcribed by hand, the program offered
being the one policy each concerns (`blind_extraction.le` holds what came
back, unedited):

| | gpt-oss-120b (Groq) | Kimi K3 (Together) |
|---|---:|---:|
| Time per decision | 10–20 s | 2–10 min (it thinks first; 60,000-token budget) |
| Facts written (10 decisions) | 55 | 117 |
| Passages found verbatim in the decision | 41 (75%) | 106 (91%) |
| Templates of the hand transcription recovered | 33 of 115 (29%) | 77 of 115 (67%) |
| Claims stated ("claim 1 is for ...") | never | in 8 of 10 |
| Decisions where the draft yields the hand transcription's answer, of the 5 that yield one | 0 | 2 (11-332, Keelers: the same conditional "reasonable and necessary") |

The five decisions whose hand transcription yields no answer yield none from
the drafts either, which proves little: a missing fact gives the same
silence. What the drafts miss is what decides these cases: the findings.
gpt-oss wrote none; Kimi wrote a few, sometimes attributing a reviewer's
conclusion to the wrong party. The run found two defects of the path itself,
now fixed: the prompt listed the values the rules read without their quotes,
so every model wrote its HCPCS and ICD-10 codes bare (atoms no rule compares
with), and the reply is now repaired where a bare word equals such a value;
and the LLM client sent Kimi a thinking switch that emptied its replies.
Before the fixes neither model's drafts yielded any answer. As in customs,
the path produces drafts for a reviewer, not transcriptions: the facts it
recovers are the easy ones (items, codes, dates, weights), and the findings
remain the reviewer's work.

## What the work taught

- **The judged finding is the right unit for a coverage criterion**, and
  alternatives (criterion J or K) must be one finding, not two; a finding
  that stands behind a measurable criterion goes in an `otherwise` branch,
  asked only when the record's own facts do not decide (an excess quantity).
- **Engine fixes made along the way** (each with its test): the section
  checklist charges a failure to the rule that needed the condition, and
  ignores failures under a goal that succeeded another way
  (`reasoner:goal_attempt/5`, `le_sections`); a table cell whose value
  contains "and" or "or" stays a value; a loaded CSV's text cells keep their
  quotes (a code like G71.01 was read as a number and lost its zero); a minus
  sign attached to a number is a negative number (`-5` was a compound, and
  comparisons with it were silently wrong); the extraction prompt shows
  string values with their quotes and repairs a reply that drops them; the
  LLM client no longer sends Kimi a thinking switch that emptied its
  replies.
- **Placement matters in a combined model**: each policy's code list sits
  before the first section, so that another policy's guard does not charge a
  claim's documentation failure to applicability; and A9270, the generic
  "non-covered item" code, belongs to no policy.
- **LE authoring gotchas** (all in `GUIDE.md`): a bare `E0601` is a variable
  — codes are quoted strings; a list broken over lines drops its rule; a
  labelled `rule ...:` before a fact loses the rest of the file; `otherwise`
  splits the whole body, bindings included; a comparison does not evaluate
  an expression; loaded CSV columns bind to template arguments by position;
  negate after binding.
- **Effort.** The library, the guide and the first three policies took about
  six hours; the other 55 programs were written by parallel agents from the
  guide (never more than ten at a time, later two), each passing its own
  cases on delivery, then reviewed, repaired where needed (four programs),
  consolidated and re-verified as a whole. About 19,000 lines of LE for
  130,000 words of LCD text.

## Known limits

- **Codes shared by policies.** A handful of supply codes belong to two or
  more LCDs (tape A4450/A4452 to ostomy, urological, tracheostomy and
  dressings; A4364, A4402, A5120, A6216, A4357, A5102; J1561/J1569 to IVIG
  and infusion pumps). A claim for one is read under every policy it belongs
  to, so its payment may combine one policy's criteria with another's
  documentation rule.
- **Not modelled**: replacement within the reasonable useful lifetime and
  after loss (BPM ch. 15 §110.2), repairs, limitation of liability (§1879),
  the KX/GA/GZ modifiers and PDAC coding verification, payment amounts and
  capped rental, partial allowance of a claim, and each policy's smaller
  exclusions, listed in its header comment. Versioned rules cover two
  changes, not every revision.

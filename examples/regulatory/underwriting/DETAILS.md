# Homeowners underwriting in Logical English: details

This page describes the files of this folder, the sources, how a guideline
is written as a rule, what could and could not be written, the test results,
the historical part, and what the two periods have in common. The plan it
carries out is `docs/strategy/UnderwritingExperiments.md` of the lpsPlus
repository; the method is the one of the customs and Medicare models beside
this folder (`../customs/DETAILS.md`, `../medicare/GUIDE.md`).

## The files

| File | What it is |
|---|---|
| `homeowners.le` | The library: the words of a proposal (the application and the inspection report), the three outcomes, the decision, and two rules of the model's own (missing information, conflicting information). |
| `arkansas.le` | The Arkansas homeowners guidelines of Auto Club Family Insurance Company (ACFIC, an AAA insurer), Section 05, Rule 05.2, version of 15 July 2021: 40 numbered items, 50 labelled rules. |
| `arkansas_cases.le` | 34 synthetic proposals, 45 expected answers, and the view *underwriting desk*. |
| `california.le` | The eligibility pages (2 to 8) of National General's "California Premier and OneChoice Homeowners Underwriting & Product Guide", revised 14 January 2020: 53 labelled rules and the brush decision table (12 rows). |
| `california_cases.le` | 42 synthetic proposals, 59 expected answers. |
| `contributionship.le`, `contributionship_surveys.le` | The historical part (see below). |
| `sources/` | The two PDFs, their text as the programs quote it, and the historical sources. |

## Sources

- **ACFIC Arkansas, Rule 05.2**: <https://services.autoclubmo.aaa.com/InsuranceAux/RefManual/AR/HomeOwners/Rule_05_2vers071521.pdf>,
  the insurer's own online reference manual, retrieved on 24 September 2026.
- **National General, California**: <https://www.ironpointagent.com/wp-content/uploads/2020/03/uwg_ca_inic_ho-NatGen.pdf>,
  a copy published by an insurance agency, retrieved on 24 September 2026.

The plan asked for versions retrieved from SERFF (the System for Electronic
Rates & Forms Filing, where US insurers file their rule manuals), with their
SERFF tracking numbers. That was not done: the SERFF Filing Access search is
an interactive web application, and both documents are the plan's named
fallbacks. The programs cite the copies above; the SERFF check is still open.

## How a guideline is written

A guideline is a rule whose conclusion is one of three outcomes, named after
the item it encodes, and which quotes the item:

```le
rule acfic_34 with provenance the ACFIC Arkansas underwriting guidelines,
        confer "Dwellings with knob and tube wiring or Federal Pacific Stab-Lok panels with circuit breakers are unacceptable.":
a proposal is ineligible under item 34
    if the proposal is for a dwelling
    and the dwelling has knob and tube wiring.
```

- The outcomes are `is ineligible under G`, `must be referred to
  underwriting under G`, and `is eligible` (neither). The decision follows:
  *decline* if ineligible under anything, *refer to underwriting* if
  referred and not ineligible, *accept* otherwise.
- What a proposal states is a template marked `undefined`: what it does not
  state is taken as not the case. Because silence would then read as a clean
  risk, the model's own rule *missing information* refers a proposal that
  leaves out the construction, the roof, the heating or the electrical
  service. A second rule of the model's own, *conflicting information*,
  refers a proposal whose application and inspection state different roofs.
  Both are marked as the model's, not the insurer's.
- A guideline that needs a person's judgment ("serious exterior exposures",
  "inherently vicious, aggressive or dangerous", "rundown condition") is a
  **finding**: the judged template `the finding F about X is established` or
  `unsupported`, recorded with who made it and why. It is asked only when a
  fact of the proposal raises it (a dog kept, a concern the inspection report
  notes). While nobody has recorded it, the answer is conditional: the
  proposal is ineligible *if* the finding is established, and it is not yet
  eligible. The explanation marks the step *judgment needed*.
- Every quotation is checked against the text in `sources/` when the program
  is loaded (`quote_not_found`); none is reported.

## What could be written

**Arkansas, Rule 05.2 (40 items).**

- Written from the proposal's facts: items 1 to 6, 8 to 15, 17 to 20, 22 to
  24, 26, 27, 29, 31 to 39 and 40 (33 items).
- Written with a finding someone records: items 7, 16, 21 (a dog) and
  40 B 1 (undue fire hazard next door).
- Written only in part: 15 (beach and congested resort only), 26 (not
  "frequent or extensive travel"), 40 (not "high level of foot traffic", not
  "overgrown trees, shrubs or brush").
- Not written: 25 (it restricts earthquake coverage, not the policy), 28
  (Premier Renters only), 30 (it refers to business activities "identified in
  the manual", a list outside the rule).
- Interpretations, stated in the program: item 3's "chargeable claims" are
  read as the non-weather, non-liability claims the item allows; a claim
  counts for three years from its date, in calendar months.

**National General, California (eligibility pages).**

- Written from the proposal's facts: applicant information (arson or fraud,
  occupation, lapse, prior insurance, loss history, trusts), occupancy
  (families, vacant, rentals, home day care, timeshares), protection class and
  distance to a fire department, slope, coast, historic home, age of home,
  construction and foundation types, under construction and renovation, roof,
  electrical, heating, plumbing, pets (breeds, bite history, wild animals),
  trampolines, swimming pools, ramps and treehouses, farm animals, the two
  referrals on the limits, and the brush grid as a decision table.
- Written with a finding: a dog "showing aggressive tendencies".
- Not written: named insureds and additional insureds, LLCs, mortgagees,
  business activity, residence employees, protective devices and smoke
  detectors, insurance to value, roof condition (chimneys, gutters,
  flashing), "properly installed" heating and above-ground tanks, the brush
  factors listed after the grid without a weight, and the other coverages of
  the guide (scheduled property, excess liability, watercraft, recreational
  vehicles).
- A gap in the guide: the brush grid gives, for a FireLine score of 3, "< 1.00"
  and "> 1.00", and nothing for a WillisRe score of exactly 1.00. No row
  answers such a proposal; the model's own rule *brush score outside the
  table* refers it (scenario `brush_gap`).

## Results

- `arkansas_cases.le`: 34 proposals, 45 expected answers, all pass.
- `california_cases.le`: 42 proposals, 59 expected answers, all pass.
- The verifier reports no warning on either (no quotation missing from its
  source, no value no rule reads, no fact no rule uses).

The proposals are invented. They show that the guidelines were captured as
written, not how either insurer actually decides: no real decision of either
insurer is public.

## The historical part: the Philadelphia Contributionship, 1752-1810

`contributionship.le` holds the Contributionship's underwriting rules as far
as typed sources state them, each with the years it was in force, so that a
survey is judged by the rules of its own year:

| Rule | In force | Source (in `sources/contributionship/`) |
|---|---|---|
| Ten miles round Philadelphia (Article 3) | 1752-1836 | Deed of Settlement, 1752 (primary) |
| No more than 500 pounds on one house (Article 6) | from 1752, "or such other Sum" as the members appoint | Deed of Settlement |
| Wooden houses and hazardous trades only by special agreement (Article 7) | from 1752 | Deed of Settlement |
| The table of deposits by kind of building: 15 to 40 shillings per 100 pounds (Article 8) | from 1752 | Deed of Settlement |
| No survey of a house out of the city without iron rails and a trap door | from 12 April 1768 | the minute, quoted by the company's archive essay |
| No wooden buildings | from April 1769 | Horace Binney, centennial address, 1852 |
| No house with a tree before it in the street | 14 April 1781 to 1810 | McKean v. Biddle, 181 Pa. 361 (the court's summary of the minutes) |
| Such a house with an additional deposit | 9 April 1810 to 1823 | McKean v. Biddle |

The company's own timeline dates the tree vote 1784; the program follows the
court's 1781. The Board minutes themselves survive only as scanned
handwriting, so no rule is read from them directly. The Directors' power to
raise any deposit or refuse any house (Article 32) is not a rule that can be
applied; it is the reason the recorded rates are compared with the table
rather than derived from it.

`contributionship_surveys.le` holds, in the scenario `sample`, the 150
surveys of the Contributionship dated 1752-1810 for which a typed source
exists: 23 quote the survey itself (a transcription in the Papers of
Benjamin Franklin, a journal article, the appendices of National Park Service
reports), 76 rest on a National Park Service report's summary, and 51
on the catalogue record of the company's digital archive (policy
number, year, amount). A survey states only what its source states. 137 are
recorded as insured; for 13 the source does not say. The survey images and
the minutes could not be read: the archive's site refuses automated access,
and they are handwritten.

**Results on the sample.**

- **Agreement with the rules.** Of the 137 insured surveys, 135 break no rule
  in force in their year. The two others were insured for more than 500
  pounds under one policy number (policy 2426, St Michael's and Zion Churches,
  1788, 2,000 pounds; policy 2879, 1798, 900 pounds). Article 6 lets the
  members change the limit, and the court says it was later raised; the
  sources do not date the change. So these are departures from the 1752 text,
  not necessarily from the rules of 1788.
- **Special agreements.** Eight surveys needed one: a wooden building of 1767
  (before the ban) and seven buildings of hazardous trades (City Tavern
  three times, two other taverns, an apothecary's shop, a brewhouse). Their
  terms are not recorded. (Policy 885 appears twice: the catalogue dates it
  1762, a National Park Service report 1763; the program keeps both.)
- **Rates against the 1752 table.** Nine surveys give both the walls and the
  rate the Board charged. Every rate is above the table, by 10 to 40
  shillings per 100 pounds. Article 32 allows it; Binney's address says the
  same ("For good risks they rarely exceeded twenty-five and thirty
  shillings", against the table's 20).
- **Coherence.** The Board's rates are read as precedents on one issue, a
  *low deposit* (30 shillings or less, Binney's ceiling for good risks), with
  the factors the surveys record (nine-inch party walls, a way out onto the
  roof, iron rails favour it; a hazardous trade counts against it), in the
  result model of `../precedent.le`. The query `conflicts` finds six pairs
  of decisions that the recorded factors cannot both justify. The clearest:
  City Tavern paid 30 shillings in 1773 and 47 shillings 6 pence in 1785, on
  the same walls and the same trade. Whatever explains the Board's rates
  (the building's size or value, the date, the currency after the
  Revolution), the surveys do not record it.
- **No refusals.** No typed source records a survey the Board refused. The
  rules that would refuse (the wooden ban, the tree ban, the ten miles, the
  order of 1768) are tested on invented houses instead, one per rule (eight
  scenarios). The coherence test of refusals the plan asked for needs the
  minutes, read by hand.

The sample is not random: it leans to brick houses around Independence Mall
and to famous buildings.

## 1752 and today, side by side

| Category | Contributionship, 1752-1810 | Arkansas 2021, California 2020 |
|---|---|---|
| Construction | brick against wood; wall thickness sets the deposit; wooden buildings banned from 1769 | mobile, manufactured, log, dome, synthetic stucco; foundations on piers |
| Fire spread and fighting | party walls above the roof, a door onto the roof, iron rails; no street trees (engines could not reach) | protection class, distance to a fire department; wildfire scores; brush next door |
| Ignition sources | hazardous trades: bakehouses, breweries, apothecaries, inns | wiring (knob and tube, aluminum), panels, amperage, woodstoves, space heaters |
| Location | ten miles round Philadelphia; out of the city only with rails and a trap door | coast, slope, commercial neighbours, congested resorts |
| Amount | 500 pounds on one house; unfinished houses two thirds of value | limits that trigger referral; contents against dwelling |
| Applicant | none | claims history, membership, prior insurance, arson or fraud, occupation, pets |
| Regulation | the Deed of Settlement, changed at general meetings | guidelines filed with the state |
| Judgment | the Board decided every survey and set every rate | named referrals to an underwriter |

What persists: construction, the ways a fire starts and spreads, and where
the house stands. What is new: the applicant's own history, catastrophe
geography (wildfire, coast), and the insurer's liability for what happens on
the premises (pools, trampolines, dogs). What changed most is where the
judgment sits: in 1752 the Board judged every house; today the guideline
decides most proposals and names the few that need a person.

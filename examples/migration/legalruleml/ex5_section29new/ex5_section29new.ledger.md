# Migration ledger: ex5_section29new

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex5-section29new-normal.lrml
Translator: InsurLE2/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 0 |
| residue | 4 |
| **total** | 17 |

Fidelity: **24 of 24** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel engageCreditActivity/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* engages in a credit activity |  |
| Rel hasLicence/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* holds a credit licence |  |
| Rel imprisonment/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* is imprisoned for *a term* |  |
| Rel payCivilUnits/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* pays *a number* civil penalty units |  |
| Rel payPebnalUnitPlusImprisonment/3 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* pays *a number* penalty units and is imprisoned for *a term* |  |
| Rel payPenalUnits/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* pays *a number* penalty units |  |
| Rel person/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* is a person |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| prescriptive statement ps2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2 |  |
| Override ps2 over ps1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | ps1 |  |
| Reparation reparation_1 (pen2 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | reparation_1 |  |
| Reparation assoc1 (pen1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | assoc1 |  |
| source ls1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ls1 |  |
| ascs0 -> atom1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | atom1 |  |
| ascs0 -> atom2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | atom2 |  |
| ascs0 -> atom3 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | atom3 |  |
| ascs1 -> oblig1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | oblig1 |  |

## Residue

- **ascs0 -> atom1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: atom1. 
- **ascs0 -> atom2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: atom2. 
- **ascs0 -> atom3** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: atom3. 
- **ascs1 -> oblig1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: oblig1. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| unlicensed_trader | prohibitions | pass |  |
| unlicensed_trader | obligations | pass |  |
| unlicensed_trader | permissions | pass |  |
| unlicensed_trader | violated_obligations | pass |  |
| unlicensed_trader | violated_prohibitions | pass |  |
| unlicensed_trader | breaches | pass |  |
| licensed_trader | prohibitions | pass |  |
| licensed_trader | obligations | pass |  |
| licensed_trader | permissions | pass |  |
| licensed_trader | violated_obligations | pass |  |
| licensed_trader | violated_prohibitions | pass |  |
| licensed_trader | breaches | pass |  |
| no_activity | prohibitions | pass |  |
| no_activity | obligations | pass |  |
| no_activity | permissions | pass |  |
| no_activity | violated_obligations | pass |  |
| no_activity | violated_prohibitions | pass |  |
| no_activity | breaches | pass |  |
| defaulter | prohibitions | pass |  |
| defaulter | obligations | pass |  |
| defaulter | permissions | pass |  |
| defaulter | violated_obligations | pass |  |
| defaulter | violated_prohibitions | pass |  |
| defaulter | breaches | pass |  |


# Migration ledger: ex12_usc_17_504_context

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex12-USC_17_504_context-normal.lrml
Translator: InsurLE2/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 46 |
| approximated | 0 |
| residue | 14 |
| **total** | 60 |

Fidelity: **20 of 20** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel Infringer/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a person* is an infringer |  |
| Rel claimStatutoryDamages/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a copyright owner* elects statutory damages |  |
| Rel claimStatutoryDamanges/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a copyright owner* claims statutory damages |  |
| Rel isNotEqual/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *a copyright owner* is not the same person as *an infringer* |  |
| Rel isOwner/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *a copyright owner* owns the copyright in *a work* |  |
| Rel isWork/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a work* is a work protected by copyright |  |
| Rel notUse/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *an infringer* uses *a work* |  |
| Rel payNotWillfullyInfringement/2 | relation | encoded | Rel -> a template (the reviewer's wording) | reduced statutory damages of between *a minimum* and *a maximum* are paid |  |
| Rel payStatutoryDamages/2 | relation | encoded | Rel -> a template (the reviewer's wording) | statutory damages of between *a minimum* and *a maximum* are paid |  |
| Rel payWillfullyInfringement/2 | relation | encoded | Rel -> a template (the reviewer's wording) | increased statutory damages of between *a minimum* and *a maximum* are paid |  |
| Rel sustainBurdenProving/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *a party* sustains the burden of proof |  |
| Rel willfullyInfringing/1 | relation | encoded | Rel -> a template (the reviewer's wording) | *an infringer* infringed wilfully |  |
| constitutive statement cs1 | statement | encoded | ConstitutiveStatement -> an LE rule | cs1 |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| prescriptive statement ps2-tblock1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2_tblock1 |  |
| prescriptive statement ps3-tblock1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps3_tblock1 |  |
| prescriptive statement ps4-tblock1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps4_tblock1 |  |
| prescriptive statement ps2-tblock2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2_tblock2 |  |
| prescriptive statement ps3-tblock2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps3_tblock2 |  |
| prescriptive statement ps4-tblock2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps4_tblock2 |  |
| prescriptive statement ps2-tblock3 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2_tblock3 |  |
| prescriptive statement ps3-tblock3 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps3_tblock3 |  |
| prescriptive statement ps4-tblock3 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps4_tblock3 |  |
| Override rule3-tblock1 over rule2-tblock1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | rule2-tblock1 |  |
| Override rule4-tblock1 over rule3-tblock1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | rule3-tblock1 |  |
| Override rule3-tblock2 over rule2-tblock2 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | rule2-tblock2 |  |
| Override rule4-tblock2 over rule3-tblock2 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | rule3-tblock2 |  |
| Reparation rep1-tblock1 (penalty1-tblock1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep1-tblock1 |  |
| Reparation rep2-tblock1 (penalty2-tblock1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep2-tblock1 |  |
| Reparation rep3-tblock1 (penalty3-tblock1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep3-tblock1 |  |
| Reparation rep1-tblock2 (penalty1-tblock2 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep1-tblock2 |  |
| Reparation rep2-tblock2 (penalty2-tblock2 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep2-tblock2 |  |
| Reparation rep3-tblock2 (penalty3-tblock2 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep3-tblock2 |  |
| Reparation rep1-tblock3 (penalty1-tblock3 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep1-tblock3 |  |
| Reparation rep2-tblock3 (penalty2-tblock3 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep2-tblock3 |  |
| Reparation rep3-tblock3 (penalty3-tblock3 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep3-tblock3 |  |
| source sec_504__cls_a__pnt_1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_a__pnt_1 |  |
| source sec_504__cls_a_pnt_2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_a_pnt_2 |  |
| source sec_504__cls_b | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_b |  |
| source sec_504__cls_c__pnt_1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_c__pnt_1 |  |
| source sec_504__cls_c__pnt_2__sb_1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_c__pnt_2__sb_1 |  |
| source sec_504__cls_c__pnt_2__sb_2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_c__pnt_2__sb_2 |  |
| source sec_504__cls_c__pnt_2__sb_3 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | sec_504__cls_c__pnt_2__sb_3 |  |
| temporal tblock1 | temporal | encoded | TemporalCharacteristics -> a period of the relevant date (Starts / Ends) | tblock1 |  |
| temporal tblock2 | temporal | encoded | TemporalCharacteristics -> a period of the relevant date (Starts / Ends) | tblock2 |  |
| temporal tblock3 | temporal | encoded | TemporalCharacteristics -> a period of the relevant date (Starts / Ends) | tblock3 |  |
| Override rule3-tblock3 over rule2-tblock3 | override | residue | an Override naming a rule the document does not contain: dropped | rule3-tblock3 |  |
| Override rule4-tblock3 over rule3-tblock3 | override | residue | an Override naming a rule the document does not contain: dropped | rule4-tblock3 |  |
| ruleInfo1 -> rule1-tblock1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1-tblock1 |  |
| ruleInfo2 -> rule2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule2 |  |
| ruleInfo3 -> rule3 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule3 |  |
| ruleInfo4 -> rule4 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule4 |  |
| ruleInfo5 -> rule5 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule5 |  |
| ruleInfo6 -> rule6 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule6 |  |
| ruleInfo7 -> rule7 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule7 |  |
| ruleInfo8 -> rule8 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule8 |  |
| ruleInfo9 -> rule9 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule9 |  |
| ruleInfo10 -> rule10 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule10 |  |
| ruleInfo11 -> rule11 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule11 |  |
| ruleInfo12 -> rule12 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule12 |  |

## Residue

- **Override rule3-tblock3 over rule2-tblock3** (override) — an Override naming a rule the document does not contain: dropped; in the program: rule3-tblock3. 
- **Override rule4-tblock3 over rule3-tblock3** (override) — an Override naming a rule the document does not contain: dropped; in the program: rule4-tblock3. 
- **ruleInfo1 -> rule1-tblock1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1-tblock1. 
- **ruleInfo2 -> rule2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule2. 
- **ruleInfo3 -> rule3** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule3. 
- **ruleInfo4 -> rule4** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule4. 
- **ruleInfo5 -> rule5** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule5. 
- **ruleInfo6 -> rule6** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule6. 
- **ruleInfo7 -> rule7** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule7. 
- **ruleInfo8 -> rule8** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule8. 
- **ruleInfo9 -> rule9** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule9. 
- **ruleInfo10 -> rule10** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule10. 
- **ruleInfo11 -> rule11** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule11. 
- **ruleInfo12 -> rule12** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule12. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| statutory_damages | prohibitions | pass |  |
| statutory_damages | obligations | pass |  |
| statutory_damages | violated_obligations | pass |  |
| statutory_damages | violated_prohibitions | pass |  |
| statutory_damages | breaches | pass |  |
| wilful_infringement | prohibitions | pass |  |
| wilful_infringement | obligations | pass |  |
| wilful_infringement | violated_obligations | pass |  |
| wilful_infringement | violated_prohibitions | pass |  |
| wilful_infringement | breaches | pass |  |
| innocent_infringement | prohibitions | pass |  |
| innocent_infringement | obligations | pass |  |
| innocent_infringement | violated_obligations | pass |  |
| innocent_infringement | violated_prohibitions | pass |  |
| innocent_infringement | breaches | pass |  |
| own_work | prohibitions | pass |  |
| own_work | obligations | pass |  |
| own_work | violated_obligations | pass |  |
| own_work | violated_prohibitions | pass |  |
| own_work | breaches | pass |  |


# Migration ledger: ex3_deontic

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex3-deontic-normal.lrml
Translator: lpsPlus/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 14 |
| approximated | 11 |
| residue | 1 |
| **total** | 26 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel rel1/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel1 |  |
| Rel rel103/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel103 |  |
| Rel rel2/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel2 |  |
| Rel rel3/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel3 |  |
| Rel rel4/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel4 |  |
| Rel rel5/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel5 |  |
| constitutive statement cs1 | statement | encoded | ConstitutiveStatement -> an LE rule | cs1 |  |
| constitutive statement cs2 | statement | encoded | ConstitutiveStatement -> an LE rule | cs2 |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| prescriptive statement ps2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2_1 |  |
| prescriptive statement ps2 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps2_2 |  |
| factual statement fact1 | statement | encoded | FactualStatement -> a fact | fact1 |  |
| prescriptive statement ps3 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps3 |  |
| Override ps2 over ps1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | ps1 | The document's statements depend on one another through negation, and the verifier says so (non_stratified): ps2 overrides ps1, so once ps2's prohibition is violated its next element keeps ps1 from applying; and ps1's reparations (rep1, rep3) oblige what ps2 forbids. SPINdle settles such a loop by the superiority of its rules; the twin states it as it is. The scenario violates nothing, so the loop is never entered. |
| Reparation rep-implicit1 (pen1-v1 for ps2) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep-implicit1 |  |
| Reparation rep1 (pen1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep1 |  |
| Reparation rep3 (pen1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep3 |  |
| source ls1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ls1 |  |
| source pen1-v1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | pen1-v1 |  |
| source ps2-v1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ps2-v1 |  |
| Violation of ps0 | violation | approximated | a Violation of a statement the document does not contain -> `the statement ... is violated`, a fact for the scenarios | ps0 |  |
| Violation of ps101 | violation | approximated | a Violation of a statement the document does not contain -> `the statement ... is violated`, a fact for the scenarios | ps101 |  |
| Reparation rep-implicit1 | reparation | residue | a Reparation whose penalty or statement is missing: dropped | rep-implicit1 |  |
| Reparation rep-implicit1 | reparation | approximated | a Reparation with nothing to conclude | rep-implicit1 |  |
| asc1 -> oblig101 | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | oblig101 |  |
| asc2 -> oblig102 | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | oblig102 |  |

## Residue

- **Reparation rep-implicit1** (reparation) — a Reparation whose penalty or statement is missing: dropped; in the program: rep-implicit1. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| permitted_and_obliged | prohibitions | pass |  |
| permitted_and_obliged | obligations | pass |  |
| permitted_and_obliged | rel103 | pass |  |
| permitted_and_obliged | rel3 | pass |  |
| permitted_and_obliged | rel5 | pass |  |
| permitted_and_obliged | violated_obligations | pass |  |
| permitted_and_obliged | violated_prohibitions | pass |  |
| permitted_and_obliged | breaches | pass |  |


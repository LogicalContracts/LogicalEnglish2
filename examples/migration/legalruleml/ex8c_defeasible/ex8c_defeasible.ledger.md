# Migration ledger: ex8c_defeasible

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex8c-defeasible-normal.lrml
Translator: lpsPlus/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 3 |
| residue | 0 |
| **total** | 10 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel rel1/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel1 |  |
| Rel rel103/1 | relation | encoded | Rel -> no template: it occurs only as the conclusion of a defeater, which concludes nothing (its rule is an exception of the rules it attacks) |  |  |
| Rel rel2/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel2 |  |
| Rel rel3/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel3 |  |
| constitutive statement cs1 | statement | encoded | ConstitutiveStatement -> an LE rule | cs1 |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| defeater cs2 | defeater | encoded | a defeater -> an exception (it is not the case that ...) of the rules it attacks | cs2 |  |
| defeater ps2 | defeater | encoded | a defeater -> an exception (it is not the case that ...) of the rules it attacks | ps2 |  |
| Override cs2 over cs1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | cs1 |  |
| Override ps2 over ps1 | override | encoded | Override -> the under rule holds only when the over rule does not apply (E2) | ps1 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| both_conditions | not_rel3 | pass |  |
| both_conditions | rel3 | pass |  |


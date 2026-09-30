# Migration ledger: unless_example

Source: an L4 program (smucclaw/l4-ide) — unless-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 39 |
| approximated | 0 |
| residue | 0 |
| **total** | 39 |

Fidelity: **51 of 51** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| basic1 | definition | encoded | pred | basic1 |  |
| basic2 | definition | encoded | pred | basic2 |  |
| basic3 | definition | encoded | pred | basic3 |  |
| basic4 | definition | encoded | pred | basic4 |  |
| is a citizen | assume | encoded | a template the scenarios state (; undefined) | is a citizen |  |
| has resided for 5 years | assume | encoded | a template the scenarios state (; undefined) | has resided for 5 years |  |
| has valid identification | assume | encoded | a template the scenarios state (; undefined) | has valid identification |  |
| has been disqualified | assume | encoded | a template the scenarios state (; undefined) | has been disqualified |  |
| is eligible for benefits | definition | encoded | pred | is eligible for benefits |  |
| and_unless_example | definition | encoded | pred | as well as except when example |  |
| and_unless_example2 | definition | encoded | pred | as well as except when example2 |  |
| or_unless_example | definition | encoded | pred | else except when example |  |
| or_unless_example2 | definition | encoded | pred | else except when example2 |  |
| single_and | definition | encoded | pred | single as well as |  |
| single_or | definition | encoded | pred | single else |  |
| precedence_test | definition | encoded | pred | precedence test |  |
| signed by both parties | assume | encoded | a template the scenarios state (; undefined) | signed by both parties |  |
| consideration exchanged | assume | encoded | a template the scenarios state (; undefined) | consideration exchanged |  |
| signed under duress | assume | encoded | a template the scenarios state (; undefined) | signed under duress |  |
| contract is valid | definition | encoded | pred | contract is valid |  |
| has valid badge | assume | encoded | a template the scenarios state (; undefined) | has valid badge |  |
| during business hours | assume | encoded | a template the scenarios state (; undefined) | during business hours |  |
| building is closed | assume | encoded | a template the scenarios state (; undefined) | building is closed |  |
| can enter building | definition | encoded | pred | can enter building |  |
| is employee | assume | encoded | a template the scenarios state (; undefined) | is employee |  |
| is contractor | assume | encoded | a template the scenarios state (; undefined) | is contractor |  |
| has been terminated | assume | encoded | a template the scenarios state (; undefined) | has been terminated |  |
| has system access | definition | encoded | pred | has system access |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 18 | test | encoded | a query and the evaluator's answer | line_18 |  |
| #EVAL at line 22 | test | encoded | a query and the evaluator's answer | line_22 |  |
| #EVAL at line 53 | test | encoded | a query and the evaluator's answer | line_53 |  |
| #EVAL at line 61 | test | encoded | a query and the evaluator's answer | line_61 |  |
| #EVAL at line 76 | test | encoded | a query and the evaluator's answer | line_76 |  |
| #EVAL at line 84 | test | encoded | a query and the evaluator's answer | line_84 |  |
| #EVAL at line 93 | test | encoded | a query and the evaluator's answer | line_93 |  |
| #EVAL at line 94 | test | encoded | a query and the evaluator's answer | line_94 |  |
| #EVAL at line 105 | test | encoded | a query and the evaluator's answer | line_105 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_10 | line_10 | pass |  |
| line_14 | line_14 | pass |  |
| line_18 | line_18 | pass |  |
| line_22 | line_22 | pass |  |
| line_53 | line_53 | pass |  |
| line_61 | line_61 | pass |  |
| line_76 | line_76 | pass |  |
| line_84 | line_84 | pass |  |
| line_93 | line_93 | pass |  |
| line_94 | line_94 | pass |  |
| line_105 | line_105 | pass |  |
| variant_1 | is_eligible_for_benefits | pass |  |
| variant_2 | is_eligible_for_benefits | pass |  |
| variant_3 | is_eligible_for_benefits | pass |  |
| variant_4 | is_eligible_for_benefits | pass |  |
| variant_5 | is_eligible_for_benefits | pass |  |
| variant_6 | is_eligible_for_benefits | pass |  |
| variant_7 | is_eligible_for_benefits | pass |  |
| variant_8 | is_eligible_for_benefits | pass |  |
| variant_9 | is_eligible_for_benefits | pass |  |
| variant_10 | is_eligible_for_benefits | pass |  |
| variant_11 | is_eligible_for_benefits | pass |  |
| variant_12 | is_eligible_for_benefits | pass |  |
| variant_13 | is_eligible_for_benefits | pass |  |
| variant_14 | is_eligible_for_benefits | pass |  |
| variant_15 | is_eligible_for_benefits | pass |  |
| variant_16 | is_eligible_for_benefits | pass |  |
| variant_17 | contract_is_valid | pass |  |
| variant_18 | contract_is_valid | pass |  |
| variant_19 | contract_is_valid | pass |  |
| variant_20 | contract_is_valid | pass |  |
| variant_21 | contract_is_valid | pass |  |
| variant_22 | contract_is_valid | pass |  |
| variant_23 | contract_is_valid | pass |  |
| variant_24 | contract_is_valid | pass |  |
| variant_25 | can_enter_building | pass |  |
| variant_26 | can_enter_building | pass |  |
| variant_27 | can_enter_building | pass |  |
| variant_28 | can_enter_building | pass |  |
| variant_29 | can_enter_building | pass |  |
| variant_30 | can_enter_building | pass |  |
| variant_31 | can_enter_building | pass |  |
| variant_32 | can_enter_building | pass |  |
| variant_33 | has_system_access | pass |  |
| variant_34 | has_system_access | pass |  |
| variant_35 | has_system_access | pass |  |
| variant_36 | has_system_access | pass |  |
| variant_37 | has_system_access | pass |  |
| variant_38 | has_system_access | pass |  |
| variant_39 | has_system_access | pass |  |
| variant_40 | has_system_access | pass |  |


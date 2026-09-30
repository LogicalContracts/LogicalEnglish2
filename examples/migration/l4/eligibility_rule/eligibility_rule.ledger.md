# Migration ledger: eligibility_rule

Source: an L4 program (smucclaw/l4-ide) — eligibility-rule.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Applicant | record | encoded | a type of individuals, one template per field | Applicant |  |
| the applicant is eligible | definition | encoded | pred | *an applicant* is eligible |  |
| the applicant is at least 18 years old | definition | encoded | pred | *an applicant* is at least 18 years old |  |
| the applicant has shown valid identification | definition | encoded | pred | *an applicant* has shown valid identification |  |
| Alice the adult | record | encoded | an individual with one fact per field | alice_the_adult |  |
| Bob without ID | record | encoded | an individual with one fact per field | bob_without_id |  |
| Young Charlie | record | encoded | an individual with one fact per field | young_charlie |  |
| #EVAL at line 34 | test | encoded | a query and the evaluator's answer | line_34 |  |
| #EVAL at line 35 | test | encoded | a query and the evaluator's answer | line_35 |  |
| #EVAL at line 36 | test | encoded | a query and the evaluator's answer | line_36 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_34 | line_34 | pass |  |
| line_35 | line_35 | pass |  |
| line_36 | line_36 | pass |  |


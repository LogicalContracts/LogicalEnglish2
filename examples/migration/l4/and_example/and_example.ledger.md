# Migration ledger: and_example

Source: an L4 program (smucclaw/l4-ide) — and-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 25 |
| approximated | 4 |
| residue | 0 |
| **total** | 29 |

Fidelity: **14 of 14** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| allTrue | wording | approximated | the template's words made from the name, its inputs appended | all true for *a boolean* with *a second boolean* with *a third boolean* | to be reviewed: the name does not say where its inputs go |
| inRange | wording | approximated | the template's words made from the name, its inputs appended | in range for *a number* with *a second number* | to be reviewed: the name does not say where its inputs go |
| passingGrade | wording | approximated | the template's words made from the name, its inputs appended | passing grade for *a score* | to be reviewed: the name does not say where its inputs go |
| accessLevel | wording | approximated | the template's words made from the name, its inputs appended | the access level for *an user age* with *a boolean* is *a text* | to be reviewed: the name does not say where its inputs go |
| age | assume | encoded | a template the scenarios state (; undefined) | age |  |
| hasLicense | assume | encoded | a template the scenarios state (; undefined) | hasLicense |  |
| canDrive | definition | encoded | pred | can drive |  |
| allTrue | definition | encoded | pred | all true for *a boolean* with *a second boolean* with *a third boolean* |  |
| personAge | assume | encoded | a template the scenarios state (; undefined) | personAge |  |
| personIncome | assume | encoded | a template the scenarios state (; undefined) | personIncome |  |
| hasCriminalRecord | assume | encoded | a template the scenarios state (; undefined) | hasCriminalRecord |  |
| isEligible | definition | encoded | pred | is eligible |  |
| inRange | definition | encoded | pred | in range for *a number* with *a second number* |  |
| passingGrade | definition | encoded | pred | passing grade for *a score* |  |
| accessLevel | definition | encoded | func | the access level for *an user age* with *a boolean* is *a text* |  |
| #EVAL at line 5 | test | encoded | a query and the evaluator's answer | line_5 |  |
| #EVAL at line 6 | test | encoded | a query and the evaluator's answer | line_6 |  |
| #EVAL at line 7 | test | encoded | a query and the evaluator's answer | line_7 |  |
| #EVAL at line 8 | test | encoded | a query and the evaluator's answer | line_8 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 31 | test | encoded | a query and the evaluator's answer | line_31 |  |
| #EVAL at line 32 | test | encoded | a query and the evaluator's answer | line_32 |  |
| #EVAL at line 52 | test | encoded | a query and the evaluator's answer | line_52 |  |
| #EVAL at line 53 | test | encoded | a query and the evaluator's answer | line_53 |  |
| #EVAL at line 60 | test | encoded | a query and the evaluator's answer | line_60 |  |
| #EVAL at line 61 | test | encoded | a query and the evaluator's answer | line_61 |  |
| #EVAL at line 71 | test | encoded | a query and the evaluator's answer | line_71 |  |
| #EVAL at line 72 | test | encoded | a query and the evaluator's answer | line_72 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_5 | line_5 | pass |  |
| line_6 | line_6 | pass |  |
| line_7 | line_7 | pass |  |
| line_8 | line_8 | pass |  |
| line_12 | line_12 | pass |  |
| line_13 | line_13 | pass |  |
| line_31 | line_31 | pass |  |
| line_32 | line_32 | pass |  |
| line_52 | line_52 | pass |  |
| line_53 | line_53 | pass |  |
| line_60 | line_60 | pass |  |
| line_61 | line_61 | pass |  |
| line_71 | line_71 | pass |  |
| line_72 | line_72 | pass |  |


# Migration ledger: or_example

Source: an L4 program (smucclaw/l4-ide) — or-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 26 |
| approximated | 3 |
| residue | 0 |
| **total** | 29 |

Fidelity: **27 of 27** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| anyTrue | wording | approximated | the template's words made from the name, its inputs appended | any true for *a boolean* with *a second boolean* with *a third boolean* | to be reviewed: the name does not say where its inputs go |
| getPriority | wording | approximated | the template's words made from the name, its inputs appended | the get priority for *an user type* with *a boolean* is *a text* | to be reviewed: the name does not say where its inputs go |
| complexCondition | wording | approximated | the template's words made from the name, its inputs appended | complex condition for *a number* with *a boolean* | to be reviewed: the name does not say where its inputs go |
| isStudent | assume | encoded | a template the scenarios state (; undefined) | isStudent |  |
| isSenior | assume | encoded | a template the scenarios state (; undefined) | isSenior |  |
| getsDiscount | definition | encoded | pred | gets discount |  |
| anyTrue | definition | encoded | pred | any true for *a boolean* with *a second boolean* with *a third boolean* |  |
| isAdmin | assume | encoded | a template the scenarios state (; undefined) | isAdmin |  |
| isOwner | assume | encoded | a template the scenarios state (; undefined) | isOwner |  |
| hasPermission | assume | encoded | a template the scenarios state (; undefined) | hasPermission |  |
| hasAccess | definition | encoded | pred | has access |  |
| isTerminalStatus | definition | encoded | pred | is terminal *a status* |  |
| getPriority | definition | encoded | func | the get priority for *an user type* with *a boolean* is *a text* |  |
| complexCondition | definition | encoded | pred | complex condition for *a number* with *a boolean* |  |
| #EVAL at line 5 | test | encoded | a query and the evaluator's answer | line_5 |  |
| #EVAL at line 6 | test | encoded | a query and the evaluator's answer | line_6 |  |
| #EVAL at line 7 | test | encoded | a query and the evaluator's answer | line_7 |  |
| #EVAL at line 8 | test | encoded | a query and the evaluator's answer | line_8 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 31 | test | encoded | a query and the evaluator's answer | line_31 |  |
| #EVAL at line 32 | test | encoded | a query and the evaluator's answer | line_32 |  |
| #EVAL at line 55 | test | encoded | a query and the evaluator's answer | line_55 |  |
| #EVAL at line 56 | test | encoded | a query and the evaluator's answer | line_56 |  |
| #EVAL at line 66 | test | encoded | a query and the evaluator's answer | line_66 |  |
| #EVAL at line 67 | test | encoded | a query and the evaluator's answer | line_67 |  |
| #EVAL at line 75 | test | encoded | a query and the evaluator's answer | line_75 |  |
| #EVAL at line 76 | test | encoded | a query and the evaluator's answer | line_76 |  |
| #EVAL at line 77 | test | encoded | a query and the evaluator's answer | line_77 |  |

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
| line_55 | line_55 | pass |  |
| line_56 | line_56 | pass |  |
| line_66 | line_66 | pass |  |
| line_67 | line_67 | pass |  |
| line_75 | line_75 | pass |  |
| line_76 | line_76 | pass |  |
| line_77 | line_77 | pass |  |
| variant_1 | gets_discount | pass |  |
| variant_2 | gets_discount | pass |  |
| variant_3 | gets_discount | pass |  |
| variant_4 | gets_discount | pass |  |
| variant_5 | has_access | pass |  |
| variant_6 | has_access | pass |  |
| variant_7 | has_access | pass |  |
| variant_8 | has_access | pass |  |
| variant_9 | has_access | pass |  |
| variant_10 | has_access | pass |  |
| variant_11 | has_access | pass |  |
| variant_12 | has_access | pass |  |


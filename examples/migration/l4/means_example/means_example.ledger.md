# Migration ledger: means_example

Source: an L4 program (smucclaw/l4-ide) — means-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 23 |
| approximated | 4 |
| residue | 0 |
| **total** | 27 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| double | wording | approximated | the template's words made from the name, its inputs appended | the double for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| add | wording | approximated | the template's words made from the name, its inputs appended | the add for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| factorial | wording | approximated | the template's words made from the name, its inputs appended | the factorial for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| circumference | wording | approximated | the template's words made from the name, its inputs appended | the circumference for *a radius* is *a number* | to be reviewed: the name does not say where its inputs go |
| greeting | definition | encoded | func | the greeting is *a text* |  |
| answer | definition | encoded | func | the answer is *a number* |  |
| double | definition | encoded | func | the double for *a number* is *a second number* |  |
| add | definition | encoded | func | the add for *a number* with *a second number* is *a third number* |  |
| factorial | definition | encoded | func | the factorial for *a number* is *a second number* |  |
| pi | definition | encoded | func | the pi is *a number* |  |
| circumference | definition | encoded | func | the circumference for *a radius* is *a number* |  |
| baseValue | definition | encoded | func | the base value is *a number* |  |
| innerResult | definition | encoded | func | the inner result is *a number* |  |
| outerFunction | definition | encoded | func | the outer function is *a number* |  |
| valueWithMeans | definition | encoded | func | the value with means is *a number* |  |
| valueWithMeans2 | definition | encoded | func | the value with means2 is *a number* |  |
| sumItems | definition | encoded | func | the sum *an items* is *a number* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 20 | test | encoded | a query and the evaluator's answer | line_20 |  |
| #EVAL at line 21 | test | encoded | a query and the evaluator's answer | line_21 |  |
| #EVAL at line 32 | test | encoded | a query and the evaluator's answer | line_32 |  |
| #EVAL at line 42 | test | encoded | a query and the evaluator's answer | line_42 |  |
| #EVAL at line 53 | test | encoded | a query and the evaluator's answer | line_53 |  |
| #EVAL at line 61 | test | encoded | a query and the evaluator's answer | line_61 |  |
| #EVAL at line 62 | test | encoded | a query and the evaluator's answer | line_62 |  |
| #EVAL at line 72 | test | encoded | a query and the evaluator's answer | line_72 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |
| line_10 | line_10 | pass |  |
| line_20 | line_20 | pass |  |
| line_21 | line_21 | pass |  |
| line_32 | line_32 | pass |  |
| line_42 | line_42 | pass |  |
| line_53 | line_53 | pass |  |
| line_61 | line_61 | pass |  |
| line_62 | line_62 | pass |  |
| line_72 | line_72 | pass |  |


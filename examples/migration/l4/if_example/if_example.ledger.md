# Migration ledger: if_example

Source: an L4 program (smucclaw/l4-ide) — if-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 25 |
| approximated | 9 |
| residue | 0 |
| **total** | 34 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| check if positive | wording | approximated | the template's words made from the name, its inputs appended | the check whether positive for *a number* is *a text* | to be reviewed: the name does not say where its inputs go |
| absolute value of | wording | approximated | the template's words made from the name, its inputs appended | the absolute value of *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| letter grade for | wording | approximated | the template's words made from the name, its inputs appended | the letter grade for *a score* is *a text* | to be reviewed: the name does not say where its inputs go |
| can enter venue | wording | approximated | the template's words made from the name, its inputs appended | the can enter venue for *an age* with *a boolean* with *a second boolean* is *a text* | to be reviewed: the name does not say where its inputs go |
| is adult | wording | approximated | the template's words made from the name, its inputs appended | *a person age* is adult | to be reviewed: the name does not say where its inputs go |
| is adult 2 | wording | approximated | the template's words made from the name, its inputs appended | *a number* is adult 2 | to be reviewed: the name does not say where its inputs go |
| maximum number | wording | approximated | the template's words made from the name, its inputs appended | the maximum number for *a number* with *a second number* is *a value* | to be reviewed: the name does not say where its inputs go |
| list if true otherwise empty | wording | approximated | the template's words made from the name, its inputs appended | the list whether true else empty for *a condition* is *a list* | to be reviewed: the name does not say where its inputs go |
| fibonacci number | wording | approximated | the template's words made from the name, its inputs appended | the fibonacci number for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| basic if example | definition | encoded | func | the basic whether example is *a text* |  |
| check if positive | definition | encoded | func | the check whether positive for *a number* is *a text* |  |
| absolute value of | definition | encoded | func | the absolute value of *a number* is *a second number* |  |
| letter grade for | definition | encoded | func | the letter grade for *a score* is *a text* |  |
| can enter venue | definition | encoded | func | the can enter venue for *an age* with *a boolean* with *a second boolean* is *a text* |  |
| is adult | definition | encoded | pred | *a person age* is adult |  |
| is adult 2 | definition | encoded | pred | *a number* is adult 2 |  |
| maximum number | definition | encoded | func | the maximum number for *a number* with *a second number* is *a value* |  |
| list if true otherwise empty | definition | encoded | func | the list whether true else empty for *a condition* is *a list* |  |
| fibonacci number | definition | encoded | func | the fibonacci number for *a number* is *a second number* |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 24 | test | encoded | a query and the evaluator's answer | line_24 |  |
| #EVAL at line 25 | test | encoded | a query and the evaluator's answer | line_25 |  |
| #EVAL at line 37 | test | encoded | a query and the evaluator's answer | line_37 |  |
| #EVAL at line 38 | test | encoded | a query and the evaluator's answer | line_38 |  |
| #EVAL at line 39 | test | encoded | a query and the evaluator's answer | line_39 |  |
| #EVAL at line 51 | test | encoded | a query and the evaluator's answer | line_51 |  |
| #EVAL at line 52 | test | encoded | a query and the evaluator's answer | line_52 |  |
| #EVAL at line 53 | test | encoded | a query and the evaluator's answer | line_53 |  |
| #EVAL at line 82 | test | encoded | a query and the evaluator's answer | line_82 |  |
| #EVAL at line 83 | test | encoded | a query and the evaluator's answer | line_83 |  |
| #EVAL at line 84 | test | encoded | a query and the evaluator's answer | line_84 |  |
| #EVAL at line 95 | test | encoded | a query and the evaluator's answer | line_95 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_12 | line_12 | pass |  |
| line_13 | line_13 | pass |  |
| line_14 | line_14 | pass |  |
| line_24 | line_24 | pass |  |
| line_25 | line_25 | pass |  |
| line_37 | line_37 | pass |  |
| line_38 | line_38 | pass |  |
| line_39 | line_39 | pass |  |
| line_51 | line_51 | pass |  |
| line_52 | line_52 | pass |  |
| line_53 | line_53 | pass |  |
| line_82 | line_82 | pass |  |
| line_83 | line_83 | pass |  |
| line_84 | line_84 | pass |  |
| line_95 | line_95 | pass |  |


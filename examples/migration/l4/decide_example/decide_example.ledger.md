# Migration ledger: decide_example

Source: an L4 program (smucclaw/l4-ide) — decide-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 23 |
| approximated | 5 |
| residue | 0 |
| **total** | 28 |

Fidelity: **9 of 9** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| double a number | wording | approximated | the template's words made from the name, its inputs appended | the double a number for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| square of | wording | approximated | the template's words made from the name, its inputs appended | the square of *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| age category for | wording | approximated | the template's words made from the name, its inputs appended | the age category for *an age* is *a text* | to be reviewed: the name does not say where its inputs go |
| factorial of | wording | approximated | the template's words made from the name, its inputs appended | the factorial of *a num* is *a number* | to be reviewed: the name does not say where its inputs go |
| maximum of two numbers | wording | approximated | the template's words made from the name, its inputs appended | the maximum of two numbers for *a number* with *a second number* is *a value* | to be reviewed: the name does not say where its inputs go |
| the answer | definition | encoded | func | the answer is *a number* |  |
| approximate pi | definition | encoded | func | the approximate pi is *a number* |  |
| welcome greeting | definition | encoded | func | the welcome greeting is *a text* |  |
| is enabled | definition | encoded | pred | is enabled |  |
| double a number | definition | encoded | func | the double a number for *a number* is *a second number* |  |
| square of | definition | encoded | func | the square of *a number* is *a second number* |  |
| age category for | definition | encoded | func | the age category for *an age* is *a text* |  |
| person age | assume | encoded | a template the scenarios state (; undefined) | person age |  |
| has valid ID | assume | encoded | a template the scenarios state (; undefined) | has valid ID |  |
| can enter venue | definition | encoded | pred | can enter venue |  |
| local pi | definition | encoded | func | the local pi is *a number* |  |
| area of circle with radius | definition | encoded | func | the area of circle with *a radius* is *a number* |  |
| factorial of | definition | encoded | func | the factorial of *a num* is *a number* |  |
| maximum of two numbers | definition | encoded | func | the maximum of two numbers for *a number* with *a second number* is *a value* |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |
| #EVAL at line 19 | test | encoded | a query and the evaluator's answer | line_19 |  |
| #EVAL at line 25 | test | encoded | a query and the evaluator's answer | line_25 |  |
| #EVAL at line 36 | test | encoded | a query and the evaluator's answer | line_36 |  |
| #EVAL at line 37 | test | encoded | a query and the evaluator's answer | line_37 |  |
| #EVAL at line 56 | test | encoded | a query and the evaluator's answer | line_56 |  |
| #EVAL at line 67 | test | encoded | a query and the evaluator's answer | line_67 |  |
| #EVAL at line 75 | test | encoded | a query and the evaluator's answer | line_75 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_10 | line_10 | pass |  |
| line_11 | line_11 | pass |  |
| line_19 | line_19 | pass |  |
| line_25 | line_25 | pass |  |
| line_36 | line_36 | pass |  |
| line_37 | line_37 | pass |  |
| line_56 | line_56 | pass |  |
| line_67 | line_67 | pass |  |
| line_75 | line_75 | pass |  |


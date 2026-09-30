# Migration ledger: where_example

Source: an L4 program (smucclaw/l4-ide) — where-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 27 |
| approximated | 17 |
| residue | 1 |
| **total** | 45 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| area of circle | wording | approximated | the template's words made from the name, its inputs appended | the area of circle for *a radius* is *a number* | to be reviewed: the name does not say where its inputs go |
| sum times difference | wording | approximated | the template's words made from the name, its inputs appended | the sum times difference for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| quadratic discriminant | wording | approximated | the template's words made from the name, its inputs appended | the quadratic discriminant for *a number* with *a second number* with *a third number* is *a fourth number* | to be reviewed: the name does not say where its inputs go |
| sum of squares | wording | approximated | the template's words made from the name, its inputs appended | the sum of squares for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| distance between points | wording | approximated | the template's words made from the name, its inputs appended | the distance between points for *a number* with *a second number* with *a third number* with *a fourth number* is *a value* | to be reviewed: the name does not say where its inputs go |
| sum of list using where | wording | approximated | the template's words made from the name, its inputs appended | the sum of list using where for *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| pi | definition | encoded | func | the pi is *a number* |  |
| area of circle | definition | encoded | func | the area of circle for *a radius* is *a number* |  |
| sum value | wording | approximated | the template's words made from the name, its inputs appended | the sum value for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| diff value | wording | approximated | the template's words made from the name, its inputs appended | the diff value for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| sum value | definition | encoded | func | the sum value for *a number* with *a second number* is *a third number* |  |
| diff value | definition | encoded | func | the diff value for *a number* with *a second number* is *a third number* |  |
| sum times difference | definition | encoded | func | the sum times difference for *a number* with *a second number* is *a third number* |  |
| b squared | wording | approximated | the template's words made from the name, its inputs appended | the b squared for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| four a c | wording | approximated | the template's words made from the name, its inputs appended | the four a c for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| b squared | definition | encoded | func | the b squared for *a number* is *a second number* |  |
| four a c | definition | encoded | func | the four a c for *a number* with *a second number* is *a third number* |  |
| quadratic discriminant | definition | encoded | func | the quadratic discriminant for *a number* with *a second number* with *a third number* is *a fourth number* |  |
| inner | definition | encoded | func | the inner is *a number* |  |
| middle | definition | encoded | func | the middle is *a value* |  |
| outer | definition | encoded | func | the outer is *a value* |  |
| square of | wording | approximated | the template's words made from the name, its inputs appended | the square of *a value* is *a number* | to be reviewed: the name does not say where its inputs go |
| square of | definition | encoded | func | the square of *a value* is *a number* |  |
| sum of squares | definition | encoded | func | the sum of squares for *a number* with *a second number* is *a third number* |  |
| delta x | wording | approximated | the template's words made from the name, its inputs appended | the delta x for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| delta y | wording | approximated | the template's words made from the name, its inputs appended | the delta y for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| dx squared | wording | approximated | the template's words made from the name, its inputs appended | the dx squared for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| dy squared | wording | approximated | the template's words made from the name, its inputs appended | the dy squared for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| square root | wording | approximated | the template's words made from the name, its inputs appended | the square root for *a value* is *a second value* | to be reviewed: the name does not say where its inputs go |
| delta x | definition | encoded | func | the delta x for *a number* with *a second number* is *a third number* |  |
| delta y | definition | encoded | func | the delta y for *a number* with *a second number* is *a third number* |  |
| dx squared | definition | encoded | func | the dx squared for *a number* with *a second number* is *a third number* |  |
| dy squared | definition | encoded | func | the dy squared for *a number* with *a second number* is *a third number* |  |
| square root | definition | residue | a value with no LE form | r1 |  |
| distance between points | definition | encoded | func | the distance between points for *a number* with *a second number* with *a third number* with *a fourth number* is *a value* |  |
| rest sum | wording | approximated | the template's words made from the name, its inputs appended | the rest sum for *a tail* is *a number* | to be reviewed: the name does not say where its inputs go |
| rest sum | definition | encoded | func | the rest sum for *a tail* is *a number* |  |
| sum of list using where | definition | encoded | func | the sum of list using where for *a list* is *a number* |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |
| #EVAL at line 22 | test | encoded | a query and the evaluator's answer | line_22 |  |
| #EVAL at line 35 | test | encoded | a query and the evaluator's answer | line_35 |  |
| #EVAL at line 47 | test | encoded | a query and the evaluator's answer | line_47 |  |
| #EVAL at line 57 | test | encoded | a query and the evaluator's answer | line_57 |  |
| #EVAL at line 76 | test | encoded | a query and the evaluator's answer | line_76 |  |
| #EVAL at line 89 | test | encoded | a query and the evaluator's answer | line_89 |  |

## Residue

- **square root** (definition) — a value with no LE form; in the program: r1. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_11 | line_11 | pass |  |
| line_22 | line_22 | pass |  |
| line_35 | line_35 | pass |  |
| line_47 | line_47 | pass |  |
| line_57 | line_57 | pass |  |
| line_89 | line_89 | pass |  |


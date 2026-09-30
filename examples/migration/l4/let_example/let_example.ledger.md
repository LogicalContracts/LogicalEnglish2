# Migration ledger: let_example

Source: an L4 program (smucclaw/l4-ide) — let-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 44 |
| approximated | 4 |
| residue | 3 |
| **total** | 51 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Point | record | encoded | a type of individuals, one template per field | Point |  |
| factorial of | wording | approximated | the template's words made from the name, its inputs appended | the factorial of *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| quadratic discriminant | wording | approximated | the template's words made from the name, its inputs appended | the quadratic discriminant for *a number* with *a second number* with *a third number* is *a value* | to be reviewed: the name does not say where its inputs go |
| x | definition | encoded | func | the x is *a number* |  |
| result with single binding | definition | encoded | func | the result with single binding is *a number* |  |
| x | definition | encoded | func | the x in sum of two values is *a number* |  |
| y | definition | encoded | func | the y is *a number* |  |
| sum of two values | definition | encoded | func | the sum of two values is *a number* |  |
| x | definition | encoded | func | the x in sum of three values is *a number* |  |
| y | definition | encoded | func | the y in sum of three values is *a number* |  |
| z | definition | encoded | func | the z is *a number* |  |
| sum of three values | definition | encoded | func | the sum of three values is *a number* |  |
| initial value | definition | encoded | func | the initial value is *a number* |  |
| doubled value | definition | encoded | func | the doubled value is *a number* |  |
| final value | definition | encoded | func | the final value is *a number* |  |
| calculated result using forward references | definition | encoded | func | the calculated result using forward references is *a value* |  |
| a | definition | encoded | func | a is *a number* |  |
| b | definition | encoded | func | the b is *a number* |  |
| c | definition | encoded | func | the c is *a number* |  |
| d | definition | encoded | func | the d is *a number* |  |
| e | definition | encoded | func | the e is *a number* |  |
| sum using various binding keywords | definition | encoded | func | the sum using various binding keywords is *a number* |  |
| val | definition | encoded | func | the val is *a number* |  |
| result | definition | encoded | func | the result is *a number* |  |
| using equals for binding | definition | encoded | func | the using equals for binding is *a value* |  |
| step one | definition | encoded | func | the step one is *a number* |  |
| step two | definition | encoded | func | the step two is *a number* |  |
| step three | definition | encoded | func | the step three is *a number* |  |
| nested let expressions | definition | encoded | func | the nested let expressions is *a value* |  |
| previous factorial | wording | approximated | the template's words made from the name, its inputs appended | the previous factorial for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| previous factorial | definition | encoded | func | the previous factorial for *a number* is *a second number* |  |
| factorial of | definition | encoded | func | the factorial of *a number* is *a second number* |  |
| the origin | definition | residue | a value with no LE form | r1 |  |
| shifted point | definition | residue | a value with no LE form | r2 |  |
| shifted point example | definition | encoded | func | the shifted point example is *a value* |  |
| all numbers | definition | encoded | func | the all numbers is *a list* |  |
| list of numbers example | definition | encoded | func | the list of numbers example is *a value* |  |
| the discriminant | wording | approximated | the template's words made from the name, its inputs appended | the discriminant for *a number* with *a second number* with *a third number* is *a fourth number* | to be reviewed: the name does not say where its inputs go |
| the discriminant | definition | encoded | func | the discriminant for *a number* with *a second number* with *a third number* is *a fourth number* |  |
| quadratic discriminant | definition | encoded | func | the quadratic discriminant for *a number* with *a second number* with *a third number* is *a value* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #EVAL at line 19 | test | encoded | a query and the evaluator's answer | line_19 |  |
| #EVAL at line 30 | test | encoded | a query and the evaluator's answer | line_30 |  |
| #EVAL at line 41 | test | encoded | a query and the evaluator's answer | line_41 |  |
| #EVAL at line 54 | test | encoded | a query and the evaluator's answer | line_54 |  |
| #EVAL at line 64 | test | encoded | a query and the evaluator's answer | line_64 |  |
| #EVAL at line 74 | test | encoded | a query and the evaluator's answer | line_74 |  |
| #EVAL at line 85 | test | encoded | a query and the evaluator's answer | line_85 |  |
| #eval at line 97 | test | residue | the evaluator's answer is not a value LE writes: Point WITH x IS 10, y IS 20 |  |  |
| #EVAL at line 106 | test | encoded | a query and the evaluator's answer | line_106 |  |
| #EVAL at line 118 | test | encoded | a query and the evaluator's answer | line_118 |  |

## Residue

- **the origin** (definition) — a value with no LE form; in the program: r1. 
- **shifted point** (definition) — a value with no LE form; in the program: r2. 
- **#eval at line 97** (test) — the evaluator's answer is not a value LE writes: Point WITH x IS 10, y IS 20; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |
| line_19 | line_19 | pass |  |
| line_30 | line_30 | pass |  |
| line_41 | line_41 | pass |  |
| line_54 | line_54 | pass |  |
| line_64 | line_64 | pass |  |
| line_74 | line_74 | pass |  |
| line_85 | line_85 | pass |  |
| line_106 | line_106 | pass |  |
| line_118 | line_118 | pass |  |


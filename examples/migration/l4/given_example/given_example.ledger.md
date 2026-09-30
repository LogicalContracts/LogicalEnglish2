# Migration ledger: given_example

Source: an L4 program (smucclaw/l4-ide) — given-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 22 |
| approximated | 12 |
| residue | 4 |
| **total** | 38 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Point | record | encoded | a type of individuals, one template per field | Point |  |
| double the value | wording | approximated | the template's words made from the name, its inputs appended | the double the value for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| greet the person | wording | approximated | the template's words made from the name, its inputs appended | the greet the person for *a person name* is *a value* | to be reviewed: the name does not say where its inputs go |
| add two numbers | wording | approximated | the template's words made from the name, its inputs appended | the add two numbers for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| multiply two numbers | wording | approximated | the template's words made from the name, its inputs appended | the multiply two numbers for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| sum of three numbers | wording | approximated | the template's words made from the name, its inputs appended | the sum of three numbers for *a number* with *a second number* with *a third number* is *a fourth number* | to be reviewed: the name does not say where its inputs go |
| get x coordinate | wording | approximated | the template's words made from the name, its inputs appended | the get x coordinate for *a point* is *a value* | to be reviewed: the name does not say where its inputs go |
| distance squared between points | wording | approximated | the template's words made from the name, its inputs appended | the distance squared between points for *a point* with *a second point* is *a number* | to be reviewed: the name does not say where its inputs go |
| length of list | wording | approximated | the template's words made from the name, its inputs appended | the length of list for *a value* with *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| is positive number | wording | approximated | the template's words made from the name, its inputs appended | *a number* is positive number | to be reviewed: the name does not say where its inputs go |
| sign of number | wording | approximated | the template's words made from the name, its inputs appended | the sign of number for *a num* is *a text* | to be reviewed: the name does not say where its inputs go |
| double the value | definition | encoded | func | the double the value for *a number* is *a second number* |  |
| greet the person | definition | residue | a value with no LE form | r1 |  |
| add two numbers | definition | encoded | func | the add two numbers for *a number* with *a second number* is *a third number* |  |
| multiply two numbers | definition | encoded | func | the multiply two numbers for *a number* with *a second number* is *a third number* |  |
| sum of three numbers | definition | encoded | func | the sum of three numbers for *a number* with *a second number* with *a third number* is *a fourth number* |  |
| get x coordinate | definition | encoded | func | the get x coordinate for *a point* is *a value* |  |
| delta x | wording | approximated | the template's words made from the name, its inputs appended | the delta x for *a point* with *a second point* is *a number* | to be reviewed: the name does not say where its inputs go |
| delta y | wording | approximated | the template's words made from the name, its inputs appended | the delta y for *a point* with *a second point* is *a number* | to be reviewed: the name does not say where its inputs go |
| delta x | definition | encoded | func | the delta x for *a point* with *a second point* is *a number* |  |
| delta y | definition | encoded | func | the delta y for *a point* with *a second point* is *a number* |  |
| distance squared between points | definition | encoded | func | the distance squared between points for *a point* with *a second point* is *a number* |  |
| the origin | record | encoded | an individual with one fact per field | the_origin |  |
| point one | record | encoded | an individual with one fact per field | point_one |  |
| length of list | definition | residue | a value with no LE form | r2 |  |
| is positive number | definition | encoded | pred | *a number* is positive number |  |
| sign of number | definition | encoded | func | the sign of number for *a num* is *a text* |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 22 | test | encoded | a query and the evaluator's answer | line_22 |  |
| #EVAL at line 23 | test | encoded | a query and the evaluator's answer | line_23 |  |
| #EVAL at line 32 | test | encoded | a query and the evaluator's answer | line_32 |  |
| #EVAL at line 51 | test | encoded | a query and the evaluator's answer | line_51 |  |
| #EVAL at line 52 | test | encoded | a query and the evaluator's answer | line_52 |  |
| #eval at line 63 | test | residue | a value with no LE form: (`length of list` OF (LIST 1, 2, 3, 4, 5)) |  |  |
| #eval at line 64 | test | residue | a value with no LE form: (`length of list` OF (LIST "a", "b", "c")) |  |  |
| #EVAL at line 79 | test | encoded | a query and the evaluator's answer | line_79 |  |
| #EVAL at line 80 | test | encoded | a query and the evaluator's answer | line_80 |  |

## Residue

- **greet the person** (definition) — a value with no LE form; in the program: r1. 
- **length of list** (definition) — a value with no LE form; in the program: r2. 
- **#eval at line 63** (test) — a value with no LE form: (`length of list` OF (LIST 1, 2, 3, 4, 5)); in the program: . 
- **#eval at line 64** (test) — a value with no LE form: (`length of list` OF (LIST "a", "b", "c")); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_11 | line_11 | pass |  |
| line_22 | line_22 | pass |  |
| line_23 | line_23 | pass |  |
| line_32 | line_32 | pass |  |
| line_51 | line_51 | pass |  |
| line_52 | line_52 | pass |  |
| line_79 | line_79 | pass |  |
| line_80 | line_80 | pass |  |


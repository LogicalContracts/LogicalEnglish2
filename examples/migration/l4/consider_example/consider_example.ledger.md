# Migration ledger: consider_example

Source: an L4 program (smucclaw/l4-ide) — consider-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 26 |
| approximated | 8 |
| residue | 5 |
| **total** | 39 |

Fidelity: **13 of 13** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Colour | choice | encoded | named individuals | Colour |  |
| Shape | choice | encoded | named individuals | Shape |  |
| PairNum | record | encoded | a type of individuals, one template per field | PairNum |  |
| name of colour | wording | approximated | the template's words made from the name, its inputs appended | the name of colour for *a colour* is *a text* | to be reviewed: the name does not say where its inputs go |
| sum of list | wording | approximated | the template's words made from the name, its inputs appended | the sum of list for *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| first element or zero | wording | approximated | the template's words made from the name, its inputs appended | the first element else zero for *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| length of list | wording | approximated | the template's words made from the name, its inputs appended | the length of list for *a value* with *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| get value or default to zero | wording | approximated | the template's words made from the name, its inputs appended | the get value else default to zero for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| area of shape | wording | approximated | the template's words made from the name, its inputs appended | the area of shape for *a shape* is *a number* | to be reviewed: the name does not say where its inputs go |
| add pair values | wording | approximated | the template's words made from the name, its inputs appended | the add pair values for *a pair num* is *a number* | to be reviewed: the name does not say where its inputs go |
| sum of maybe list | wording | approximated | the template's words made from the name, its inputs appended | the sum of maybe list for *a maybe list* is *a number* | to be reviewed: the name does not say where its inputs go |
| name of colour | definition | encoded | func | the name of colour for *a colour* is *a text* |  |
| sum of list | definition | encoded | func | the sum of list for *a list* is *a number* |  |
| first element or zero | definition | encoded | func | the first element else zero for *a list* is *a number* |  |
| length of list | definition | residue | a value with no LE form | r1 |  |
| get value or default to zero | definition | encoded | func | the get value else default to zero for *a number* is *a second number* |  |
| area of shape | definition | encoded | func | the area of shape for *a shape* is *a number* |  |
| my circle | record | encoded | an individual with one fact per field | my_circle |  |
| my rectangle | record | encoded | an individual with one fact per field | my_rectangle |  |
| handle either result | definition | residue | a pattern with no LE form | r2 |  |
| add pair values | definition | encoded | func | the add pair values for *a pair num* is *a number* |  |
| first pair | record | encoded | an individual with one fact per field | first_pair |  |
| sum of maybe list | definition | encoded | func | the sum of maybe list for *a maybe list* is *a number* |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 15 | test | encoded | a query and the evaluator's answer | line_15 |  |
| #EVAL at line 27 | test | encoded | a query and the evaluator's answer | line_27 |  |
| #EVAL at line 37 | test | encoded | a query and the evaluator's answer | line_37 |  |
| #EVAL at line 38 | test | encoded | a query and the evaluator's answer | line_38 |  |
| #eval at line 48 | test | residue | a value with no LE form: (`length of list` OF (LIST "a", "b", "c")) |  |  |
| #EVAL at line 58 | test | encoded | a query and the evaluator's answer | line_58 |  |
| #EVAL at line 59 | test | encoded | a query and the evaluator's answer | line_59 |  |
| #EVAL at line 78 | test | encoded | a query and the evaluator's answer | line_78 |  |
| #EVAL at line 79 | test | encoded | a query and the evaluator's answer | line_79 |  |
| #EVAL at line 80 | test | encoded | a query and the evaluator's answer | line_80 |  |
| #eval at line 90 | test | residue | a value that is not a constant: (`LEFT` OF "not found") |  |  |
| #eval at line 91 | test | residue | a value that is not a constant: (`RIGHT` OF 42) |  |  |
| #EVAL at line 103 | test | encoded | a query and the evaluator's answer | line_103 |  |
| #EVAL at line 113 | test | encoded | a query and the evaluator's answer | line_113 |  |
| #EVAL at line 114 | test | encoded | a query and the evaluator's answer | line_114 |  |

## Residue

- **length of list** (definition) — a value with no LE form; in the program: r1. 
- **handle either result** (definition) — a pattern with no LE form; in the program: r2. 
- **#eval at line 48** (test) — a value with no LE form: (`length of list` OF (LIST "a", "b", "c")); in the program: . 
- **#eval at line 90** (test) — a value that is not a constant: (`LEFT` OF "not found"); in the program: . 
- **#eval at line 91** (test) — a value that is not a constant: (`RIGHT` OF 42); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_14 | line_14 | pass |  |
| line_15 | line_15 | pass |  |
| line_27 | line_27 | pass |  |
| line_37 | line_37 | pass |  |
| line_38 | line_38 | pass |  |
| line_58 | line_58 | pass |  |
| line_59 | line_59 | pass |  |
| line_78 | line_78 | pass |  |
| line_79 | line_79 | pass |  |
| line_80 | line_80 | pass |  |
| line_103 | line_103 | pass |  |
| line_113 | line_113 | pass |  |
| line_114 | line_114 | pass |  |


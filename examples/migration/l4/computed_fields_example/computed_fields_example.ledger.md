# Migration ledger: computed_fields_example

Source: an L4 program (smucclaw/l4-ide) — computed-fields-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 28 |
| approximated | 2 |
| residue | 2 |
| **total** | 32 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (waits for residue r1, r2): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Employee | record | encoded | a type of individuals, one template per field | Employee |  |
| Account | record | encoded | a type of individuals, one template per field | Account |  |
| Shape | record | encoded | a type of individuals, one template per field | Shape |  |
| apply rate | wording | approximated | the template's words made from the name, its inputs appended | the apply *a rate* for *a base* is *a number* | to be reviewed: the name does not say where its inputs go |
| square | wording | approximated | the template's words made from the name, its inputs appended | the square for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| age | computed_field | encoded | a rule over the record's other fields | Employee |  |
| years of service | computed_field | encoded | a rule over the record's other fields | Employee |  |
| senior | computed_field | encoded | a rule over the record's other fields | Employee |  |
| eligible | computed_field | encoded | a rule over the record's other fields | Employee |  |
| interest | computed_field | encoded | a rule over the record's other fields | Account |  |
| projected | computed_field | encoded | a rule over the record's other fields | Account |  |
| area | computed_field | encoded | a rule over the record's other fields | Shape |  |
| w2 | definition | residue | a value with no LE form | r1 |  |
| h2 | definition | residue | a value with no LE form | r2 |  |
| result | definition | encoded | func | the result is *a number* |  |
| diag sq | computed_field | encoded | a rule over the record's other fields | Shape |  |
| factor | definition | encoded | func | the factor is *a number* |  |
| scaled | computed_field | encoded | a rule over the record's other fields | Shape |  |
| veteran | record | encoded | an individual with one fact per field | veteran |  |
| apply rate | definition | encoded | func | the apply *a rate* for *a base* is *a number* |  |
| savings | record | encoded | an individual with one fact per field | savings |  |
| square | definition | encoded | func | the square for *a number* is *a second number* |  |
| rect | record | encoded | an individual with one fact per field | rect |  |
| #EVAL at line 40 | test | encoded | a query and the evaluator's answer | line_40 |  |
| #EVAL at line 41 | test | encoded | a query and the evaluator's answer | line_41 |  |
| #EVAL at line 42 | test | encoded | a query and the evaluator's answer | line_42 |  |
| #EVAL at line 43 | test | encoded | a query and the evaluator's answer | line_43 |  |
| #EVAL at line 71 | test | encoded | a query and the evaluator's answer | line_71 |  |
| #EVAL at line 72 | test | encoded | a query and the evaluator's answer | line_72 |  |
| #EVAL at line 100 | test | encoded | a query and the evaluator's answer | line_100 |  |
| #EVAL at line 101 | test | encoded | a query and the evaluator's answer | line_101 |  |
| #EVAL at line 102 | test | encoded | a query and the evaluator's answer | line_102 |  |

## Residue

- **w2** (definition) — a value with no LE form; in the program: r1. 
- **h2** (definition) — a value with no LE form; in the program: r2. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_40 | line_40 | pass |  |
| line_41 | line_41 | pass |  |
| line_42 | line_42 | pass |  |
| line_43 | line_43 | pass |  |
| line_71 | line_71 | pass |  |
| line_72 | line_72 | pass |  |
| line_100 | line_100 | pass |  |
| line_102 | line_102 | pass |  |


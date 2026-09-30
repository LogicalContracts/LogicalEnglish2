# Migration ledger: giveth_example

Source: an L4 program (smucclaw/l4-ide) — giveth-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 11 |
| residue | 7 |
| **total** | 36 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

**2 further expectation(s) are pending** (waits for residue r1; waits for residue r2): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| square | wording | approximated | the template's words made from the name, its inputs appended | the square for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| maximum | wording | approximated | the template's words made from the name, its inputs appended | the maximum for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| isAdult | wording | approximated | the template's words made from the name, its inputs appended | *an age* is adult | to be reviewed: the name does not say where its inputs go |
| isEven | wording | approximated | the template's words made from the name, its inputs appended | *a number* is even | to be reviewed: the name does not say where its inputs go |
| greet | wording | approximated | the template's words made from the name, its inputs appended | the greet for *a name* is *a text* | to be reviewed: the name does not say where its inputs go |
| describe | wording | approximated | the template's words made from the name, its inputs appended | the describe for *a num* is *a text* | to be reviewed: the name does not say where its inputs go |
| safeHead | wording | approximated | the template's words made from the name, its inputs appended | the safe head for *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| countdown | wording | approximated | the template's words made from the name, its inputs appended | the countdown for *a number* is *a list* | to be reviewed: the name does not say where its inputs go |
| triple | wording | approximated | the template's words made from the name, its inputs appended | the triple for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| singleton | wording | approximated | the template's words made from the name, its inputs appended | the singleton for *a value* with *a thing* is *a list* | to be reviewed: the name does not say where its inputs go |
| makePerson | wording | approximated | the template's words made from the name, its inputs appended | the make person for *a person name* with *a person age* is *a person* | to be reviewed: the name does not say where its inputs go |
| square | definition | encoded | func | the square for *a number* is *a second number* |  |
| maximum | definition | encoded | func | the maximum for *a number* with *a second number* is *a third number* |  |
| isAdult | definition | encoded | pred | *an age* is adult |  |
| isEven | definition | encoded | pred | *a number* is even |  |
| greet | definition | residue | a value with no LE form | r1 |  |
| describe | definition | encoded | func | the describe for *a num* is *a text* |  |
| safeHead | definition | encoded | func | the safe head for *a list* is *a number* |  |
| countdown | definition | residue | a value with no LE form | r2 |  |
| triple | definition | encoded | func | the triple for *a number* is *a second number* |  |
| singleton | definition | residue | a value with no LE form | r3 |  |
| makePerson | definition | residue | a value with no LE form | r4 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 15 | test | encoded | a query and the evaluator's answer | line_15 |  |
| #EVAL at line 27 | test | encoded | a query and the evaluator's answer | line_27 |  |
| #EVAL at line 28 | test | encoded | a query and the evaluator's answer | line_28 |  |
| #EVAL at line 43 | test | encoded | a query and the evaluator's answer | line_43 |  |
| #EVAL at line 44 | test | encoded | a query and the evaluator's answer | line_44 |  |
| #EVAL at line 57 | test | encoded | a query and the evaluator's answer | line_57 |  |
| #EVAL at line 58 | test | encoded | a query and the evaluator's answer | line_58 |  |
| #EVAL at line 67 | test | encoded | a query and the evaluator's answer | line_67 |  |
| #EVAL at line 75 | test | encoded | a query and the evaluator's answer | line_75 |  |
| #eval at line 83 | test | residue | a value with no LE form: (`singleton` OF 42) |  |  |
| #eval at line 84 | test | residue | a value with no LE form: (`singleton` OF "hello") |  |  |
| #eval at line 95 | test | residue | the evaluator's answer is not a value LE writes: Person WITH name IS "Bob", age IS 30 |  |  |

## Residue

- **greet** (definition) — a value with no LE form; in the program: r1. 
- **countdown** (definition) — a value with no LE form; in the program: r2. 
- **singleton** (definition) — a value with no LE form; in the program: r3. 
- **makePerson** (definition) — a value with no LE form; in the program: r4. 
- **#eval at line 83** (test) — a value with no LE form: (`singleton` OF 42); in the program: . 
- **#eval at line 84** (test) — a value with no LE form: (`singleton` OF "hello"); in the program: . 
- **#eval at line 95** (test) — the evaluator's answer is not a value LE writes: Person WITH name IS "Bob", age IS 30; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_14 | line_14 | pass |  |
| line_15 | line_15 | pass |  |
| line_27 | line_27 | pass |  |
| line_28 | line_28 | pass |  |
| line_44 | line_44 | pass |  |
| line_57 | line_57 | pass |  |
| line_58 | line_58 | pass |  |
| line_75 | line_75 | pass |  |


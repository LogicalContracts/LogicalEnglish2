# Migration ledger: aka_example

Source: an L4 program (smucclaw/l4-ide) — aka-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 17 |
| approximated | 2 |
| residue | 8 |
| **total** | 27 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| B | type | encoded | a type | B |  |
| Pair | record | encoded | a type of individuals, one template per field | Pair |  |
| Authorized Representative | record | encoded | a type of individuals, one template per field | Authorized Representative |  |
| double | wording | approximated | the template's words made from the name, its inputs appended | the double for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| tax | wording | approximated | the template's words made from the name, its inputs appended | the tax for *an amount* is *a number* | to be reviewed: the name does not say where its inputs go |
| x | definition | encoded | pred | x |  |
| example1 | definition | encoded | func | the example1 is *a b* |  |
| example2 | definition | encoded | func | the example2 is *a yes no* |  |
| testPair1 | record | encoded | an individual with one fact per field | test_pair1 |  |
| testPair2 | record | encoded | an individual with one fact per field | test_pair2 |  |
| myAgent | record | encoded | an individual with one fact per field | my_agent |  |
| double | definition | encoded | func | the double for *a number* is *a second number* |  |
| tax | definition | encoded | func | the tax for *an amount* is *a number* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #eval at line 10 | test | residue | a value with no LE form: `y` |  |  |
| #eval at line 11 | test | residue | a value with no LE form: `z` |  |  |
| #EVAL at line 25 | test | encoded | a query and the evaluator's answer | line_25 |  |
| #EVAL at line 26 | test | encoded | a query and the evaluator's answer | line_26 |  |
| #eval at line 45 | test | residue | the evaluator's answer is not a value LE writes: Pair WITH px IS 3, py IS 5 |  |  |
| #eval at line 46 | test | residue | the evaluator's answer is not a value LE writes: Pair WITH px IS 10, py IS 20 |  |  |
| #EVAL at line 62 | test | encoded | a query and the evaluator's answer | line_62 |  |
| #EVAL at line 70 | test | encoded | a query and the evaluator's answer | line_70 |  |
| #eval at line 71 | test | residue | a value with no LE form: (`twice` OF 5) |  |  |
| #EVAL at line 78 | test | encoded | a query and the evaluator's answer | line_78 |  |
| #eval at line 79 | test | residue | a value with no LE form: (`VAT` OF 100) |  |  |
| #eval at line 80 | test | residue | a value with no LE form: (`sales tax` OF 100) |  |  |
| #eval at line 81 | test | residue | a value with no LE form: (`GST` OF 100) |  |  |

## Residue

- **#eval at line 10** (test) — a value with no LE form: `y`; in the program: . 
- **#eval at line 11** (test) — a value with no LE form: `z`; in the program: . 
- **#eval at line 45** (test) — the evaluator's answer is not a value LE writes: Pair WITH px IS 3, py IS 5; in the program: . 
- **#eval at line 46** (test) — the evaluator's answer is not a value LE writes: Pair WITH px IS 10, py IS 20; in the program: . 
- **#eval at line 71** (test) — a value with no LE form: (`twice` OF 5); in the program: . 
- **#eval at line 79** (test) — a value with no LE form: (`VAT` OF 100); in the program: . 
- **#eval at line 80** (test) — a value with no LE form: (`sales tax` OF 100); in the program: . 
- **#eval at line 81** (test) — a value with no LE form: (`GST` OF 100); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |
| line_25 | line_25 | pass |  |
| line_26 | line_26 | pass |  |
| line_62 | line_62 | pass |  |
| line_70 | line_70 | pass |  |
| line_78 | line_78 | pass |  |


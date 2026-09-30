# Migration ledger: associativity_example

Source: an L4 program (smucclaw/l4-ide) — associativity-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 0 |
| residue | 1 |
| **total** | 5 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| a | definition | encoded | func | a is *a number* |  |
| b | definition | encoded | func | the b is *a number* |  |
| c | definition | encoded | func | the c is *a number* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #eval at line 13 | test | residue | a value with no LE form: (1 FOLLOWED BY 2 FOLLOWED BY 3 FOLLOWED BY `EMPTY`) |  |  |

## Residue

- **#eval at line 13** (test) — a value with no LE form: (1 FOLLOWED BY 2 FOLLOWED BY 3 FOLLOWED BY `EMPTY`); in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |


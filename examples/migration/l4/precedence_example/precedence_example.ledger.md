# Migration ledger: precedence_example

Source: an L4 program (smucclaw/l4-ide) — precedence-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| x | definition | encoded | func | the x is *a number* |  |
| y | definition | encoded | func | the y is *a number* |  |
| z | definition | encoded | func | the z is *a number* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |
| line_13 | line_13 | pass |  |


# Migration ledger: list_example

Source: an L4 program (smucclaw/l4-ide) — list-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 1 |
| **total** | 4 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| first list | definition | encoded | func | the first list is *a list* |  |
| second list | definition | residue | a value with no LE form | r1 |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |

## Residue

- **second list** (definition) — a value with no LE form; in the program: r1. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_10 | line_10 | pass |  |


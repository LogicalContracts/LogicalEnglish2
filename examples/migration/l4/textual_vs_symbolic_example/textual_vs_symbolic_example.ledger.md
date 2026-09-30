# Migration ledger: textual_vs_symbolic_example

Source: an L4 program (smucclaw/l4-ide) — textual-vs-symbolic-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 8 |
| approximated | 0 |
| residue | 0 |
| **total** | 8 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| age | definition | encoded | func | the age is *a number* |  |
| citizen | definition | encoded | pred | citizen |  |
| eligible1 | definition | encoded | pred | eligible1 |  |
| eligible2 | definition | encoded | pred | eligible2 |  |
| eligible3 | definition | encoded | pred | eligible3 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_12 | line_12 | pass |  |
| line_13 | line_13 | pass |  |
| line_14 | line_14 | pass |  |


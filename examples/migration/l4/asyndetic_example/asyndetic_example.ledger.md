# Migration ledger: asyndetic_example

Source: an L4 program (smucclaw/l4-ide) — asyndetic-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| citizen | definition | encoded | pred | citizen |  |
| over18 | definition | encoded | pred | over18 |  |
| hasID | definition | encoded | pred | has ID |  |
| approved | definition | encoded | pred | approved |  |
| pending | definition | encoded | pred | pending |  |
| review | definition | encoded | pred | review |  |
| eligible1 | definition | encoded | pred | eligible1 |  |
| inProgress | definition | encoded | pred | in progress |  |
| #EVAL at line 20 | test | encoded | a query and the evaluator's answer | line_20 |  |
| #EVAL at line 21 | test | encoded | a query and the evaluator's answer | line_21 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_20 | line_20 | pass |  |
| line_21 | line_21 | pass |  |


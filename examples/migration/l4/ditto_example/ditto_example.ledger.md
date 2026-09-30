# Migration ledger: ditto_example

Source: an L4 program (smucclaw/l4-ide) — ditto-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 0 |
| residue | 0 |
| **total** | 7 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| eligible | definition | encoded | pred | eligible |  |
| john | definition | encoded | pred | john |  |
| mary | definition | encoded | pred | mary |  |
| alice | definition | encoded | pred | alice |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_10 | line_10 | pass |  |
| line_11 | line_11 | pass |  |
| line_12 | line_12 | pass |  |


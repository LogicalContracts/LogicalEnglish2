# Migration ledger: enum_example

Source: an L4 program (smucclaw/l4-ide) — enum-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 0 |
| residue | 0 |
| **total** | 4 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Color | choice | encoded | named individuals | Color |  |
| my favorite color | definition | encoded | func | the my favorite color is *a value* |  |
| name of the color | definition | encoded | func | the name of the color is *a text* |  |
| #EVAL at line 18 | test | encoded | a query and the evaluator's answer | line_18 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_18 | line_18 | pass |  |


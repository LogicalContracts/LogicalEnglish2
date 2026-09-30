# Migration ledger: maybe_example

Source: an L4 program (smucclaw/l4-ide) — maybe-example.l4
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
| value is present | definition | encoded | func | the value is present is *a value* |  |
| value is absent | definition | encoded | func | the value is absent is *a value* |  |
| get the value or default to zero | definition | encoded | func | the get the value else default to zero is *a value* |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_12 | line_12 | pass |  |


# Migration ledger: function_type_example

Source: an L4 program (smucclaw/l4-ide) — function-type-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 1 |
| residue | 0 |
| **total** | 3 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| add | wording | approximated | the template's words made from the name, its inputs appended | the add for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| add | definition | encoded | func | the add for *a number* with *a second number* is *a third number* |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_9 | line_9 | pass |  |


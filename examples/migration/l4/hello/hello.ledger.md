# Migration ledger: hello

Source: an L4 program (smucclaw/l4-ide) — hello.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 4 |
| approximated | 1 |
| residue | 0 |
| **total** | 5 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| is adult | wording | approximated | the template's words made from the name, its inputs appended | *a person* is adult | to be reviewed: the name does not say where its inputs go |
| alice | record | encoded | an individual with one fact per field | alice |  |
| is adult | definition | encoded | pred | *a person* is adult |  |
| #EVAL at line 17 | test | encoded | a query and the evaluator's answer | line_17 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_17 | line_17 | pass |  |


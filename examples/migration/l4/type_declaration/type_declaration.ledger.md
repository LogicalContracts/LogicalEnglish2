# Migration ledger: type_declaration

Source: an L4 program (smucclaw/l4-ide) — type-declaration.l4
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

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Registered Charity | record | encoded | a type of individuals, one template per field | Registered Charity |  |
| Example Charity | record | encoded | an individual with one fact per field | example_charity |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 15 | test | encoded | a query and the evaluator's answer | line_15 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_14 | line_14 | pass |  |
| line_15 | line_15 | pass |  |


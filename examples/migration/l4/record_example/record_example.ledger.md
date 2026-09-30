# Migration ledger: record_example

Source: an L4 program (smucclaw/l4-ide) — record-example.l4
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
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| the applicant | record | encoded | an individual with one fact per field | the_applicant |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_13 | line_13 | pass |  |
| line_14 | line_14 | pass |  |


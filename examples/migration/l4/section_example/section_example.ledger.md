# Migration ledger: section_example

Source: an L4 program (smucclaw/l4-ide) — section-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 0 |
| **total** | 6 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| age | definition | encoded | func | the age is *a number* |  |
| citizen | definition | encoded | pred | citizen |  |
| ageEligible | definition | encoded | pred | age eligible |  |
| citizenshipEligible | definition | encoded | pred | citizenship eligible |  |
| #EVAL at line 17 | test | encoded | a query and the evaluator's answer | line_17 |  |
| #EVAL at line 18 | test | encoded | a query and the evaluator's answer | line_18 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_17 | line_17 | pass |  |
| line_18 | line_18 | pass |  |


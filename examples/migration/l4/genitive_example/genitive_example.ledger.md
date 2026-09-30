# Migration ledger: genitive_example

Source: an L4 program (smucclaw/l4-ide) — genitive-example.l4
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
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| the applicant | record | encoded | an individual with one fact per field | the_applicant |  |
| applicant age using genitive | definition | encoded | func | the applicant age using genitive is *a value* |  |
| applicant age using THE OF | definition | encoded | func | the applicant age using THE OF is *a value* |  |
| #EVAL at line 18 | test | encoded | a query and the evaluator's answer | line_18 |  |
| #EVAL at line 19 | test | encoded | a query and the evaluator's answer | line_19 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_18 | line_18 | pass |  |
| line_19 | line_19 | pass |  |


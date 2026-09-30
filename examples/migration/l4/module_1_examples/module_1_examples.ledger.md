# Migration ledger: module_1_examples

Source: an L4 program (smucclaw/l4-ide) — module-1-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 2 |
| **total** | 12 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Charity Status | choice | encoded | named individuals | Charity Status |  |
| Registered Charity | record | encoded | a type of individuals, one template per field | Registered Charity |  |
| Party | choice | encoded | named individuals | Party |  |
| Action | choice | encoded | named individuals | Action |  |
| the annual return obligation | contract | residue | the contracts half (step 3) | the annual return obligation |  |
| the sale contract | contract | residue | the contracts half (step 3) | the sale contract |  |
| Animal Welfare Society | record | encoded | an individual with one fact per field | animal_welfare_society |  |
| #EVAL at line 83 | test | encoded | a query and the evaluator's answer | line_83 |  |
| #EVAL at line 84 | test | encoded | a query and the evaluator's answer | line_84 |  |
| #EVAL at line 85 | test | encoded | a query and the evaluator's answer | line_85 |  |
| the annual return obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the annual return obligation |  |
| the sale contract | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the sale contract |  |

## Residue

- **the annual return obligation** (contract) — the contracts half (step 3); in the program: the annual return obligation. 
- **the sale contract** (contract) — the contracts half (step 3); in the program: the sale contract. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_83 | line_83 | pass |  |
| line_84 | line_84 | pass |  |
| line_85 | line_85 | pass |  |


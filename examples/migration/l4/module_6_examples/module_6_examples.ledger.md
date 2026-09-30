# Migration ledger: module_6_examples

Source: an L4 program (smucclaw/l4-ide) — module-6-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 31 |
| approximated | 0 |
| residue | 2 |
| **total** | 33 |

Fidelity: **9 of 9** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Purpose | choice | encoded | named individuals | Purpose |  |
| Status | choice | encoded | named individuals | Status |  |
| Conviction | record | encoded | a type of individuals, one template per field | Conviction |  |
| Governor | record | encoded | a type of individuals, one template per field | Governor |  |
| Registered Charity | record | encoded | a type of individuals, one template per field | Registered Charity |  |
| Actor | choice | encoded | named individuals | Actor |  |
| Action | choice | encoded | named individuals | Action |  |
| the governor is an adult | definition | encoded | pred | *a governor* is an adult |  |
| the governor has a disqualifying conviction | definition | encoded | pred | *a governor* has a disqualifying conviction |  |
| the person can be a governor | definition | encoded | pred | the person can be *a governor* |  |
| the purpose is charitable | definition | encoded | pred | *a purpose* is charitable |  |
| the charity is valid | definition | encoded | pred | *a charity* is valid |  |
| the annual return obligation | contract | residue | the contracts half (step 3) | the annual return obligation |  |
| the correction period | contract | residue | the contracts half (step 3) | the correction period |  |
| Jane Smith | record | encoded | an individual with one fact per field | jane_smith |  |
| John Doe (bankrupt) | record | encoded | an individual with one fact per field | john_doe_bankrupt |  |
| unspent conviction | record | encoded | an individual with one fact per field | unspent_conviction |  |
| Bob Jones (with conviction) | record | encoded | an individual with one fact per field | bob_jones_with_conviction |  |
| Young Person | record | encoded | an individual with one fact per field | young_person |  |
| Jersey Animal Welfare | record | encoded | an individual with one fact per field | jersey_animal_welfare |  |
| Problem Charity | record | encoded | an individual with one fact per field | problem_charity |  |
| Suspended Charity | record | encoded | an individual with one fact per field | suspended_charity |  |
| #EVAL at line 162 | test | encoded | a query and the evaluator's answer | line_162 |  |
| #EVAL at line 163 | test | encoded | a query and the evaluator's answer | line_163 |  |
| #EVAL at line 164 | test | encoded | a query and the evaluator's answer | line_164 |  |
| #EVAL at line 165 | test | encoded | a query and the evaluator's answer | line_165 |  |
| #EVAL at line 166 | test | encoded | a query and the evaluator's answer | line_166 |  |
| #EVAL at line 167 | test | encoded | a query and the evaluator's answer | line_167 |  |
| #EVAL at line 170 | test | encoded | a query and the evaluator's answer | line_170 |  |
| #EVAL at line 171 | test | encoded | a query and the evaluator's answer | line_171 |  |
| #EVAL at line 172 | test | encoded | a query and the evaluator's answer | line_172 |  |
| the annual return obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the annual return obligation |  |
| the correction period | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the correction period |  |

## Residue

- **the annual return obligation** (contract) — the contracts half (step 3); in the program: the annual return obligation. 
- **the correction period** (contract) — the contracts half (step 3); in the program: the correction period. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_162 | line_162 | pass |  |
| line_163 | line_163 | pass |  |
| line_164 | line_164 | pass |  |
| line_165 | line_165 | pass |  |
| line_166 | line_166 | pass |  |
| line_167 | line_167 | pass |  |
| line_170 | line_170 | pass |  |
| line_171 | line_171 | pass |  |
| line_172 | line_172 | pass |  |


# Migration ledger: module_2_examples

Source: an L4 program (smucclaw/l4-ide) — module-2-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 23 |
| approximated | 1 |
| residue | 1 |
| **total** | 25 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| Registered Charity | record | encoded | a type of individuals, one template per field | Registered Charity |  |
| Purpose | choice | encoded | named individuals | Purpose |  |
| Status | choice | encoded | named individuals | Status |  |
| Bank Account | record | encoded | a type of individuals, one template per field | Bank Account |  |
| Company | record | encoded | a type of individuals, one template per field | Company |  |
| Legal Entity | choice | encoded | named individuals | Legal Entity |  |
| the entity's name | wording | approximated | the template's words made from the name, its inputs appended | the entitys name for *an entity* is *a text* | to be reviewed: the name does not say where its inputs go |
| the purpose is charitable | definition | encoded | pred | *a purpose* is charitable |  |
| the entity's name | definition | encoded | func | the entitys name for *an entity* is *a text* |  |
| Alice Smith | record | encoded | an individual with one fact per field | alice_smith |  |
| Bob Jones | record | encoded | an individual with one fact per field | bob_jones |  |
| education purpose | definition | encoded | func | the education purpose is *a value* |  |
| custom purpose | record | encoded | an individual with one fact per field | custom_purpose |  |
| Acme Bank Account | record | encoded | an individual with one fact per field | acme_bank_account |  |
| Acme Corporation | record | encoded | an individual with one fact per field | acme_corporation |  |
| Alice as individual | record | encoded | an individual with one fact per field | alice_as_individual |  |
| Acme as corporation | record | encoded | an individual with one fact per field | acme_as_corporation |  |
| #EVAL at line 112 | test | encoded | a query and the evaluator's answer | line_112 |  |
| #EVAL at line 113 | test | encoded | a query and the evaluator's answer | line_113 |  |
| #EVAL at line 116 | test | encoded | a query and the evaluator's answer | line_116 |  |
| #eval at line 119 | test | residue | a value that is not a constant: `education purpose` |  |  |
| #EVAL at line 120 | test | encoded | a query and the evaluator's answer | line_120 |  |
| #EVAL at line 123 | test | encoded | a query and the evaluator's answer | line_123 |  |
| #EVAL at line 124 | test | encoded | a query and the evaluator's answer | line_124 |  |

## Residue

- **#eval at line 119** (test) — a value that is not a constant: `education purpose`; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_112 | line_112 | pass |  |
| line_113 | line_113 | pass |  |
| line_116 | line_116 | pass |  |
| line_120 | line_120 | pass |  |
| line_123 | line_123 | pass |  |
| line_124 | line_124 | pass |  |


# Migration ledger: a_an_example

Source: an L4 program (smucclaw/l4-ide) — a-an-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 2 |
| residue | 0 |
| **total** | 22 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Account | record | encoded | a type of individuals, one template per field | Account |  |
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| Contract | record | encoded | a type of individuals, one template per field | Contract |  |
| double | wording | approximated | the template's words made from the name, its inputs appended | the double for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| getBalance | wording | approximated | the template's words made from the name, its inputs appended | the get balance for *an acc* is *a value* | to be reviewed: the name does not say where its inputs go |
| age | assume | encoded | a template the scenarios state (; undefined) | age |  |
| name | assume | encoded | a template the scenarios state (; undefined) | name |  |
| employed | assume | encoded | a template the scenarios state (; undefined) | employed |  |
| double | definition | encoded | func | the double for *a number* is *a second number* |  |
| myAccount | assume | encoded | a template the scenarios state (; undefined) | myAccount |  |
| getBalance | definition | encoded | func | the get balance for *an acc* is *a value* |  |
| john | record | encoded | an individual with one fact per field | john |  |
| johnsName | definition | encoded | func | the johns name is *a value* |  |
| johnsAge | definition | encoded | func | the johns age is *a value* |  |
| nameViaGenitive | definition | encoded | func | the name via genitive is *a value* |  |
| agreement | assume | encoded | a template the scenarios state (; undefined) | agreement |  |
| contractDate | definition | encoded | func | the contract date is *a value* |  |
| contractAmount | definition | encoded | func | the contract amount is *a value* |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 44 | test | encoded | a query and the evaluator's answer | line_44 |  |
| #EVAL at line 45 | test | encoded | a query and the evaluator's answer | line_45 |  |
| #EVAL at line 52 | test | encoded | a query and the evaluator's answer | line_52 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_14 | line_14 | pass |  |
| line_44 | line_44 | pass |  |
| line_45 | line_45 | pass |  |
| line_52 | line_52 | pass |  |


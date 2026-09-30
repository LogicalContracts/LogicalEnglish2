# Migration ledger: module_3_examples

Source: an L4 program (smucclaw/l4-ide) — module-3-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 38 |
| approximated | 9 |
| residue | 7 |
| **total** | 54 |

Fidelity: **13 of 13** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Conviction | record | encoded | a type of individuals, one template per field | Conviction |  |
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| the age category | wording | approximated | the template's words made from the name, its inputs appended | the age category for *an age* is *a text* | to be reviewed: the name does not say where its inputs go |
| the letter grade | wording | approximated | the template's words made from the name, its inputs appended | the letter grade for *a score* is *a text* | to be reviewed: the name does not say where its inputs go |
| the amount category | wording | approximated | the template's words made from the name, its inputs appended | the amount category for *an amount* is *a text* | to be reviewed: the name does not say where its inputs go |
| the person can vote | wording | approximated | the template's words made from the name, its inputs appended | the person can vote for *an age* with *a boolean* | to be reviewed: the name does not say where its inputs go |
| the transaction needs review | wording | approximated | the template's words made from the name, its inputs appended | the transaction needs review for *an amount* with *a boolean* | to be reviewed: the name does not say where its inputs go |
| the person is a minor | wording | approximated | the template's words made from the name, its inputs appended | the person is a minor for *an age* | to be reviewed: the name does not say where its inputs go |
| some number is negative | wording | approximated | the template's words made from the name, its inputs appended | some number is negative for *a numbers* | to be reviewed: the name does not say where its inputs go |
| numbers above threshold | wording | approximated | the template's words made from the name, its inputs appended | the numbers above threshold for *a numbers* with *a threshold* is *a list* | to be reviewed: the name does not say where its inputs go |
| describe the list | wording | approximated | the template's words made from the name, its inputs appended | the describe the list for *an items* is *a text* | to be reviewed: the name does not say where its inputs go |
| the age category | definition | encoded | func | the age category for *an age* is *a text* |  |
| the letter grade | definition | encoded | func | the letter grade for *a score* is *a text* |  |
| the amount category | definition | encoded | func | the amount category for *an amount* is *a text* |  |
| the person can vote | definition | encoded | pred | the person can vote for *an age* with *a boolean* |  |
| the transaction needs review | definition | encoded | pred | the transaction needs review for *an amount* with *a boolean* |  |
| the person is a minor | definition | encoded | pred | the person is a minor for *an age* |  |
| all numbers are positive | definition | encoded | pred | all *a numbers* are positive |  |
| some number is negative | definition | encoded | pred | some number is negative for *a numbers* |  |
| numbers above threshold | definition | encoded | func | the numbers above threshold for *a numbers* with *a threshold* is *a list* |  |
| describe the list | definition | encoded | func | the describe the list for *an items* is *a text* |  |
| the person has an unspent conviction | definition | encoded | pred | *a person* has an unspent conviction |  |
| the person is eligible for the position | definition | encoded | pred | *a person* is eligible for the position |  |
| positive numbers | definition | encoded | func | the positive numbers is *a list* |  |
| mixed numbers | definition | encoded | func | the mixed numbers is *a list* |  |
| empty list | definition | encoded | func | the empty list is *a list* |  |
| single item | definition | encoded | func | the single item is *a list* |  |
| multiple items | definition | encoded | func | the multiple items is *a list* |  |
| spent conviction | record | encoded | an individual with one fact per field | spent_conviction |  |
| unspent conviction | record | encoded | an individual with one fact per field | unspent_conviction |  |
| eligible person | record | encoded | an individual with one fact per field | eligible_person |  |
| bankrupt person | record | encoded | an individual with one fact per field | bankrupt_person |  |
| person with unspent conviction | record | encoded | an individual with one fact per field | person_with_unspent_conviction |  |
| young person | record | encoded | an individual with one fact per field | young_person |  |
| #EVAL at line 157 | test | encoded | a query and the evaluator's answer | line_157 |  |
| #EVAL at line 158 | test | encoded | a query and the evaluator's answer | line_158 |  |
| #EVAL at line 159 | test | encoded | a query and the evaluator's answer | line_159 |  |
| #EVAL at line 160 | test | encoded | a query and the evaluator's answer | line_160 |  |
| #EVAL at line 161 | test | encoded | a query and the evaluator's answer | line_161 |  |
| #EVAL at line 162 | test | encoded | a query and the evaluator's answer | line_162 |  |
| #EVAL at line 165 | test | encoded | a query and the evaluator's answer | line_165 |  |
| #EVAL at line 166 | test | encoded | a query and the evaluator's answer | line_166 |  |
| #EVAL at line 167 | test | encoded | a query and the evaluator's answer | line_167 |  |
| #eval at line 170 | test | residue | a value that is not a constant: `positive numbers` |  |  |
| #eval at line 171 | test | residue | a value that is not a constant: `mixed numbers` |  |  |
| #eval at line 172 | test | residue | a value that is not a constant: `mixed numbers` |  |  |
| #eval at line 173 | test | residue | a value that is not a constant: `positive numbers` |  |  |
| #eval at line 176 | test | residue | a value that is not a constant: `empty list` |  |  |
| #eval at line 177 | test | residue | a value that is not a constant: `single item` |  |  |
| #eval at line 178 | test | residue | a value that is not a constant: `multiple items` |  |  |
| #EVAL at line 181 | test | encoded | a query and the evaluator's answer | line_181 |  |
| #EVAL at line 182 | test | encoded | a query and the evaluator's answer | line_182 |  |
| #EVAL at line 183 | test | encoded | a query and the evaluator's answer | line_183 |  |
| #EVAL at line 184 | test | encoded | a query and the evaluator's answer | line_184 |  |

## Residue

- **#eval at line 170** (test) — a value that is not a constant: `positive numbers`; in the program: . 
- **#eval at line 171** (test) — a value that is not a constant: `mixed numbers`; in the program: . 
- **#eval at line 172** (test) — a value that is not a constant: `mixed numbers`; in the program: . 
- **#eval at line 173** (test) — a value that is not a constant: `positive numbers`; in the program: . 
- **#eval at line 176** (test) — a value that is not a constant: `empty list`; in the program: . 
- **#eval at line 177** (test) — a value that is not a constant: `single item`; in the program: . 
- **#eval at line 178** (test) — a value that is not a constant: `multiple items`; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_157 | line_157 | pass |  |
| line_158 | line_158 | pass |  |
| line_159 | line_159 | pass |  |
| line_160 | line_160 | pass |  |
| line_161 | line_161 | pass |  |
| line_162 | line_162 | pass |  |
| line_165 | line_165 | pass |  |
| line_166 | line_166 | pass |  |
| line_167 | line_167 | pass |  |
| line_181 | line_181 | pass |  |
| line_182 | line_182 | pass |  |
| line_183 | line_183 | pass |  |
| line_184 | line_184 | pass |  |


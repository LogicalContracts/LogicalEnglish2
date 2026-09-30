# Migration ledger: not_example

Source: an L4 program (smucclaw/l4-ide) — not-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 27 |
| approximated | 6 |
| residue | 0 |
| **total** | 33 |

Fidelity: **18 of 18** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| hasAccess | wording | approximated | the template's words made from the name, its inputs appended | *a boolean* has access for *a second boolean* | to be reviewed: the name does not say where its inputs go |
| notAThenB | wording | approximated | the template's words made from the name, its inputs appended | not athen b for *a boolean* with *a second boolean* | to be reviewed: the name does not say where its inputs go |
| notBoth | wording | approximated | the template's words made from the name, its inputs appended | not both for *a value* with *a second value* | to be reviewed: the name does not say where its inputs go |
| isNotZero | wording | approximated | the template's words made from the name, its inputs appended | *a number* is not zero | to be reviewed: the name does not say where its inputs go |
| isNotPositive | wording | approximated | the template's words made from the name, its inputs appended | *a value* is not positive | to be reviewed: the name does not say where its inputs go |
| invertedMessage | wording | approximated | the template's words made from the name, its inputs appended | the inverted message for *a flag* is *a text* | to be reviewed: the name does not say where its inputs go |
| hasCriminalRecord | assume | encoded | a template the scenarios state (; undefined) | hasCriminalRecord |  |
| isClean | definition | encoded | pred | is clean |  |
| personAge | assume | encoded | a template the scenarios state (; undefined) | personAge |  |
| isBlocked | assume | encoded | a template the scenarios state (; undefined) | isBlocked |  |
| canAccess | definition | encoded | pred | can access |  |
| hasAccess | definition | encoded | pred | *a boolean* has access for *a second boolean* |  |
| notAThenB | definition | encoded | pred | not athen b for *a boolean* with *a second boolean* |  |
| notBoth | definition | encoded | pred | not both for *a value* with *a second value* |  |
| isNotZero | definition | encoded | pred | *a number* is not zero |  |
| isNotPositive | definition | encoded | pred | *a value* is not positive |  |
| invertedMessage | definition | encoded | func | the inverted message for *a flag* is *a text* |  |
| #EVAL at line 5 | test | encoded | a query and the evaluator's answer | line_5 |  |
| #EVAL at line 6 | test | encoded | a query and the evaluator's answer | line_6 |  |
| #EVAL at line 10 | test | encoded | a query and the evaluator's answer | line_10 |  |
| #EVAL at line 11 | test | encoded | a query and the evaluator's answer | line_11 |  |
| #EVAL at line 35 | test | encoded | a query and the evaluator's answer | line_35 |  |
| #EVAL at line 36 | test | encoded | a query and the evaluator's answer | line_36 |  |
| #EVAL at line 48 | test | encoded | a query and the evaluator's answer | line_48 |  |
| #EVAL at line 49 | test | encoded | a query and the evaluator's answer | line_49 |  |
| #EVAL at line 50 | test | encoded | a query and the evaluator's answer | line_50 |  |
| #EVAL at line 51 | test | encoded | a query and the evaluator's answer | line_51 |  |
| #EVAL at line 59 | test | encoded | a query and the evaluator's answer | line_59 |  |
| #EVAL at line 60 | test | encoded | a query and the evaluator's answer | line_60 |  |
| #EVAL at line 61 | test | encoded | a query and the evaluator's answer | line_61 |  |
| #EVAL at line 62 | test | encoded | a query and the evaluator's answer | line_62 |  |
| #EVAL at line 72 | test | encoded | a query and the evaluator's answer | line_72 |  |
| #EVAL at line 73 | test | encoded | a query and the evaluator's answer | line_73 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_5 | line_5 | pass |  |
| line_6 | line_6 | pass |  |
| line_10 | line_10 | pass |  |
| line_11 | line_11 | pass |  |
| line_35 | line_35 | pass |  |
| line_36 | line_36 | pass |  |
| line_48 | line_48 | pass |  |
| line_49 | line_49 | pass |  |
| line_50 | line_50 | pass |  |
| line_51 | line_51 | pass |  |
| line_59 | line_59 | pass |  |
| line_60 | line_60 | pass |  |
| line_61 | line_61 | pass |  |
| line_62 | line_62 | pass |  |
| line_72 | line_72 | pass |  |
| line_73 | line_73 | pass |  |
| variant_1 | is_clean | pass |  |
| variant_2 | is_clean | pass |  |


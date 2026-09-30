# Migration ledger: implies_example

Source: an L4 program (smucclaw/l4-ide) — implies-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 31 |
| approximated | 5 |
| residue | 0 |
| **total** | 36 |

Fidelity: **24 of 24** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| impliesVersion | wording | approximated | the template's words made from the name, its inputs appended | implies version for *a boolean* with *a second boolean* | to be reviewed: the name does not say where its inputs go |
| orVersion | wording | approximated | the template's words made from the name, its inputs appended | else version for *a value* with *a second value* | to be reviewed: the name does not say where its inputs go |
| chainedImpl | wording | approximated | the template's words made from the name, its inputs appended | chained impl for *a boolean* with *a second boolean* with *a third boolean* | to be reviewed: the name does not say where its inputs go |
| conjunctionImplies | wording | approximated | the template's words made from the name, its inputs appended | conjunction implies for *a boolean* with *a second boolean* with *a third boolean* | to be reviewed: the name does not say where its inputs go |
| impliesDisjunction | wording | approximated | the template's words made from the name, its inputs appended | implies disjunction for *a value* with *a second value* with *a third value* | to be reviewed: the name does not say where its inputs go |
| impliesVersion | definition | encoded | pred | implies version for *a boolean* with *a second boolean* |  |
| orVersion | definition | encoded | pred | else version for *a value* with *a second value* |  |
| isEmployee | assume | encoded | a template the scenarios state (; undefined) | isEmployee |  |
| hasBadge | assume | encoded | a template the scenarios state (; undefined) | hasBadge |  |
| badgeRule | definition | encoded | pred | badge rule |  |
| personAge | assume | encoded | a template the scenarios state (; undefined) | personAge |  |
| hasParentalConsent | assume | encoded | a template the scenarios state (; undefined) | hasParentalConsent |  |
| consentRule | definition | encoded | pred | consent rule |  |
| chainedImpl | definition | encoded | pred | chained impl for *a boolean* with *a second boolean* with *a third boolean* |  |
| conjunctionImplies | definition | encoded | pred | conjunction implies for *a boolean* with *a second boolean* with *a third boolean* |  |
| impliesDisjunction | definition | encoded | pred | implies disjunction for *a value* with *a second value* with *a third value* |  |
| #EVAL at line 5 | test | encoded | a query and the evaluator's answer | line_5 |  |
| #EVAL at line 6 | test | encoded | a query and the evaluator's answer | line_6 |  |
| #EVAL at line 7 | test | encoded | a query and the evaluator's answer | line_7 |  |
| #EVAL at line 8 | test | encoded | a query and the evaluator's answer | line_8 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 13 | test | encoded | a query and the evaluator's answer | line_13 |  |
| #EVAL at line 14 | test | encoded | a query and the evaluator's answer | line_14 |  |
| #EVAL at line 26 | test | encoded | a query and the evaluator's answer | line_26 |  |
| #EVAL at line 27 | test | encoded | a query and the evaluator's answer | line_27 |  |
| #EVAL at line 29 | test | encoded | a query and the evaluator's answer | line_29 |  |
| #EVAL at line 30 | test | encoded | a query and the evaluator's answer | line_30 |  |
| #EVAL at line 32 | test | encoded | a query and the evaluator's answer | line_32 |  |
| #EVAL at line 33 | test | encoded | a query and the evaluator's answer | line_33 |  |
| #EVAL at line 61 | test | encoded | a query and the evaluator's answer | line_61 |  |
| #EVAL at line 62 | test | encoded | a query and the evaluator's answer | line_62 |  |
| #EVAL at line 63 | test | encoded | a query and the evaluator's answer | line_63 |  |
| #EVAL at line 77 | test | encoded | a query and the evaluator's answer | line_77 |  |
| #EVAL at line 78 | test | encoded | a query and the evaluator's answer | line_78 |  |
| #EVAL at line 79 | test | encoded | a query and the evaluator's answer | line_79 |  |
| #EVAL at line 80 | test | encoded | a query and the evaluator's answer | line_80 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_5 | line_5 | pass |  |
| line_6 | line_6 | pass |  |
| line_7 | line_7 | pass |  |
| line_8 | line_8 | pass |  |
| line_12 | line_12 | pass |  |
| line_13 | line_13 | pass |  |
| line_14 | line_14 | pass |  |
| line_26 | line_26 | pass |  |
| line_27 | line_27 | pass |  |
| line_29 | line_29 | pass |  |
| line_30 | line_30 | pass |  |
| line_32 | line_32 | pass |  |
| line_33 | line_33 | pass |  |
| line_61 | line_61 | pass |  |
| line_62 | line_62 | pass |  |
| line_63 | line_63 | pass |  |
| line_77 | line_77 | pass |  |
| line_78 | line_78 | pass |  |
| line_79 | line_79 | pass |  |
| line_80 | line_80 | pass |  |
| variant_1 | badge_rule | pass |  |
| variant_2 | badge_rule | pass |  |
| variant_3 | badge_rule | pass |  |
| variant_4 | badge_rule | pass |  |


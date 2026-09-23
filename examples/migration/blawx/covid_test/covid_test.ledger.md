# Migration ledger: covid_test

Source: Covid Test Rule — sources/covid_test.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-23
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 0 |
| residue | 0 |
| **total** | 18 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| test_result/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a test result* is a test result | As in the source: facts are stated and no rule, constraint or test of the source reads them (the verifier reports them unconsumed). |
| may_board/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is permitted to board *a flight* |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| flight/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a flight* is a flight |  |
| test/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a test* is a test |  |
| ticketed_for/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* has a ticket for *a flight* |  |
| subject/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* took a covid test *a test* |  |
| scheduled_departure/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a flight* is scheduled to depart at *a time* |  |
| result/2 | category, attribute or relationship | encoded | its #pred wording -> a template | the result of *a test* was *a test result* |  |
| administered_at/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a test* was administered at *a time* |  |
| test_result(positive) | fact | encoded | a fact of the section, citing it | test_result(positive) |  |
| test_result(negative) | fact | encoded | a fact of the section, citing it | test_result(negative) |  |
| according_to(sec_1_section, may_board, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| 100 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 190 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest can_fly | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | can_fly |  |
| blawxtest good_test | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | good_test |  |
| blawxtest old_test | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | old_test |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| can_fly | can_fly | pass |  |
| good_test | good_test | pass |  |
| old_test | old_test | pass |  |


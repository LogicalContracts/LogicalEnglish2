# Migration ledger: siblings

Source: Siblings Act — sources/siblings.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 1 |
| residue | 0 |
| **total** | 14 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (abductive: the test lets s(CASP) assume ward/1 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| sibling/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a sibling of *a second person* |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| parent/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a parent of *a second person* |  |
| ward/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a ward of the state |  |
| according_to(sec_1_section, sibling, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| person(opg) | fact | encoded | a fact of the section, citing it | person(opg) |  |
| according_to(sec_2_section, parent, ...) :- ... | rule | encoded | a rule of the section, citing it | section_2 |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 36 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest broken_test | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | broken_test |  |
| blawxtest broken_code | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | broken_code |  |
| blawxtest broken_rule | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | broken_rule | abductive: the test lets s(CASP) assume ward/1 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all |
| blawxtest automation | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | automation |  |
| 7 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| broken_test | broken_test | pass |  |
| broken_code | broken_code | pass |  |
| automation | automation | pass |  |
| case_1 | which_is_a_sibling_of | pass |  |
| case_1_without_fact_1 | which_is_a_sibling_of | pass |  |
| case_1_without_fact_2 | which_is_a_sibling_of | pass |  |
| case_1_without_fact_3 | which_is_a_sibling_of | pass |  |
| case_1_without_fact_4 | which_is_a_sibling_of | pass |  |
| case_1_without_fact_5 | which_is_a_sibling_of | pass |  |
| case_2 | which_is_a_parent_of | pass |  |


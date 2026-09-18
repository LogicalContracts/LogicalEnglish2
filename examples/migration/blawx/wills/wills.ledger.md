# Migration ledger: wills

Source: Wills Act — sources/wills.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 0 |
| **total** | 10 |

Fidelity: **10 of 10** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| eligible/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* may make a will |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| age/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is *a number* years of age |  |
| military/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is an active military member |  |
| according_to(sec_1_section, eligible, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| according_to(sec_2_section, eligible, ...) :- ... | rule | encoded | a rule of the section, citing it | section_2 |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 36 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest valid_will | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | valid_will |  |
| 9 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| valid_will | valid_will | pass |  |
| case_1 | which_may_make_a_will | pass |  |
| case_1_without_fact_1 | which_may_make_a_will | pass |  |
| case_1_without_fact_2 | which_may_make_a_will | pass |  |
| case_1_missing_comparison_1 | which_may_make_a_will | pass |  |
| case_2 | which_may_make_a_will | pass |  |
| case_2_without_fact_1 | which_may_make_a_will | pass |  |
| case_2_without_fact_2 | which_may_make_a_will | pass |  |
| case_2_without_fact_3 | which_may_make_a_will | pass |  |
| case_2_missing_comparison_1 | which_may_make_a_will | pass |  |


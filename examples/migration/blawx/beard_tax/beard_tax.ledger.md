# Migration ledger: beard_tax

Source: Beard Tax Act — sources/beard_tax.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: InsurLE2/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 17 |
| approximated | 0 |
| residue | 0 |
| **total** | 17 |

Fidelity: **13 of 13** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| bearded/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is bearded |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| facial_hair_length_mm/2 | category, attribute or relationship | encoded | its #pred wording -> a template | the facial hair of *a person* is *a number* mm in length |  |
| qualifies_s1a/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* qualifies under section 1 a |  |
| qualifies_s1b/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* qualifies under section 1 b |  |
| facial_hair_on_chin/1 | category, attribute or relationship | encoded | its #pred wording -> a template | the facial hair of *a person* is on the chin |  |
| facial_hair_below_chin/1 | category, attribute or relationship | encoded | its #pred wording -> a template | the facial hair of *a person* is below the chin |  |
| facial_hair_continuous/1 | category, attribute or relationship | encoded | its #pred wording -> a template | the facial hair of *a person* is ear to ear below the nose |  |
| according_to(sec_1_section, bearded, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| according_to(sec_1_section, bearded, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1_2 |  |
| according_to(sec_1__para_a_section, qualifies_s1a, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1_a |  |
| according_to(sec_1__para_a_section, qualifies_s1a, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1_a_2 |  |
| according_to(sec_1__para_b_section, qualifies_s1b, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1_b |  |
| 80 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 152 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest are_they_bearded | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | are_they_bearded |  |
| 12 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| are_they_bearded | are_they_bearded | pass |  |
| case_1 | which_is_bearded | pass |  |
| case_1_without_fact_1 | which_is_bearded | pass |  |
| case_1_without_fact_2 | which_is_bearded | pass |  |
| case_1_without_fact_3 | which_is_bearded | pass |  |
| case_1_missing_comparison_1 | which_is_bearded | pass |  |
| case_2 | which_is_bearded | pass |  |
| case_2_without_fact_1 | which_is_bearded | pass |  |
| case_2_without_fact_2 | which_is_bearded | pass |  |
| case_2_missing_comparison_1 | which_is_bearded | pass |  |
| case_3 | which_qualifies_under_section_1_a | pass |  |
| case_4 | which_qualifies_under_section_1_a | pass |  |
| case_5 | which_qualifies_under_section_1_b | pass |  |


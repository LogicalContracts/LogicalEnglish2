# Migration ledger: bird

Source: New Bird Act — sources/bird.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: InsurLE2/migration/blawx (blawx_twin.pl)
Date: 2026-09-16
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 25 |
| approximated | 0 |
| residue | 0 |
| **total** | 25 |

Fidelity: **17 of 17** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| bird/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a thing* is a bird |  |
| penguin/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a penguin* is a penguin |  |
| flies/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a thing* can fly |  |
| on_plane/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a penguin* is on a plane |  |
| blawx_applies/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a provision* applies to *a thing* |  |
| cartoon_jetpack/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a penguin* is a cartoon with a jetpack |  |
| holds(sec_3_section, neg(flies), ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a thing* cannot fly under *a provision* |  |
| holds(sec_4_section, flies, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a thing* can fly under *a provision* |  |
| holds(sec_5_section, flies, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a thing* can fly under *a provision* |  |
| holds(sec_5__span_pingu_section, neg(blawx_applies), ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a provision* does not apply to *a thing* under *a provision* |  |
| according_to(sec_1_section, bird, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| according_to(sec_2_section, flies, ...) :- ... | rule | encoded | a defeasible rule: guarded by the failure of its defeaters under their sections | section_2 |  |
| according_to(sec_3_section, -flies, ...) :- ... | rule | encoded | a defeasible rule: guarded by the failure of its defeaters under their sections | section_3 |  |
| according_to(sec_4_section, flies, ...) :- ... | rule | encoded | a rule of the section, citing it | section_4 |  |
| blawx_applies(sec_5_section,_6140) :- ... | rule | encoded | a rule of the section, citing it | section_5 |  |
| according_to(sec_5_section, flies, ...) :- ... | rule | encoded | a rule of the section, citing it | section_5_2 |  |
| penguin(pingu) | fact | encoded | a fact of the section, citing it | penguin(pingu) |  |
| holds(sec_5__span_pingu_section,-blawx_applies,sec_5_section,pingu) | fact | encoded | a conclusion stated by a section -> a fact under that section | holds(sec_5__span_pingu_section,-blawx_applies,sec_5_section,pingu) |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 54 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest is_pingu_a_bird | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | is_pingu_a_bird |  |
| blawxtest pingu_cant_fly | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | pingu_cant_fly | Blawx proves `not <the query>`: the twin's query expects no answer |
| blawxtest pingu_on_plane_can_fly | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | pingu_on_plane_can_fly |  |
| blawxtest pingu_with_jetpack_cant_fly | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | pingu_with_jetpack_cant_fly | Blawx cannot prove `not <the query>`: the twin's query expects its answer |
| 13 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| is_pingu_a_bird | is_pingu_a_bird | pass |  |
| pingu_cant_fly | pingu_cant_fly | pass |  |
| pingu_on_plane_can_fly | pingu_on_plane_can_fly | pass |  |
| pingu_with_jetpack_cant_fly | pingu_with_jetpack_cant_fly | pass |  |
| case_1 | which_is_a_bird | pass |  |
| case_2 | which_can_fly | pass |  |
| case_2_with_sec_3_section | which_can_fly | pass |  |
| case_3 | which_cannot_fly | pass |  |
| case_3_with_sec_4_section | which_cannot_fly | pass |  |
| case_3_with_sec_5_section | which_cannot_fly | pass |  |
| case_4 | which_can_fly | pass |  |
| case_4_without_fact_1 | which_can_fly | pass |  |
| case_4_without_fact_2 | which_can_fly | pass |  |
| case_5 | which_can_fly | pass |  |
| case_5_without_fact_1 | which_can_fly | pass |  |
| case_5_without_fact_2 | which_can_fly | pass |  |
| case_5_without_fact_3 | which_can_fly | pass |  |


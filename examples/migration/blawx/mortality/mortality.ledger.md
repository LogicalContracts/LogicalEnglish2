# Migration ledger: mortality

Source: Mortality Act — sources/mortality.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 0 |
| residue | 0 |
| **total** | 7 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| mortal/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a thing* is a mortal |  |
| human/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a thing* is a human |  |
| according_to(sec_1_section, mortal, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 18 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest Socrates | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | socrates |  |
| 1 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| socrates | socrates | pass |  |
| case_1 | which_is_a_mortal | pass |  |


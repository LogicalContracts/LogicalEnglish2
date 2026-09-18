# Migration ledger: list_demo

Source: Lists Demonstration — sources/list_demo.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 1 |
| **total** | 7 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

**1 further expectation(s) are pending** (waits for residue section_1_residue): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| average_score/2 | category, attribute or relationship | encoded | its #pred wording -> a template | the average score adding a 10 of *a person* is *a number* |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| score/2 | category, attribute or relationship | encoded | its #pred wording -> a template | the score of *a person* is *a number* |  |
| according_to(sec_1_section,average_score,_63382,_63384):-person(_63382),findall(_63404,score(_63382,_63404),_63408),coun... | rule | residue | not translated: kept verbatim as a residue block | section_1_residue | a list aggregate (findall): the rule collects values with findall and Blawx's list predicates |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 27 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest test | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | test |  |

## Residue

- **according_to(sec_1_section,average_score,_63382,_63384):-person(_63382),findall(_63404,score(_63382,_63404),_63408),coun...** (rule) — not translated: kept verbatim as a residue block; in the program: section_1_residue. a list aggregate (findall): the rule collects values with findall and Blawx's list predicates

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|


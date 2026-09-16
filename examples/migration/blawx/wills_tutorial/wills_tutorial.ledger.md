# Migration ledger: wills_tutorial

Source: Wills Act — sources/wills_tutorial.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: InsurLE2/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 0 |
| **total** | 3 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 0 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest example | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | example | the test asks nothing |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|


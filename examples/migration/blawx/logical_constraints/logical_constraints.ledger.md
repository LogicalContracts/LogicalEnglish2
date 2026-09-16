# Migration ledger: logical_constraints

Source: Logical Constraints — sources/logical_constraints.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: InsurLE2/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 0 |
| residue | 0 |
| **total** | 9 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| age/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is *a number* years of age |  |
| person(bob) | fact | encoded | a fact of the section, citing it | person(bob) |  |
| age(bob,40) | fact | encoded | a fact of the section, citing it | age(bob,40) |  |
| age(bob,50) | fact | encoded | a fact of the section, citing it | age(bob,50) |  |
| false :- ... (section 3) | constraint | encoded | a denial -> an integrity constraint, it must not be true that … | it must not be true that … | as in s(CASP), a model that meets the conditions is rejected: a case whose facts meet them answers nothing |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 18 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest how_old_bob | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | how_old_bob |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| how_old_bob | how_old_bob | pass |  |


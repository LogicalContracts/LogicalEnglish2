# Migration ledger: rps

Source: Rock Paper Scissors Act — sources/rps.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-23
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 19 |
| approximated | 1 |
| residue | 0 |
| **total** | 20 |

Fidelity: **11 of 11** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (abductive: the test lets s(CASP) assume game/1, player/2, throw/3 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| sign/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a sign* is a sign | As in the source: facts are stated and no rule, constraint or test of the source reads them (the verifier reports them unconsumed). |
| beats/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a sign* beats *a second sign* |  |
| winner/2 | category, attribute or relationship | encoded | its #pred wording -> a template | the winner of *a game* is *a player* |  |
| game/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a game* is a game |  |
| player/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a player* is a player |  |
| player/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a player* played in *a game* |  |
| throw/3 | category, attribute or relationship | encoded | its #pred wording -> a template | *a player* threw *a sign* in *a game* |  |
| sign(rock) | fact | encoded | a fact of the section, citing it | sign(rock) |  |
| sign(paper) | fact | encoded | a fact of the section, citing it | sign(paper) |  |
| sign(scissors) | fact | encoded | a fact of the section, citing it | sign(scissors) |  |
| beats(rock,scissors) | fact | encoded | a fact of the section, citing it | beats(rock,scissors) |  |
| beats(paper,rock) | fact | encoded | a fact of the section, citing it | beats(paper,rock) |  |
| beats(scissors,paper) | fact | encoded | a fact of the section, citing it | beats(scissors,paper) |  |
| according_to(sec_4_section, winner, ...) :- ... | rule | encoded | a rule of the section, citing it | section_4 |  |
| 18 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them1 (1 of them do not parse: typos of Blawx's generator) |
| 83 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest bobjane | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | bobjane |  |
| blawxtest hypothetical | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | hypothetical | abductive: the test lets s(CASP) assume game/1, player/2, throw/3 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all |
| blawxtest who_wins | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | who_wins |  |
| 9 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| bobjane | bobjane | pass |  |
| who_wins | who_wins | pass |  |
| case_1 | which_the_winner_of_is | pass |  |
| case_1_without_fact_1 | which_the_winner_of_is | pass |  |
| case_1_without_fact_2 | which_the_winner_of_is | pass |  |
| case_1_without_fact_3 | which_the_winner_of_is | pass |  |
| case_1_without_fact_4 | which_the_winner_of_is | pass |  |
| case_1_without_fact_5 | which_the_winner_of_is | pass |  |
| case_1_without_fact_6 | which_the_winner_of_is | pass |  |
| case_1_without_fact_7 | which_the_winner_of_is | pass |  |
| case_1_without_fact_8 | which_the_winner_of_is | pass |  |


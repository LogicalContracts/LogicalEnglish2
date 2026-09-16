# Migration ledger: numerical_constraints

Source: Sucker Act — sources/numerical_constraints.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: InsurLE2/migration/blawx (blawx_twin.pl)
Date: 2026-09-15
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 1 |
| residue | 0 |
| **total** | 12 |

Fidelity: **11 of 11** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (abductive: the test lets s(CASP) assume person/1, age/2 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| may_vote/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* may vote at *a number* years of age |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| age/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is *a number* years of age |  |
| must_pay_taxes/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* must pay taxes at *a number* years of age |  |
| is_sucker/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a sucker |  |
| according_to(sec_1_section, may_vote, ...) :- ... | rule | encoded | a rule of the section, citing it | section_1 |  |
| according_to(sec_2_section, must_pay_taxes, ...) :- ... | rule | encoded | a rule of the section, citing it | section_2 |  |
| according_to(sec_3_section, is_sucker, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3 |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 45 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest sucker | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | sucker | abductive: the test lets s(CASP) assume person/1, age/2 (#abducible); Blawx's answers are hypotheses, which an LE scenario states as facts or not at all |
| 11 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| case_1 | which_may_vote_at_years_of_age | pass |  |
| case_1_without_fact_1 | which_may_vote_at_years_of_age | pass |  |
| case_1_without_fact_2 | which_may_vote_at_years_of_age | pass |  |
| case_1_missing_comparison_1 | which_may_vote_at_years_of_age | pass |  |
| case_2 | which_must_pay_taxes_at_years_of_age | pass |  |
| case_2_without_fact_1 | which_must_pay_taxes_at_years_of_age | pass |  |
| case_2_without_fact_2 | which_must_pay_taxes_at_years_of_age | pass |  |
| case_2_missing_comparison_1 | which_must_pay_taxes_at_years_of_age | pass |  |
| case_3 | which_is_a_sucker | pass |  |
| case_3_without_fact_1 | which_is_a_sucker | pass |  |
| case_3_without_fact_2 | which_is_a_sucker | pass |  |


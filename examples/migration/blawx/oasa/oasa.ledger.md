# Migration ledger: oasa

Source: Old Age Security Act — sources/oasa.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-23
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 58 |
| approximated | 11 |
| residue | 5 |
| **total** | 74 |

Fidelity: **20 of 20** source test expectation(s) reproduced (100%).

**1 further expectation(s) are pending** (the answer is symbolic (a variable or a constraint), which LE's answers are not): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| qualifies_s3_1_a/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* qualifies under s3_1_a |  |
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person |  |
| pensioner_july/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* was a pensioner on July 1 1977 |  |
| meets_residence_requirement_s3_1_b_i/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* meets the residence requirements of section 3_1_b_i | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| birthdate/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* was born on *a time* | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| resided_in_canada_july/1 | category, attribute or relationship | encoded | its #pred wording -> a template | as of July 1977 *a person* resided in Canada | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| possessed_valid_immigration_visa_july/1 | category, attribute or relationship | encoded | its #pred wording -> a template | as of July 1977 *a person* possessed a valid immigration visa | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| resided_in_canada_after_18_as_of_july/1 | category, attribute or relationship | encoded | its #pred wording -> a template | as of July 1977 *a person* had resided in Canada after 18 years of age | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| meets_age_requirement_s3_1_b_ii/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* meets the age requirement of section 3_1_b_ii | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| blawx_today/1 | category, attribute or relationship | encoded | its #pred wording -> a template | the date today is *a time* | Read in the source only by clauses this twin keeps as residue blocks (see the residue entries), so no rule here reads its facts: the verifier reports them unconsumed. |
| qualifies_s3_1_b/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* qualifies under s3_1_b |  |
| meets_residence_duration_requirement_s3_1_b_iii/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* meets the residence duration requirement of section 3_1_b_iii |  |
| qualifies_s3_1_c/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* qualifies under s3_1_c |  |
| meets_s3_1_c_i/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* satisfies the non pensioner requirement of s3_1_c_i |  |
| meets_s3_1_c_ii/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* satisfies the age requirement of s3_1_c_ii | Used in the source only by clauses this twin keeps as residue blocks (see the residue entries): the verifier reports the template unused. |
| meets_s3_1_c_iii/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* satisfies the residency requirement of s3_1_c_iii |  |
| may_be_paid_full_monthly_pension/1 | category, attribute or relationship | encoded | its #pred wording -> a template | a full monthly pension may be paid to *a person* |  |
| resided_in_canada_10_years_prior_to_approval/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* resided in canada for 10 years prior to approval |  |
| meets_aggregate_residence_requirement_s3_1_b_iii/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* was in Canada more than away between 18 and 10 years prior to approval |  |
| has_resided_one_year_prior_to_approval/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* resided in Canada for the year prior to approval |  |
| resided_40_years_after_18_yoa/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* resided in Canada at least 40 years since the age of 18 |  |
| satisfies_4_1_a/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* satisfies section 4_1_a |  |
| satisfies_4_1_b/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* satisfies section 4_1_b |  |
| citizen_or_resident_before_approval/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* was a citizen or legal resident the day before approval |  |
| holds(sec_3__subsec_1__para_b__subpara_i_section, meets_residence_requirement_s3_1_b_i, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* meets the residence requirements of section 3_1_b_i under *a provision* | Defined in the source only by clauses this twin keeps as residue blocks (see the residue entries), so nothing defines it here: the verifier reports it undefined. |
| holds(sec_3__subsec_1__para_b__subpara_ii_section, meets_age_requirement_s3_1_b_ii, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* meets the age requirement of section 3_1_b_ii under *a provision* | Defined in the source only by clauses this twin keeps as residue blocks (see the residue entries), so nothing defines it here: the verifier reports it undefined. |
| holds(sec_3__subsec_1__para_b__subpara_iii_section, meets_residence_duration_requirement_s3_1_b_iii, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* meets the residence duration requirement of section 3_1_b_iii under *a provision* |  |
| holds(sec_3__subsec_1__para_c__subpara_i_section, meets_s3_1_c_i, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* satisfies the non pensioner requirement of s3_1_c_i under *a provision* |  |
| holds(sec_3__subsec_1__para_c__subpara_ii_section, meets_s3_1_c_ii, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* satisfies the age requirement of s3_1_c_ii under *a provision* | Defined in the source only by clauses this twin keeps as residue blocks (see the residue entries), so nothing defines it here: the verifier reports it undefined. |
| holds(sec_3__subsec_1__para_c__subpara_iii_section, meets_s3_1_c_iii, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* satisfies the residency requirement of s3_1_c_iii under *a provision* |  |
| holds(sec_3__subsec_1__para_a_section, qualifies_s3_1_a, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* qualifies under s3_1_a under *a provision* |  |
| holds(sec_3__subsec_1__para_b_section, qualifies_s3_1_b, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* qualifies under s3_1_b under *a provision* |  |
| holds(sec_3__subsec_1__para_c_section, qualifies_s3_1_c, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* qualifies under s3_1_c under *a provision* |  |
| holds(sec_4__subsec_1_section, neg(may_be_paid_full_monthly_pension), ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | a full monthly pension may not be paid to *a person* under *a provision* |  |
| holds(sec_4__subsec_1__para_a_section, satisfies_4_1_a, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* satisfies section 4_1_a under *a provision* |  |
| holds(sec_4__subsec_1__para_b_section, satisfies_4_1_b, ...) | section conclusion | encoded | the conclusion of a section, read by a defeat, a fact or a test -> `... under <provision>` | *a person* satisfies section 4_1_b under *a provision* |  |
| blawx_now / blawx_today (2026-09-14) | clock | approximated | the machine clock -> a fact of the day the twin was built (the oracle uses the same) | the date today | Blawx answers with the day it runs; the twin and the oracle with a fixed one |
| according_to(sec_3__subsec_1__para_a_section, qualifies_s3_1_a, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_a |  |
| according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_29188):-not(pensioner_july... | rule | residue | not translated: kept verbatim as a residue block | section_3_1_b_i_residue | calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx |
| according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_28966):-not(pensioner_july... | rule | residue | not translated: kept verbatim as a residue block | section_3_1_b_i_residue_2 | calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx |
| according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_28744):-not(pensioner_july... | rule | residue | not translated: kept verbatim as a residue block | section_3_1_b_i_residue_3 | calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx |
| according_to(sec_3__subsec_1__para_b__subpara_ii_section,meets_age_requirement_s3_1_b_ii,_28428):-blawx_today(_28438),bi... | rule | residue | not translated: kept verbatim as a residue block | section_3_1_b_ii_residue | calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx |
| according_to(sec_3__subsec_1__para_b_section, qualifies_s3_1_b, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_b |  |
| according_to(sec_3__subsec_1__para_c_section, qualifies_s3_1_c, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_c |  |
| according_to(sec_3__subsec_1_section, may_be_paid_full_monthly_pension, ...) :- ... | rule | encoded | a defeasible rule: guarded by the failure of its defeaters under their sections | section_3_1 |  |
| according_to(sec_3__subsec_1_section, may_be_paid_full_monthly_pension, ...) :- ... | rule | encoded | a defeasible rule: guarded by the failure of its defeaters under their sections | section_3_1_2 |  |
| according_to(sec_3__subsec_1_section, may_be_paid_full_monthly_pension, ...) :- ... | rule | encoded | a defeasible rule: guarded by the failure of its defeaters under their sections | section_3_1_3 |  |
| according_to(sec_3__subsec_1__para_b__subpara_iii_section, meets_residence_duration_requirement_s3_1_b_iii, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_b_iii |  |
| according_to(sec_3__subsec_1__para_b__subpara_iii_section, meets_residence_duration_requirement_s3_1_b_iii, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_b_iii_2 |  |
| according_to(sec_3__subsec_1__para_c__subpara_ii_section,meets_s3_1_c_ii,_26952):-blawx_today(_26962),birthdate(_26952,_... | rule | residue | not translated: kept verbatim as a residue block | section_3_1_c_ii_residue | calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx |
| according_to(sec_3__subsec_1__para_c__subpara_i_section, meets_s3_1_c_i, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_c_i |  |
| according_to(sec_3__subsec_1__para_c__subpara_iii_section, meets_s3_1_c_iii, ...) :- ... | rule | encoded | a rule of the section, citing it | section_3_1_c_iii |  |
| according_to(sec_4__subsec_1_section, -may_be_paid_full_monthly_pension, ...) :- ... | rule | encoded | a rule of the section, citing it | section_4_1 |  |
| according_to(sec_4__subsec_1__para_a_section, satisfies_4_1_a, ...) :- ... | rule | encoded | a rule of the section, citing it | section_4_1_a |  |
| according_to(sec_4__subsec_1__para_b_section, satisfies_4_1_b, ...) :- ... | rule | encoded | a rule of the section, citing it | section_4_1_b |  |
| 0 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 216 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest generic_3_1 | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1 |  |
| blawxtest generic_3_1_a | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_a |  |
| blawxtest generic_3_1_b | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_b | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_c | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_c | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_b_i | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_b_i | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_b_ii | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_b_ii | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_c_i | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_c_i | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_c_ii | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_c_ii | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_b_iii | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_b_iii | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_3_1_c_iii | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_3_1_c_iii | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_4_1 | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_4_1 |  |
| blawxtest generic_4_1_a | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_4_1_a | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_4_1_b | test | approximated | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_4_1_b | Blawx's own run of this test ends in an error (the query calls a predicate its reasoner does not define); no expectation |
| blawxtest generic_eligible | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | generic_eligible |  |
| blawxtest true_or_false | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | true_or_false |  |
| blawxtest search | test | encoded | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | search |  |
| 15 cases generated from the rules | generated cases | encoded | each rule met by facts, each near miss, each defeat: Blawx's answers as the expectations | the case_ scenarios | not Blawx's tests: written by blawx_cases.pl from the encoding; the answers are Blawx's own |

## Residue

- **according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_29188):-not(pensioner_july...** (rule) — not translated: kept verbatim as a residue block; in the program: section_3_1_b_i_residue. calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx
- **according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_28966):-not(pensioner_july...** (rule) — not translated: kept verbatim as a residue block; in the program: section_3_1_b_i_residue_2. calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx
- **according_to(sec_3__subsec_1__para_b__subpara_i_section,meets_residence_requirement_s3_1_b_i,_28744):-not(pensioner_july...** (rule) — not translated: kept verbatim as a residue block; in the program: section_3_1_b_i_residue_3. calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx
- **according_to(sec_3__subsec_1__para_b__subpara_ii_section,meets_age_requirement_s3_1_b_ii,_28428):-blawx_today(_28438),bi...** (rule) — not translated: kept verbatim as a residue block; in the program: section_3_1_b_ii_residue. calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx
- **according_to(sec_3__subsec_1__para_c__subpara_ii_section,meets_s3_1_c_ii,_26952):-blawx_today(_26962),birthdate(_26952,_...** (rule) — not translated: kept verbatim as a residue block; in the program: section_3_1_c_ii_residue. calls datetime_add, which Blawx v1.6.22's reasoner does not define: the rule never applies in Blawx

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| generic_3_1 | generic_3_1 | pass |  |
| generic_3_1_a | generic_3_1_a | pass |  |
| generic_4_1 | generic_4_1 | pass |  |
| generic_eligible | generic_eligible | pass |  |
| true_or_false | true_or_false | pass |  |
| search | search | pass |  |
| case_1 | which_qualifies_under_s3_1_a | pass |  |
| case_1_without_fact_1 | which_qualifies_under_s3_1_a | pass |  |
| case_1_without_fact_2 | which_qualifies_under_s3_1_a | pass |  |
| case_8 | which_a_full_monthly_pension_may_be_paid_to | pass |  |
| case_8_without_fact_1 | which_a_full_monthly_pension_may_be_paid_to | pass |  |
| case_8_without_fact_2 | which_a_full_monthly_pension_may_be_paid_to | pass |  |
| case_11 | which_meets_the_residence_duration_requirement_of_section_3_1_b_iii | pass |  |
| case_12 | which_meets_the_residence_duration_requirement_of_section_3_1_b_iii | pass |  |
| case_12_without_fact_1 | which_meets_the_residence_duration_requirement_of_section_3_1_b_iii | pass |  |
| case_12_without_fact_2 | which_meets_the_residence_duration_requirement_of_section_3_1_b_iii | pass |  |
| case_15 | which_satisfies_the_residency_requirement_of_s3_1_c_iii | pass |  |
| case_16 | which_a_full_monthly_pension_may_not_be_paid_to | pass |  |
| case_17 | which_satisfies_section_4_1_a | pass |  |
| case_18 | which_satisfies_section_4_1_b | pass |  |


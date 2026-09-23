# Migration ledger: citizenshiptrust

Source: an s(CASP) program — citizenshiptrust-scasp.pl
Translator: lpsPlus/migration/scasp (scasp_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 0 |
| residue | 0 |
| **total** | 20 |

Fidelity: **4 of 4** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| acquires_British_citizenship_on/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* acquires British citizenship on *a date* |  |
| is_a_parent_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is a parent of *a second person* |  |
| is_citizen_or_settled/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is citizen or settled *a date* |  |
| is_the_father_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is the father of *a person* |  |
| is_born_in_on/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is born in *a place* on *a date* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_after_commencement/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a date* isafter commencement | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_the_mother_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is the mother of *a person* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_a_British_citizen_on/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is a British citizen on *a date* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_settled_in_the_UK_on/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is settled in the UK on *a date* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| says_that/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* says that *a sentence* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_qualified_to_determine_fatherhood/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is qualified to determine fatherhood | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| a clause of acquires_British_citizenship_on/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_a_parent_of/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_citizen_or_settled/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_the_father_of/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario alice | scenario | encoded | an LE1 scenario -> a scenario | alice |  |
| Scenario harry | scenario | encoded | an LE1 scenario -> a scenario | harry |  |
| Scenario trust_harry | scenario | encoded | an LE1 scenario -> a scenario | trust_harry |  |
| Scenario alice_harry | scenario | encoded | an LE1 scenario -> a scenario | alice_harry |  |
| ?- acquires_British_citizenship_on(_112870,_112872) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| alice | query_1 | pass |  |
| harry | query_1 | pass |  |
| trust_harry | query_1 | pass |  |
| alice_harry | query_1 | pass |  |


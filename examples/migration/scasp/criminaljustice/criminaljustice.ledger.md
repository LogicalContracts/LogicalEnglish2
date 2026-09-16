# Migration ledger: criminaljustice

Source: an s(CASP) program — criminaljustice-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 26 |
| approximated | 0 |
| residue | 0 |
| **total** | 26 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| has_with_in_under_of/6 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has *a right* with *a thing* in *a proceeding* under *an article* of *a law* |  |
| exception_to_applies_to_under_of/4 | predicate | encoded | a template (the #pred wording, else a naive one) | exception to *an article* applies to *a person* under *an article* of *a law* |  |
| is_in/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is *a status* in *a proceeding* |  |
| is_involved_in/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is involved in *a proceeding* |  |
| is_ongoing/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a proceeding* is ongoing |  |
| knows/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* knows *a language* |  |
| has_been_made_aware_that/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has been made aware that *a fact* |  |
| understands/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* understands *a language* |  |
| is_represented_by/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is represented by *a lawyer* |  |
| speaks/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* speaks *a language* |  |
| has/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a proceeding* has *a status* |  |
| member/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the member of *a second thing* |  |
| is_in_danger_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* isin danger of *a thing* |  |
| is_in_the_language/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a proceeding* isin the language *a language* |  |
| has_in_under/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has *a right* in *a proceeding* under *an article* |  |
| is_an_exception_to/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *an exception* is an exception to *an article* |  |
| has_in/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has *a right* in *a proceeding* |  |
| a clause of has_with_in_under_of/6 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of exception_to_applies_to_under_of/4 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_in/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_involved_in/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_ongoing/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of knows/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| Scenario two | scenario | encoded | an LE1 scenario -> a scenario | two |  |
| ?- exception_to_applies_to_under_of(_1588,_1590,_1592,_1594) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |
| two | query_1 | pass |  |


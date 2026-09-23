# Migration ledger: itispermittedthat

Source: an s(CASP) program — itispermittedthat-scasp.pl
Translator: lpsPlus/migration/scasp (scasp_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 0 |
| residue | 0 |
| **total** | 13 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| It_is_permitted_that/1 | predicate | encoded | a template (the #pred wording, else a naive one) | It is permitted that *an eventuality* |  |
| the_Schedule_specifies_that/1 | predicate | encoded | a template (the #pred wording, else a naive one) | the Schedule specifies that *a specification* |  |
| of_Default_occurs_with_respect_to_at/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *an event* of Default occurs with respect to *a party* at *a time* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_continuing_at/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *an event* is continuing at *a time* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| gives_notice_to_at_that/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a party* gives notice to *a party* at *a time* that *a message* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| is_on_or_before/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a date* isonorbefore *a date* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| and_are_at_most_days_apart/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a date* and are at most days apart *a time* with *a thing* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| Automatic_Early_Termination_applies_to_for_of_Default/2 | predicate | encoded | a template (the #pred wording, else a naive one) | Automatic Early Termination applies to *a party* for *an event* of Default | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| designates_at_that/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a party* designates at *a time* that *an eventuality* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| occurs_at/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *an event* occurs at *a time* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| a clause of It_is_permitted_that/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| ?- 'It_is_permitted_that'(designates_at_that(_92704,_92706,occurs_at(_92712,_92714))) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |


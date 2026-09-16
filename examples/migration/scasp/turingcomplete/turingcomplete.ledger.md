# Migration ledger: turingcomplete

Source: an s(CASP) program — turingcomplete-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 14 |
| approximated | 0 |
| residue | 0 |
| **total** | 14 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| some_tm_goes_from_to/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* some tm goes from to *a second thing* |  |
| it_changes_from_to_and_from_to/5 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* it changes from to and from to *a second thing* with *a third thing* with *a fourth thing* with *a fifth thing* |  |
| the_head_of_is_leaving/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* the head of is leaving *a second thing* with *a third thing* |  |
| moves_to_and_to/5 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* moves to and to *a second thing* with *a third thing* with *a fourth thing* with *a fifth thing* |  |
| is_left_after_and_is_left_after/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is left after and is left after *a second thing* with *a third thing* with *a fourth thing* |  |
| says_that_and_lead_to_and_after_performing/6 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* says that and lead to and after performing *a second thing* with *a third thing* with *a fourth thing* with *a fifth thing* with *a sixth thing* |  |
| has_as_head_before/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* has as head before *a second thing* with *a third thing* |  |
| a clause of some_tm_goes_from_to/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of it_changes_from_to_and_from_to/5 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of the_head_of_is_leaving/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of moves_to_and_to/5 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_left_after_and_is_left_after/4 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario machine_one | scenario | encoded | an LE1 scenario -> a scenario | machine_one |  |
| ?- some_tm_goes_from_to([1,1,1,b],_63736) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| machine_one | query_1 | pass |  |


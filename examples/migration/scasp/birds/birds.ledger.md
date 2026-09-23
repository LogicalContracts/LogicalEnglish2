# Migration ledger: birds

Source: an s(CASP) program — birds.pl
Translator: lpsPlus/migration/scasp (scasp_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 16 |
| approximated | 0 |
| residue | 0 |
| **total** | 16 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| penguin/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a penguin |  |
| wounded_bird/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a wounded bird |  |
| bird/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a bird |  |
| ab/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is an ab |  |
| flies/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* can fly |  |
| penguin/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the penguin of *a second thing* | Source defect: the source reads it and defines it nowhere (and does not declare it dynamic), so nothing makes it true; s(CASP) answers nothing through it, and neither does the twin (the verifier reports it undefined). |
| s/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a s | Source defect: the source reads it and defines it nowhere (and does not declare it dynamic), so nothing makes it true; s(CASP) answers nothing through it, and neither does the twin (the verifier reports it undefined). |
| a clause of bird/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of ab/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of flies/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of can_not_fly/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_not_a_wounded_bird/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_not_a_bird/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_not_a_penguin/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_not_an_ab/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| ?- flies(_74980) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| the_program | query_1 | pass |  |


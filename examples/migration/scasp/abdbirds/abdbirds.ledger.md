# Migration ledger: abdbirds

Source: an s(CASP) program — abdbirds.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 8 |
| approximated | 0 |
| residue | 0 |
| **total** | 8 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| bird/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a bird |  |
| ab/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is an ab |  |
| flies/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* flies |  |
| penguin/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a penguin |  |
| wounded_bird/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a wounded bird |  |
| a clause of ab/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of flies/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| ?- not(flies(tweety)) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| the_program | query_1 | pass |  |


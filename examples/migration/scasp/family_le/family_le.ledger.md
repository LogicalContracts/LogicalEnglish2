# Migration ledger: family_le

Source: an s(CASP) program — family-le-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is_a_grandparent_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is a grandparent of *a person* |  |
| is_a_parent_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* is a parent of *a person* |  |
| a clause of is_a_grandparent_of/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| ?- is_a_grandparent_of(_636,_638) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |


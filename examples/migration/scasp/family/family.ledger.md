# Migration ledger: family

Source: an s(CASP) program — family.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 27 |
| approximated | 0 |
| residue | 0 |
| **total** | 27 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| test1/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is test one |  |
| test2/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the test two of *a second thing* |  |
| test3/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is test three |  |
| male/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a male |  |
| female/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a female |  |
| father/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the father of *a second thing* |  |
| mother/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the mother of *a second thing* |  |
| parent/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the parent of *a second thing* |  |
| grandparent/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the grandparent of *a second thing* |  |
| ancestor/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the ancestor of *a second thing* |  |
| sibling/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the sibling of *a second thing* |  |
| sister/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the sister of *a second thing* |  |
| brother/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the brother of *a second thing* |  |
| cousin/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is the cousin of *a second thing* |  |
| hardmath/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a hardmath |  |
| a clause of test1/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of test2/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of test3/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of parent/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of grandparent/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of ancestor/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of sibling/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of sister/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of brother/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of cousin/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of hardmath/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| ?- ancestor(bob,sam) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| the_program | query_1 | pass |  |


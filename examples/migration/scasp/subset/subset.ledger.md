# Migration ledger: subset

Source: an s(CASP) program — subset-scasp.pl
Translator: lpsPlus/migration/scasp (scasp_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 8 |
| approximated | 0 |
| residue | 0 |
| **total** | 8 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is_a_subset_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a set* is a subset of *a set* |  |
| is_a_set/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a set | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| belongs_to/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* belongs to *a set* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| a clause of is_a_subset_of/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| Scenario two | scenario | encoded | an LE1 scenario -> a scenario | two |  |
| ?- is_a_subset_of(_84482,_84484) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |
| the program's own forall/2 (by double negation, through wrong/2 and once/1) is the universal built into s(CASP) and LE (for all cases in which ...): its definitions are left out | dates | encoded | LE1 dates and date arithmetic -> LE2 dates and built-ins | the program | the program's own forall/2 (by double negation, through wrong/2 and once/1) is the universal built into s(CASP) and LE (for all cases in which ...): its definitions are left out |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |
| two | query_1 | pass |  |


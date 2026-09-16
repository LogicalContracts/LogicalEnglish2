# Migration ledger: list

Source: an s(CASP) program — list-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 0 |
| residue | 1 |
| **total** | 12 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is_a_subset_of/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a set* is a subset of *a set* |  |
| the_concatenation_of_then_is/3 | predicate | encoded | a template (the #pred wording, else a naive one) | the concatenation of *a list* then *a list* is *a list* |  |
| followed_by_is/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* followed by is *a second thing* with *a third thing* |  |
| is_a_set/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* is a set |  |
| belongs_to/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* belongs to *a set* |  |
| has_as_head_before/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a thing* has as head before *a second thing* with *a third thing* |  |
| a clause of is_a_subset_of/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of followed_by_is/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| ?- is_a_subset_of(_92738,_92740) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |
| the program's own forall/2 (by double negation, through wrong/2 and once/1) is the universal built into s(CASP) and LE (for all cases in which ...): its definitions are left out | dates | encoded | LE1 dates and date arithmetic -> LE2 dates and built-ins | the program | the program's own forall/2 (by double negation, through wrong/2 and once/1) is the universal built into s(CASP) and LE (for all cases in which ...): its definitions are left out |
| the_concatenation_of_then_is(['A' 'B'], 'C', ['A' 'D']) :-     the_concatenation_of_then_is('B', 'C', 'D').  | clause | residue | a clause taking a list apart (no list patterns in LE) | list_pattern_1 | Logical English has no list patterns (a list's first element and the rest, [H T]); a recursive definition over a list is written with an included Prolog resource, or restated with aggregates |

## Residue

- **the_concatenation_of_then_is(['A' 'B'], 'C', ['A' 'D']) :-     the_concatenation_of_then_is('B', 'C', 'D'). ** (clause) — a clause taking a list apart (no list patterns in LE); in the program: list_pattern_1. Logical English has no list patterns (a list's first element and the rest, [H T]); a recursive definition over a list is written with an included Prolog resource, or restated with aggregates

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |


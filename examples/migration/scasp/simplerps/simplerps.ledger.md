# Migration ledger: simplerps

Source: an s(CASP) program — simpleRPS-scasp.pl
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
| beats/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a choice* beats *a choice* |  |
| gets/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* gets *an amount* |  |
| the_game_is_a_draw/0 | predicate | encoded | a template (the #pred wording, else a naive one) | the game is a draw |  |
| inputs_and/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* inputs *a choice* and *an amount* |  |
| a clause of gets/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of the_game_is_a_draw/0 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario mbj | scenario | encoded | an LE1 scenario -> a scenario | mbj |  |
| ?- gets(_180994,_180996) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| mbj | query_1 | pass |  |


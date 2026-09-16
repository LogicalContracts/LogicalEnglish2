# Migration ledger: minicontract

Source: an s(CASP) program — minicontract-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 11 |
| approximated | 0 |
| residue | 0 |
| **total** | 11 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is_a_valid_contract/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a contract* is a valid contract |  |
| The_terms_of_the_contract_are_met/0 | predicate | encoded | a template (the #pred wording, else a naive one) | The terms of the contract are met |  |
| the_service_is_delivered_before/1 | predicate | encoded | a template (the #pred wording, else a naive one) | the service is delivered before *a date* |  |
| the_service_recipient_maintains_all_communication_within_the_confines_of/1 | predicate | encoded | a template (the #pred wording, else a naive one) | the service recipient maintains all communication within the confines of *a domain* |  |
| the_service_recipient_delivers_requested_information_before/1 | predicate | encoded | a template (the #pred wording, else a naive one) | the service recipient delivers requested information before *a date* |  |
| is_signed_by_the_service_provider/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a contract* is signed by the service provider |  |
| is_also_signed_by_the_service_recipient/1 | predicate | encoded | a template (the #pred wording, else a naive one) | *a contract* is also signed by the service recipient |  |
| a clause of is_a_valid_contract/1 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of The_terms_of_the_contract_are_met/0 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario one | scenario | encoded | an LE1 scenario -> a scenario | one |  |
| ?- is_a_valid_contract(_159218) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| one | query_1 | pass |  |


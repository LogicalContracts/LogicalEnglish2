# Migration ledger: obligation

Source: an s(CASP) program — obligation-scasp.pl
Translator: InsurLE2/migration/scasp (scasp_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 19 |
| approximated | 0 |
| residue | 0 |
| **total** | 19 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

**1 further expectation(s) are pending** (s(CASP) answers with a constraint, not a value): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| has_that/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has *an obligation* that *a requirement* |  |
| defaults_on/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* defaults on *a date* |  |
| cures_the_failure_of_on_or_before_that/5 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* cures the failure of on or before that *an obligation* with *a day* with *a date* with *a requirement* |  |
| fails_to_fulfil_that/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* fails to fulfil *an obligation* that *a requirement* |  |
| cures_the_failure_of_on_that/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* cures the failure of *an obligation* on *a day* that *a requirement* |  |
| is_on_or_before/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a day* is on or before *a thing* |  |
| is_days_after/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a date* is days after *a thing* with *a second date* |  |
| notifies_on_that/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a lender* notifies *a borrower* on *a date* that *a message* |  |
| pays_to_on/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* pays *an amount* to *a lender* on *a date* |  |
| performs_at/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a party* performs *an action* at *a time* |  |
| occurs_at/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *an event* occurs at *a time* |  |
| a clause of defaults_on/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of cures_the_failure_of_on_or_before_that/5 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of fails_to_fulfil_that/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of cures_the_failure_of_on_that/4 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_on_or_before/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of is_days_after/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario test | scenario | encoded | an LE1 scenario -> a scenario | test |  |
| ?- cures_the_failure_of_on_that(the_borrower,_66852,_66854,pays_to_on(the_borrower,_66862,the_lender,_66866)) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|


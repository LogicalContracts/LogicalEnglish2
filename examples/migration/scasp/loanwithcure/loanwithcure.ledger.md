# Migration ledger: loanwithcure

Source: an s(CASP) program — loanwithcure-scasp.pl
Translator: lpsPlus/migration/scasp (scasp_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 16 |
| approximated | 0 |
| residue | 0 |
| **total** | 16 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

**1 further expectation(s) are pending** (adjudicated: s(CASP) (sCASP pack, scasp_forall prev or not) answers that the borrower defaults on 2016-06-06, yet cures_the_failure_of_on_or_before(the_borrower, obligation2, 2016-06-06) succeeds on its own (payment on 2016-06-05, notice on 2016-06-06), so by the program's rules the default's not-cured condition fails: constructive negation over the anonymous variable in is_that/2. The twin follows the rules (no default)): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| is_on_or_before/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a date* is on or before *a second date* |  |
| has/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a person* has *an obligation* |  |
| is_that/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *an obligation* is that *a description* |  |
| defaults_on/2 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* defaults on *a date* |  |
| cures_the_failure_of_on_or_before/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* cures the failure of *an obligation* onorbefore *a date* |  |
| fails_on_to_fulfil/3 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* fails on *a date* to fulfil *an obligation* |  |
| notifies_on_that/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a lender* notifies *a borrower* on *a date* that *a message* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| pays_to_on/4 | predicate | encoded | a template (the #pred wording, else a naive one) | *a borrower* pays *an amount* to *a lender* on *a date* | Declared dynamic by the source and given no clause there: data a scenario supplies, so the twin marks its template a scenario element (; undefined). |
| the_loan_is_accelerated_on/1 | predicate | encoded | a template (the #pred wording, else a naive one) | the loan is accelerated on *a date* | As in the source: declared and never used (the verifier reports the template unused). |
| a clause of is_on_or_before/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of defaults_on/2 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of cures_the_failure_of_on_or_before/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| a clause of fails_on_to_fulfil/3 | rule | encoded | a clause -> an LE rule | the rules |  |
| Scenario payment | scenario | encoded | an LE1 scenario -> a scenario | payment |  |
| ?- defaults_on(_93766,_93768) | query | encoded | a ?- query -> a query, asked in every scenario | the queries |  |
| is_days_after/3, which LE1's programs call but do not define, is LE2's built-in *a date* is *a number* days after *a date* | dates | encoded | LE1 dates and date arithmetic -> LE2 dates and built-ins | the program | is_days_after/3, which LE1's programs call but do not define, is LE2's built-in *a date* is *a number* days after *a date* |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|


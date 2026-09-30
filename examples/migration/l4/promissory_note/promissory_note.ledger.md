# Migration ledger: promissory_note

Source: an L4 program (smucclaw/l4-ide) — promissory-note.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 31 |
| approximated | 7 |
| residue | 8 |
| **total** | 46 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Money | record | encoded | a type of individuals, one template per field | Money |  |
| Company | record | encoded | a type of individuals, one template per field | Company |  |
| Natural Person | record | encoded | a type of individuals, one template per field | Natural Person |  |
| Borrower | choice | encoded | named individuals | Borrower |  |
| Lender | choice | encoded | named individuals | Lender |  |
| Bank Account | record | encoded | a type of individuals, one template per field | Bank Account |  |
| Payment | record | encoded | a type of individuals, one template per field | Payment |  |
| Penalty | record | encoded | a type of individuals, one template per field | Penalty |  |
| pay monthly installment to | record | encoded | a type of individuals, one template per field | pay monthly installment to |  |
| The lesser of | wording | approximated | the template's words made from the name, its inputs appended | the lesser of *a number* with *a second number* is *a value* | to be reviewed: the name does not say where its inputs go |
| The greater of | wording | approximated | the template's words made from the name, its inputs appended | the greater of *a number* with *a second number* is *a value* | to be reviewed: the name does not say where its inputs go |
| Base to the power of | wording | approximated | the template's words made from the name, its inputs appended | the base to the power of *a base* with *an exp* is *a number* | to be reviewed: the name does not say where its inputs go |
| is money at least equal within error | wording | approximated | the template's words made from the name, its inputs appended | *a money* is money at least equal within error for *a second money* | to be reviewed: the name does not say where its inputs go |
| USD | wording | approximated | the template's words made from the name, its inputs appended | the USD for *a number* is *a value* | to be reviewed: the name does not say where its inputs go |
| EUR | wording | approximated | the template's words made from the name, its inputs appended | the EUR for *a number* is *a value* | to be reviewed: the name does not say where its inputs go |
| SGD | wording | approximated | the template's words made from the name, its inputs appended | the SGD for *a number* is *a value* | to be reviewed: the name does not say where its inputs go |
| Note Date | definition | encoded | func | the note date is *a value* |  |
| Principal Amount | definition | encoded | func | the principal amount is *a value* |  |
| Interest Rate Per Annum | definition | encoded | func | the interest rate per annum is *a number* |  |
| Security Collateral | definition | encoded | func | the security collateral is *a value* |  |
| Monthly Installments | definition | encoded | func | the monthly installments is *a number* |  |
| Default After Days Not Paid Beyond Due | definition | encoded | func | the default after days not paid beyond due is *a number* |  |
| Late Payment Penalty | record | encoded | an individual with one fact per field | late_payment_penalty |  |
| Governing Law | definition | encoded | func | the governing law is *a text* |  |
| The Borrower | record | encoded | an individual with one fact per field | the_borrower |  |
| The Lender | record | encoded | an individual with one fact per field | the_lender |  |
| Monthly Interest Rate | definition | encoded | func | the monthly interest rate is *a number* |  |
| Compound Factor | definition | encoded | func | the compound factor is *a number* |  |
| Monthly Installment Amount | definition | residue | a value with no LE form | r1 |  |
| Total Repayment Amount | record | encoded | an individual with one fact per field | total_repayment_amount |  |
| Total Interest Amount | record | encoded | an individual with one fact per field | total_interest_amount |  |
| Payment Obligations | contract | residue | the contracts half (step 3) | Payment Obligations |  |
| NaN | assume | encoded | a template the scenarios state (; undefined) | NaN |  |
| NO_COLLATERAL | assume | encoded | a template the scenarios state (; undefined) | NO_COLLATERAL |  |
| The lesser of | definition | encoded | func | the lesser of *a number* with *a second number* is *a value* |  |
| The greater of | definition | encoded | func | the greater of *a number* with *a second number* is *a value* |  |
| Base to the power of | definition | encoded | func | the base to the power of *a base* with *an exp* is *a number* |  |
| is money at least equal within error | definition | encoded | pred | *a money* is money at least equal within error for *a second money* |  |
| USD | definition | residue | a value with no LE form | r2 |  |
| EUR | definition | residue | a value with no LE form | r3 |  |
| SGD | definition | residue | a value with no LE form | r4 |  |
| #eval at line 167 | test | residue | the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 2077.49370354708 |  |  |
| #eval at line 169 | test | residue | the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 27077.49370354708 |  |  |
| #EVAL at line 171 | test | encoded | a query and the evaluator's answer | line_171 |  |
| #eval at line 173 | test | residue | the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 2256.4578086289234 |  |  |
| Payment Obligations | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Payment Obligations |  |

## Residue

- **Monthly Installment Amount** (definition) — a value with no LE form; in the program: r1. 
- **Payment Obligations** (contract) — the contracts half (step 3); in the program: Payment Obligations. 
- **USD** (definition) — a value with no LE form; in the program: r2. 
- **EUR** (definition) — a value with no LE form; in the program: r3. 
- **SGD** (definition) — a value with no LE form; in the program: r4. 
- **#eval at line 167** (test) — the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 2077.49370354708; in the program: . 
- **#eval at line 169** (test) — the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 27077.49370354708; in the program: . 
- **#eval at line 173** (test) — the evaluator's answer is not a value LE writes: Money WITH Currency IS "USD", Value IS 2256.4578086289234; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_171 | line_171 | pass |  |


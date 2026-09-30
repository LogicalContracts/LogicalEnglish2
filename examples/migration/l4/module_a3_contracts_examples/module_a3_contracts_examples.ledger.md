# Migration ledger: module_a3_contracts_examples

Source: an L4 program (smucclaw/l4-ide) — module-a3-contracts-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 39 |
| approximated | 13 |
| residue | 11 |
| **total** | 63 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Money | record | encoded | a type of individuals, one template per field | Money |  |
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| Company | record | encoded | a type of individuals, one template per field | Company |  |
| Party | choice | encoded | named individuals | Party |  |
| Borrower | choice | encoded | named individuals | Borrower |  |
| Lender | choice | encoded | named individuals | Lender |  |
| Payment | record | encoded | a type of individuals, one template per field | Payment |  |
| PenaltyTerms | record | encoded | a type of individuals, one template per field | PenaltyTerms |  |
| LoanTerms | record | encoded | a type of individuals, one template per field | LoanTerms |  |
| LoanAction | choice | encoded | named individuals | LoanAction |  |
| EscrowParty | choice | encoded | named individuals | EscrowParty |  |
| EscrowAction | choice | encoded | named individuals | EscrowAction |  |
| ServiceParty | choice | encoded | named individuals | ServiceParty |  |
| ContractAction | choice | encoded | named individuals | ContractAction |  |
| CardParty | choice | encoded | named individuals | CardParty |  |
| CardAction | choice | encoded | named individuals | CardAction |  |
| Milestone | choice | encoded | named individuals | Milestone |  |
| MilestoneAction | choice | encoded | named individuals | MilestoneAction |  |
| USD | wording | approximated | the template's words made from the name, its inputs appended | the USD for *a number* is *a money* | to be reviewed: the name does not say where its inputs go |
| SGD | wording | approximated | the template's words made from the name, its inputs appended | the SGD for *a number* is *a money* | to be reviewed: the name does not say where its inputs go |
| monthly rate | wording | approximated | the template's words made from the name, its inputs appended | the monthly rate for *a terms* is *a number* | to be reviewed: the name does not say where its inputs go |
| power | wording | approximated | the template's words made from the name, its inputs appended | the power for *a base* with *an exp* is *a number* | to be reviewed: the name does not say where its inputs go |
| monthly payment amount | wording | approximated | the template's words made from the name, its inputs appended | the monthly payment amount for *a terms* is *a money* | to be reviewed: the name does not say where its inputs go |
| calculate next payment | wording | approximated | the template's words made from the name, its inputs appended | the calculate next payment for *a terms* with *an outstanding* is *a money* | to be reviewed: the name does not say where its inputs go |
| calculate due date | wording | approximated | the template's words made from the name, its inputs appended | the calculate due date for *a terms* with *an outstanding* is *a number* | to be reviewed: the name does not say where its inputs go |
| is valid payment | wording | approximated | the template's words made from the name, its inputs appended | *a paid* is valid payment for *an expected* | to be reviewed: the name does not say where its inputs go |
| USD | definition | residue | a value with no LE form | r1 |  |
| SGD | definition | residue | a value with no LE form | r2 |  |
| exampleLoan | record | encoded | an individual with one fact per field | example_loan |  |
| monthly rate | definition | encoded | func | the monthly rate for *a terms* is *a number* |  |
| power | definition | encoded | func | the power for *a base* with *an exp* is *a number* |  |
| p | wording | approximated | the template's words made from the name, its inputs appended | the p for *a terms* is *a value* | to be reviewed: the name does not say where its inputs go |
| r | wording | approximated | the template's words made from the name, its inputs appended | the r for *a terms* is *a number* | to be reviewed: the name does not say where its inputs go |
| n | wording | approximated | the template's words made from the name, its inputs appended | the n for *a terms* is *a value* | to be reviewed: the name does not say where its inputs go |
| compoundFactor | wording | approximated | the template's words made from the name, its inputs appended | the compound factor for *a terms* is *a number* | to be reviewed: the name does not say where its inputs go |
| payment | wording | approximated | the template's words made from the name, its inputs appended | the payment for *a terms* is *a number* | to be reviewed: the name does not say where its inputs go |
| p | definition | encoded | func | the p for *a terms* is *a value* |  |
| r | definition | encoded | func | the r for *a terms* is *a number* |  |
| n | definition | encoded | func | the n for *a terms* is *a value* |  |
| compoundFactor | definition | encoded | func | the compound factor for *a terms* is *a number* |  |
| payment | definition | encoded | func | the payment for *a terms* is *a number* |  |
| monthly payment amount | definition | residue | a value with no LE form | r3 |  |
| calculate next payment | definition | encoded | func | the calculate next payment for *a terms* with *an outstanding* is *a money* |  |
| calculate due date | definition | encoded | func | the calculate due date for *a terms* with *an outstanding* is *a number* |  |
| is valid payment | definition | encoded | pred | *a paid* is valid payment for *an expected* |  |
| aliceBorrower | record | encoded | an individual with one fact per field | alice_borrower |  |
| bobLender | record | encoded | an individual with one fact per field | bob_lender |  |
| payment obligation | contract | residue | the contracts half (step 3) | payment obligation |  |
| late payment handling | contract | residue | the contracts half (step 3) | late payment handling |  |
| default handling | contract | residue | the contracts half (step 3) | default handling |  |
| escrow arrangement | contract | residue | the contracts half (step 3) | escrow arrangement |  |
| service delivery | contract | residue | the contracts half (step 3) | service delivery |  |
| delivery options | contract | residue | the contracts half (step 3) | delivery options |  |
| credit payment | contract | residue | the contracts half (step 3) | credit payment |  |
| milestone payments | contract | residue | the contracts half (step 3) | milestone payments |  |
| credit payment | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | credit payment |  |
| default handling | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | default handling |  |
| delivery options | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | delivery options |  |
| escrow arrangement | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | escrow arrangement |  |
| late payment handling | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | late payment handling |  |
| milestone payments | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | milestone payments |  |
| payment obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | payment obligation |  |
| service delivery | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | service delivery |  |

## Residue

- **USD** (definition) — a value with no LE form; in the program: r1. 
- **SGD** (definition) — a value with no LE form; in the program: r2. 
- **monthly payment amount** (definition) — a value with no LE form; in the program: r3. 
- **payment obligation** (contract) — the contracts half (step 3); in the program: payment obligation. 
- **late payment handling** (contract) — the contracts half (step 3); in the program: late payment handling. 
- **default handling** (contract) — the contracts half (step 3); in the program: default handling. 
- **escrow arrangement** (contract) — the contracts half (step 3); in the program: escrow arrangement. 
- **service delivery** (contract) — the contracts half (step 3); in the program: service delivery. 
- **delivery options** (contract) — the contracts half (step 3); in the program: delivery options. 
- **credit payment** (contract) — the contracts half (step 3); in the program: credit payment. 
- **milestone payments** (contract) — the contracts half (step 3); in the program: milestone payments. 


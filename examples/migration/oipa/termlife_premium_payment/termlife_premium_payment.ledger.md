# Migration ledger: termlife_premium_payment

Source: an OIPA transaction (Rules Palette XML) — PremiumPayment/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 0 |
| residue | 0 |
| **total** | 12 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| PremiumPayment/Transaction.xml MathVariable AmountMV | mathvariable | encoded | FIELD -> the activity field Amount, a fact of the case | AmountMV |  |
| PremiumPayment/Transaction.xml MathVariable ModalPremiumMV | mathvariable | encoded | POLICYFIELD -> the policy field ModalPremium the activity finds, a fact of the case | ModalPremiumMV |  |
| PremiumPayment/Transaction.xml MathVariable PaidToDateMV | mathvariable | encoded | POLICYFIELD -> the policy field PaidToDate the activity finds, a fact of the case | PaidToDateMV |  |
| PremiumPayment/Transaction.xml MathVariable BillingModeMV | mathvariable | encoded | POLICYFIELD -> the policy field BillingMode the activity finds, a fact of the case | BillingModeMV |  |
| PremiumPayment/Transaction.xml MathVariable RatioMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | RatioMV |  |
| PremiumPayment/Transaction.xml MathVariable ModesPaidMV | mathvariable | encoded | FUNCTION -> LE's date and number built-ins | ModesPaidMV |  |
| PremiumPayment/Transaction.xml MathVariable MonthsPerModeMV | mathvariable | encoded | reassigned (MathIF) -> an otherwise cascade, the latest assignment first | MonthsPerModeMV |  |
| PremiumPayment/Transaction.xml MathVariable MonthsAdvancedMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | MonthsAdvancedMV |  |
| PremiumPayment/Transaction.xml MathVariable NewPaidToDateMV | mathvariable | encoded | FUNCTION -> LE's date and number built-ins | NewPaidToDateMV |  |
| PremiumPayment/Transaction.xml MathVariable UnappliedAmountMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | UnappliedAmountMV |  |
| PremiumPayment/ValidateExpressions.xml P001 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | P001 | A payment of $$$AmountMV$$$ is less than one modal premium ($$$ModalPremiumMV$$$). |
| PremiumPayment/CopyToPolicyFields.xml NewPaidToDateMV -> PaidToDate | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | PaidToDate |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| monthly_payer_p1 | new_paid_to_date | pass |  |
| monthly_payer_p1 | unapplied_amount | pass |  |
| monthly_payer_p1 | checks | pass |  |
| monthly_payer_p1 | policy_after_paid_to_date | pass |  |
| monthly_payer_p2 | new_paid_to_date | pass |  |
| monthly_payer_p2 | unapplied_amount | pass |  |
| monthly_payer_p2 | checks | pass |  |
| monthly_payer_p2 | policy_after_paid_to_date | pass |  |
| annual_smoker_p1 | new_paid_to_date | pass |  |
| annual_smoker_p1 | unapplied_amount | pass |  |
| annual_smoker_p1 | checks | pass |  |
| annual_smoker_p1 | policy_after_paid_to_date | pass |  |


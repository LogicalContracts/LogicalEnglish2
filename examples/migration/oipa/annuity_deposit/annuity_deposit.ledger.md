# Migration ledger: annuity_deposit

Source: an OIPA transaction (Rules Palette XML) — Deposit/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 0 |
| residue | 0 |
| **total** | 13 |

Fidelity: **12 of 12** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Deposit/Transaction.xml MathVariable GrossAmountMV | mathvariable | encoded | FIELD -> the activity field GrossAmount, a fact of the case | GrossAmountMV |  |
| Deposit/Transaction.xml MathVariable AccountValueMV | mathvariable | encoded | POLICYFIELD -> the policy field AccountValue the activity finds, a fact of the case | AccountValueMV |  |
| Deposit/Transaction.xml MathVariable PremiumTaxRateMV | mathvariable | encoded | PLANFIELD -> the plan field PremiumTaxRate, a fact of the program (PlanFields.csv) | PremiumTaxRateMV |  |
| Deposit/Transaction.xml MathVariable PremiumTaxMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | PremiumTaxMV |  |
| Deposit/Transaction.xml MathVariable HighBonusRateMV | mathvariable | encoded | VALUE -> the constant 0.02 | HighBonusRateMV |  |
| Deposit/Transaction.xml MathVariable StandardBonusRateMV | mathvariable | encoded | VALUE -> the constant 0.01 | StandardBonusRateMV |  |
| Deposit/Transaction.xml MathVariable BonusRateMV | mathvariable | encoded | IIF -> an otherwise cascade | BonusRateMV |  |
| Deposit/Transaction.xml MathVariable BonusMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | BonusMV |  |
| Deposit/Transaction.xml MathVariable NetDepositMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | NetDepositMV |  |
| Deposit/Transaction.xml MathVariable NewAccountValueMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | NewAccountValueMV |  |
| Deposit/ValidateExpressions.xml D001 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | D001 | The deposit must be a positive amount. |
| Deposit/ValidateExpressions.xml D002 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | D002 | Deposits above $1,000,000 need home office approval. |
| Deposit/CopyToPolicyFields.xml NewAccountValueMV -> AccountValue | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | AccountValue |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| steady_saver_d1 | net_deposit | pass |  |
| steady_saver_d1 | new_account_value | pass |  |
| steady_saver_d1 | checks | pass |  |
| steady_saver_d1 | policy_after_account_value | pass |  |
| steady_saver_d2 | net_deposit | pass |  |
| steady_saver_d2 | new_account_value | pass |  |
| steady_saver_d2 | checks | pass |  |
| steady_saver_d2 | policy_after_account_value | pass |  |
| steady_saver_d3 | net_deposit | pass |  |
| steady_saver_d3 | new_account_value | pass |  |
| steady_saver_d3 | checks | pass |  |
| steady_saver_d3 | policy_after_account_value | pass |  |


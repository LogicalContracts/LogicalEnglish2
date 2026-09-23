# Migration ledger: annuity_withdrawal

Source: an OIPA transaction (Rules Palette XML) — Withdrawal/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 0 |
| residue | 0 |
| **total** | 20 |

Fidelity: **30 of 30** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Withdrawal/Transaction.xml MathVariable GrossAmountMV | mathvariable | encoded | FIELD -> the activity field GrossAmount, a fact of the case | GrossAmountMV |  |
| Withdrawal/Transaction.xml MathVariable EffectiveDateMV | mathvariable | encoded | FIELD -> the activity field EffectiveDate, a fact of the case | EffectiveDateMV |  |
| Withdrawal/Transaction.xml MathVariable AccountValueMV | mathvariable | encoded | POLICYFIELD -> the policy field AccountValue the activity finds, a fact of the case | AccountValueMV |  |
| Withdrawal/Transaction.xml MathVariable IssueDateMV | mathvariable | encoded | POLICYFIELD -> the policy field IssueDate the activity finds, a fact of the case | IssueDateMV |  |
| Withdrawal/Transaction.xml MathVariable DurationMV | mathvariable | encoded | FUNCTION -> LE's date and number built-ins | DurationMV |  |
| Withdrawal/Transaction.xml MathVariable PolicyYearMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | PolicyYearMV |  |
| Withdrawal/Transaction.xml MathVariable FreePercentMV | mathvariable | encoded | PLANFIELD -> the plan field FreeWithdrawalPercent, a fact of the program (PlanFields.csv) | FreePercentMV |  |
| Withdrawal/Transaction.xml MathVariable FreeAmountMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | FreeAmountMV |  |
| Withdrawal/Transaction.xml MathVariable ExcessMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | ExcessMV |  |
| Withdrawal/Transaction.xml MathVariable ZeroMV | mathvariable | encoded | VALUE -> the constant 0 | ZeroMV |  |
| Withdrawal/Transaction.xml MathVariable ChargeableAmountMV | mathvariable | encoded | IIF -> an otherwise cascade | ChargeableAmountMV |  |
| Withdrawal/Transaction.xml MathVariable SurrenderChargeRateMV | mathvariable | encoded | RATE -> a decision table loaded from the plan's rates, DEFAULT as the last line | SurrenderChargeRateMV |  |
| Withdrawal/Transaction.xml MathVariable SurrenderChargeMV | mathvariable | encoded | reassigned (MathIF) -> an otherwise cascade, the latest assignment first | SurrenderChargeMV |  |
| Withdrawal/Transaction.xml MathVariable NetAmountMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | NetAmountMV |  |
| Withdrawal/Transaction.xml MathVariable RemainingValueMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | RemainingValueMV |  |
| Withdrawal/Transaction.xml MathVariable MinimumBalanceMV | mathvariable | encoded | PLANFIELD -> the plan field MinimumBalance, a fact of the program (PlanFields.csv) | MinimumBalanceMV |  |
| Withdrawal/ValidateExpressions.xml W001 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | W001 | The withdrawal must be a positive amount. |
| Withdrawal/ValidateExpressions.xml W002 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | W002 | A withdrawal of $$$GrossAmountMV$$$ exceeds the account value of $$$AccountValueMV$$$. |
| Withdrawal/SpawnActivities.xml Spawn FullSurrender | spawn | encoded | Spawn -> `the activity spawns the transaction` (only an activity that fails no check) | FullSurrender |  |
| Withdrawal/CopyToPolicyFields.xml RemainingValueMV -> AccountValue | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | AccountValue |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| steady_saver_w1 | net_amount | pass |  |
| steady_saver_w1 | remaining_value | pass |  |
| steady_saver_w1 | checks | pass |  |
| steady_saver_w1 | spawns | pass |  |
| steady_saver_w1 | policy_after_account_value | pass |  |
| steady_saver_w2 | net_amount | pass |  |
| steady_saver_w2 | remaining_value | pass |  |
| steady_saver_w2 | checks | pass |  |
| steady_saver_w2 | spawns | pass |  |
| steady_saver_w2 | policy_after_account_value | pass |  |
| steady_saver_w3 | net_amount | pass |  |
| steady_saver_w3 | remaining_value | pass |  |
| steady_saver_w3 | checks | pass |  |
| steady_saver_w3 | spawns | pass |  |
| steady_saver_w3 | policy_after_account_value | pass |  |
| late_withdrawal_w1 | net_amount | pass |  |
| late_withdrawal_w1 | remaining_value | pass |  |
| late_withdrawal_w1 | checks | pass |  |
| late_withdrawal_w1 | spawns | pass |  |
| late_withdrawal_w1 | policy_after_account_value | pass |  |
| late_withdrawal_w2 | net_amount | pass |  |
| late_withdrawal_w2 | remaining_value | pass |  |
| late_withdrawal_w2 | checks | pass |  |
| late_withdrawal_w2 | spawns | pass |  |
| late_withdrawal_w2 | policy_after_account_value | pass |  |
| drained_w1 | net_amount | pass |  |
| drained_w1 | remaining_value | pass |  |
| drained_w1 | checks | pass |  |
| drained_w1 | spawns | pass |  |
| drained_w1 | policy_after_account_value | pass |  |


# Migration ledger: annuity_full_surrender

Source: an OIPA transaction (Rules Palette XML) — FullSurrender/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 0 |
| residue | 0 |
| **total** | 12 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| FullSurrender/Transaction.xml MathVariable EffectiveDateMV | mathvariable | encoded | FIELD -> the activity field EffectiveDate, a fact of the case | EffectiveDateMV |  |
| FullSurrender/Transaction.xml MathVariable AccountValueMV | mathvariable | encoded | POLICYFIELD -> the policy field AccountValue the activity finds, a fact of the case | AccountValueMV |  |
| FullSurrender/Transaction.xml MathVariable IssueDateMV | mathvariable | encoded | POLICYFIELD -> the policy field IssueDate the activity finds, a fact of the case | IssueDateMV |  |
| FullSurrender/Transaction.xml MathVariable DurationMV | mathvariable | encoded | FUNCTION -> LE's date and number built-ins | DurationMV |  |
| FullSurrender/Transaction.xml MathVariable PolicyYearMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | PolicyYearMV |  |
| FullSurrender/Transaction.xml MathVariable SurrenderChargeRateMV | mathvariable | encoded | RATE -> a decision table loaded from the plan's rates, DEFAULT as the last line | SurrenderChargeRateMV |  |
| FullSurrender/Transaction.xml MathVariable SurrenderChargeMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | SurrenderChargeMV |  |
| FullSurrender/Transaction.xml MathVariable SurrenderValueMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | SurrenderValueMV |  |
| FullSurrender/Transaction.xml MathVariable ClosedValueMV | mathvariable | encoded | VALUE -> the constant 0 | ClosedValueMV |  |
| FullSurrender/Transaction.xml MathVariable SurrenderedStatusMV | mathvariable | encoded | VALUE -> the constant Surrendered | SurrenderedStatusMV |  |
| FullSurrender/CopyToPolicyFields.xml ClosedValueMV -> AccountValue | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | AccountValue |  |
| FullSurrender/CopyToPolicyFields.xml SurrenderedStatusMV -> PolicyStatus | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | PolicyStatus |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| drained_w1_fullsurrender | surrender_value | pass |  |
| drained_w1_fullsurrender | policy_after_account_value | pass |  |
| drained_w1_fullsurrender | policy_after_policy_status | pass |  |


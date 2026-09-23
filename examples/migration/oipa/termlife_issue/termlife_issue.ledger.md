# Migration ledger: termlife_issue

Source: an OIPA transaction (Rules Palette XML) — Issue/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 1 |
| residue | 0 |
| **total** | 21 |

Fidelity: **40 of 40** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Issue/Transaction.xml MathVariable FaceAmountMV | mathvariable | encoded | FIELD -> the activity field FaceAmount, a fact of the case | FaceAmountMV |  |
| Issue/Transaction.xml MathVariable BillingModeMV | mathvariable | encoded | FIELD -> the activity field BillingMode, a fact of the case | BillingModeMV |  |
| Issue/Transaction.xml MathVariable IssueDateMV | mathvariable | encoded | FIELD -> the activity field EffectiveDate, a fact of the case | IssueDateMV |  |
| Issue/Transaction.xml MathVariable DateOfBirthMV | mathvariable | encoded | POLICYFIELD -> the policy field InsuredDateOfBirth the activity finds, a fact of the case | DateOfBirthMV |  |
| Issue/Transaction.xml MathVariable GenderMV | mathvariable | encoded | POLICYFIELD -> the policy field InsuredGender the activity finds, a fact of the case | GenderMV |  |
| Issue/Transaction.xml MathVariable TobaccoMV | mathvariable | encoded | POLICYFIELD -> the policy field InsuredTobacco the activity finds, a fact of the case | TobaccoMV |  |
| Issue/Transaction.xml MathVariable IssueAgeMV | mathvariable | approximated | FUNCTION ANBAgeOf -> the age six calendar months later (lib/temporal) | IssueAgeMV |  |
| Issue/Transaction.xml MathVariable PremiumRateMV | mathvariable | encoded | RATE -> a decision table loaded from the plan's rates, DEFAULT as the last line | PremiumRateMV |  |
| Issue/Transaction.xml MathVariable PolicyFeeMV | mathvariable | encoded | PLANFIELD -> the plan field PolicyFee, a fact of the program (PlanFields.csv) | PolicyFeeMV |  |
| Issue/Transaction.xml MathVariable AnnualPremiumMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | AnnualPremiumMV |  |
| Issue/Transaction.xml MathVariable ModalFactorMV | mathvariable | encoded | reassigned (MathIF) -> an otherwise cascade, the latest assignment first | ModalFactorMV |  |
| Issue/Transaction.xml MathVariable ModalPremiumMV | mathvariable | encoded | EXPRESSION -> a rule, the MathVariables it reads as conditions | ModalPremiumMV |  |
| Issue/Transaction.xml MathVariable ActiveStatusMV | mathvariable | encoded | VALUE -> the constant Active | ActiveStatusMV |  |
| Issue/ValidateExpressions.xml I001 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | I001 | The insured's issue age of $$$IssueAgeMV$$$ is outside 18 to 65. |
| Issue/ValidateExpressions.xml I002 | validation | encoded | ValidateExpressions Expression -> `the activity fails the check` | I002 | The face amount must be at least $50,000. |
| Issue/CopyToPolicyFields.xml IssueDateMV -> IssueDate | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | IssueDate |  |
| Issue/CopyToPolicyFields.xml IssueDateMV -> PaidToDate | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | PaidToDate |  |
| Issue/CopyToPolicyFields.xml FaceAmountMV -> FaceAmount | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | FaceAmount |  |
| Issue/CopyToPolicyFields.xml BillingModeMV -> BillingMode | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | BillingMode |  |
| Issue/CopyToPolicyFields.xml ModalPremiumMV -> ModalPremium | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | ModalPremium |  |
| Issue/CopyToPolicyFields.xml ActiveStatusMV -> PolicyStatus | copy | encoded | CopyToPolicyFields -> the policy field after the activity (only an activity that fails no check) | PolicyStatus |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| monthly_payer_i1 | issue_age | pass |  |
| monthly_payer_i1 | annual_premium | pass |  |
| monthly_payer_i1 | modal_premium | pass |  |
| monthly_payer_i1 | checks | pass |  |
| monthly_payer_i1 | policy_after_issue_date | pass |  |
| monthly_payer_i1 | policy_after_paid_to_date | pass |  |
| monthly_payer_i1 | policy_after_face_amount | pass |  |
| monthly_payer_i1 | policy_after_billing_mode | pass |  |
| monthly_payer_i1 | policy_after_modal_premium | pass |  |
| monthly_payer_i1 | policy_after_policy_status | pass |  |
| annual_smoker_i1 | issue_age | pass |  |
| annual_smoker_i1 | annual_premium | pass |  |
| annual_smoker_i1 | modal_premium | pass |  |
| annual_smoker_i1 | checks | pass |  |
| annual_smoker_i1 | policy_after_issue_date | pass |  |
| annual_smoker_i1 | policy_after_paid_to_date | pass |  |
| annual_smoker_i1 | policy_after_face_amount | pass |  |
| annual_smoker_i1 | policy_after_billing_mode | pass |  |
| annual_smoker_i1 | policy_after_modal_premium | pass |  |
| annual_smoker_i1 | policy_after_policy_status | pass |  |
| too_old_i1 | issue_age | pass |  |
| too_old_i1 | annual_premium | pass |  |
| too_old_i1 | modal_premium | pass |  |
| too_old_i1 | checks | pass |  |
| too_old_i1 | policy_after_issue_date | pass |  |
| too_old_i1 | policy_after_paid_to_date | pass |  |
| too_old_i1 | policy_after_face_amount | pass |  |
| too_old_i1 | policy_after_billing_mode | pass |  |
| too_old_i1 | policy_after_modal_premium | pass |  |
| too_old_i1 | policy_after_policy_status | pass |  |
| quarterly_just_18_i1 | issue_age | pass |  |
| quarterly_just_18_i1 | annual_premium | pass |  |
| quarterly_just_18_i1 | modal_premium | pass |  |
| quarterly_just_18_i1 | checks | pass |  |
| quarterly_just_18_i1 | policy_after_issue_date | pass |  |
| quarterly_just_18_i1 | policy_after_paid_to_date | pass |  |
| quarterly_just_18_i1 | policy_after_face_amount | pass |  |
| quarterly_just_18_i1 | policy_after_billing_mode | pass |  |
| quarterly_just_18_i1 | policy_after_modal_premium | pass |  |
| quarterly_just_18_i1 | policy_after_policy_status | pass |  |


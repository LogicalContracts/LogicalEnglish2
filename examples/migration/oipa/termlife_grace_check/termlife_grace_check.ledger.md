# Migration ledger: termlife_grace_check

Source: an OIPA transaction (Rules Palette XML) — GraceCheck/Transaction.xml
Translator: lpsPlus/migration/oipa (oipa_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 0 |
| residue | 0 |
| **total** | 9 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| GraceCheck/Transaction.xml MathVariable EffectiveDateMV | mathvariable | encoded | FIELD -> the activity field EffectiveDate, a fact of the case | EffectiveDateMV |  |
| GraceCheck/Transaction.xml MathVariable PaidToDateMV | mathvariable | encoded | POLICYFIELD -> the policy field PaidToDate the activity finds, a fact of the case | PaidToDateMV |  |
| GraceCheck/Transaction.xml MathVariable PolicyStatusMV | mathvariable | encoded | POLICYFIELD -> the policy field PolicyStatus the activity finds, a fact of the case | PolicyStatusMV |  |
| GraceCheck/Transaction.xml MathVariable GracePeriodDaysMV | mathvariable | encoded | PLANFIELD -> the plan field GracePeriodDays, a fact of the program (PlanFields.csv) | GracePeriodDaysMV |  |
| GraceCheck/Transaction.xml MathVariable DaysPastDueMV | mathvariable | encoded | FUNCTION -> LE's date and number built-ins | DaysPastDueMV |  |
| GraceCheck/Transaction.xml MathVariable YesMV | mathvariable | encoded | VALUE -> the constant Yes | YesMV |  |
| GraceCheck/Transaction.xml MathVariable NoMV | mathvariable | encoded | VALUE -> the constant No | NoMV |  |
| GraceCheck/Transaction.xml MathVariable InGraceMV | mathvariable | encoded | IIF -> an otherwise cascade | InGraceMV |  |
| GraceCheck/SpawnActivities.xml Spawn Lapse | spawn | encoded | Spawn -> `the activity spawns the transaction` (only an activity that fails no check) | Lapse |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| monthly_payer_g1 | days_past_due | pass |  |
| monthly_payer_g1 | in_grace | pass |  |
| monthly_payer_g1 | spawns | pass |  |
| monthly_payer_g2 | days_past_due | pass |  |
| monthly_payer_g2 | in_grace | pass |  |
| monthly_payer_g2 | spawns | pass |  |


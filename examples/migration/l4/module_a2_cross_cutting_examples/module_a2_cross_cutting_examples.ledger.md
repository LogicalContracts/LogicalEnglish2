# Migration ledger: module_a2_cross_cutting_examples

Source: an L4 program (smucclaw/l4-ide) — module-a2-cross-cutting-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 35 |
| approximated | 2 |
| residue | 17 |
| **total** | 54 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Actor | choice | encoded | named individuals | Actor |  |
| LicenceParty | choice | encoded | named individuals | LicenceParty |  |
| Action | choice | encoded | named individuals | Action |  |
| LicenceAction | choice | encoded | named individuals | LicenceAction |  |
| Severity | choice | encoded | named individuals | Severity |  |
| Violation | record | encoded | a type of individuals, one template per field | Violation |  |
| CharityStatus | choice | encoded | named individuals | CharityStatus |  |
| RegisteredCharity | record | encoded | a type of individuals, one template per field | RegisteredCharity |  |
| Decision | record | encoded | a type of individuals, one template per field | Decision |  |
| CommissionerDecision | record | encoded | a type of individuals, one template per field | CommissionerDecision |  |
| CourtDecision | choice | encoded | named individuals | CourtDecision |  |
| RequiredStepsNotice | record | encoded | a type of individuals, one template per field | RequiredStepsNotice |  |
| PracticableDeadline | choice | encoded | named individuals | PracticableDeadline |  |
| AppealOutcome | choice | encoded | named individuals | AppealOutcome |  |
| practicable days | wording | approximated | the template's words made from the name, its inputs appended | the practicable days for *a timing* is *a number* | to be reviewed: the name does not say where its inputs go |
| to calendar days | wording | approximated | the template's words made from the name, its inputs appended | the to calendar days for *a business days* is *a number* | to be reviewed: the name does not say where its inputs go |
| practicable days | definition | encoded | func | the practicable days for *a timing* is *a number* |  |
| to calendar days | definition | encoded | func | the to calendar days for *a business days* is *a number* |  |
| ten business days | definition | encoded | func | the ten business days is *a number* |  |
| obligation within days | contract | residue | the contracts half (step 3) | obligation within days |  |
| obligation after trigger | contract | residue | the contracts half (step 3) | obligation after trigger |  |
| notice and cure | contract | residue | the contracts half (step 3) | notice and cure |  |
| required steps procedure | contract | residue | the contracts half (step 3) | required steps procedure |  |
| right to appeal | contract | residue | the contracts half (step 3) | right to appeal |  |
| suspensive appeal | contract | residue | the contracts half (step 3) | suspensive appeal |  |
| original decision takes effect | definition | residue | a value with no LE form | r1 |  |
| decision has no effect | definition | residue | a value with no LE form | r2 |  |
| varied decision takes effect | contract | residue | the contracts half (step 3) | varied decision takes effect |  |
| appeal commissioner decision | contract | residue | the contracts half (step 3) | appeal commissioner decision |  |
| escalation chain | contract | residue | the contracts half (step 3) | escalation chain |  |
| enforcement response | contract | residue | the contracts half (step 3) | enforcement response |  |
| payment with grace | contract | residue | the contracts half (step 3) | payment with grace |  |
| licence suspended | definition | residue | a value with no LE form | r3 |  |
| licence revoked | definition | residue | a value with no LE form | r4 |  |
| appeal procedure | definition | residue | a value with no LE form | r5 |  |
| licence renewal procedure | contract | residue | the contracts half (step 3) | licence renewal procedure |  |
| testCharity | record | encoded | an individual with one fact per field | test_charity |  |
| testNotice | record | encoded | an individual with one fact per field | test_notice |  |
| minorViolation | record | encoded | an individual with one fact per field | minor_violation |  |
| seriousViolation | record | encoded | an individual with one fact per field | serious_violation |  |
| criticalViolation | record | encoded | an individual with one fact per field | critical_violation |  |
| testHolder | record | encoded | an individual with one fact per field | test_holder |  |
| appeal commissioner decision | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | appeal commissioner decision |  |
| enforcement response | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | enforcement response |  |
| escalation chain | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | escalation chain |  |
| licence renewal procedure | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | licence renewal procedure |  |
| notice and cure | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | notice and cure |  |
| obligation after trigger | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | obligation after trigger |  |
| obligation within days | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | obligation within days |  |
| payment with grace | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | payment with grace |  |
| required steps procedure | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | required steps procedure |  |
| right to appeal | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | right to appeal |  |
| suspensive appeal | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | suspensive appeal |  |
| varied decision takes effect | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | varied decision takes effect |  |

## Residue

- **obligation within days** (contract) — the contracts half (step 3); in the program: obligation within days. 
- **obligation after trigger** (contract) — the contracts half (step 3); in the program: obligation after trigger. 
- **notice and cure** (contract) — the contracts half (step 3); in the program: notice and cure. 
- **required steps procedure** (contract) — the contracts half (step 3); in the program: required steps procedure. 
- **right to appeal** (contract) — the contracts half (step 3); in the program: right to appeal. 
- **suspensive appeal** (contract) — the contracts half (step 3); in the program: suspensive appeal. 
- **original decision takes effect** (definition) — a value with no LE form; in the program: r1. 
- **decision has no effect** (definition) — a value with no LE form; in the program: r2. 
- **varied decision takes effect** (contract) — the contracts half (step 3); in the program: varied decision takes effect. 
- **appeal commissioner decision** (contract) — the contracts half (step 3); in the program: appeal commissioner decision. 
- **escalation chain** (contract) — the contracts half (step 3); in the program: escalation chain. 
- **enforcement response** (contract) — the contracts half (step 3); in the program: enforcement response. 
- **payment with grace** (contract) — the contracts half (step 3); in the program: payment with grace. 
- **licence suspended** (definition) — a value with no LE form; in the program: r3. 
- **licence revoked** (definition) — a value with no LE form; in the program: r4. 
- **appeal procedure** (definition) — a value with no LE form; in the program: r5. 
- **licence renewal procedure** (contract) — the contracts half (step 3); in the program: licence renewal procedure. 


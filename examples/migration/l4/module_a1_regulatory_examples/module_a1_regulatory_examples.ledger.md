# Migration ledger: module_a1_regulatory_examples

Source: an L4 program (smucclaw/l4-ide) — module-a1-regulatory-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 43 |
| approximated | 9 |
| residue | 5 |
| **total** | 57 |

Fidelity: **6 of 6** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Conviction | record | encoded | a type of individuals, one template per field | Conviction |  |
| Money | record | encoded | a type of individuals, one template per field | Money |  |
| Asset | record | encoded | a type of individuals, one template per field | Asset |  |
| Applicant | record | encoded | a type of individuals, one template per field | Applicant |  |
| MisconductType | choice | encoded | named individuals | MisconductType |  |
| CharitablePurpose | choice | encoded | named individuals | CharitablePurpose |  |
| Governor | record | encoded | a type of individuals, one template per field | Governor |  |
| CoreFinancialInfo | record | encoded | a type of individuals, one template per field | CoreFinancialInfo |  |
| RegisterSection | choice | encoded | named individuals | RegisterSection |  |
| CharityStatus | choice | encoded | named individuals | CharityStatus |  |
| RegisteredCharity | record | encoded | a type of individuals, one template per field | RegisteredCharity |  |
| ReportableMatter | choice | encoded | named individuals | ReportableMatter |  |
| Actor | choice | encoded | named individuals | Actor |  |
| Action | choice | encoded | named individuals | Action |  |
| RegisterEvent | choice | encoded | named individuals | RegisterEvent |  |
| PurposeWithDate | record | encoded | a type of individuals, one template per field | PurposeWithDate |  |
| event effect | wording | approximated | the template's words made from the name, its inputs appended | the event effect for *an event* is *a text* | to be reviewed: the name does not say where its inputs go |
| has charitable purposes | wording | approximated | the template's words made from the name, its inputs appended | *a charity* has charitable purposes | to be reviewed: the name does not say where its inputs go |
| provides public benefit | wording | approximated | the template's words made from the name, its inputs appended | *a charity* provides public benefit | to be reviewed: the name does not say where its inputs go |
| has identifiable benefit | wording | approximated | the template's words made from the name, its inputs appended | *a charity* has identifiable benefit | to be reviewed: the name does not say where its inputs go |
| benefit outweighs detriment | wording | approximated | the template's words made from the name, its inputs appended | benefit outweighs detriment for *a charity* | to be reviewed: the name does not say where its inputs go |
| unduly restricts beneficiaries | wording | approximated | the template's words made from the name, its inputs appended | unduly restricts beneficiaries for *a charity* | to be reviewed: the name does not say where its inputs go |
| has valid constitution | wording | approximated | the template's words made from the name, its inputs appended | *a charity* has valid constitution | to be reviewed: the name does not say where its inputs go |
| has complete financial info | wording | approximated | the template's words made from the name, its inputs appended | *a charity* has complete financial info | to be reviewed: the name does not say where its inputs go |
| purpose valid at date | wording | approximated | the template's words made from the name, its inputs appended | *a purpose* valid at date for *a date* | to be reviewed: the name does not say where its inputs go |
| annual return obligation | contract | residue | the contracts half (step 3) | annual return obligation |  |
| Commissioner may issue notice | contract | residue | the contracts half (step 3) | Commissioner may issue notice |  |
| charity must comply with notice | contract | residue | the contracts half (step 3) | charity must comply with notice |  |
| governor reporting obligation | contract | residue | the contracts half (step 3) | governor reporting obligation |  |
| commissioner may suspend | contract | residue | the contracts half (step 3) | commissioner may suspend |  |
| event effect | definition | encoded | func | the event effect for *an event* is *a text* |  |
| meets charity test | definition | encoded | pred | meets *a charity* test |  |
| has charitable purposes | definition | encoded | pred | *a charity* has charitable purposes |  |
| provides public benefit | definition | encoded | pred | *a charity* provides public benefit |  |
| has identifiable benefit | definition | encoded | pred | *a charity* has identifiable benefit |  |
| benefit outweighs detriment | definition | encoded | pred | benefit outweighs detriment for *a charity* |  |
| unduly restricts beneficiaries | definition | encoded | pred | unduly restricts beneficiaries for *a charity* |  |
| has valid constitution | definition | encoded | pred | *a charity* has valid constitution |  |
| has complete financial info | definition | encoded | pred | *a charity* has complete financial info |  |
| purpose valid at date | definition | encoded | pred | *a purpose* valid at date for *a date* |  |
| John Smith | record | encoded | an individual with one fact per field | john_smith |  |
| sample financials | record | encoded | an individual with one fact per field | sample_financials |  |
| Acme Animal Shelter | record | encoded | an individual with one fact per field | acme_animal_shelter |  |
| bankruptcy matter | record | encoded | an individual with one fact per field | bankruptcy_matter |  |
| registration event | record | encoded | an individual with one fact per field | registration_event |  |
| late filing event | record | encoded | an individual with one fact per field | late_filing_event |  |
| #EVAL at line 400 | test | encoded | a query and the evaluator's answer | line_400 |  |
| #EVAL at line 403 | test | encoded | a query and the evaluator's answer | line_403 |  |
| #EVAL at line 406 | test | encoded | a query and the evaluator's answer | line_406 |  |
| #EVAL at line 409 | test | encoded | a query and the evaluator's answer | line_409 |  |
| #EVAL at line 413 | test | encoded | a query and the evaluator's answer | line_413 |  |
| #EVAL at line 417 | test | encoded | a query and the evaluator's answer | line_417 |  |
| Commissioner may issue notice | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Commissioner may issue notice |  |
| annual return obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | annual return obligation |  |
| charity must comply with notice | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | charity must comply with notice |  |
| commissioner may suspend | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | commissioner may suspend |  |
| governor reporting obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | governor reporting obligation |  |

## Residue

- **annual return obligation** (contract) — the contracts half (step 3); in the program: annual return obligation. 
- **Commissioner may issue notice** (contract) — the contracts half (step 3); in the program: Commissioner may issue notice. 
- **charity must comply with notice** (contract) — the contracts half (step 3); in the program: charity must comply with notice. 
- **governor reporting obligation** (contract) — the contracts half (step 3); in the program: governor reporting obligation. 
- **commissioner may suspend** (contract) — the contracts half (step 3); in the program: commissioner may suspend. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_400 | line_400 | pass |  |
| line_403 | line_403 | pass |  |
| line_406 | line_406 | pass |  |
| line_409 | line_409 | pass |  |
| line_413 | line_413 | pass |  |
| line_417 | line_417 | pass |  |


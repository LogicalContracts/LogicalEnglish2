# Migration ledger: module_4_examples

Source: an L4 program (smucclaw/l4-ide) — module-4-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 68 |
| approximated | 33 |
| residue | 0 |
| **total** | 101 |

Fidelity: **23 of 23** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| the person is an adult | wording | approximated | the template's words made from the name, its inputs appended | the person is an adult for *an age* | to be reviewed: the name does not say where its inputs go |
| the person is eligible to vote | wording | approximated | the template's words made from the name, its inputs appended | the person is eligible to vote for *an age* with *a boolean* | to be reviewed: the name does not say where its inputs go |
| qualifies for senior discount | wording | approximated | the template's words made from the name, its inputs appended | *an age* qualifies for senior discount | to be reviewed: the name does not say where its inputs go |
| the person is a student | wording | approximated | the template's words made from the name, its inputs appended | the person is a student for *an age* with *a boolean* | to be reviewed: the name does not say where its inputs go |
| qualifies for exemption | wording | approximated | the template's words made from the name, its inputs appended | *an income* qualifies for exemption | to be reviewed: the name does not say where its inputs go |
| the tax bracket | wording | approximated | the template's words made from the name, its inputs appended | the tax bracket for *an income* is *a text* | to be reviewed: the name does not say where its inputs go |
| the income category | wording | approximated | the template's words made from the name, its inputs appended | the income category for *an income* is *a text* | to be reviewed: the name does not say where its inputs go |
| the tax owed | wording | approximated | the template's words made from the name, its inputs appended | the tax owed for *a gross income* with *a tax rate* is *a number* | to be reviewed: the name does not say where its inputs go |
| the income tax owed | wording | approximated | the template's words made from the name, its inputs appended | the income tax owed for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| the net income | wording | approximated | the template's words made from the name, its inputs appended | the net income for *a gross income* with *an expenses* is *a number* | to be reviewed: the name does not say where its inputs go |
| the taxpayer's bracket | wording | approximated | the template's words made from the name, its inputs appended | the taxpayers bracket for *a taxpayer* is *a text* | to be reviewed: the name does not say where its inputs go |
| the loan is approved | wording | approximated | the template's words made from the name, its inputs appended | the loan is approved for *an income* with *a credit score* with *a loan amount* | to be reviewed: the name does not say where its inputs go |
| the annual premium | wording | approximated | the template's words made from the name, its inputs appended | the annual premium for *an insured age* with *a coverage amount* with *a boolean* is *a number* | to be reviewed: the name does not say where its inputs go |
| the late payment penalty | wording | approximated | the template's words made from the name, its inputs appended | the late payment penalty for *a principal amount* with *a days overdue* is *a number* | to be reviewed: the name does not say where its inputs go |
| qualifies for lease renewal | wording | approximated | the template's words made from the name, its inputs appended | *a years as tenant* qualifies for lease renewal for *a late payments* with *a current rent* with *a market rent* | to be reviewed: the name does not say where its inputs go |
| the person is an adult | definition | encoded | pred | the person is an adult for *an age* |  |
| the person is eligible to vote | definition | encoded | pred | the person is eligible to vote for *an age* with *a boolean* |  |
| qualifies for senior discount | definition | encoded | pred | *an age* qualifies for senior discount |  |
| the person is a student | definition | encoded | pred | the person is a student for *an age* with *a boolean* |  |
| qualifies for exemption | definition | encoded | pred | *an income* qualifies for exemption |  |
| the tax bracket | definition | encoded | func | the tax bracket for *an income* is *a text* |  |
| the income category | definition | encoded | func | the income category for *an income* is *a text* |  |
| the taxable income | wording | approximated | the template's words made from the name, its inputs appended | the taxable income for *a gross income* is *a number* | to be reviewed: the name does not say where its inputs go |
| the standard deduction | definition | encoded | func | the standard deduction is *a number* |  |
| the taxable income | definition | encoded | func | the taxable income for *a gross income* is *a number* |  |
| the tax owed | definition | encoded | func | the tax owed for *a gross income* with *a tax rate* is *a number* |  |
| tax on first bracket | wording | approximated | the template's words made from the name, its inputs appended | the tax on first bracket for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| tax on second bracket | wording | approximated | the template's words made from the name, its inputs appended | the tax on second bracket for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| tax on third bracket | wording | approximated | the template's words made from the name, its inputs appended | the tax on third bracket for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| amount in first bracket | wording | approximated | the template's words made from the name, its inputs appended | the amount in first bracket for *an income* is *a value* | to be reviewed: the name does not say where its inputs go |
| amount in second bracket | wording | approximated | the template's words made from the name, its inputs appended | the amount in second bracket for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| amount in third bracket | wording | approximated | the template's words made from the name, its inputs appended | the amount in third bracket for *an income* is *a number* | to be reviewed: the name does not say where its inputs go |
| tax on first bracket | definition | encoded | func | the tax on first bracket for *an income* is *a number* |  |
| tax on second bracket | definition | encoded | func | the tax on second bracket for *an income* is *a number* |  |
| tax on third bracket | definition | encoded | func | the tax on third bracket for *an income* is *a number* |  |
| amount in first bracket | definition | encoded | func | the amount in first bracket for *an income* is *a value* |  |
| amount in second bracket | definition | encoded | func | the amount in second bracket for *an income* is *a number* |  |
| amount in third bracket | definition | encoded | func | the amount in third bracket for *an income* is *a number* |  |
| the income tax owed | definition | encoded | func | the income tax owed for *an income* is *a number* |  |
| the standard deduction | wording | approximated | the template's words made from the name, its inputs appended | the standard deduction for *a gross income* is *a number* | to be reviewed: the name does not say where its inputs go |
| calculated deduction | wording | approximated | the template's words made from the name, its inputs appended | the calculated deduction for *a gross income* is *a number* | to be reviewed: the name does not say where its inputs go |
| the total deductions | wording | approximated | the template's words made from the name, its inputs appended | the total deductions for *an expenses* with *a gross income* is *a number* | to be reviewed: the name does not say where its inputs go |
| the standard deduction | definition | encoded | func | the standard deduction for *a gross income* is *a number* |  |
| calculated deduction | definition | encoded | func | the calculated deduction for *a gross income* is *a number* |  |
| the total deductions | definition | encoded | func | the total deductions for *an expenses* with *a gross income* is *a number* |  |
| the net income | definition | encoded | func | the net income for *a gross income* with *an expenses* is *a number* |  |
| the applicant is a qualifying resident | definition | encoded | pred | *an applicant* is a qualifying resident |  |
| the applicant is of age | definition | encoded | pred | *an applicant* is of age |  |
| the applicant meets income threshold | definition | encoded | pred | *an applicant* meets income threshold |  |
| the applicant is disqualified | definition | encoded | pred | *an applicant* is disqualified |  |
| the applicant is eligible for benefit | definition | encoded | pred | *an applicant* is eligible for benefit |  |
| the taxpayer's bracket | definition | encoded | func | the taxpayers bracket for *a taxpayer* is *a text* |  |
| income requirement is met | wording | approximated | the template's words made from the name, its inputs appended | income requirement is met for *an income* with *a loan amount* | to be reviewed: the name does not say where its inputs go |
| credit score is sufficient | wording | approximated | the template's words made from the name, its inputs appended | credit score is sufficient for *a credit score* | to be reviewed: the name does not say where its inputs go |
| debt to income ratio is acceptable | wording | approximated | the template's words made from the name, its inputs appended | debt to income ratio is acceptable for *an income* with *a loan amount* | to be reviewed: the name does not say where its inputs go |
| income requirement is met | definition | encoded | pred | income requirement is met for *an income* with *a loan amount* |  |
| credit score is sufficient | definition | encoded | pred | credit score is sufficient for *a credit score* |  |
| debt to income ratio is acceptable | definition | encoded | pred | debt to income ratio is acceptable for *an income* with *a loan amount* |  |
| the loan is approved | definition | encoded | pred | the loan is approved for *an income* with *a credit score* with *a loan amount* |  |
| the base premium | wording | approximated | the template's words made from the name, its inputs appended | the base premium for *a coverage amount* is *a number* | to be reviewed: the name does not say where its inputs go |
| the age factor | wording | approximated | the template's words made from the name, its inputs appended | the age factor for *an insured age* is *a number* | to be reviewed: the name does not say where its inputs go |
| the smoking factor | wording | approximated | the template's words made from the name, its inputs appended | the smoking factor for *a boolean* is *a number* | to be reviewed: the name does not say where its inputs go |
| the base premium | definition | encoded | func | the base premium for *a coverage amount* is *a number* |  |
| the age factor | definition | encoded | func | the age factor for *an insured age* is *a number* |  |
| the smoking factor | definition | encoded | func | the smoking factor for *a boolean* is *a number* |  |
| the annual premium | definition | encoded | func | the annual premium for *an insured age* with *a coverage amount* with *a boolean* is *a number* |  |
| the late payment penalty | definition | encoded | func | the late payment penalty for *a principal amount* with *a days overdue* is *a number* |  |
| tenant is in good standing | wording | approximated | the template's words made from the name, its inputs appended | tenant is in good standing for *a late payments* with *a years as tenant* | to be reviewed: the name does not say where its inputs go |
| rent is at market rate | wording | approximated | the template's words made from the name, its inputs appended | rent is at market rate for *a current rent* with *a market rent* | to be reviewed: the name does not say where its inputs go |
| tenant is in good standing | definition | encoded | pred | tenant is in good standing for *a late payments* with *a years as tenant* |  |
| rent is at market rate | definition | encoded | pred | rent is at market rate for *a current rent* with *a market rent* |  |
| qualifies for lease renewal | definition | encoded | pred | *a years as tenant* qualifies for lease renewal for *a late payments* with *a current rent* with *a market rent* |  |
| test person eligible | record | encoded | an individual with one fact per field | test_person_eligible |  |
| test person ineligible age | record | encoded | an individual with one fact per field | test_person_ineligible_age |  |
| test person ineligible citizenship | record | encoded | an individual with one fact per field | test_person_ineligible_citizenship |  |
| test person ineligible income | record | encoded | an individual with one fact per field | test_person_ineligible_income |  |
| test person disqualified | record | encoded | an individual with one fact per field | test_person_disqualified |  |
| #EVAL at line 271 | test | encoded | a query and the evaluator's answer | line_271 |  |
| #EVAL at line 272 | test | encoded | a query and the evaluator's answer | line_272 |  |
| #EVAL at line 273 | test | encoded | a query and the evaluator's answer | line_273 |  |
| #EVAL at line 274 | test | encoded | a query and the evaluator's answer | line_274 |  |
| #EVAL at line 275 | test | encoded | a query and the evaluator's answer | line_275 |  |
| #EVAL at line 276 | test | encoded | a query and the evaluator's answer | line_276 |  |
| #EVAL at line 279 | test | encoded | a query and the evaluator's answer | line_279 |  |
| #EVAL at line 280 | test | encoded | a query and the evaluator's answer | line_280 |  |
| #EVAL at line 281 | test | encoded | a query and the evaluator's answer | line_281 |  |
| #EVAL at line 284 | test | encoded | a query and the evaluator's answer | line_284 |  |
| #EVAL at line 285 | test | encoded | a query and the evaluator's answer | line_285 |  |
| #EVAL at line 286 | test | encoded | a query and the evaluator's answer | line_286 |  |
| #EVAL at line 287 | test | encoded | a query and the evaluator's answer | line_287 |  |
| #EVAL at line 288 | test | encoded | a query and the evaluator's answer | line_288 |  |
| #EVAL at line 289 | test | encoded | a query and the evaluator's answer | line_289 |  |
| #EVAL at line 292 | test | encoded | a query and the evaluator's answer | line_292 |  |
| #EVAL at line 293 | test | encoded | a query and the evaluator's answer | line_293 |  |
| #EVAL at line 294 | test | encoded | a query and the evaluator's answer | line_294 |  |
| #EVAL at line 295 | test | encoded | a query and the evaluator's answer | line_295 |  |
| #EVAL at line 298 | test | encoded | a query and the evaluator's answer | line_298 |  |
| #EVAL at line 299 | test | encoded | a query and the evaluator's answer | line_299 |  |
| #EVAL at line 300 | test | encoded | a query and the evaluator's answer | line_300 |  |
| #EVAL at line 301 | test | encoded | a query and the evaluator's answer | line_301 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_271 | line_271 | pass |  |
| line_272 | line_272 | pass |  |
| line_273 | line_273 | pass |  |
| line_274 | line_274 | pass |  |
| line_275 | line_275 | pass |  |
| line_276 | line_276 | pass |  |
| line_279 | line_279 | pass |  |
| line_280 | line_280 | pass |  |
| line_281 | line_281 | pass |  |
| line_284 | line_284 | pass |  |
| line_285 | line_285 | pass |  |
| line_286 | line_286 | pass |  |
| line_287 | line_287 | pass |  |
| line_288 | line_288 | pass |  |
| line_289 | line_289 | pass |  |
| line_292 | line_292 | pass |  |
| line_293 | line_293 | pass |  |
| line_294 | line_294 | pass |  |
| line_295 | line_295 | pass |  |
| line_298 | line_298 | pass |  |
| line_299 | line_299 | pass |  |
| line_300 | line_300 | pass |  |
| line_301 | line_301 | pass |  |


# Migration ledger: assume_example

Source: an L4 program (smucclaw/l4-ide) — assume-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 1 |
| residue | 0 |
| **total** | 13 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| calculate tax | wording | approximated | the template's words made from the name, its inputs appended | the calculate tax for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| is employed | assume | encoded | a template the scenarios state (; undefined) | is employed |  |
| annual income | assume | encoded | a template the scenarios state (; undefined) | annual income |  |
| applicant name | assume | encoded | a template the scenarios state (; undefined) | applicant name |  |
| calculate tax | assume | encoded | a template the scenarios state (; undefined) | calculate tax |  |
| tax on income | definition | encoded | func | the tax on income is *a number* |  |
| age | assume | encoded | a template the scenarios state (; undefined) | age |  |
| has valid license | assume | encoded | a template the scenarios state (; undefined) | has valid license |  |
| can drive | definition | encoded | pred | can drive |  |
| applicant age | assume | encoded | a template the scenarios state (; undefined) | applicant age |  |
| years of residence | assume | encoded | a template the scenarios state (; undefined) | years of residence |  |
| has criminal record | assume | encoded | a template the scenarios state (; undefined) | has criminal record |  |
| is eligible for benefit | definition | encoded | pred | is eligible for benefit |  |


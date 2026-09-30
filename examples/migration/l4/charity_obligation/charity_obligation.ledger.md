# Migration ledger: charity_obligation

Source: an L4 program (smucclaw/l4-ide) — charity-obligation.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 0 |
| residue | 1 |
| **total** | 7 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Charity Status | choice | encoded | named individuals | Charity Status |  |
| Registered Charity | record | encoded | a type of individuals, one template per field | Registered Charity |  |
| Party | choice | encoded | named individuals | Party |  |
| Action | choice | encoded | named individuals | Action |  |
| the charity must file its annual return | contract | residue | the contracts half (step 3) | the charity must file its annual return |  |
| Acme Animal Shelter | record | encoded | an individual with one fact per field | acme_animal_shelter |  |
| the charity must file its annual return | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the charity must file its annual return |  |

## Residue

- **the charity must file its annual return** (contract) — the contracts half (step 3); in the program: the charity must file its annual return. 


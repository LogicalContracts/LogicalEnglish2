# Migration ledger: sale_contract

Source: an L4 program (smucclaw/l4-ide) — sale-contract.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 1 |
| **total** | 4 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Party | choice | encoded | named individuals | Party |  |
| Contract Action | choice | encoded | named individuals | Contract Action |  |
| the sale contract | contract | residue | the contracts half (step 3) | the sale contract |  |
| the sale contract | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the sale contract |  |

## Residue

- **the sale contract** (contract) — the contracts half (step 3); in the program: the sale contract. 


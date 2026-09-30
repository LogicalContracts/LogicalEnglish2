# Migration ledger: module_5_examples

Source: an L4 program (smucclaw/l4-ide) — module-5-examples.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 0 |
| residue | 6 |
| **total** | 16 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Contract Party | choice | encoded | named individuals | Contract Party |  |
| Sale Action | choice | encoded | named individuals | Sale Action |  |
| Spouse | choice | encoded | named individuals | Spouse |  |
| Vow | choice | encoded | named individuals | Vow |  |
| the delivery obligation | contract | residue | the contracts half (step 3) | the delivery obligation |  |
| the inspection right | contract | residue | the contracts half (step 3) | the inspection right |  |
| the complete sale contract | contract | residue | the contracts half (step 3) | the complete sale contract |  |
| the payment with late fee | contract | residue | the contracts half (step 3) | the payment with late fee |  |
| the wedding ceremony | contract | residue | the contracts half (step 3) | the wedding ceremony |  |
| the fidelity clause | contract | residue | the contracts half (step 3) | the fidelity clause |  |
| the complete sale contract | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the complete sale contract |  |
| the delivery obligation | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the delivery obligation |  |
| the fidelity clause | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the fidelity clause |  |
| the inspection right | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the inspection right |  |
| the payment with late fee | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the payment with late fee |  |
| the wedding ceremony | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | the wedding ceremony |  |

## Residue

- **the delivery obligation** (contract) — the contracts half (step 3); in the program: the delivery obligation. 
- **the inspection right** (contract) — the contracts half (step 3); in the program: the inspection right. 
- **the complete sale contract** (contract) — the contracts half (step 3); in the program: the complete sale contract. 
- **the payment with late fee** (contract) — the contracts half (step 3); in the program: the payment with late fee. 
- **the wedding ceremony** (contract) — the contracts half (step 3); in the program: the wedding ceremony. 
- **the fidelity clause** (contract) — the contracts half (step 3); in the program: the fidelity clause. 


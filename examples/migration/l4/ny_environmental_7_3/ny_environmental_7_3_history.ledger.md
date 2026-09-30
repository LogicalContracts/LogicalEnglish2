# Migration ledger: ny_environmental_7_3_history

Source: an L4 file (smucclaw/l4-ide) — ny-environmental-7.3.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 0 |
| approximated | 0 |
| residue | 3 |
| **total** | 3 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| contract Example Filing | contract | residue | outside what the translator covers: "a function applied to fewer or more inputs than it takes" | Example Filing |  |
| contract Filing of draft copy of EIS and causing notice of hearing to be published | contract | residue | outside what the translator covers: field_of_unknown('General circulation area') | Filing of draft copy of EIS and causing notice of hearing to be published |  |
| #TRACE `Example Filing` (line 119) | trace | residue | not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes" | trace_119 |  |

## Residue

- **contract Example Filing** (contract) — outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: Example Filing. 
- **contract Filing of draft copy of EIS and causing notice of hearing to be published** (contract) — outside what the translator covers: field_of_unknown('General circulation area'); in the program: Filing of draft copy of EIS and causing notice of hearing to be published. 
- **#TRACE `Example Filing` (line 119)** (trace) — not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: trace_119. 


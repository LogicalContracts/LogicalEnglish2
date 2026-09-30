# Migration ledger: shant_example_history

Source: an L4 file (smucclaw/l4-ide) — shant-example.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 0 |
| residue | 0 |
| **total** | 9 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| confidentiality obligation, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | confidentiality obligation |  |
| structural alteration prohibition, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | structural alteration prohibition |  |
| debt restriction, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | debt restriction |  |
| #TRACE `confidentiality obligation` (line 104) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_104 |  |
| #TRACE `confidentiality obligation` (line 107) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_107 |  |
| #TRACE `structural alteration prohibition` (line 111) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_111 |  |
| #TRACE `structural alteration prohibition` (line 115) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_115 |  |
| #TRACE `debt restriction` (line 119) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_119 |  |
| #TRACE `debt restriction` (line 123) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_123 |  |


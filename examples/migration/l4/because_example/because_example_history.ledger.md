# Migration ledger: because_example_history

Source: an L4 file (smucclaw/l4-ide) — because-example.l4
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
| delivery with reason, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | delivery with reason |  |
| delivery full form, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | delivery full form |  |
| no smoking policy, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | no smoking policy |  |
| rental agreement, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | rental agreement |  |
| rental agreement, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | rental agreement |  |
| #TRACE `delivery with reason` (line 109) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_109 |  |
| #TRACE `delivery full form` (line 114) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_114 |  |
| #TRACE `no smoking policy` (line 117) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_117 |  |
| #TRACE `rental agreement` (line 121) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_121 |  |


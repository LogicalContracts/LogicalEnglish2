# Migration ledger: module_5_examples_history

Source: an L4 file (smucclaw/l4-ide) — module-5-examples.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 14 |
| approximated | 1 |
| residue | 0 |
| **total** | 15 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| the delivery obligation, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the delivery obligation |  |
| the complete sale contract, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the complete sale contract |  |
| the payment with late fee, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the payment with late fee |  |
| the wedding ceremony, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the wedding ceremony |  |
| the fidelity clause, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the fidelity clause |  |
| the complete sale contract, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the complete sale contract |  |
| the complete sale contract, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the complete sale contract |  |
| the payment with late fee, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the payment with late fee |  |
| the wedding ceremony, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | the wedding ceremony |  |
| #TRACE `the delivery obligation` (line 128) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_128 |  |
| #TRACE `the delivery obligation` (line 132) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_132 |  |
| #TRACE `the complete sale contract` (line 136) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_136 |  |
| #TRACE `the payment with late fee` (line 141) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_141 |  |
| #TRACE `the wedding ceremony` (line 145) | trace | approximated | a #TRACE -> a scenario (its events as facts, each on its day) | trace_145 | two events are on the same day: L4 takes them one after the other, a history read by days cannot order them; no expectation |
| #TRACE `the fidelity clause` (line 150) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_150 |  |


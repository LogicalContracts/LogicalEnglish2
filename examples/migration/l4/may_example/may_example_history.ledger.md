# Migration ledger: may_example_history

Source: an L4 file (smucclaw/l4-ide) — may-example.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 26 |
| approximated | 0 |
| residue | 0 |
| **total** | 26 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| prepayment option, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | prepayment option |  |
| purchase with warranty, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | purchase with warranty |  |
| first renewal option, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | first renewal option |  |
| payment with acceleration right, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with acceleration right |  |
| conversion option, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | conversion option |  |
| shareholder put option, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | shareholder put option |  |
| early termination clause, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | early termination clause |  |
| warranty claim process, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | warranty claim process |  |
| purchase with warranty, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | purchase with warranty |  |
| first renewal option, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | first renewal option |  |
| payment with acceleration right, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with acceleration right |  |
| warranty claim process, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | warranty claim process |  |
| warranty claim process, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | warranty claim process |  |
| #TRACE `prepayment option` (line 149) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_149 |  |
| #TRACE `prepayment option` (line 153) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_153 |  |
| #TRACE `purchase with warranty` (line 156) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_156 |  |
| #TRACE `purchase with warranty` (line 161) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_161 |  |
| #TRACE `first renewal option` (line 165) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_165 |  |
| #TRACE `first renewal option` (line 169) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_169 |  |
| #TRACE `payment with acceleration right` (line 174) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_174 |  |
| #TRACE `payment with acceleration right` (line 178) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_178 |  |
| #TRACE `conversion option` (line 182) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_182 |  |
| #TRACE `shareholder put option` (line 186) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_186 |  |
| #TRACE `early termination clause` (line 190) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_190 |  |
| #TRACE `early termination clause` (line 194) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_194 |  |
| #TRACE `warranty claim process` (line 197) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_197 |  |


# Migration ledger: must_example_history

Source: an L4 file (smucclaw/l4-ide) — must-example.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 28 |
| approximated | 0 |
| residue | 0 |
| **total** | 28 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| monthly loan payment, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | monthly loan payment |  |
| purchase and delivery agreement, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | purchase and delivery agreement |  |
| payment with late fee, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with late fee |  |
| staged service contract, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | staged service contract |  |
| construction contract workflow, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | construction contract workflow |  |
| lease termination and deposit return, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | lease termination and deposit return |  |
| landlord repair obligation, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | landlord repair obligation |  |
| purchase and delivery agreement, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | purchase and delivery agreement |  |
| payment with late fee, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with late fee |  |
| staged service contract, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | staged service contract |  |
| construction contract workflow, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | construction contract workflow |  |
| lease termination and deposit return, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | lease termination and deposit return |  |
| landlord repair obligation, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | landlord repair obligation |  |
| staged service contract, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | staged service contract |  |
| construction contract workflow, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | construction contract workflow |  |
| lease termination and deposit return, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | lease termination and deposit return |  |
| construction contract workflow, obligation 4 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | construction contract workflow |  |
| lease termination and deposit return, obligation 4 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | lease termination and deposit return |  |
| #TRACE `monthly loan payment` (line 147) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_147 |  |
| #TRACE `monthly loan payment` (line 151) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_151 |  |
| #TRACE `purchase and delivery agreement` (line 154) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_154 |  |
| #TRACE `payment with late fee` (line 159) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_159 |  |
| #TRACE `payment with late fee` (line 163) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_163 |  |
| #TRACE `staged service contract` (line 166) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_166 |  |
| #TRACE `construction contract workflow` (line 172) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_172 |  |
| #TRACE `lease termination and deposit return` (line 179) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_179 |  |
| #TRACE `landlord repair obligation` (line 185) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_185 |  |
| #TRACE `landlord repair obligation` (line 189) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_189 |  |


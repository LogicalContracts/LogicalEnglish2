# Migration ledger: deontic_example_history

Source: an L4 file (smucclaw/l4-ide) — deontic-example.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 32 |
| approximated | 0 |
| residue | 0 |
| **total** | 32 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| simple delivery obligation, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | simple delivery obligation |  |
| delivery within days, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | delivery within days |  |
| sale contract, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | sale contract |  |
| mutual obligations, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | mutual obligations |  |
| mutual obligations, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | mutual obligations |  |
| flexible delivery, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | flexible delivery |  |
| flexible delivery, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | flexible delivery |  |
| conditional delivery, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | conditional delivery |  |
| conditional delivery, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | conditional delivery |  |
| minimum payment contract, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | minimum payment contract |  |
| exact payment required, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | exact payment required |  |
| create order contract, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | create order contract |  |
| create order contract, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | create order contract |  |
| sale contract, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | sale contract |  |
| create order contract, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | create order contract |  |
| create order contract, obligation 4 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | create order contract |  |
| #TRACE `simple delivery obligation` (line 170) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_170 |  |
| #TRACE `simple delivery obligation` (line 174) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_174 |  |
| #TRACE (`delivery within days` OF 7) (line 178) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_178 |  |
| #TRACE (`sale contract` OF 500) (line 182) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_182 |  |
| #TRACE `mutual obligations` (line 187) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_187 |  |
| #TRACE `flexible delivery` (line 192) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_192 |  |
| #TRACE `flexible delivery` (line 196) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_196 |  |
| #TRACE (`conditional delivery` OF `TRUE`) (line 200) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_200 |  |
| #TRACE (`conditional delivery` OF `FALSE`) (line 204) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_204 |  |
| #TRACE `minimum payment contract` (line 222) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_222 |  |
| #TRACE `minimum payment contract` (line 226) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_226 |  |
| #TRACE (`exact payment required` OF 500) (line 245) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_245 |  |
| #TRACE (`exact payment required` OF 500) (line 249) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_249 |  |
| #TRACE `simple delivery obligation` (line 259) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_259 |  |
| #TRACE (`create order contract` OF "express", 200) (line 299) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_299 |  |
| #TRACE (`create order contract` OF "standard", 200) (line 304) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_304 |  |


# Migration ledger: module_a2_cross_cutting_examples_history

Source: an L4 file (smucclaw/l4-ide) — module-a2-cross-cutting-examples.l4
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
| obligation within days, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | obligation within days |  |
| required steps procedure, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | required steps procedure |  |
| payment with grace, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with grace |  |
| escalation chain, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| enforcement response, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | enforcement response |  |
| enforcement response, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | enforcement response |  |
| licence renewal procedure, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | licence renewal procedure |  |
| required steps procedure, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | required steps procedure |  |
| payment with grace, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | payment with grace |  |
| escalation chain, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| enforcement response, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | enforcement response |  |
| licence renewal procedure, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | licence renewal procedure |  |
| required steps procedure, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | required steps procedure |  |
| required steps procedure, obligation 4 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | required steps procedure |  |
| escalation chain, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| licence renewal procedure, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | licence renewal procedure |  |
| escalation chain, obligation 4 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| escalation chain, obligation 5 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| escalation chain, obligation 6 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| escalation chain, obligation 7 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | escalation chain |  |
| #TRACE (`obligation within days` OF `CommissionerActor`, `take action`, 14) (line 444) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_444 |  |
| #TRACE (`obligation within days` OF `CommissionerActor`, `take action`, 14) (line 448) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_448 |  |
| #TRACE (`required steps procedure` OF `testCharity`, `testNotice`) (line 452) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_452 |  |
| #TRACE (`required steps procedure` OF `testCharity`, `testNotice`) (line 458) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_458 |  |
| #TRACE (`payment with grace` OF `CommissionerActor`, 1000, 30, 10, 0.1) (line 463) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_463 |  |
| #TRACE (`payment with grace` OF `CommissionerActor`, 1000, 30, 10, 0.1) (line 467) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_467 |  |
| #TRACE (`escalation chain` OF `CommissionerActor`) (line 471) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_471 |  |
| #TRACE (`enforcement response` OF `minorViolation`, `CommissionerActor`) (line 476) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_476 |  |
| #TRACE (`enforcement response` OF `criticalViolation`, `CommissionerActor`) (line 481) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_481 |  |
| #TRACE (`licence renewal procedure` OF `testHolder`, 100) (line 486) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_486 |  |
| #TRACE (`licence renewal procedure` OF `testHolder`, 100) (line 490) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_490 |  |
| #TRACE (`licence renewal procedure` OF `testHolder`, 100) (line 494) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_494 |  |


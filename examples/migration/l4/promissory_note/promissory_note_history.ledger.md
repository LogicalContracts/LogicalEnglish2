# Migration ledger: promissory_note_history

Source: an L4 file (smucclaw/l4-ide) — promissory-note.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 0 |
| **total** | 5 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Payment Obligations, obligation 1 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | Payment Obligations |  |
| Payment Obligations, obligation 2 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | Payment Obligations |  |
| Payment Obligations, obligation 3 | obligation | encoded | an obligation -> when it starts, its deadline and the events that meet it; four rules: met, missed, pending, ends | Payment Obligations |  |
| #TRACE (`Payment Obligations` OF `Total Repayment Amount`) (line 179) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_179 | no expectation: longer than the test runner's time limit (the LE for LPS twin runs it) |
| #TRACE (`Payment Obligations` OF `Total Repayment Amount`) (line 195) | trace | encoded | a #TRACE -> a scenario (its events as facts, each on its day) | trace_195 |  |


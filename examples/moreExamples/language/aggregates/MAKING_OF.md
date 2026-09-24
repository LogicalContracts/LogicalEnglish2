# How the examples in this folder were made

`ecommerce.le` came with the programs carried over from the first Logical
English (LE1). `sums.le` was put together by an AI agent from two older
programs.

| File | Made by | How |
|---|---|---|
| `ecommerce.le` | Committed by Miguel Calejo, 2026-04-01, among the LE1 programs | Written by people. |
| `sums.le` | AI agent (Claude Opus 5, in Claude Code), 2026-09-16 | Joins `sum_onto.le` and `sum_simple.le`, two programs committed on 2026-04-01 with the LE1 programs, into one program. The agent wrote the opening comment and the merged scenarios. |
| `README.md` | AI agent (Claude, in Claude Code), 2026-09-16 | |

## The record
- commit `e59a179` (2026-04-01) "Add LE working examples": `ecommerce.le`, `sum_onto.le`, `sum_simple.le`.
- commit `dfeddca` (2026-09-16) "Examples cleanup, step 1": "sum_onto + sum_simple into sums.le".

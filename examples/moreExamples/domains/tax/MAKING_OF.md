# How the examples in this folder were made

Most of these programs come from the first Logical English (LE1), where
people wrote them on Australian tax law. They were carried over to LE2
syntax on 2026-04-01. One program, `div36_loss_sequencing.le`, was written
by an AI agent.

| File | Made by | How |
|---|---|---|
| `1_cgt_assets_and_exemptions_3.le`, `1_net_asset_value_test_3.le`, `3_rollover_3.le`, `4_affiliates_3.le`, `gst.le`, `gstturnover.le`, `journal_balance.le`, `payg.le`, `sbpp_0.le`, `sbppxml1.le`, `small_business.le` | People: the authors of the LE1 tax programs | Carried over from LE1. Later agent edits were small fixes of a few lines each. |
| `div36_loss_sequencing.le` | AI agent (Claude, in Claude Code), 2026-09-01, at Miguel Calejo's request | Written from the Income Tax Assessment Act 1997 (Division 36 and the sections its comments cite) to settle the question of a customer support ticket (LodgeiT #56568), as its comments say. |
| `README.md` | AI agent (Claude, in Claude Code), 2026-09-16 | |

## The record
- commit `e59a179` (2026-04-01) "Add LE working examples": the LE1 programs.
- commit `7e8f374` (2026-09-01) "split test suite, core and with extensions", authored "Miguel Calejo (via Claude)": `div36_loss_sequencing.le`.

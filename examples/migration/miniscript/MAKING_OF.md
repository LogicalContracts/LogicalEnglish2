# How the examples in this folder were made

Every program here is a *twin*: a Bitcoin spending policy, written in
Miniscript, rewritten in Logical English by a translator, a Prolog program
that reads the policy and writes the twin. The twelve policies are real ones,
published by their authors (Bitcoin Core, Liana, Pieter Wuille's Miniscript
page); an AI agent (Claude, in Claude Code) chose them, recorded where each is
published, and named the roles of their keys. The translator itself, and this
folder's README, were written by the AI agent at Miguel Calejo's request.

| File | Made by | How |
|---|---|---|
| `*/<id>.le` | Translator program `lpsPlus/migration/miniscript/build.pl` (`main/1`, which calls `ms_twin:build_twin/3`) | Parses and evaluates the policy with `miniscript.pl` and writes the program through LE2's `le_writer.pl` and `le_migration.pl`. The scenarios are computed from the policy: its satisfaction analysis, the loss of each key, and the recorded spending attempts on a test network. The expected answers come from the translator's own evaluator of the policy (`ms_eval/2`), following BIP 379. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<id>.ledger.md`, `*/<id>.ledger.json` | The same translator (`le_migration.pl`) | What each part of the twin was translated from. |
| The key legends and titles inside each twin | AI agent (Claude, in Claude Code), 13 September 2026 | Written in `lpsPlus/migration/miniscript/policies.pl` and `core_wallet_policies.pl`: which key belongs to whom ("cosigner A", "the manager"), and which published text each policy is quoted from. |
| `*/temporal.le`, `*/temporal.pl` | A copy of LE2's `lib/temporal.le` and `lib/temporal.pl`, put there by the translator | The library of dates and lock times. It was written by the AI agent (commit `63c3591`, 13 September 2026). |
| `*/sources/*.txt` | People: the authors of each cited document | The excerpt each twin quotes, copied from Pieter Wuille's Miniscript page (https://bitcoin.sipa.be/miniscript/), Bitcoin Core's documentation and tests (https://github.com/bitcoin/bitcoin), or Liana's documentation (https://github.com/wizardsardine/liana). |
| `*/sources/originals/*` | The same authors | The whole page or file the excerpt comes from, unchanged, with its licence where it has one (`COPYING` for Bitcoin Core, `LICENCE` for Liana). The Miniscript page carries no licence file. |
| `*/sources/<id>.policy` | The translator | The policy as File ▸ Open reads it back: title, key legend, the source's text, the compiled Miniscript, a link to the Minsc playground. |
| `*/sources/<id>.chain.json` | Program `lpsPlus/migration/miniscript/chain.pl` | The recorded run of the twin's spending attempts on a real test network (Rewind Bitcoin's public Tape network). |
| `README.md` | AI agent (Claude, in Claude Code), at Miguel Calejo's request (it came from InsurLE2 with the twins on 16 September 2026 and was rewritten on 23 September) | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `0ca7270` (13 September 2026) "Migration Phase 1c/1d/1e: … Bitcoin
  Miniscript translator (12 cited policies, 271/271) …", in the InsurLE2
  repository, by Miguel Calejo with Claude Opus 5 (the commit's
  `Co-Authored-By` line): the translator, the policies and the first build.
- The translator moved to the lpsPlus repository on 18 September 2026 (commit
  `44d3f65` there); the twins moved into this repository on 16 September
  (commit `9d42150`, "move examples"). Later changes here came from rebuilds,
  and from refreshed copies of the `temporal` library (commits `dfeddca`,
  16 September, and `6e903fd`, 22 September); the record shows no hand edit of
  a twin.
- To build the twins again, from the LE2 checkout:

  ```sh
  ./myswipl.sh -q /lpsPlus/migration/miniscript/build.pl                   # all
  ./myswipl.sh -q /lpsPlus/migration/miniscript/build.pl liana_recovery    # one
  ./myswipl.sh -q /lpsPlus/migration/miniscript/chain.pl                   # the chain runs
  ```

  The lpsPlus repository is not public.

# How the examples in this folder were made

The small programs at the top of this folder were written by an AI agent
(Claude, working in Claude Code) on 11 September 2026, at Miguel Calejo's
request. The agent wrote them as test examples while it implemented the
regulatory-decision constructs of Logical English (the language reference,
§17). Those constructs come from a written proposal, *Logical English
extensions for regulatory decision-making*, which the same kind of agent
drafted with Miguel Calejo. No person typed these programs. The two large
models in `customs/` and `medicare/` have their own `MAKING_OF.md`.

| File | Made by | How |
|---|---|---|
| `judged_damage.le` | AI agent (Claude Opus 5, in Claude Code), 11 September 2026, at Miguel Calejo's request | written as the test example of facts that name their source and of questions someone must decide (proposal §3.1) |
| `otherwise_table.le`, `loaded_table.le`, `shipping.csv` | the same agent, the same day | written as the test examples of `otherwise` and of decision tables, one of them read from the CSV file beside it (proposal §3.3); the CSV's rows are invented |
| `precedent.le`, `precedent_pattern.le` | the same agent, the same day | written as a plain Logical English library for reasoning from precedent, following John Horty's published model of precedent, and a program that uses it (proposal §3.2) |
| `sections_benefit.le` | the same agent, the same day | written as the test example of a decision in three sections (proposal §3.4); a view and draft letters were added on 12–13 September, after reviews in which the agent played a public officer |
| `scoped_notice.le` | the same agent, the same day | written as the test example of a proof that may use only one party's evidence (proposal §3.5) |
| `semantic_match.le`, `semantic_llm.le` | the same agent, the same day | written as the test examples of services and of matching the meaning of text (proposal §3.6) |
| `flip_housing.le` | the same agent, the same day | written as the test example of "flip" questions: the smallest change to the facts that changes an answer (proposal §3.7) |
| `eu261_integration.le` | the same agent, the same day | written to use all the constructs together, on EU Regulation 261/2004 (compensation for cancelled flights). Its facts are those of the European Court of Justice's Wallentin-Hermann judgment (case C-549/07), as the agent read them |
| `scenario_table.le` | AI agent (Claude, in Claude Code), 18 September 2026 | written as the test example of a decision table placed inside a scenario |
| `README.md` | AI agents (Claude, in Claude Code), 16 and 23 September 2026 | written when the example trees were regrouped, then shortened |

Later changes to these files, such as new syntax, disclaimers and plainer
comments, were also made by AI agents.

## The record

- The proposal is `docs/strategy/LE_extensions_proposal.md` of the lpsPlus
  repository (it began in the InsurLE2 repository, commit `825a246`,
  11 September 2026, "Plans for RulesRus and other systems").
- LogicalEnglish2 commits of 11 September 2026, all with the trailer
  "Co-Authored-By: Claude Opus 5 (1M context)": `8cd9db7` (§3.1,
  `judged_damage.le`), `f6dc97b` (§3.3, `otherwise_table.le`,
  `loaded_table.le`, `shipping.csv`), `0f43214` (§3.2, `precedent.le`,
  `precedent_pattern.le`), `2ebc10e` (§3.4, `sections_benefit.le`), `7a9920f`
  (§3.5, `scoped_notice.le`), `0a7bc9a` (§3.6, `semantic_match.le`,
  `semantic_llm.le`), `a0bae59` (§3.7, `flip_housing.le`), `5192cda`
  (`eu261_integration.le`).
- `7473c25` (18 September 2026, "let tables stay elsewhere too") added
  `scenario_table.le`; the commit is marked "Miguel Calejo (via Claude)".
- Every commit that touched these programs is marked "via Claude" or carries
  a Claude co-author trailer: 32 commits, none by a person alone.
- The files first lived in `examples/RulesRus/` and moved here in commit
  `49a324f` (16 September 2026).

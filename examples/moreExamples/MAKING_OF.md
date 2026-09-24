# How the examples in this folder were made

This note covers only the programs at the top of `moreExamples/`; each folder
below it has its own note where one is needed. Most of these programs are
small teaching programs committed by Miguel Calejo. One program,
`royal_family.le`, was written by an AI agent, and says so in its opening
comment. `citizenship.le` comes from the first Logical English (LE1).

| File | Made by | How |
|---|---|---|
| `royal_family.le` | AI agent (Claude, through the Logical English 2 (LE2) MCP server), 2026-04-28, at Miguel Calejo's request | Claude looked up the facts itself and wrote the rules and tests. Miguel Calejo's prompts are quoted in the file's opening comment. The commit calls it "synthetic". |
| `citizenship.le` | People: the authors of LE1 | The classic British Nationality Act program, carried over from LE1 and brought to LE2 syntax. |
| `alice.le`, `dates.le`, `happy_dragon.le`, `numbers.le`, `tea_party.le` | Committed by Miguel Calejo (2026-05-27 to 2026-06-12) | The record does not say whether a person or an agent typed them. They are short, have no commentary, and were committed with the feature each one tests. |
| `README.md` | AI agent (Claude, in Claude Code), 2026-09-16 | Written when the example trees were regrouped. |

Later changes by agents to these files were small: fixes of a few lines each,
when the language changed.

## The record
- commit `e59a179` (2026-04-01) "Add LE working examples": `citizenship.le`, among the LE1 programs.
- commit `accb541` (2026-04-28) "Add one (synthetic) example".
- commit `49a324f` (2026-09-16) "Examples cleanup, step 3": the README, co-authored by Claude Opus 5.
- Commits written through Claude Code carry the author name "Miguel Calejo (via Claude)" from 2026-07-15. Before that date, the commits carry only "Miguel Calejo". An `AGENTS.md` file for coding agents has been in the repository since 2026-04-25, so a commit without the tag may still contain agent-written text.

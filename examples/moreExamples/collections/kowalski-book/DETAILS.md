# Kowalski's book in Logical English: details

Which example of Robert Kowalski's *Computational Logic and Human Thinking*
(Cambridge University Press, 2011) each program renders. The programs were
drafted from the examples that
[bookExamples.md](https://github.com/LogicalContracts/LogicalEnglish2/blob/main/docs/project/research/rk-book/bookExamples.md)
judged to fit current Logical English. Each program's opening comment gives
its chapter and section.

All programs pass their embedded tests (`expects answers`). One program,
`grass_wet_abduction.le`, carries two `rule_without_variables` warnings: the
book's grass-is-wet beliefs have no variables.

## Checking a program again

From the repository root:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/moreExamples/collections/kowalski-book/<FILE>.le', R), print_test_result(R), halt."
```

## Coverage map

| File | Origin (chapter / section, example) |
|------|--------------------------------------|
| `underground_emergency.le` | Ch.1 §1.2 & §1.4 — disambiguated 2nd/3rd Emergency-Notice sentences + forward reasoning |
| `fox_and_crow.le` | Ch.3 §3.1 — the fox's goal and beliefs (also covers the §3.3 backward-reasoning step) |
| `above_transitivity.le` | Ch.3 §3.5 — beginning-of-story atomic facts + the `above` transitivity rule |
| `party_looping.le` | Ch.4 §4.1 — the party-looping example (also the §5.3 mutually-recursive loop) |
| `last_train.le` | Ch.5 §5.2 — the last-train conditional (weekday + date range) |
| `party_naf.le` | Ch.5 §5.3 — party example with negation-as-failure and its defeat |
| `older_brother.le` | Ch.5 §5.5 — Moore's older-brother selective closed-world assumption |
| `innocent_until_guilty.le` | Ch.5 §5.6 — innocent-unless-proven-guilty default reasoning |
| `library_study.le` | Ch.5 §5.7 — precise suppression-task rule with the `prevented` exceptions (also the §5.7 naive form) |
| `housing_benefit.le` | Ch.5 §5.7 — Housing Benefit rule and `ineligible` exception |
| `thieves_punishment.le` | Ch.5 §5.8 — decompiled layered rules-and-exceptions + Bob/Mary trace (also the §5.8 compiled form) |
| `bna_citizenship_1_1.le` | Ch.6 §6.2 Ex.4 — informal CL of BNA 1981 subsection 1.1 (also Ex.1) |
| `relative_clauses.le` | Ch.6 §6.2 Ex.2 & Ex.3 — restrictive/non-restrictive relative clauses as conditionals |
| `naturalisation_schedule1.le` | Ch.6 §6.6 Ex.17 — Schedule 1 naturalisation requirements |
| `lease_termination.le` | Ch.6 §6.7 Ex.20 & Ex.21 — disambiguated University of Michigan lease-termination clause |
| `genesis_ancestors.le` | Ch.7 §7.9 Ex.14 — Genesis facts + a declarative rendering of the ancestor relation |
| `equation_solving_goal.le` | Ch.7 §7.8 Ex.13 — explicit-goal conditional for equation solving (abstract goal) |
| `grass_wet_abduction.le` | Ch.10 §10.2 — the wet-grass abduction (open/assumable predicates → unknowns) |
| `cause_and_effect.le` | Ch.11 §11.4 Ex.7 — general cause-and-effect pattern |
| `trolley_problem.le` | Ch.12 §12.2 Ex.1 & Ex.2 — beliefs for the trolley problem + the current situation |
| `behaviourist_fox.le` | Ch.14 §14.1 — fox-and-crow as input-output (behaviourist) rules |
| `amazing_animals.le` | Appendix A1 §A1.4 — `amazing if can-fly` with `is-a` taxonomy |

## "Fits current LE" entries deliberately folded or not given their own file

A few "Fits current LE" entries in `bookExamples.md` are abstract schemas, pure
fact lists, or verbatim duplicates of rules already covered above. They are
folded into the files noted, or omitted because they carry no runnable content of
their own:

- **§1.3 "Coherence patterns linking sentences"** — an abstract `A→B→C` schema with
  no concrete data; the chaining it illustrates is exercised by `underground_emergency.le`.
- **§2.7 "Significance depends on the reader's beliefs"** (Susan's rucksack) — two
  bare facts illustrating context-dependence; no rules, so no standalone program.
- **§3.3 backward-reasoning step** and **§4.1 interdependent subgoals** — single
  inference steps over the fox rules already in `fox_and_crow.le`.
- **§5.3 naf inference template** — a schematic procedural reading, realised
  concretely by `party_naf.le` / `library_study.le` / `housing_benefit.le`.
- **§14.9 object-oriented grouping of sentences** — the same atomic facts regrouped
  for readability; a documentation device, not a distinct program.

# Abduction in Logical English

Working LE renderings of the abductive-reasoning examples from Kowalski &
Calejo, *Teaching Logical Thinking through Logic Programming using Logical
English, Argumentation Games and Animation* (PEG Lisbon 2026), plus a more
more complex examples of our own.

Logical English has **unknowns**:
a template declared `; assumable` (synonym: `; unknown`) is an open/abducible
predicate. When proving a goal, the reasoner may ASSUME an instance of an open
predicate, returning it in the answer's unknowns list. Each answer plus its
unknowns is one abductive explanation — equivalently a *conditional answer*
(slide 26): "the grass is wet IF it rained". In the editor, assumed conditions
show as yellow (unknown) nodes in the explanation tree. It also has
**integrity constraints** (`it must not be true that …`, docs/user/reference/language.md
§3.3), which reject the answers whose assumptions break them.

| File | Origin | What it shows |
|------|--------|---------------|
| `grass_is_wet.le` | slide 24 | Explaining an observation: two alternative explanations of "the grass is wet" — assuming "it rained", or assuming "the sprinkler was on". |
| `sunglasses.le` | slide 25 | Generating a plan: "alice likes you" is achieved by assuming the action "you wears sunglasses". |
| `diagnosis.le` | own example, after slides 24–26 & 28 | Differential diagnosis: a conjunctive observation (fever and rash), several candidate diseases, a single-cause explanation ({measles}) competing with multi-cause ones, and constraint-style elimination of candidates. |
| `loan_approval.le` | own example | Several alternative models (sets of assumptions) for one decision, richer than grass_is_wet and sunglasses. |

## Integrity constraints, and guards (slide 28)

Slide 28 eliminates the sprinkler explanation with the passive integrity
constraint "it is not the case that the sprinkler was on if the sprinkler is
broken". LE can now say that directly:

    it must not be true that
        the sprinkler was on
        and the sprinkler is broken.

(see docs/user/reference/language.md §3.3, and `../assumption_constraints.le`). These
examples predate constraints and obtain the same effect another way, which is
still useful: guarding the rules that USE an assumable with negation as
failure over **closed** (scenario) predicates —
`diagnosis.le` blames measles only when

    it is not the case that the person is immune to measles

and immunity is derived from the closed fact "bob is vaccinated against
measles". Adding that one fact (the `vaccinated` scenario) kills every
explanation that assumes measles, leaving only {flu, food allergy}.

Caveat: the guard must test a closed predicate. Negation as failure attacks
assumptions too — an assumable goal counts as (possibly) true, so a guard like
"it is not the case that the person has measles" over the *assumable* predicate
itself would never succeed.

## Re-verifying

From the repo root:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/moreExamples/language/abduction/<FILE>.le', R), print_test_result(R), halt."
```

All four files pass their embedded `expects answers [...] and unknowns [...]`
tests (and are included in the `runTests` suite, which scans this directory).
`grass_is_wet.le` carries two inherent `rule_without_variables` warnings: the
slide's beliefs are genuinely propositional.

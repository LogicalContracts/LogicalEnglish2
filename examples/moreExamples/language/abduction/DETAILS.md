# Abduction in Logical English: details

How the four programs get the effect of integrity constraints, and how to
check them again. See [the folder's guide](README.md) for what each program shows.

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

# Memoization: `; memorable` templates

A template marked `; memorable` has the calls on it cached during a query
(docs/user/reference/language.md §2.4): the first call of each distinct
call — distinct up to the renaming of variables — computes every answer with
its explanation, and every later variant of that call in the same query
replays them. The answers and the explanations are the same as without the
marker; only the repeated proving is saved.

- `lattice_paths.le` — a count defined by two smaller counts, the same
  corner reached along many routes: several times faster with the marker.
- `family_relatives.le` — the ancestors of a person, asked by several rules
  and, in a query about everybody, many times over.
- `memorable_warnings.le` — the two warnings: a memorable call under a
  negation (`memorable_under_negation`) and a memorable predicate whose rule
  runs an embedded `prolog` goal (`memorable_calls_prolog`).

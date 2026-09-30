# Memoization: `; memorable` templates

A template marked `; memorable` has the calls on it cached during a query
(docs/user/reference/language.md §2.4): the first call of each distinct
call — distinct up to the renaming of variables — computes every answer with
its explanation, and every later variant of that call in the same query
replays them. The answers and the explanations are the same as without the
marker — except in a recursion through a value not yet known, where the
marker finds answers the plain rule cannot (`instalments.le`); otherwise
only the repeated proving is saved.

- `lattice_paths.le` — a count defined by two smaller counts, the same
  corner reached along many routes: several times faster with the marker.
- `family_relatives.le` — the ancestors of a person, asked by several rules
  and, in a query about everybody, many times over.
- `instalments.le` — a recursion through a value not yet known: the days
  an obligation starts on, each asked about an earlier, unknown day. The
  marker finds every day (the rounds of §2.4); without it only the days
  that follow the first.
- `memorable_warnings.le` — the two warnings: a memorable call under a
  negation (`memorable_under_negation`) and a memorable predicate whose rule
  runs an embedded `prolog` goal (`memorable_calls_prolog`).

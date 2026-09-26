# Unknowns (assumable conditions) and constraints

- `unknowns.le` — a template declared `; unknown`: answers that assume it; an
  expectation with `and any unknowns` checks the answers only (§12).
- `unknowns_in_aggregates.le` — assumptions inside a sum or count.
- `unknowns_in_forall.le` — assumptions inside "for all cases in which".
- `assumption_constraints.le` — integrity constraints on what is assumed
  (`it must not be true that …`, §3.3).

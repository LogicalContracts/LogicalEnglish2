Write the COMPLETE Logical English program for the computable twin, following
the agreed vocabulary and the architecture sketch exactly (fill in the
skeletons; add missing leaf templates if strictly needed).

The program must contain, in order:

1. a header comment: what the twin decides, and a "Known simplifications" list;
2. `the target language is: prolog.`
3. `the templates are:` — the vocabulary (with epistemic markers);
4. `the contract states that:` — decision rules and exception rules,
   each rule preceded by a `%` comment citing its clause;
5. `the annexes to the contract are:` — derived notions, date/geography
   helpers, limit machinery;
6. the schedule as facts (from the SCHEDULE material) — but only the
   parameters EVERY case shares; where the cases name different schedules,
   each scenario carries its own (see the house style);
7. the scenarios permitted by the SCENARIOS section below — one per case,
   facts only from case-datum templates plus that case's own schedule
   parameters, with embedded expectations
   (`<queryname> expects answers [...]` — remember: no leading `query` keyword
   on expectation lines);
8. the queries (`query <name> is:` sections) used by the expectations —
   queries use plain `which` variables (`we will pay which amount for which
   claim.`), NEVER asterisks; asterisks appear only inside
   `the templates are:`.

For expected-answer strings, render numbers without thousands separators
(write `expects answers ["we will pay 18500 for claim one"]`).

**Cover the whole of the wording you were given.** The twin is judged against
a clause-by-clause coverage ledger, and a program that encodes one coverage
section of a policy that has five is a failure however cleanly it verifies.
Work through the material in order: the definitions that gate the peril, every
coverage part and its sub-limits, the property-not-insured list, every
exclusion, the conditions, and the loss-settlement rules. A clause you
deliberately leave out belongs in the "Known simplifications" header comment,
named — silence there reads as an oversight.

Output exactly one fenced code block containing the full program and nothing
else.
{{existing}}
{{scenarios}}
{{instructions}}

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
6. the schedule as facts (from the SCHEDULE material);
7. one `scenario <name> is:` per case, with facts only from case-datum
   templates and embedded expectations (`<queryname> expects answers [...]` —
   remember: no leading `query` keyword on expectation lines);
   plus at least one adversarial variant scenario per major exception;
8. the queries (`query <name> is:` sections) used by the expectations —
   queries use plain `which` variables (`we will pay which amount for which
   claim.`), NEVER asterisks; asterisks appear only inside
   `the templates are:`.

For expected-answer strings, render numbers without thousands separators
(write `expects answers ["we will pay 18500 for claim one"]`).

Output exactly one fenced code block containing the full program and nothing
else.
{{existing}}

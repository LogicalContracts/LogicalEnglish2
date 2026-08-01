The Logical English program below is CORRECT: it loads without errors and all
its scenario expectations pass. Do not change what it decides.

The verifier still reports the warnings listed under FEEDBACK. Most of them are
mechanical. Fix as many as you safely can, in this order of preference:

1. **Unused template** — delete the template. It is dead vocabulary: nothing in
   the program refers to it. Only keep one if a rule, fact, scenario or query
   actually uses it (in which case fixing that use is the real repair).
2. **Untested predicate** — the rule is never reachable from a query. Prefer
   connecting it to the decision surface: if the predicate is a genuine part of
   the decision, make the top-level rules consult it; if it is a leftover, delete
   it and its templates. Do NOT add a scenario to make a warning go away.
3. **Single-variable fact / rule without variables** — an indefinite article
   turned a constant into a variable; use the constant.
4. **Suspicious `is a` / missing template drift** — the sentence and its
   template drifted apart; align them.
5. **Undefined predicate** — a rule asks about something no rule or fact
   establishes. If the contract makes it a case datum, mark its template
   `; undefined` and stop there. NEVER write a rule to define it away, least of
   all one whose only condition is its own head — such rules are deleted
   automatically before you see the program, and writing them wastes the round.
6. Anything else you can fix without changing behaviour.

A note on what reaches you: tautological rules, duplicated rules and the
comments introducing them have already been removed mechanically, and templates
that were only ever asked about have already been marked `; undefined`. What is
left needs judgement — spend the round on that, not on re-doing the mechanical
part.

Hard rules:

- The scenarios, their facts and their `expects answers` lines stay EXACTLY as
  they are. Every test that passes now must still pass.
- Do not add scenarios, queries or rules that the contract does not require.
- If a warning cannot be fixed without changing a decision, LEAVE IT and add a
  `% Known simplification:` comment saying why.

Preferred output — targeted edits, one block per change, with the SEARCH text
copied EXACTLY (including whitespace and indentation) from the program:

<<<<<<< SEARCH
<exact existing text, a few lines>
=======
<replacement text>
>>>>>>> REPLACE

Use several blocks for several changes, and repeat all three markers —
`<<<<<<< SEARCH`, `=======`, `>>>>>>> REPLACE` — in EVERY block: a block that
reuses the previous header is dropped. Only if the changes are so extensive
that edits would be unreadable, output instead ONE fenced code block with the
FULL corrected program — complete from first line to last, never eliding
sections with `% ...` placeholders (an elided program is rejected).
{{existing}}
{{instructions}}

The Logical English program below was verified by the LE engine; the verifier
issues and failing tests are listed under FEEDBACK. Repair the program.

Rules of repair:

- Fix the CAUSE, not the symptom: a `missing_template` usually means the rule
  sentence and the template drifted apart — align them (or add the template);
  a failing expectation may mean the expected string, the rule, or the
  scenario facts are wrong — check against the contract quotation in the
  nearby `%` comment before choosing which to change.
- `reserved_word_in_template` errors: reword the template to avoid the
  reserved word entirely.
- `single_variable_fact` warnings: replace the accidental variable with a
  constant (proper name, or drop the indefinite article).
- `unconsumed_facts` warnings are the most serious warning here, and deleting
  the facts is almost never the fix. The program STATES something — a limit, an
  excess, a deductible, an exclusion, a notification deadline — and no rule
  condition and no query ever reads it, so it changes no answer. A payment limit
  of 150 per person per day sitting in a scenario while the payment rules cap
  nothing is the exact bug this catches, and every test still passes because
  nothing was ever going to read it. Go back to the contract wording, find the
  rule the datum is supposed to constrain, and add the condition to that rule.
  Only if the wording genuinely gives the datum no work to do may you delete it
  — and then say so in a `% Known simplification:` comment. Facts inside
  user-supplied scenarios and existing code must not be deleted at all.
- Expected-answer strings must match the engine's rendering exactly — when a
  test failure shows an `actual` answer that is correct in substance, update
  the expectation to that exact string.
- Scenarios marked as interrogation probes carry expectations derived from an
  independent reading of the contract; they MAY be wrong. Adjudicate: if the
  contract quotation supports the probe, fix the rules; if it does not, fix
  the probe's expectation — and say which in a `%` comment.
- Do not delete scenarios, expectations or exception rules to make problems
  disappear; simplify only with a `% Known simplification:` comment.
- If a section below carries EXISTING LOGICAL ENGLISH CODE supplied by the
  user, its templates, facts, rules, scenarios and expectations are binding:
  never delete or reword them to make a failure go away — repair the rest of
  the program until they hold.

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
sections with `% ...` placeholders (an elided program is rejected and wastes
the iteration).

**Once the program is close to loading (a handful of errors or fewer), a whole
new program is not an option.** It is re-verified before it is accepted and
kept only if it comes out strictly better than the one below; otherwise it is
thrown away and the round is wasted. At that stage everything in the program
already works except the few things FEEDBACK names — rewriting it discards
every rule that verifies and every scenario that passes, to fix three lines.
Send edits.
{{existing}}
{{scenarios}}
{{instructions}}

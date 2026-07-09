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
- Expected-answer strings must match the engine's rendering exactly — when a
  test failure shows an `actual` answer that is correct in substance, update
  the expectation to that exact string.
- Scenarios marked as interrogation probes carry expectations derived from an
  independent reading of the contract; they MAY be wrong. Adjudicate: if the
  contract quotation supports the probe, fix the rules; if it does not, fix
  the probe's expectation — and say which in a `%` comment.
- Do not delete scenarios, expectations or exception rules to make problems
  disappear; simplify only with a `% Known simplification:` comment.

Preferred output — targeted edits, one block per change, with the SEARCH text
copied EXACTLY (including whitespace and indentation) from the program:

<<<<<<< SEARCH
<exact existing text, a few lines>
=======
<replacement text>
>>>>>>> REPLACE

Use several blocks for several changes. Only if the changes are so extensive
that edits would be unreadable, output instead ONE fenced code block with the
FULL corrected program.

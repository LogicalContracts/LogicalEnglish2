The {{kind}} block below was appended to the user's program and the whole thing
was verified by the LE engine. FEEDBACK lists ONLY what YOUR block introduced —
the program's own pre-existing issues have been subtracted, and the line numbers
are lines of your block. Repair the block.

The program is still fixed: your reply changes the block and nothing else.

Rules of repair:

- `unknown_template` is the important one. It means the sentence matches NO
  declared template, so it states nothing and the reasoner never reads it —
  which is why it is an error rather than a warning even though the program
  loads. Rewrite the sentence as an instance of a template the program declares.
  If none fits, DELETE the sentence: the fact that it could not be expressed
  belongs in the coverage comment, not in a template you invent.
- `forbidden_section` / `missing_block` / `too_many_blocks`: your reply must be
  exactly one `{{kind}} <name> is:` section. Nothing else — no templates, no
  rules, no second block.
- `single_variable_fact`: an article turned an individual into a universal.
  Replace it with a named constant, or with `the ...` if the individual has
  already been introduced in this scenario.
- `regression`: your block broke a test that passes in the user's program. That
  is never acceptable and never a reason to change the program. It almost always
  means a line escaped your section — check the indentation and that you opened
  no second section.
- `unconsumed_facts`: you stated something no rule and no query ever reads. Either
  it belongs to a template the rules do read (you picked the wrong one), or the
  text's detail genuinely has no counterpart in this program — in which case drop
  it and record it as a limitation.
- A failing expectation: check the expected string against what the engine
  actually rendered. If your expectation asserts an outcome the text does not
  state, remove it rather than bending the string.

{{expectations}}

Preferred output — targeted edits, one block per change, with the SEARCH text
copied EXACTLY (including whitespace and indentation) from the block:

<<<<<<< SEARCH
<exact existing text, a few lines>
=======
<replacement text>
>>>>>>> REPLACE

Repeat all three markers — `<<<<<<< SEARCH`, `=======`, `>>>>>>> REPLACE` — in
EVERY block. Since the block is short, you may instead output ONE fenced code
block containing the whole corrected section, complete from its header line to
its last statement, never eliding anything.
{{instructions}}

Your residue translations were spliced into the skeleton and the whole program
was verified by the LE engine and run against its scenarios — which are the
source system's own tests. FEEDBACK lists what is still wrong. An item that begins
`residue <id>` belongs to that residue's block; other line numbers are lines
of THE PROGRAM AS SPLICED (given below — shortened, when it is long, to what
concerns the residues listed).

The residue ids are:

{{ids}}

Your current blocks:

{{current}}

FEEDBACK:

{{feedback}}

Reply with a fenced block for EACH residue you change, in the same form
(```le residue <id>```), holding its complete new text. A block you do not send
keeps its current text. Never change the skeleton — you cannot; the fix is
always in a residue block (or in the `templates` block).

- `regression`: a scenario that passed with the residue untranslated fails
  with your translation — your rules conclude something they should not.
- `residue_conclusion`: your block does not conclude the sentence the residue
  names, or concludes it for everything (its constant replaced by `a ...`).
  Keep the constant; if the text gives nothing checkable, keep the skeleton's
  own line.
- `residue_open`: the block still holds only the skeleton's placeholder (or
  nothing): translate the text, or keep the placeholder with a comment saying
  why the text gives nothing checkable.
- `residue_restates`: the block only repeats what the rule calling it already
  checks. Write as conditions what the text adds, with new templates
  (`; unknown`) where needed.
- `unknown_template`: a sentence of yours matches no declared template.
- a failing expectation: compare the expected answer (the source system's) with
  what your rules computed, and correct the rules.
{{instructions}}

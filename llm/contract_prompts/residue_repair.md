Your residue translations were spliced into the skeleton and the whole program
was verified by the LE engine and run against its scenarios — which are the
source system's own tests. FEEDBACK lists what is still wrong. Line numbers are
lines of THE PROGRAM AS SPLICED (given below), so you can see where each
problem is.

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
- `unknown_template`: a sentence of yours matches no declared template.
- a failing expectation: compare the expected answer (the source system's) with
  what your rules computed, and correct the rules.
{{instructions}}

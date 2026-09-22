# Embedded Prolog goals

- `prolog_call.le` — a body condition `prolog <goal>` calls Prolog directly,
  with LE variables written inside the goal as `the <name>` phrases, `*a name*`
  markers or ALL-CAPS ids (docs/user/reference/language.md §15.6); here the
  goals read the system predicates of §13 (`le_my_kb/1`, `le_my_id/1`).

See also `../includes/prolog_resources/` (a Prolog facts file behind a thin LE
layer of `prolog` bodies, §14.1) and `../rules/rule_id_test.le`.

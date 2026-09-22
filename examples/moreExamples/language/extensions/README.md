# Extension constructs (need le_extensions.pl)

Programs using the constructs of docs/user/reference/extensions.md that the proprietary
`le_extensions.pl` implements; they run where it is installed (the hosted
service), and are left out of the core test suite.

- `numbering_test.le` — numbered rule bodies (§15.5).

Embedded `prolog` goals (§15.6) are core LE: see `../prolog/prolog_call.le`.

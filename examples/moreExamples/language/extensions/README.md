# Extension constructs (need le_extensions.pl)

Programs using the constructs of docs/user/reference/language.md §15 that the proprietary
`le_extensions.pl` implements; they run where it is installed (the hosted
service), and are left out of the core test suite.

- `numbering_test.le` — numbered rule bodies (§15.5).
- `prolog_call.le` — embedded `prolog` goals (§15.6).

# Logical English for LPS: `the target language is: lps.`

*Kind: reference · Audience: users · Status: current (2026-09-20)*

A Logical English document that declares `the target language is: lps.` is a
program for **LPS** (Logic Production Systems): besides timeless rules it
speaks of **events and actions** that happen over time, **fluents** that hold
between them, and **reactive rules** (`if … then …`, `when … then …`) that
make the program act. The editor verifies such a document like any other; to
run it, use **Run in LPS** (it needs an LPS2 server), or open it in the LPS2
IDE.

Four built-in templates exist only for this target, and only for a program
that will be **deployed as a contract**: `the gas of *an action* is *a
number*`, `the code size of the contract is *a number*`, `the call data of
*an action* is *a number* bytes` — budgets, checked against a measurement of
the contract when it is exported — and `the largest whole number is *a
number*`, which is how a program says the ceiling its target's arithmetic
has. They are written as conditions of an ordinary `it must not be true
that` sentence; LPS2's `docs/user/reference/le-for-lps.md` §3.10 is the
reference.

The language is documented, construct by construct, in LPS2's
`docs/user/reference/le-for-lps.md` (served by an LPS2 server at
`/docs/user/reference/le-for-lps`), and its programs are LPS2's
`examples/le/`. How LE2 and LPS2 exchange a translated program is LPS2's
`docs/dev/le-lps-interface.md`.

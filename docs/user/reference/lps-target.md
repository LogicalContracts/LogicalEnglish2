# Logical English for LPS: `the target language is: lps.`

*Kind: reference · Audience: users · Status: current (2026-09-20)*

A Logical English (LE) document that declares `the target language is: lps.`
is a program for **LPS** (Logic Production System). An LPS program has the
timeless rules that every Logical English program has, and it also speaks of
what happens over time. An LPS program speaks of **events and actions**, the
things that happen. It speaks of **fluents**, the facts that hold from one
event until the next one changes them. And it speaks of **reactive rules**
(`if … then …`, `when … then …`), the sentences that make the program act.
The editor checks such a document for mistakes exactly as it checks any
other. To run the program, use **Run in LPS**, which needs an LPS2 server;
alternatively, open the program in the LPS2 IDE (Integrated Development
Environment), the editor in which LPS programs are written and run.

Four built-in templates exist only for LPS programs, and only for a program
that will be **deployed as a contract**. Three of the four set budgets: `the gas of *an action* is *a
number*`, `the code size of the contract is *a number*` and `the call data of
*an action* is *a number* bytes`. When the program is exported, each budget is
checked against a measurement of the contract. The fourth template, `the largest whole number is *a
number*`, is how a program states the highest number the target language can
count to. All four templates are written as conditions of an ordinary `it must not be true
that` sentence. LPS2's `docs/user/reference/le-for-lps.md` §3.10 is the
reference for the four.

LPS2's `docs/user/reference/le-for-lps.md` documents the language one
construct at a time, and an LPS2 server serves that document at
`/docs/user/reference/le-for-lps`. The example programs are in LPS2's
`examples/le/`. LPS2's `docs/dev/le-lps-interface.md` explains how LE2 and
LPS2 hand a translated program to each other.

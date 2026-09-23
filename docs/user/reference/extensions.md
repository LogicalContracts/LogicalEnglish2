# Logical English Extensions

*Kind: reference · Audience: users, developers, the assistants (read whole by the LLM features where the extensions are loaded) · Status: current (2026-09-16)*

The constructs on this page work only where the proprietary
`le_extensions.pl` module is installed, and that is the hosted Logical
English (LE) service. A server without the module — a fresh copy of this
code as published — cannot even read a program that uses one of these
constructs, so the program fails before it runs. The module is installed as
a symbolic link, a stand-in file that points at the real one, next to the
LE2 sources (see the InsurLE2 README).

The section numbers carry on from the language reference
([language.md](language.md) §15). That reference describes three things as
part of core Logical English, which every server understands: §15.1 (`only
if` rules), the rule labels and provenance of §15.5, and embedded `prolog`
goals (§15.6). Any section mentioned here but not found on this page (§2.1,
§4, §13, …) belongs to the language reference.

## Contents
- [15.2 `which` relative clauses](#152-which-relative-clauses-requires-le_extensionspl)
- [15.3 `unless` inside rule bodies](#153-unless-inside-rule-bodies-requires-le_extensionspl)
- [15.4 Grouped alternatives](#154-grouped-alternatives-either--any-of--at-least-one-of--all-of-requires-le_extensionspl)
- [15.5 Numbered rule bodies](#155-numbered-rule-bodies-requires-le_extensionspl)
- [15.6 Embedded Prolog goals](#156-embedded-prolog-goals-core-le) — core LE, see language.md
- [15.7 Prepositional chaining](#157-prepositional-chaining-requires-le_extensionspl)

### 15.2 `which` relative clauses **[requires le_extensions.pl]**
`which` continues a condition with a further clause about the **last
variable** of the condition just before it, so the writer does not have to
name that variable a second time:
```le
a person is an ancestor of a descendant if
    the person is a parent of a child
    which is an ancestor of the descendant.
```
(Here `which` stands for `the child`.) In **rule heads and facts** ("big
conclusions"), the head keeps only the words before the first `which`, and
each `which` clause becomes one more condition of the rule:
```le
we will cover a cost
    which is in respect of a damage
    which is caused by a burst pipe
if it is not the case that
    the damage is caused by wear and tear or negligence.
```
is read as the conclusion `we will cover a cost` together with the two
`which` clauses as extra conditions. A fact that stands on its own and has
`which` clauses becomes a rule in the same way.

### 15.3 `unless` inside rule bodies **[requires le_extensions.pl]**
Core Logical English has two forms: `Head if Body unless Condition.` (§4) and
`Head unless Body.`, which says the same as `Head if it is not the case that Body`.
The extension also allows `unless` (or `and unless`) **inside** a body,
either on the same line as the condition it denies or standing at the head of
an indented block. Either way, the `unless` says the same as
`and it is not the case that <the negated conditions>`:
```le
we will pay a claim if
    the claim is covered
    and unless
        the claim is fraudulent
        and the fraud is proven.
```

### 15.4 Grouped alternatives: `either:` / `any of:` / `at least one of:` / `all of:` **[requires le_extensions.pl]**
A body line that holds one of these connecting words groups the lines
indented beneath it. `either`, `any of` and `at least one of` join those
lines with *or*, so one of the lines is enough. `all of` joins them with
*and*, so every line must hold, which is useful inside an `or` block. Each
line directly beneath the connecting word is one alternative and may have a
shape of its own, so an `all of` written inside an `either` still asks for
all of its own lines:
```le
the claimant is eligible for a pension if
    either
        the claimant is poor
        all of
            the claimant is sick
            the claimant has been sick for more than 6 months
            it is not the case that
                the claimant has another form of income
        the claimant has been entitled to a pension previously.
```
In a numbered body (§15.5) an item may deny something — `1.2.3. it is not the
case that the claimant has another form of income; or`. The denied condition
may sit on the item's own line, as it does there, or in the items numbered
beneath it (`1.2.3. it is not the case
that:` followed by `1.2.3.1. ...`).

### 15.5 Numbered rule bodies **[requires le_extensions.pl]**
A rule may carry a label, written `rule <name>: Head if ...`, and it may also
carry `with provenance`, which records where the rule came from. Both the
label and the provenance are core Logical English, described in
[language.md §15.5](language.md#155-rule-labels-and-provenance).

With the extension installed, a rule body introduced by `if:` may be written
as a numbered outline that follows the numbering of a statute or a contract
clause:
```le
rule jd:
an A has a relevant asset a B if:
1. the A is affiliated with a C; and
2. the C is connected to a D; and
3. the D owns the B; and
4. either:
4.1. the B is used in the business of the A; or
4.2. all of:
4.2.1. the A is connected to an E; and
4.2.2. the B is used in the business of the E.
```
Each numbered condition can be fetched by its number through
`le_source_element(RuleID, Designator, Goal)`; goal 4.2.1 of rule `jd`, for
example. Fetching a condition by its number is what lets a reader trace each
clause back to the words of the statute or contract it came from. See
`examples/moreExamples/language/extensions/numbering_test.le`.

### 15.6 Embedded Prolog goals **[core LE]**
`prolog <goal>` conditions in a rule body are part of core Logical English
and no longer need the extensions module: see [language.md](language.md)
§15.6, and §14.1 for Prolog resources. Inside a numbered rule body (§15.5) a
`prolog` item is read in the same way.

### 15.7 Prepositional chaining **[requires le_extensions.pl]**
§2.1 describes the `; prepositional` template marker and the chained way of
using it. The chaining itself — leaving out the first argument, so that one
sentence stands for several conditions joined by *and* — is worked out by the
extensions module.

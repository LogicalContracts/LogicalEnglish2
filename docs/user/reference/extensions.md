# Logical English Extensions

*Kind: reference · Audience: users, developers, the assistants (read whole by the LLM features where the extensions are loaded) · Status: current (2026-09-16)*

The constructs on this page are available where the proprietary
`le_extensions.pl` module is installed — the hosted Logical English service.
On a server without it (a clean checkout of this repository) programs using
them do not parse. The module is installed as a symlink next to the LE2
sources (see the InsurLE2 README).

The section numbers continue those of the language reference
([language.md](language.md) §15), where §15.1 (`only if` rules) and the
labels and provenance of §15.5 are documented as core LE. References to
sections not on this page (§2.1, §4, §13, …) are to that document.

## Contents
- [15.2 `which` relative clauses](#152-which-relative-clauses-requires-le_extensionspl)
- [15.3 `unless` inside rule bodies](#153-unless-inside-rule-bodies-requires-le_extensionspl)
- [15.4 Grouped alternatives](#154-grouped-alternatives-either--any-of--at-least-one-of--all-of-requires-le_extensionspl)
- [15.5 Numbered rule bodies](#155-numbered-rule-bodies-requires-le_extensionspl)
- [15.6 Embedded Prolog goals](#156-embedded-prolog-goals-resolution-requires-le_extensionspl)
- [15.7 Prepositional chaining](#157-prepositional-chaining-requires-le_extensionspl)

### 15.2 `which` relative clauses **[requires le_extensions.pl]**
`which` continues a condition with a subordinate clause about the **last
variable** of the preceding condition, avoiding a re-named repetition:
```le
a person is an ancestor of a descendant if
    the person is a parent of a child
    which is an ancestor of the descendant.
```
(`which` = `the child`.) In **rule heads and facts** ("big conclusions"), the
head keeps only the part before the first `which`; each `which` clause becomes
a body condition:
```le
we will cover a cost
    which is in respect of a damage
    which is caused by a burst pipe
if it is not the case that
    the damage is caused by wear and tear or negligence.
```
parses as head `we will cover a cost` with the two `which` clauses as extra
conditions. A standalone fact with `which` clauses becomes a rule the same
way.

### 15.3 `unless` inside rule bodies **[requires le_extensions.pl]**
The core forms are `Head if Body unless Condition.` (§4) and
`Head unless Body.` (≡ `Head if it is not the case that Body`). The extension
also allows `unless` (or `and unless`) **within** a body, either inline or
governing an indented block — equivalent to
`and it is not the case that <the negated conditions>`:
```le
we will pay a claim if
    the claim is covered
    and unless
        the claim is fraudulent
        and the fraud is proven.
```

### 15.4 Grouped alternatives: `either:` / `any of:` / `at least one of:` / `all of:` **[requires le_extensions.pl]**
A body line consisting of one of these connectives groups its indented
children: `either`, `any of` and `at least one of` OR the children together;
`all of` groups them conjunctively (useful inside an `or` block). Each direct
child is one alternative with its own structure, so an `all of` nested in an
`either` stays a conjunction:
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
In a numbered body (§15.5) an item may be a negation — `1.2.3. it is not the
case that the claimant has another form of income; or` — with the negated
goal on the item's line or as its sub-items (`1.2.3. it is not the case
that:` / `1.2.3.1. ...`).

### 15.5 Numbered rule bodies **[requires le_extensions.pl]**
A rule may be labelled (`rule <name>: Head if ...`, with an optional
`with provenance`: [language.md §15.5](language.md#155-rule-labels-and-provenance),
core LE).

With the extension, a rule body introduced by `if:` may be written as a
numbered outline mirroring a statute or contract clause:
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
Each numbered condition is addressable by its hierarchical designator through
`le_source_element(RuleID, Designator, Goal)` — e.g. goal 4.2.1 of rule `jd` —
which supports clause-level traceability to the source text. See
`examples/moreExamples/language/extensions/numbering_test.le`.

### 15.6 Embedded Prolog goals **[resolution requires le_extensions.pl]**
A body condition of the form `prolog <goal>` (parenthesise conjunctions:
`prolog (g1, g2)`) calls raw Prolog. LE variables are referenced inside the
goal as `the <name>` phrases, `*a name*` markers, or ALL-CAPS ids, and are
bound to the goal's results; the system predicates of §13 are commonly used:
```le
an id has designator a d if
    prolog (le_my_kb(KB), KB:le_source_element(the id, the d, the g)).
```
See `examples/moreExamples/language/extensions/prolog_call.le` and `language/rules/rule_id_test.le`.

### 15.7 Prepositional chaining **[requires le_extensions.pl]**
The `; prepositional` template marker and its chained usage are described in
§2.1; note that the *chaining* itself (omitting the leading argument so one
sentence expands into a conjunction of conditions) is resolved by the
extensions module.

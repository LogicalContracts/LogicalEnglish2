# Appendix: Logical English 2 — Features Added Since the Draft

*Companion to "Logical English 2: A Reimplementation."*

Miguel Calejo (mc@logicalcontracts.com) and
Jacinto Dávila Quintero (jd@logicalcontracts.com)

*logicalcontracts.com*

## A.1 Purpose of this appendix

The body of the paper describes LE2 as it stood when the draft was
written. Development has continued at a steady pace since, and a number
of the features the paper lists as "under development", "still being
stabilised", or "deferred to future work" have since matured, while
several genuinely new capabilities have appeared that the draft does not
mention at all. This appendix records the major additions, grouped under
the same headings the paper uses — language, tooling, reasoning and
verification, and deployment — and adds one heading, *education*, for a
body of work that has grown large enough to stand on its own. Throughout,
"the paper" refers to the main draft and "since" means since that draft.

The intent is documentary rather than argumentative: the appendix should
let a reader of the paper understand what the current system does that
the paper does not describe, with pointers into the example library and
the user documentation for detail.

## A.2 Language

The paper characterises LE2's language as "if anything, slightly
narrower" than LE1's, carrying the stable core forward while deferring
LE1's more experimental constructs. Several of those deferred constructs
have since been re-introduced — in native form rather than as back-end
features — and a number of ergonomic constructs have been added that
neither LE1 nor the paper describes. The language reference in
`docs/le_summary.md` documents the current surface in full; the
highlights follow.

**Assumables (unknowns) as a native construct.** The paper notes that
s(CASP)'s abducibles were among the features dropped when LE2 narrowed to
a single Prolog back-end. Abductive reasoning has since returned as a
first-class part of the LE2 language, independent of any back-end. A
template may be marked `; unknown` (with `; assumed` and `; assumable`
accepted as synonyms) to declare it *assumable*: a matching goal that
cannot be proven is assumed true and reported as an **unknown** rather
than failing. Individual instances can be declared unknown in the
knowledge base or within a scenario with `it is unknown whether …` (again
with `it is assumed whether …` / `it is assumable whether …` variants),
and scenarios can carry `and unknowns […]` expectations alongside their
answer expectations. Unknowns are surfaced everywhere they matter:
tooltips report unproven goals, explanation nodes render unknown
conditions in amber, and the scenario tools let a fact be toggled
*unknown* with a checkbox. This restores the practical value of the
abductive style — reasoning under open-world assumptions about what is
not yet known — without the s(CASP) dependency.

**Template synonyms.** A template definition may now carry one or more
`; synonym …` additions declaring equivalent surface forms that map to
the *same* underlying predicate, so facts, rule heads, rule bodies and
queries may be written with whichever wording reads best in context
(e.g. `*a payment* is in respect of *a claim*` and `*a payment* covers
*a claim*` as two forms of one relation). Arguments are matched
positionally; explanations render each node with the form actually used
at its source location. This directly addresses a recurring friction in
legal drafting, where the same relation is referred to in several
idioms.

**Prepositional templates.** A binary template that begins with an
argument may be marked `; prepositional` so that it can *extend* a
previous condition with its leading argument elided and filled in
automatically from the preceding, type-compatible condition. This lets a
clause such as *"we will make a payment under this policy in respect of a
claim"* expand into the conjunction of a payment, that payment under the
policy, and that payment in respect of the claim — matching the way
policy and contract prose actually chains prepositional qualifiers onto a
noun. **Not available in the open-source version:** while the core grammar
recognises and validates the `; prepositional` marker, the chaining engine
that exploits it lives in the proprietary `le_extensions` module.

**Fuller query bodies.** The body of a `query … is:` section is now
parsed exactly like a rule body rather than as a single template
instance. A query may combine conditions with `and` / `or`, negation
(`it is not the case that …`), and universals (`for all cases in which …
it is the case that …`), sharing variables across conditions. Answers to
multi-condition queries are rendered from the goal with its bindings.
This removes an asymmetry the paper's language did not remark on — that
rules were more expressive than the questions one could ask of them.

**Named variables and richer typing.** Variable phrases may now carry a
*name* distinct from their *type*, so that several variables of one type
can be distinguished without inventing new nouns: a leading ordinal or
qualifier (`a first person`, `another person`) or a trailing all-caps
identifier (`a person X`, `a number N`) marks a distinct variable of the
same type. Type checking has correspondingly become stricter and more
principled: it is lazy and lenient (rejecting only on a clear conflict),
consults both scenario and knowledge-base `is_a` facts, and — notably —
uses argument types to *disambiguate rules that share a predicate but
declare different argument types*, checking types only at the argument
positions where the templates actually disagree. This makes it possible
to write several same-functor bridging rules that are kept apart by type
rather than by textual gymnastics.

**Rule sections and globals.** Rules may be grouped into named
**sections** (`section <name> is:`, with `the annexes to the contract
are:` as a shorthand), recorded as metadata that tools can use for
navigation and cross-referencing without affecting reasoning. A template
may `; defines global …` to introduce a global abbreviation, and globals
are ordered so that a global's defining sub-goal is emitted before its
uses. Rules and unknowns may also appear *inside* scenarios, not only in
the knowledge base, so a scenario can locally extend or vary the logic it
is testing.

**Smaller additions.** `only if` rules and explicit `opposite`
declarations; `is not equal to` / `is different from` comparisons; a set
of unary arithmetic functions (`ceiling`, `floor`, `round`, `truncate`,
`integer`, `abs`, `sign`, `sqrt`); acceptance of numbers written with
comma-separated thousands; support for apostrophes in names; and a more
tolerant parser for indentation, long comma-bearing templates, and line
comments. Individually minor, together these remove a long tail of
avoidable parse failures on realistic documents.

## A.3 Education: the Proof Game

The single largest addition since the paper is the **Proof Game**, an
interactive, manipulable environment that turns a query into a puzzle the
user *builds* rather than reads. The paper does not mention it. It is
documented for teachers in `docs/ProofGame.md`, with the implementation
in `le_proof_game.pl`.

Where the explanation tree (§3.3 of the paper) *presents* a completed
proof, the Proof Game asks the user to *construct* one. The query sits at
the top of a board; the rules and facts of the knowledge base appear as
movable cards; and the user draws connections from card outputs to rule
condition sockets until every condition is satisfied down to plain facts.
The system gives immediate feedback: a completed proof lights up green
and celebrates, while a **clash** (red) appears the moment two
connections would bind one variable to two different values — making
unification tactile rather than expository.

The game covers the hard parts of the language, not just the easy ones.
"For all cases" conditions present two sockets, one for the case and one
for the consequence, so a universal must be discharged by supplying both.
Negation has a dedicated **failure mode**: an *"it is not the case
that …"* condition can be discharged the quick way, by dropping a **FAIL**
card onto it, or the thorough way, by connecting the rule that *would*
prove the goal and then building out the reasons it fails, condition by
condition, until every branch bottoms out in a FAIL leaf. This lets a
learner experience directly the asymmetry between positive proof (one way
to succeed suffices) and negation as failure (every way must fail) that
the paper's justification trees can only report.

The game also covers **abduction**, building on the assumables of §A.2:
an assumable statement appears as an **Assumption card** with a dashed
amber border, which plays like a fact but is *assumed* rather than
proved — connecting it makes the assumption explicit. An answer that
holds only under assumptions is labelled with them in the "Answer to
prove" picker, so a query like *"the grass is wet"* offers *"…assuming
it rained"* and *"…assuming the sprinkler was on"* as two alternative
**explanations** of the same observation, each with its own proof to
build. A small library of abductive examples supports this
(`examples/moreExamples/abduction`: wet grass, sunglasses, and a
fault-diagnosis case, with a teacher-facing README).

Supporting affordances
include a per-predicate colour legend, a **Child Mode** that hides all
text so that only the coloured shape of a proof remains (for younger
learners or for emphasising structure over wording), a **Clone Tool** for
reusing a rule in more than one place (as failure trees frequently
require), an **Answer to prove** selector when a query has several
answers with different proofs, **Show Proof** as an answer key, and
auto-layout. Clicking a card highlights the corresponding source in the
editor, tying the puzzle back to the Logical English text.

The Proof Game runs in its own reasoning session, is exercised by the
automated test suite, and has been iterated extensively for correctness
of bindings, negation, and vacuous universals, and for usability on
touch devices. It is, in effect, LE2's answer to the pedagogical
ambitions the paper attributes to the LE research line ("teaching logic
and computational thinking to school-age learners"), realised as a
concrete tool rather than a stated goal.

A companion **LE2 tutorial** (under `docs/tutorial0`) and a growing
library of short teaching examples — including a set drawn from
R. Kowalski's book — have been added alongside the game.

## A.4 Tooling

Beyond the Proof Game, the IDE described in §3.2 of the paper has gained
several substantial tools.

**Scenario Editor.** Scenarios can now be built and edited through a
fill-in-the-blank form rather than by typing facts by hand. Each fact is
rendered from its template with the fixed words as labels and the
placeholders as editable fields, so the surrounding wording cannot be
broken and the user need not remember a template's exact phrasing. The
editor recognises each existing fact's template on load, offers only
templates that make sense as scenario facts (those declared `; undefined`
or already used in a scenario, plus plain `is a` assertions), supports an
**Assume** checkbox to write a fact back as unknown, and preserves
comments, test lines, and unrecognised lines rather than discarding them.

**Query Editor.** Queries can be built the same way. The Query Editor
renders a query as a list of fill-in-the-blank conditions, each an
instance of one of the program's templates; conditions are combined with
per-row **and/or** selectors, negated with a **not** checkbox (written
back as `it is not the case that …`), and nested by indenting rows —
reflecting LE's indentation-based and/or scoping. The result can be
copied to the clipboard or inserted into the program, replacing the
query it was loaded from or appending a new one. It deliberately does
not cover the full body-condition syntax (aggregates, deeply nested
groups); the main editor remains available for those.

**"Write it in English" — LLM-assisted input.** Both the Scenario Editor
and the Query Editor offer a *Write it in English* entry in their
add-fact / add-condition menus: the user types one or more plain-language
sentences and an LLM turns them into Logical English facts or query
conditions that use **the program's existing templates** — the model
fills templates in, normalising wording and tense, but does not invent
predicates. The proposed LE is verified against the program before it is
added, baseline-diffed so that only *new* issues count; if problems are
introduced the user is warned but may still insert (or rephrase and
regenerate). This uses the same model configuration as the LE Assistant
and gives a much narrower, safer entry point for natural-language input
than free-form program generation.

**Scenario Variations.** A closely related but distinct tool lets a user
take a scenario, *alter* it, and immediately run one or more queries
against the variation without touching the program — the "what-if"
workflow ("what if Alice were *not* a citizen?"). It reuses the Scenario
Editor's form for the facts, lets the user assemble a list of queries to
run together, and shows the familiar answers-plus-explanation view under
each, with clickable nodes that navigate back to the source. The
explanation now feeds back into the scenario: right-clicking a node lets
the user **patch the variation from the explanation itself** — deleting
the scenario fact behind a succeeded node, or adding (or assuming as
unknown) the missing fact behind a failed one — with the queries re-run
immediately, closing the what-if loop without ever leaving the
explanation. Both the altered scenario and the query list are encoded in
the window's URL, so a particular exploration can be shared by copying a
link.

**Executive mode.** A new, deliberately minimalist entry point at
`/executive` serves people who want to *use* an existing program — ask
its questions of its scenarios — without ever editing rules. It is
mobile-friendly and read-only: a filterable list of programs, then just
two dropdowns, **Scenario** and **Question**, with the query re-run
automatically whenever either changes; each answer is a card that expands
into an indented explanation tree (assumed unknowns noted), and a button
opens the full Scenario Variations window on the same program. The whole
state — program, scenario, query — lives in the URL, so a link can put a
non-technical reader directly in front of a running query; the page
honours the same user authentication as the editor. Where the paper's IDE
addresses the *author* of an LE document, Executive mode addresses its
*consumer*.

**Interactive debugger.** The paper describes LE2's Debug Adapter
Protocol (DAP) server as having an operational tracer but a client-facing
surface "still being stabilised". That surface has since stabilised
inside the editor itself: an **LE Debugger** panel steps through a
query's proof with Step/Continue/Stop controls, shows the call stack
top-down (root query at the top, the goal executing now at the bottom,
mirroring top-down LE/Prolog execution), highlights the exact source span
of the current goal in the editor, and renders each frame's variables as
they become bound — so a binding made deep in the proof is seen
propagating to the ancestor goals, making unification observable over
time. Multiple answers can be traced by continuing past the first.

**Sharing via URL.** More broadly, the editor keeps the current program
in the URL (a `text` parameter), and `example`, `query` and `answer` URL
parameters allow a link to open a specific example, pre-select a query,
or target a specific answer; the landing page takes `dir` and `expand`
parameters to focus its example list on one subdirectory or open all its
folders. Together with the Variations and Executive URLs, this makes
"send someone exactly what I am looking at" a first-class operation. In
the other direction, **New from URL** loads an LE program *from* a link:
the editor fetches the document and resolves its relative
`includes these resources:` references against the URL's location, so a
program published anywhere on the web can be opened, and its resources
found, in one step.

**Help menu and user documentation.** The editor has gained a Help menu
whose entries — an introductory LE2 tutorial, a how-to-use guide for the
web application, and the language reference — open in an in-application
Markdown viewer, with the same links offered on the landing page. The
language reference itself has grown sections on LE extensions and on
*humanising* LE — guidelines for using constructs such as `only if`,
`unless` and prepositional additions to make programs read more
naturally.

**Multi-user deployment.** The hosted service has gained user accounts
and authentication, with per-user isolation building on the isolated
reasoning sessions the paper describes; proprietary examples have been
separated from the open example set, and session handling has been
hardened against expiry and cross-session leakage. Attempting to open a
restricted example without the required credentials now produces an
explicit error and a redirect to the login page rather than failing
silently.

**LE Assistant refinements.** The in-document LLM assistant (§3.2) has
gained a lighter-weight "light mode", explicit control over its agentic
loop, and support for additional model providers, alongside a `docs`
write-up of its behaviour. The MCP integration has acquired an automated
test suite.

## A.5 Reasoning and verification

The paper's claim that "explanations are pervasive" has been considerably
deepened, chiefly on the side of *failure*.

**Detailed failure explanations.** Failure trees now explain, per rule,
why a predicate proven by several rules did not succeed: an optional
preference renders an intermediate node per candidate rule (each
navigable to that rule) with its failed sub-goals beneath. FAIL nodes and
additional failure nodes have been added throughout, and negation
interacts correctly with assumed solutions.

**Repeated sub-explanations.** Large trees — especially failure trees —
tend to repeat the same sub-explanation many times. LE2 now detects
repeated subtrees and, by default, shows such a sub-explanation once, in
italics, with a tooltip reporting how many times it occurred; a repeat
that stands in for a full copy shown elsewhere carries a marker and a
"Go to full sub-explanation" action. This is governed by a
user preference.

**Important reason and the Explanation Drill.** Each answer now has an
identifiable *important reason* — a one-line summary of why it holds,
reachable from the explanation title and honouring the user's display
preferences. Built on this is the **Explanation Drill**, a guided,
non-modal walkthrough that treats an explanation as a "suspects tree" and
asks the user, region by region, whether they accept the current
important reason ("Yes", set it aside; "Not yet", descend into it),
tracking progress and highlighting each question's source in the editor.
This is aimed at the practical problem of finding, within a large
justification, the specific reason a particular reader cares about.

**Explanation ergonomics.** Supporting improvements include hierarchical
numbering of nodes, persistent expand/collapse state per answer, a
configurable prefix for failed nodes when copying, copy-to-clipboard as
both text and HTML, and unfolding of prepositional templates in rendered
answers and nodes (the latter only where prepositional chaining is
available — see the prepositional-templates note in §A.2; not in the
open-source version). Performance work — short-circuiting failing negated
goals, truncating over-long queries in the UI — keeps these richer
explanations responsive on larger documents.

**Verifier.** The structured verifier described in §3.3 continues to gain
checks, including a warning for facts or rules with a single variable and
for suspicious `is …` templates, and stricter enforcement that scenarios
appear at the end of a document and that their items end in periods.
Several recent checks target failure modes that used to surface far from
their cause. A reserved word inside a template (`if`, `unless`,
`only if`, …) used to silently truncate the template and corrupt the
parse of the whole templates section, with errors reported on unrelated
templates; it is now a targeted error at the offending template. Scenario
facts whose arguments begin with an indefinite article ("a person is a
citizen") are warned about — they introduce a variable rather than name
an individual, so the fact holds for everything — extending a check that
previously covered only knowledge-base facts. And a sentence that chains
several templates none of which is declared `; prepositional` — so that
the tail of the sentence would silently parse as a compound term inside a
template slot — now draws a warning, except in meta-template slots (those
conventionally marked by a preceding *that* or *says*), whose own parsing
has been made more robust.

## A.6 Summary

Relative to the paper, LE2 has:

- **re-widened the language** in native form — assumables/unknowns,
  template synonyms, prepositional templates, full query bodies, named
  variables and type-based rule disambiguation, sections and globals —
  narrowing the gap the paper opens between LE2 and LE1's construct set,
  without reintroducing LE1's back-end dependencies (prepositional-template
  chaining excepted: it remains in the proprietary `le_extensions` module
  and is not part of the open-source version);
- **added a major educational tool**, the Proof Game, that makes proof
  construction, unification, quantification, negation-as-failure and
  abduction manipulable rather than merely explained, together with a
  tutorial, teaching examples, and a library of abductive examples;
- **grown the IDE** with form-based Scenario and Query Editors,
  LLM-assisted "Write it in English" input verified against the program's
  own templates, a "what-if" Scenario Variations tool whose explanations
  can patch the scenario in place, a read-only mobile-friendly Executive
  mode for consumers of a program, an interactive in-editor debugger,
  richer URL-based sharing (including loading programs *from* URLs), an
  in-application documentation viewer, and multi-user authentication; and
- **deepened explanation and verification**, especially for failure —
  detailed per-rule failure trees, repeated-subtree collapsing, the
  important-reason summary, and the guided Explanation Drill — alongside
  verifier checks that catch template-level mistakes (reserved words,
  unintended template chaining, variable-introducing scenario facts) at
  their source.

None of these change the paper's central thesis — that LE2 consolidates
the robustly useful core of LE into a self-contained, deployable,
tool-rich system — but several sharpen it. In particular, the return of
abducibles and of prepositional and synonym templates narrows the
"LE2 narrows" caveat in the paper's summary, and the Proof Game and
Explanation Drill make good, concretely, on the teaching and
explanation ambitions the paper states in principle.

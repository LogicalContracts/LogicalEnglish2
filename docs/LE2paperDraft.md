# Logical English 2: A Reimplementation

*Draft — comparing the original Logical English (LE1) with its successor (LE2)*

## TODO
Convert, Use the LaTeX CEURART

## 1. Introduction

Logical English (LE) is a controlled natural language designed to let
domain experts write executable rules that read like ordinary English yet
have a precise logical meaning [1, 2]. The aim is to reduce the gap
between informal legal or business prose and the formal artefacts that
machines can reason with: rather than encoding a regulation in a
programming language and then verifying that the encoding is faithful to
the text, the regulation can in principle *be* the program. LE has been
applied to tax law, contracts, citizenship rules, financial agreements
and, more recently, to a domain-specific dialect for insurance
contracts [3]. It has also been promoted as an accessible vehicle for
teaching logic and computational thinking to school-age learners [2].

A program in LE consists of *templates* (natural-language patterns with
typed slots, e.g. `*a person* is the father of *another person*`) used
to express *facts*, *rules* (`Head if Body`), *queries* and *scenarios*
of test facts. Reasoning produces both answers and *justification trees*
in the same controlled English, so users can inspect how a conclusion was
reached. The language has remained close to a stable core since [1]:
templates with `*…*` slots, conjunction, disjunction, `unless`, classical
and conditional negation, universal quantification (`for all cases in
which … it is the case that …`), aggregates (`sum`, `count`,
`min`, `max`, `average`), an ontology section for `is_a` taxonomies, and
the use of `that` to embed sentences as meta-arguments.

This note compares two implementations of the language. The first,
referred to here as **LE1**, is the original implementation associated
with [1, 2] and developed at Imperial College and partner organisations.
The second, **LE2**, is a clean reimplementation undertaken by the same
working group with the goal of making LE easier to use, easier to deploy,
and easier to embed in modern toolchains. Both interpret essentially the
same language — programs written for one usually port to the other with
small surface adjustments — but they differ substantially in scope,
tooling and intended audience.

## 2. Logical English (LE1)

LE1 was conceived as a research artefact whose primary value is to
demonstrate that controlled natural language plus logic programming can
faithfully represent legal and contractual reasoning. Its design
emphasises **breadth**: many language constructs, several reasoning
back-ends, and integration with an existing notebook environment for
logic programming.

**Form of delivery.** LE1 is distributed as a SWI-Prolog package intended
to be loaded into SWISH, the web-based Prolog notebook server. A LE
document is typically embedded as a string inside a Prolog source file
and translated on demand by predicates such as `answer/1` or
`answer X with scenario Y`. Users interact with the system either through
a SWISH notebook or through an external Visual Studio Code extension that
talks to a SWISH server.

**Reasoning back-ends.** LE1 can target three back-ends from the same LE
source: pure Prolog, *TaxLog* (a Prolog dialect with explanation
facilities, originally developed for tax-law applications), and
*s(CASP)*, a constraint-based ASP system that supports classical
negation, abducibles, and HTML-rendered justifications. The choice of
back-end is determined by a `the target language is …` declaration. This
plurality made LE1 a useful platform for experimenting with which form of
non-monotonic reasoning is best suited to a given legal artefact.

**Language scope.** Beyond the stable core listed in §1, LE1 supports
several experimental constructs that reflect its research character:
multilingual front-ends for English, French, Italian and Spanish; *event*
and *fluent* sections for temporal reasoning in the style of the Event
Calculus; the form `*X* is a collection of … where …` for
set-comprehension; multiple combined knowledge bases with simple
inheritance; rule names; and prototype mechanisms for deontic operators
and rule priorities. The handbook and the `le_syntax.md` document
describe these features in detail; a number of them are flagged as
experimental or "currently being tested".

**Application portfolio.** The repository ships an example library of
contracts and statutes encoded in LE — the small business restructure
rollover, the net-asset-value test for capital gains, the ISDA Master
Agreement, the OECD model tax convention, criminal-justice rules, an
escrow blockchain agreement, and Italian citizenship law — most of which
also appear, in whole or in part, in the published literature [1, 2].
**InsurLE** [3] is a more recent and substantial extension developed in
the same family: a domain-specific controlled natural language for
insurance contracts that adds an insurance ontology, restrictive relative
clauses, and a rule-and-exception structure that mirrors the way insurers
actually write policy documents. The aim is for the contract text and the
machine-readable representation to coincide, eliminating the verification
gap that arises when a separate codification is maintained alongside the
prose.

**Style.** LE1 grew incrementally over several years. Its strength is
that almost every language idea explored in the LE research line has been
prototyped at least once; the cost is a sizeable code base whose features
have accumulated organically and whose deployment story (SWISH plus
external clients) is geared towards researchers and pilot users rather
than to general developers.

## 3. Logical English 2

LE2 is a redesign and full reimplementation of the same language family.
Its goal is not to extend LE — the language is, if anything, slightly
narrower — but to consolidate the parts of LE that are robustly useful
into a single coherent system that can be installed, deployed and
extended outside a SWISH environment.

### 3.1 Language

LE2 carries forward the stable LE core: templates and facts, `if`-rules,
`and`/`or`/`unless`/negation, universal quantification, aggregates,
ontologies, scenarios, queries, the `that` meta-argument convention, and
fluents/events for temporal modelling. Three smaller language changes are
worth noting.

First, LE2 elevates *testing* to a first-class concept. A scenario may
declare expected answers (`<query> expects answers ["…"].`); these are
parsed as part of the document and exercised by a built-in test runner.
A LE file is, in effect, both program and test suite — a contract
between the author and the system that supports continuous verification
as the rules evolve.

Second, LE2 exposes a small **introspection API** as named system
predicates: the active knowledge base, the source-level identifier of the
current rule, the type taxonomy, hierarchical designators for numbered
rules of the form `1.1.a`, and structured records for parsing issues and
expected answers. This makes LE programs themselves describable from
within LE, which is useful for explanation, for legal cross-referencing
and for tools built on top of the language.

Third, LE2 deliberately drops or postpones some of LE1's experimental
constructs. Currently it targets only Prolog (s(CASP) and TaxLog
back-ends, and the multilingual front-ends, are not present); the
`is a collection of … where …` form, deontic prototypes and rule-priority
hierarchies are likewise absent from this iteration. These are roadmap
items rather than rejected ideas, and the reimplementation includes
explicit extension points (multifile hooks at the parsing, second-pass
and reasoning levels) so that they — or proprietary additions — can be
re-introduced without forking the core.

### 3.2 Tooling

The most visible change in LE2 is the **integrated development
environment**. Rather than relying on SWISH or an external editor, LE2
ships its own browser-based IDE. It provides syntax highlighting that is
*template-aware* (so user-defined template words are not confused with
language keywords), live error reporting against a structured diagnostic
model, code folding by section and rule, completion of templates, hover
inspection, and an integrated query and explanation panel. The
explanation tree is interactive: every node is linked back to the source
range that produced it, so clicking a justification step navigates the
editor to the corresponding text. Diagnostics carry suggested fixes —
for example, a missing template warning offers to insert a hypothesised
template into the declarations section. The editor is supported by an
in-document chat-style **LE Assistant** that uses an LLM (OpenAI,
Anthropic or Google models, configured by the user) to explain, refactor
or generate LE code.

LE2 also speaks two protocols that did not exist in usable form during
LE1's main development. It implements the **Debug Adapter Protocol
(DAP)**, so any DAP-compliant client (VS Code, JetBrains IDEs and others)
can step through an LE proof, set breakpoints, and inspect the chain of
ancestor goals. And it implements the **Model Context Protocol (MCP)**
standard for tool-using LLMs, which lets agents such as Claude load LE
documents, run queries, and verify rules through a typed, tool-style
interface. Together these turn LE into something that other software —
human IDEs and AI agents alike — can drive directly.

### 3.3 Reasoning and verification

LE2's reasoner is a fresh meta-interpreter rather than a layer over an
existing logic-programming substrate. Its observable difference from
LE1's reasoner is that explanations are pervasive: every successful proof
yields a natural-language justification tree, and every *failed* query
yields a failure tree explaining why each candidate path did not succeed.
Both trees carry source-range information, which is what the editor uses
for click-to-navigate explanations. Each loaded document runs in its own
isolated session, so multiple users — or multiple scenarios within a
single session — cannot interfere with each other's facts.

A separate **verifier** runs at every load and produces a structured list
of issues: missing templates, undefined predicates, untested predicates,
rules with no variables, redefined system templates, and failed
expectations. Each issue carries a description, a suggested fix, and a
source range, so the editor can render diagnostics inline and offer
quick-fixes. LE1 prints diagnostics; LE2 *models* them, and that model is
exposed to clients over the API.

### 3.4 Deployment

LE1 is run as a SWISH plug-in or via small example servers bundled with
the repository. LE2 is a self-contained HTTP service: a single command
brings up a JSON-over-HTTP API and the editor as a web application, and a
Docker image packages both. A hosted demonstration is available at
`le2.logicalcontracts.com`. The intent is that an organisation interested
in adopting LE for a real workflow should not need to learn SWISH first.

### 3.5 What LE2 inherits and what it changes, in summary

LE2 keeps:

- the language and semantics of LE's stable core, sufficient to express
  the bulk of the LE1 example portfolio;
- the philosophy that the source text and the executable artefact should
  coincide;
- the use of justification trees rendered in the same controlled English
  as the rules.

LE2 changes:

- **Surface**: a dedicated browser IDE replaces SWISH and external
  extensions; explanations and diagnostics become interactive surfaces
  rather than text dumps.
- **Engineering**: a smaller, more modular code base built around a
  source-tracking pipeline that retains character offsets from token to
  proof tree.
- **Integration**: first-class web, MCP and DAP endpoints make LE
  usable from IDEs and from LLM-based agents without bespoke glue.
- **Process**: tests are part of the language, the verifier is part of
  the loop, and extension points are part of the architecture.

LE2 narrows:

- to a single Prolog back-end and a single (English) front-end, with
  s(CASP), TaxLog, multilingual support and several experimental
  constructs deferred to future work.

## 4. Conclusion

LE1 and LE2 are best understood as two phases of the same project. LE1
established the language and the case for it [1, 2], explored its reach
through experimental constructs and multiple back-ends, and demonstrated
domain-specific viability through extensions such as InsurLE [3]. LE2
takes the consolidated core of that work and delivers it as a modern,
self-contained development environment, with verification, debugging and
LLM integration built in. The two systems are complementary: LE1 remains
the reference for the wider design space LE has explored, while LE2 is
intended to be the practical entry point for new users and new
applications.

## References

[1] R. Kowalski, J. Dávila, M. Calejo. *Logical English for Legal
Applications*. 2021. Available at
`http://www.doc.ic.ac.uk/~rak/papers/LE_for_LA.pdf`. Project repository:
`https://github.com/LogicalContracts/LogicalEnglish`.

[2] R. Kowalski, J. Dávila, G. Sartor, M. Calejo. *Logical English for
Law and Education*. In *Prolog: The Next 50 Years*, Lecture Notes in
Computer Science, vol. 13900, Springer, 2023.
`https://doi.org/10.1007/978-3-031-35254-6_24`. Preprint:
`http://www.doc.ic.ac.uk/~rak/papers/Logical%20English%20for%20Law%20and%20Education%20.pdf`.

[3] R. Kowalski, J. Cummins, J. Dávila, D. Ovenden. *Computable
Contracts for Insurance: Establishing an Insurance-Specific Controlled
Natural Language — InsurLE*. British Insurance Law Association Journal,
2024. Preprint:
`http://www.doc.ic.ac.uk/~rak/papers/InsurLE.pdf`.

[4] *Logical English 2.0* — project repository, documentation and live
demo: `https://github.com/mcalejo/LogicalEnglish2`,
`https://le2.logicalcontracts.com`.

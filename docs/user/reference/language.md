# Logical English (LE) Syntax Summary

*Kind: reference · Audience: users, developers, the assistants (read whole by the LLM features) · Status: current (2026-09-16)*

This document summarises the constructs of Logical English (LE) that the system understands. `le_grammar.pl` is the part of the software that reads an LE document and works out what each sentence says, and the constructs listed here are the ones it accepts.

## Table of Contents
- [Logical English (LE) Syntax Summary](#logical-english-le-syntax-summary)
  - [Table of Contents](#table-of-contents)
  - [1. Document Sections](#1-document-sections)
  - [2. Templates](#2-templates)
    - [Template additions (after `;`)](#template-additions-after-)
    - [2.1 Prepositional templates](#21-prepositional-templates)
    - [2.2 Named constants: `the constants are:`](#22-named-constants-the-constants-are)
    - [2.3 Functions: `the functions are:`](#23-functions-the-functions-are)
    - [2.4 Memorable templates: `; memorable`](#24-memorable-templates--memorable)
  - [3. Rules and Facts](#3-rules-and-facts)
    - [3.1 Rule Sections](#31-rule-sections)
    - [3.2 Query bodies](#32-query-bodies)
    - [3.3 Integrity constraints: `it must not be true that …`](#33-integrity-constraints-it-must-not-be-true-that-)
  - [4. Logical Operators](#4-logical-operators)
  - [5. Aggregates](#5-aggregates)
  - [6. Variables and Constants](#6-variables-and-constants)
    - [6.0 Definite descriptions: back-reference or global constant](#60-definite-descriptions-back-reference-or-global-constant)
    - [6.1 Variable names and types](#61-variable-names-and-types)
    - [6.2 Type checking](#62-type-checking)
  - [7. Arithmetic and Comparisons](#7-arithmetic-and-comparisons)
    - [7.1 Date Handling and Comparisons](#71-date-handling-and-comparisons)
  - [8. Taxonomy (Ontology)](#8-taxonomy-ontology)
  - [9. Ignorable Words](#9-ignorable-words)
  - [10. Comments](#10-comments)
  - [11. Meta-Templates](#11-meta-templates)
  - [12. Testing and Expectations](#12-testing-and-expectations)
  - [13. System Predicates](#13-system-predicates)
  - [14. Included Resources](#14-included-resources)
  - [15. LE Extensions](#15-le-extensions)
  - [16. Humanizing LE](#16-humanizing-le)
  - [17. Regulatory-decision constructs](#17-regulatory-decision-constructs)
    - [17.1 Provenance trailers and judged templates](#171-provenance-trailers-and-judged-templates)
    - [17.2 `otherwise` cascades](#172-otherwise-cascades)
    - [17.3 Decision tables](#173-decision-tables)
    - [17.4 The decision skeleton: applicability, question, remedy](#174-the-decision-skeleton-applicability-question-remedy)
    - [17.5 Source-scoped proof: `according to` in a rule](#175-source-scoped-proof-according-to-in-a-rule)
    - [17.6 Services and semantic predicates over text](#176-services-and-semantic-predicates-over-text)
    - [17.7 Flip queries: which minimal change flips the outcome](#177-flip-queries-which-minimal-change-flips-the-outcome)
    - [17.8 Factors and precedent: a pattern, not syntax](#178-factors-and-precedent-a-pattern-not-syntax)
    - [17.9 Facts from a document](#179-facts-from-a-document)
    - [17.10 Views: how a screen shows a program](#1710-views-how-a-screen-shows-a-program)

## 1. Document Sections
A program is written in sections, and each section says how to read the sentences that follow it. Every section header ends with a colon `:`.

- **Included Resources:** `the knowledge base <name> includes these resources:` or `the contract <name> includes these resources:` (brings in other LE files, or documents at a web address — a URL. Write such a section before the main knowledge base header).
- **Knowledge Base:** `the knowledge base <name> includes:` or `the contract <name> states that:`
- **Scenario:** `scenario <name> is:` (states the facts of one case, usually a case the program is tested on)
  - Can include expectations: `<QueryName> expects answers [<List of Strings>] and unknowns [<List of Strings>].` (the word `answers` may be omitted; `and any unknowns` checks the answers only, §12)
- **Query:** `query <name> is:` (says what the program should try to prove). The
  body of a query may be a **whole condition — just like the body of a rule** — and
  not only one sentence: the body may combine conditions with `and`, `or`,
  negation (`it is not the case that …`) and `for all cases in which …` (see §3.2).
- **Ontology:** `the ontology is:` (says which kinds of thing are kinds of other things)
- **Templates:** `the predicates are:` or `the templates are:` (gives the sentence patterns the program is written in)
- **Constants:** `the constants are:` (named values, one per line: `the fee is 5.` — §2.2)
- **Functions:** `the functions are:` (templates of the form `... is *a value*`, whose value may be written without that last place — §2.3)
- **Bases (LPS target):** LPS is Logic Production System, the companion system for rules about time and change. `the knowledge base <name> extends <base>, <base>.` — the bases' templates, laws and constraints, without their instance (`le_lps_surface.md` §1.1)
- **Dynamics:** `the fluents are:` or `the events are:` (for reasoning about time). In the LPS target a sentence needs times only where it relates two moments: `if there is a fire in a room and it is not the case that an alarm is on then an alarm goes on.` reads its conditions at one time and starts its action at it, and `when an alarm goes on then an alarm is on.` needs none either (`le_lps_surface.md` §3.1)
- **Meta:** `the target language is: prolog.` (needed before the system can produce Prolog)

## 2. Templates
A template is a sentence pattern. Each template says how one kind of sentence may be written, and ties that kind of sentence to a predicate — a named relation — in the Prolog program that Logical English is translated into.
- **Pattern:** `*a person* is a friend of *another person*`
- **Variables:** Words enclosed in asterisks `*...*`.
- **Types:** The **head noun** of the variable phrase (e.g. `person`); see §6 for how names and types are separated.
- **Variable Scoping:** Writing the same variable name twice in one sentence, or in one query, refers to the same individual both times.
  - `which person is the father of which person` will only match if a person is their own father.
  - Use `which person is the father of which other person` to refer to two different people.

### Template additions (after `;`)
A template definition can be followed by one or more additions, each introduced by `;`:
- `; opposite: <template>` — declares how to say the opposite of the template. A rule may then conclude the opposite form, and an explanation may report it.
  **The opposite form is not a negation when it is used as a condition.** Written as a condition, `the claimant does not have another form of income` asks about a relation of its own, and only a rule that concludes that relation — an `only if` rule, §15.1 — can prove it. To test instead that the positive template does not hold, write `it is not the case that the claimant has another form of income`. The verifier reports an opposite form used as a condition that nothing concludes (`opposite_as_condition`).
- `; synonym <template>` — declares a **second way of saying the same thing**. The synonym stands for the **same** relation as the main template, so a fact, the head of a rule, a condition of a rule and a query may each be written in either form. A template may carry several `; synonym ...` additions, one after another. The system matches the synonym's `*variables*` to the main template's **by position**, so both forms must list their arguments in the same order.
  - Example: `*a payment* is in respect of *a claim*; synonym *a payment* covers *a claim*.` — writing `p covers c` is the same fact as `p is in respect of c`.
  - **Rendering:** the main form, the one written first, is the one shown by default. In an explanation, each step is shown in the form actually used where it was written, that is, in the wording of the rule or fact that proves it. A query shows its answers in the form the query itself used.
  - **Restriction:** a template with a synonym **cannot carry any other addition** (`opposite`, `prepositional`, `unknown`, `undefined`); a template written that way is reported as a `synonym_with_other_additions` error.
- `; prepositional` — marks a **prepositional** template (see §2.1). The synonym `; composite` is accepted and means the same thing.
- `; unknown` — marks the template as **assumable**. A sentence of this kind that the program cannot prove is assumed to be true instead, and is reported as an unknown, as far as the integrity constraints allow (§3.3). Logicians call a sentence that may be assumed this way an abducible. The synonyms `; assumed` and `; assumable` are accepted and mean the same thing.
- `; undefined` — marks the template as a **scenario element**: sentences of this kind belong in scenarios only, and never appear as facts or as the conclusion of a rule in the knowledge base. The synonym `; scenario element` (two words) is also accepted. The verifier then treats the template differently in two ways:
  - The verifier does **not** raise its `undefined_predicate` warning for this template, even though the knowledge base holds no rule and no fact for it.
  - The verifier raises a **`defined_scenario_element` warning** when it does find a fact, or a rule concluding this template, in the knowledge base.
  - Example: `*a person* has passed the test; undefined.`
- `; via service <name>` — the template is answered at run time by a declared service (§17.6).
- `; <value> by default` — **LPS target, fluents only** (`le_lps_surface.md` §2): the value the template's last place takes wherever no fact has stored one (`the balance of *an account* is *an amount*; 0 by default`, `…; the zero address by default`). A default on any other template is reported (`default_not_lps`).
- `; judged` — marks an **open-textured** relation, one whose instances are *decided* by a person rather than worked out from rules (synonyms `; open textured`, `; evaluative`). The system solves it as it solves `; assumable`, with one difference: once an outcome — the last argument — has been recorded for a question, no other outcome of that question is assumed. A rule concluding a judged template is an error, and an instance still undecided is shown as *judgment needed*. See §17.1.
- `; memorable` — while a query runs, the system **remembers** the answers to this template: it works out each distinct question once, keeping its answers and their explanations, and gives the same answers again wherever that question comes up (§2.4). Remembering answers this way is called memoization. The synonyms `; memoised`, `; memoized` and `; cached` are accepted.

### 2.1 Prepositional templates
A prepositional template relates two things and **starts with one of them**, so that it can extend the condition written before it. When such templates are chained, the author may leave the leading argument out. The system then fills it in from the previous condition, taking the variable whose type fits.
- **Declaration:**
  ```le
  *a payment* under *a policy*; prepositional.
  ```
- **Constraints:** the template must have exactly two `*variable*` arguments, and its first word must be a `*variable*`. A template that breaks either rule is reported as a `prepositional_arity` or a `prepositional_first_arg` issue.
- **Chained usage** (omitting the first argument; the chaining needs `le_extensions.pl`, [extensions.md](extensions.md) §15.7):
  ```le
  we will make a payment under this policy in respect of a claim
  ```
  expands to the conjunction
  ```le
  we will make a payment
  and the payment under this policy
  and the payment in respect of a claim
  ```
  Each prepositional template becomes an **extra condition** of the rule, whether the chain was written in the rule's head or among its conditions.
- **Standalone usage** is still allowed: write the leading argument out (for example `the payment under this policy`) and the sentence matches the template directly.

### 2.2 Named constants: `the constants are:`
A section of named values, one line each, `<name> is <value>.`:
```le
the constants are:
    the tax free allowance is 12570.
    the unlimited allowance is 115792089237316195423570985008687907853269984665640564039457584007913129639935.
```
The name then stands for the value wherever a rule, a scenario or a query uses
it: `a person pays tax if the person earns an income and the income > the tax
free allowance.` An explanation shows the value as a reason.

Each line declares the template `the value of <name> is *a <type>*` and states
its one fact, so the value can also be read into a variable — `the value of
the tax free allowance is an allowance A`. Reading the value into a variable is
how to use a constant in arithmetic, because arithmetic cannot work on a name.
Either compare a value with the name, or read the name's value into a variable
first.

The system takes the value's type from the value as written: a number, a piece
of text, or a name. The name itself may contain the word `is`, and the value is
then the part after the last `is`. The verifier reports a constant that nothing
uses (`unused_constant`). `le_writer.pl`, the part that writes an LE program out
again, writes the section back from the item `constant(F, Name, Value)`.

A constant is the special case of a **function** (§2.3) whose value is written
down rather than worked out. Where the rules compute the value, use the
functions section instead.

### 2.3 Functions: `the functions are:`
A **function** is an ordinary template of the form `... is *a value*`. Its last
place, the one after the word `is`, is the value the function gives. A function
is declared in a section of its own:
```le
the functions are:
    the price of a cup with capacity *a number* ml is *an amount*.
```
Declaring it lets the sentence be written **without that last place** wherever
a value is expected. The two conditions

```le
    and the price of a cup with capacity the capacity ml is a price
    and the price > 10
```

can then be written as one:

```le
    and the price of a cup with capacity the capacity ml > 10
```

Nothing else changes. The full sentence still works. What defines the function
is an ordinary rule or fact (`the price of a cup with capacity a number ml is
an amount if the amount is the number / 10.`). A function may also be a relation
with **several answers**, and every sentence that uses it then has several
answers too. The same use of a function written twice in one sentence is asked
**once**, so repeating the phrase does not multiply the answers.

A function with no place of its own is a value with a name — `our policy is *a
policy*` used as `our policy` — which is what the `; defines global` addition
used to be for. That addition has been removed: a value written down is a
constant (§2.2), and a value the rules compute is a function, whose name is
the sentence's own words instead of one invented beside it. A program that
still carries `; defines global` is told so at that line
(`defines_global_removed`).

Details worth knowing:

- **Where it may be written.** Anywhere a value is expected: a comparison, an
  `is`, a place of another template, the value of a rule's head (`the label of
  thimble is our currency.` — a fact whose value is a function's is a rule).
- **Arithmetic cannot work on it**, exactly as arithmetic cannot work on a
  constant: `the total is the price of a cup with capacity 200 ml + 5` does not
  read the function. Read the value into a variable first, then do the
  arithmetic.
- **Nothing may follow the phrase where the sentence goes on with `is`.**
  `the price of the cup > 10` is fine, and so is `the label is our currency`;
  `the price of the cup is in [10, 20]` is not — the function's own sentence
  matches from the start and reads `in [10, 20]` as its value. For those
  forms (`is in`, `is equal to`, `is a`, or a template that opens with the
  place you are filling), bind the value in a condition of its own.
- **The condition goes first.** The question that asks the function for its
  value is placed before the condition that uses the value, which is what lets
  a comparison work.
- **The form is checked.** The verifier reports a line of the section that is
  not of the form `... is *a value*` (`function_not_is_form`), and that line
  stays an ordinary template.
- **LPS.** The same section, and the same reading, in `the target language is:
  lps.` (`/lps2/examples/le/functions.le`). A fluent, an event or an action
  keeps its own declaration section, which is what confers its LPS role, so
  the value of a fluent is still written in full.
- **The writer**, which turns a program back into LE text, writes the section
  back from the item `function(F, Text)`. Where a value is used once its inputs
  are known, the writer writes the function the short way, which is the form the
  translators from other systems produce.

The worked example is
`examples/moreExamples/language/templates/functions.le`.

### 2.4 Memorable templates: `; memorable`
A query on a large program often proves the same thing many times over. The
same condition, with the same values, is reached from several rules, or from
several cases of one rule. The explanation shows the repetition afterwards, by
folding the repeated parts together. The `; memorable` addition avoids the
repeated work itself, for the templates the author chooses:
```le
the templates are:
    *an ancestor* is an ancestor of *a person*; memorable.
```
- **What is remembered.** Within one query, the first time the program asks a
  *distinct* question of the template, it works out **every** answer to that
  question, each with its unknowns and its explanation. Every later question
  that is the same but for the names of its variables is answered from what was
  remembered: `which ancestor is an ancestor of Lettice` again, but not `is
  Owen an ancestor of Lettice`, which is a question of its own. The system
  recognises a question it has already answered by a short code computed from
  the question's shape.
- **Only finished questions are reused.** The system remembers a question once
  all its answers have been worked out. While a question is still being worked
  out, the same question met again inside that work is solved in the usual way.
  The check that stops a rule from calling itself for ever applies exactly as it
  does without the marker.
- **Same answers, same explanations.** The marker changes when the work is
  done, not what is concluded. A question answered from memory gives the answers
  the first asking gave, in the same order, and its explanation is the same
  proof, so the editor folds repeated explanations together as it always does.
  Where such a question has no answer, its explanation of the failure, and the
  alternatives that were tried and ran out, are read from the first asking.
  There is one difference: the first asking works out all its answers before the
  first one is used, so a query that would have stopped early — `once`, or a
  time limit — does that work up front.
- **Per query, not per session.** The system forgets the remembered answers
  when a query starts. The facts a session holds change between queries — a
  scenario is set, a flip query tries changes — and an answer worked out under
  other facts would be wrong. Within one query, a proof made inside another
  proof — a why-not attempt, a section check, a constraint check of an
  assumption, a flip — remembers its own answers separately, and so does a
  scoped proof (`according to`, §17.5).
- **When it pays.** The marker pays for a template that is asked again and
  again with the same arguments and has an expensive proof behind it: a count
  that calls itself, a classification consulted by many rules, a relation built
  up from facts step by step. A template that is merely looked up in a table of
  facts gains nothing, and still pays for computing the code of each question.
  Choose the templates by looking at the repeated explanations the editor
  shows.
- **Warnings.** The verifier reports:
  - `memorable_under_negation` — a memorable question asked under `it is not
    the case that`, under `unless`, or in the guard of `otherwise`. A negation
    stops at the first answer, while a memorable question works out every
    answer before giving the first, so the effort is wasted unless the same
    question is also asked outside a negation;
  - `memorable_calls_prolog` — a rule of the memorable relation runs an
    embedded `prolog` goal (§15.6). A goal that changes something behind the
    program's back would leave the remembered answers out of date, with nothing
    to notice it.
- **Only for the Prolog target.** The part that answers queries for the Prolog
  target reads the marker. The s(CASP) and LPS targets ignore it, and the writer
  keeps it when it writes the program back.

See `examples/moreExamples/language/memoization/` (`lattice_paths.le`,
`family_relatives.le`, `memorable_warnings.le`).

## 3. Rules and Facts
- **Fact:** a plain statement, ending in a full stop.
  - `Alice is a person.`
- **Rule:** a statement with a head, which is what it concludes, and a body, which are the conditions.
  - `Head if Body.`
  - `*a person* is eligible if *a person* is a citizen.`
- **Unknown Fact:** A statement saying that one particular sentence of a template is unknown. Such a statement may stand in the knowledge base, where it applies to every scenario, or inside one `scenario` section.
  - `it is unknown whether *a payment* is in respect of claim 01.` (the statement fixes the second argument as 'claim 01' and leaves the first one open). The synonyms `it is assumed whether ...` and `it is assumable whether ...` are also accepted.

### 3.1 Rule Sections
The rules of a knowledge base may be grouped into named **sections**, though they need not be. A section marker is a line of this form:
```le
section <name> is:
```
Every rule, and every fact, that follows the marker belongs to section `<name>`, until the next marker. The system records which rule belongs to which section in `le_source_section/2` (see §13). A section changes nothing about how the rules behave when a query is answered: a section name is a label, no more.

Conventions:
- Where a knowledge base has no section markers at all, every one of its rules belongs to the default section **`main`**.
- The names **`applicability`**, **`question`** and **`remedy`** are reserved for the decision skeleton (§17.4). The three names change nothing about how a query is answered, but a query that fails is reported against them.
- Rules appearing before the first section marker also belong to **`main`**.

There is a shorthand for a commonly used section named `annexes`:
```le
the annexes to the contract are:
```
which is exactly equivalent to `section annexes is:`. The synonym `the annexes to the knowledge base are:` is also accepted.

Example:
```le
the knowledge base example includes:

a customer is preferred if the customer is loyal.   % belongs to section 'main'

the annexes to the contract are:

rule extra:
a customer is loyal if the customer is old.         % belongs to section 'annexes'
```

### 3.2 Query bodies
The system reads the body of a `query <name> is:` section **exactly as it reads
the body of a rule**: the body is a whole condition, and not merely one
sentence. The body may combine conditions with the operators of §4:

- **Conjunction / disjunction** with `and` / `or`. Variables are shared across the
  conditions, so the same name refers to the same individual:
  ```le
  query both is:
      a person is happy
      and the person is healthy.
  ```
- **Negation** with `it is not the case that …`. As in a rule body, the negated
  goal goes on its own nested (indented) line:
  ```le
  query safe is:
      a person is happy
      and it is not the case that
          the person is sad.
  ```
- **Universals** with `for all cases in which … it is the case that …`, written in
  the same indented shape used inside rules (see §4 and `examples/.../subset.le`):
  ```le
  query all_happy is:
      for all cases in which
          a person is a dragon
          it is the case that
          the person is happy.
  ```

A query that is a single sentence — the usual case, for example
`which dragon is happy.` — behaves as it always did. An answer to a query of
several conditions is written out from the query's own words, with the values
found for its variables: `"bob is happy and bob is healthy"`.

> The layout rules of a rule body apply here too. A negated sentence, and each
> part of a `for all cases`, must stand on its own indented line. Writing the
> whole of `… and it is not the case that the person is sad` on one line does
> **not** separate the negation — rule bodies have the same limitation — so put
> the negated sentence on the next line.

### 3.3 Integrity constraints: `it must not be true that …`
An **integrity constraint**, also called a *denial*, says that certain
conditions must never hold together. A constraint is written in the knowledge
base, like the body of a rule with nothing concluded from it, and the same
sentence serves in every target language:
```le
it must not be true that
    a person is resident in a country
    and the person is resident in a second country
    and the country is different from the second country.
```
- **Prolog target** — a constraint checks what an answer **assumes**, that is,
  the templates marked `; unknown` in §2. Reasoning that assumes what it cannot
  prove is called abductive logic programming, and this is how it works here.
  The system keeps an answer found by assuming something only when the case,
  with those assumptions taken as true and nothing else assumed, meets no
  constraint's conditions. While a constraint is checked, whatever is neither
  stated nor assumed counts as false, so a constraint may use `it is not the
  case that`.
  - Where a constraint is broken by the negation of something assumable, the
    system **mends the answer by assuming more**. Take the constraint `it must
    not be true that a person is married to a second person and it is not the
    case that the second person is married to the person`: assuming that dan is
    married to erin then also assumes that erin is married to dan, and the
    answer lists both unknowns.
  - In every other case the system **rejects the answer**. With the constraint
    above, assuming that alice, who lives in Spain, is resident in France is not
    allowed, so alice is not answered as paying tax in France.
  - A case whose **facts** break a constraint on their own, with no assumption
    to mend it, is **inconsistent, and nothing follows from it**. Every query
    then has no answer, and the explanation of the empty answer is the
    constraint together with the proof of its conditions ("the case breaks a
    constraint …").
  - Constraints leave everything else alone: ordinary `if` rules, queries and
    the definite answers of consistent cases. A program with no constraints
    behaves exactly as it did before constraints existed.
- **s(CASP) target** — the system writes each constraint as a global
  constraint, `false :- Conditions.`, which every model, and so every set of
  assumed sentences (`#abducible`), has to satisfy. One caution: s(CASP) 1.1.4
  gives wrong results for a constraint that still has open variables in it and
  uses `is different from` together with assumed sentences. A constraint whose
  values are all fixed is handled correctly.
- **LPS target** — the same sentence is an LPS constraint on actions and states
  (`d_pre/1`, `le_lps_surface.md` §3.7): actions and events are LPS's
  abducibles, and the reactive engine and the planner never choose an action
  that would break one.

See `examples/moreExamples/language/unknowns/assumption_constraints.le`. The
translators that bring s(CASP) and Prolog programs into LE
(`le_writer:prolog_to_ir/3`) read a denial, `:- Body.` or `false :- Body.`, as a
constraint of this kind.

## 4. Logical Operators
- **And:** `and` (or new line with same indentation)
- **Or:** `or`; grouped alternatives `either`, `any of`, `all of` ([extensions.md](extensions.md) §15.4)
- **Otherwise:** a line opening with `otherwise` starts a new alternative, which applies only when all the earlier alternatives fail (§17.2).
- **According to:** `<condition> according to <source>` proves the condition from that source's evidence only (§17.5).
- **Negation:** `it is not the case that` or `not the case that`
  - `it is not the case that *a person* is a citizen`
  - `not the case that *a person* is a citizen`
- **Conditional Negation:** `unless`
  - `Head if Body unless Condition.` (Equivalent to `Head if Body and not Condition.`)
- **Universal Quantification:**
  ```le
  for all cases in which
      <condition 1>
      <condition 2>
  it is the case that
      <consequence>
  ```

## 5. Aggregates
An aggregate works out one value from a whole set of answers.
- **Operators:** `sum`, `count`, `average`, `min`, `max`
- **Syntax:** `<ResultVar> is the <Op> of each <Var> such that <Goal>`
- **Example:** `*Total* is the sum of each *Amount* such that *the account* has *Amount*`
- **Scope:** the conditions of `such that` are the lines indented under it. A
  line back at the aggregate's own level (`and N > 3`) is a condition that comes
  after the aggregate. The same holds where the aggregate is the first condition
  written on the header's line (`the total is large if N is the sum of each I
  such that`, and in LE for LPS `if … then` and `when … then`), and in a query
  section, whose body may begin with an aggregate:
  ```le
  query total is:
      a number N is the sum of each I such that
          a person pays I
      and N > 12.
  ```
- **Answers and explanations** read an aggregate back as a sentence, with the
  value found and the conditions: `15 is the sum of each I such that a person
  pays I`. Where the thing counted or added up is named by a noun, the sentence
  reads `the <noun>` in those conditions: `2 is the count of each amount such
  that bob owes the amount`.

## 6. Variables and Constants
- **Variables:**
  - Explicit: `*my variable*`
  - Implicit: `a person`, `some person`, `each person`, `which person` — and
    `the person`, but **only as a back-reference**: see §6.0.
  - Special: `who`, `what`, `when`, `where`

### 6.0 Definite descriptions: back-reference or global constant
An **indefinite** phrase (`a person`, `an amount`, `some rabbit`) *introduces* a
variable. A **definite** phrase (`the person`, `the white rabbit`) never
introduces one. A definite phrase is a variable only where the *same sentence*
has already introduced a variable of that name. Otherwise the definite phrase
names a **global constant**: the one individual the phrase refers to, written
with its article (`the white rabbit`), and the same individual in every rule,
scenario and query of the program.

```le
a rabbit is in a hurry
    if the rabbit is late for an appointment.       % "the rabbit" = the head's variable

a person falls down the rabbit hole
    if the person follows the white rabbit          % "the white rabbit" = a constant,
    and the white rabbit is late for the tea party. % and so is "the tea party"
```
The second rule is about **one** rabbit. A scenario fact `the white rabbit is
late for the tea party` is about that same individual, because a definite phrase
in a scenario has always been a constant. See
`examples/moreExamples/language/templates/white_rabbit.le`.

Consequences worth knowing:
- Order matters inside a sentence, and not merely whether the name appears at
  all: the phrase that introduces the variable has to come first. The system
  reads a rule's head before its conditions, and the conditions from left to
  right, which is how LE is written anyway.
- A misspelt back-reference (`the peron`) no longer becomes a variable that
  quietly matches anything. The misspelling becomes a constant that nothing else
  mentions, so the rule simply never applies.
- To use a definite phrase as a variable that nothing introduces, name it
  explicitly: `*the white rabbit*` (§6.1).

### 6.1 Variable names and types
A variable phrase may carry a **name** as well as its **type**, so that several variables of the same type can be told apart:
- **Type** = the **head noun** of the phrase. The whole phrase is the variable's **name**, which is what tells the system whether two phrases speak of the same thing, and what it shows on screen.
- **Leading qualifier:** an ordinal (`first`, `second`, …, `tenth`), or one of `other, another, new, previous, next, current, last, same, original, single, given`, written in front of the noun marks a variable of the same type but distinct from the others. So `a first person` and `a second person` are **two different variables, both of type `person`**, and a `person` value is accepted in either place.
  - `*a first person* greets *a second person*` — two `person` arguments; see `examples/moreExamples/language/templates/named_vars.le`.
- **All-caps id convention:** a short name at the end — a single capital letter, or a short word in capitals — is the variable's name, and the noun or nouns before it are the type. `a person X` and `a person Y` are two different variables of type `person`; likewise `a number N`, `a date D`.
- **Genuine multi-word types** (no leading qualifier / trailing id) are kept whole, e.g. `a bodily injury` has type `bodily injury`, `a repair cost` has type `repair cost`.
- Where the *same* phrase appears again (`a first person` … `the first person`), it refers to the same individual, as in §2.

### 6.2 Type checking
The system uses a variable's **type** (§6.1) to reject values that do not belong to it. The check comes **late**: it happens once the argument has a value. The check is also **forgiving**: it rejects a value only on a clear conflict, and it always accepts a value whose type is unknown. The system looks for `is_a` facts both in the **knowledge base** and among the scenario facts of the **session** in hand.

- **Instance values.** A value has a known type when some `is_a` fact says so, a scenario fact such as `this payment is a payment` included. Such a value is accepted in a place of type `T` only where the value *is a* `T` — directly, or through the `is_a` taxonomy, or because the head nouns match. So a value declared a `payment` is **rejected** in a place that asks for an `amount`. A value of **no** known type is accepted anywhere.
- **Type values.** A value may itself be a *type*, as in taxonomy reasoning (`*sub* isa *super*`). Such a value has to be a sub-type of the place's own type — but only where the place's type takes part in the ontology, that is, where something is a `T`, or `T` is a something. A placeholder type such as `super`, which nothing is a and which is neither above nor below anything, asks nothing of the value, so a real type such as `dragon` is accepted there.
- **Universal types.** `any`, and the universal types `thing`, `object`, `entity`, `asset`, `element`, accept any value.
- **Telling apart rules that conclude the same relation.** Where the heads of two rules conclude one relation but declare **different argument types**, the type keeps the rules apart. For example, given both prepositional bridges
  ```le
  a payment in respect of a claim if the payment is in respect of the claim.
  an amount  in respect of a claim if the amount  is in respect of the claim.
  ```
  the fact `this payment is in respect of this claim`, together with `this payment is a payment`, matches **only** the first rule, because `this payment` is rejected by the head of the second, which asks for an `amount`. The system checks a rule's head this way **only where the templates disagree** about the type of a place — here, the first argument is a `payment` in one template and an `amount` in another. Where the templates agree, the type cannot tell one rule from another, so no check is made on the head. A single `affiliate` template is an example: a `company` may legitimately act as an `affiliate`. 

In an explanation, a type check is shown as the statement it verifies, for example `this payment is a payment`.

- **Constants:**
  - Proper names: `Alice`, `Bob`
  - Strings: `"Hello"`, `'World'`
  - Numbers: `42`, `3.14`
  - Dates: `2023-10-27`

## 7. Arithmetic and Comparisons
- **Math:** `+`, `-`, `*`, `/`, `( )`, integer division `//` and remainder `mod` (`S = B // 3 + B mod 3`) — the arithmetic of contract code that keeps a fixed number of decimals (amounts on the Ethereum Virtual Machine, the EVM, are held in units of 1e18)
- **Functions:** the arithmetic functions `ceiling`, `floor`, `round`, `truncate`, `integer`, `abs`, `sign` and `sqrt` each take one argument in brackets, as in `the result is the multiple * ceiling(the amount / the multiple)`. Prolog works them out with `is/2` while the query runs.
- **Comparison:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=` (`==` is `is equal to`, `!=` is `is different from`). A formula may stand on **either side**: `N mod 3 = 2`, `2 = N mod 3`, `N mod 3 == 2` and `N mod 3 is equal to 2` all evaluate `N mod 3` and compare the numbers (where one side has no value yet, `=` gives it the value of the other, as in `R = N mod 3`). Values that are not formulas — names, pieces of text, dates — are compared just as they are written.
- **Variable names in expressions:** the system takes a bare word in an arithmetic expression for a variable only where the word is an **id**, that is, a single capital letter or a short word in capitals (see §6.1), as in `ENT = ETI * ATR - TO`. A descriptive word in lower case or mixed case, such as `amount` or `exposure`, counts as part of a *type* and not as a variable name, so inside an expression it does not refer to the same thing as a variable of the rule's head. Use ids (e.g. `EXP`, `IAOR`, `A`) for variables that participate in arithmetic.
- **System Templates:**
  - `*V1* is equal to *V2*`
  - `*V1* is greater than or equal to *V2*` (for numbers)
  - `*V1* is less than or equal to *V2*` (for numbers)
  - `*V1* is greater than *V2*` (for numbers)
  - `*V1* is less than *V2*` (for numbers)
  - `*V1* is after or equal to *V2*` (for dates)
  - `*V1* is before or equal to *V2*` (for dates)
  - `*V1* is after *V2*` (for dates)
  - `*V1* is before *V2*` (for dates)
  - `*V1* is *V2* days after *V3*` (for dates and numbers)
  - `*V1* is *V2* months after *V3*` (calendar months, for dates). Given V3 and
    V2, the system works out V1: it keeps the same day of the month where that
    month has such a day, and otherwise takes the month's last day (31 August
    plus 6 months is 28 February). Given both dates, the system works out V2 as
    the number of WHOLE months between them (28 February is 6 months after 28
    August, while 27 February is only 5). Write a deadline as `a limit is 6
    months after the date and the other date is before or equal to the limit`,
    and never as "183 days": six months after 28 August is 184 days later.
  - `*V1* is known`
  - `*V1* is the case` (V1 a sentence: proves the sentence a variable holds —
    `the sentence is the case` — what `lib/deontic.le` checks an obligation's
    content with)
  - `*V1* is in *V2*` (V1 is one of the members of the list V2)
  - `the minimum of *V1* and *V2* is *V3*` (for numbers)
  - `the maximum of *V1* and *V2* is *V3*` (for numbers)
- **There are no `min`/`max` FUNCTIONS.** "The least of the limit and the repair
  cost" is a condition, not an expression. Write
  `and the minimum of L and R is P`, and never `and P = min(L, R)`. The system
  reads the second form without complaint and then fails while answering the
  query, with the message "min(A,B)/0 is not a function". The same goes for
  `max`.

### 7.1 Date Handling and Comparisons
Logical English treats a date as a value in its own right, like a number or a name:
- **Representation:** the system recognises a date as it reads the document, and holds it inside as a term of the form `date(Year, Month, Day)`, for example `date(2021, 10, 9)`.
- **Type System:** `date` is an ordinary type. Where a template declares a variable such as `*a date*`, the system adds the type `date` to the ontology by itself (??? to be confirmed).
- **Comparisons:** built-in templates compare two dates by the order of time:
  - `*V1* is after *V2*` (maps to `le_gt`)
  - `*V1* is before *V2*` (maps to `le_lt`)
  - `*V1* is after or equal to *V2*` (maps to `le_ge`)
  - `*V1* is before or equal to *V2*` (maps to `le_le`)
  Each of these becomes one of Prolog's standard comparison operators (`@>`, `@<`, `@>=`, `@=<`), which compare `date(Y, M, D)` terms in the right order of time.

## 8. Taxonomy (Ontology)
- **Is-a hierarchy:** `<Subtype> is a <Supertype>` or `<Subtype> is an <Supertype>`
- **Example:** `a student is a person.`

## 9. Ignorable Words
When the system matches a sentence against a template, it skips certain filler words, so that the sentence may be phrased naturally:
- `a`, `an`, `the`
- `is`, `are`, `was`, `were`
- `has`, `have`, `had`
- `do`, `does`, `did`, `been`

## 10. Comments
- **Line Comments:** `%` or `#`
- **Block Comments:** `/* ... */`

## 11. Meta-Templates
A template may take a whole sentence as one of its arguments.
- **Keywords:** `says`, `that`
- **Example:** `*the act* says that *the person* is liable.`
- **It is the case that:** introduces the consequence of a universal quantification, or wraps a statement.

## 12. Testing and Expectations
A scenario can state the answers a query is expected to give. The test runner then checks them.
- **Syntax:** `<QueryName> expects answers ["Answer 1", "Answer 2"] and unknowns ["Unknown 1"].` (The `and unknowns [...]` part is optional, and so is the word `answers`).
- **The answers, whatever they rest on:** `<QueryName> expects answers ["Answer 1"] and any unknowns.`
  Without an `and unknowns [...]` part, an expectation also says that the
  answers rest on no unknowns at all. With `and any unknowns`, the test checks
  the answers only: an answer that rests on unknowns passes, whichever they
  are. Use it where what an answer rests on is expected to change while the
  answer does not, for instance a program whose conditions are still being
  translated into rules.
- The expectation names the query directly — it must **not** be prefixed with
  `query` (a leading section keyword is reported as a misplaced expectation).
- **Flip queries** (§17.7) state their expected minimal change sets: `<QueryName> expects changes [["add: <fact>"], ["remove: <fact>", "add: <fact>"]].`
- **When they run:** the test runner (`runTests`, `runTestsFor/2`) runs every
  expectation. Verification, which happens each time the editor loads a
  program, runs them too, as far as a time allowance permits (the Prolog setting
  `le_verify_tests_seconds`, 5 seconds by default). The system reports the tests
  left over once, as a `tests_not_run` warning, so that a program with many
  scenarios still opens quickly.
- **Example:**
  ```le
  scenario alice is:
      John is born in the UK on 2021-10-09.
      one expects answers ["John acquires British citizenship on 2021-10-09"] and unknowns ["John is a good person"].
      two expects ["John is a British citizen"].
      three expects ["John acquires British citizenship on 2021-10-09"] and any unknowns.
  ```

## 13. System Predicates
Logical English provides several built-in predicates — named relations the system itself defines. A program reaches them through the `prolog` keyword (§15.6), and they also let a program ask questions about itself.

- **`le_my_kb(KB)`**: gives `KB` the name of the knowledge base being run.
- **`le_my_id(ID)`**: gives `ID` the identifier of the rule or fact being used.
- **`le_type(Type)`**: true where `Type` is a type the ontology or the templates define.
- **`is_a(Subtype, Supertype)`**: true where `Subtype` comes under `Supertype` in the taxonomy.
- **`le_source_element(RuleID, Designator, Goal)`**: says which condition of a numbered rule each designator, such as `1.1.a`, points at.
- **`le_source_section(SectionName, RuleID)`**: says which section each rule belongs to (see §3.1). A rule with no section marker above it belongs to `main`.
- **`le_source_info(Ref, Start, End, ID)`**: gives the place in the source file — the first and last character — and the identifier of the rule or fact referred to.
- **`le_issue(Severity, Type, Description, Fix, Start, End)`**: one problem found while reading or checking the program, either an error or a warning.
- **`le_dict(dict(FunctorArgs, NamedTypes, WordsAndVars))`**: holds a template as the system stores it inside.
- **`le_kb(Name)`**: holds the name the source gives the knowledge base.
- **`scenario(Name, Facts)`**: holds the facts of a named scenario.
- **`query_info(Name, Goal, Items)`**: holds what the system knows about a named query.
- **`le_expected(QueryName, ScenarioName, ExpectedAnswers)`**: holds the answers a query is expected to give in a scenario.
- **`ontology(Content)`**: holds the ontology section exactly as it was written.

## 14. Included Resources
A Logical English program can include other LE programs, by writing an `includes these resources:` header.
- **Syntax:**
  ```le
  the knowledge base myKB includes these resources:
      Resource1, Resource2.
  ```
- **Resources:** a resource is either a file path written relative to the program (`royal_family`, say) or a web address (`https://le2.logicalcontracts.com/source/royal_family`). Writing `.le` at the end is not necessary.
- **Behavior:** the system adds the included rules, facts, templates and ontology to the knowledge base that includes them, and uses them when it answers a query. It ignores the scenarios and the queries of an included resource.
- **Transitivity:** an included resource may include others in its turn, up to a limit on the length of the chain (the Prolog setting `le_include_max_depth`, 5 by default). The system notices a resource included twice, and a circle of includes, and skips it. It works out each resource's path **relative to the file that includes it**, that is, relative to that file's own folder, or to its folder on the web.
- **Local-path restriction:** a resource that is a file on the same machine may be included only where the file lies under the folder of the file that includes it, or where the file is one anyone may read on the server, allowed by `restricted_paths`. A resource at an `http(s)` address elsewhere carries no such restriction.
- **Source positions:** the system reads each included `.le` resource with the positions of its characters shifted into a range of its own (a multiple of `le_grammar:resource_offset_unit/1`, one range per resource, `le_kbs:resource_base/2`). Nothing recorded for a resource — where a rule begins and ends, a rule's identifier, a condition, a problem found, a note of where a fact comes from — is then confused with the document that includes it. Every reply of the server's `/leapi` address marks a range that falls inside a resource with `resource`, `resourceExample`, `resourceLine`, `resourceStart` and `resourceEnd` (`le_kbs:annotate_resource_ranges/2`). The editor then opens the resource at that line in a new tab, rather than selecting text in the document on screen; this happens for a step of an explanation, for a node of the graph and for *Show definition*. The editor shows a resource's problems on the `includes these resources:` section, and a printed message names the file and the line, `(apparel.le, line 53)`.

### 14.1 Prolog resources (`.pl`)
A resource whose name ends in `.pl`, whether a file or a web address, is a **Prolog resource**. Such a resource backs an LE knowledge base with a file of Prolog facts and predicates — a large lookup table, for instance. The LE program reaches that file through a *thin layer*: a few templates, and rules whose conditions are `prolog` goals (§15.6). The main program includes the layer, and the layer includes the `.pl` file:
```le
% layer.le
the knowledge base layer includes these resources:
    postcodes_facts.pl.
the templates are:
    *a postcode* is in *a region*.
the knowledge base layer includes:
    a postcode is in a region if
        prolog postcode_region(the postcode, the region).
```
- **The system only stores the file's clauses, and never runs the file** (it never uses `consult`). It stores the clauses in a module of their own, named after the content of the file, which a reasoning session then imports. While loading, the system obeys only three directives: `dynamic/1`, `discontiguous/1` and `use_module(library(...))`. It removes a `:- module(...)` directive, with a warning, and loads the clauses that follow anyway, and it skips every other directive with a warning. A `.pl` file fetched from elsewhere therefore cannot run code merely by being included.
- **Safety while a query runs:** `library(sandbox)` checks every goal of a `prolog` condition before the goal runs. LE's own predicates are allowed through, since they only read information and change nothing. An installation that trusts its programs can switch the check off, by setting the Prolog setting `le_sandbox_prolog` to `false`.
- **Loading once:** the system loads a `.pl` file again when the time the file was last changed moves on, and it fetches a `.pl` at a web address once per run of the server. Editing the LE program therefore does not load a large file of facts all over again.
- See `examples/moreExamples/language/includes/prolog_resources/` (postcodes: main → thin layer → facts `.pl`).

### 14.2 Shipped libraries (`lib/`)
A library is an ordinary LE resource kept in `lib/`. The system copies a
library next to the program that includes it (`le_migration:copy_library/2`
does the copying for the translators), so that a program and its libraries sit
in one directory.
- **`lib/temporal.le`** (+ `temporal.pl`) — dates, periods and lock times:
  `the age on *a date* of someone born on *a birth date* is *a number*`,
  whole years / months / days between two dates, `*a later date* is *a number*
  years after *a date*`, `... calendar months after ...`, `*a date* is in the
  period from *a start date* to *an end date*`, `*a date* is within the last
  *a number* months before *a reference date*` (and `days`), the first and last
  day of a month, year / month / weekday of a date, leap years, and Bitcoin
  lock times (`the lock time *a number* is a block height` / `is a time`,
  `block *a height* is at least *a number* blocks after block *a first
  height*`). Each template is answered by the predicate of `temporal.pl` named
  after it, so the library is part of core LE. The verifier does not report the
  library's own templates as untested in a program that includes it. See
  `testing/fixtures/temporal/uses_temporal.le`.
- **`lib/deontic.le`** — obligations, permissions and prohibitions (the
  deontic pattern library): `*a party* is obliged / permitted / forbidden that
  *a sentence*`, `the obligation (prohibition) of *a party* that *a sentence*
  is violated`, `*a party* complies with the obligation that *a sentence*`,
  `*a party* is in breach`. A program concludes the deontic statements; the
  library says when one is violated (an obligation's sentence not the case, a
  prohibition's the case) and a program's reparation is a rule concluding a
  new obligation from a violation: `a person is obliged that the person pays
  200 penalty units if the prohibition of the person that the person engages
  in a credit activity is violated`. The library says nothing about time: it
  says who is bound, and what is violated, in one case. The translator for
  LegalRuleML (InsurLE2 Phase 2f) writes its programs with this library.

## 15. LE Extensions
This section covers features beyond the core constructs summarised above.
Three of them are part of core LE and are documented here: `only if` rules
(§15.1), rule labels with their provenance (§15.5) and embedded `prolog` goals
(§15.6). The other constructs of this section — `which` relative clauses
(§15.2), `unless` inside a rule's conditions (§15.3), grouped alternatives
`either:` / `any of:` / `at least one of:` / `all of:` (§15.4), numbered rule
bodies (§15.5) and prepositional chaining (§15.7) — need the proprietary
`le_extensions.pl` module, which is installed where Logical English is offered
as a hosted service. Without that module those constructs are unavailable. They
are documented, under the same section numbers, in [LE
Extensions](extensions.md).

### 15.1 `only if` rules (necessary conditions)
`Head only if Body.` says that Body is a **necessary** condition for Head,
which is the rule read the other way round. The system turns the sentence into
the rule *"opposite-of-Head if it is not the case that Body"*:
- Where the head's template declares an `; opposite:` form, that form is what
  the derived rule concludes, so the program can say in so many words
  `we will not pay X` when a condition for paying fails.
- Without a declared opposite, the conclusion is the plain negation of Head.
```le
the templates are:
    I will marry *a woman*; opposite I will not marry *a woman*.
    I love *a woman*.

I will marry a woman if the woman is "Alice".   % sufficient condition
I will marry a woman only if I love the woman.  % necessary condition:
                                                % I will not marry W if
                                                % it is not the case that I love W
```
An ordinary `if` rule gives a sufficient condition. An `only if` rule acts as a
constraint instead, and produces negative conclusions. See
`examples/moreExamples/language/negation/only_if.le`.

### 15.5 Rule labels and provenance
A rule may be labelled: `rule <name>: Head if ...`. The label becomes the
rule's identifier, which `le_source_element/3` and `le_source_info/4` show
(§13). A label may also point at where the rule comes from — this is core LE
and needs no extension — naming a document and, where possible, a place in
it:
```le
rule note_61_4_pockets with provenance HTSUS Chapter 61,
        confer "Headings 6105 and 6106 do not cover garments with pockets below the waist":
a garment is excluded from heading a heading
    if heading the heading is a shirt heading
    and the garment has pockets below the waist.
```
Write `with provenance <document>`, where the document is a name, or a quoted
piece of text such as a web address (`with provenance
"https://example.org/act.html#s2"`). After it may come `at <locator>` (`at
section 4`), or `, confer "<passage>"`, a quotation of the document (§17.1).
The trailers a fact may carry (`according to`, `as stated in`, `because`) are
accepted here too. The system records the provenance as
`le_rule_provenance(ID, Prov)`, with Prov shaped as it is for a fact. The
provenance changes nothing in the proof; explanations and the editor show it
(§17.1, *Documents*). The header of a decision table takes the same addition:
`the table apparel is, with first match, with provenance ...:`, recorded under
the table's identifier, `table_<name>`.

### 15.6 Embedded Prolog goals
A condition of the form `prolog <goal>` runs a goal written directly in
Prolog. Put two or more goals in brackets: `prolog (g1, g2)`. Inside the goal,
an LE variable is written as a `the <name>` phrase, as a `*a name*` marker, or
as an ALL-CAPS id, and it takes the value the goal finds for it. Such goals
commonly use the built-in predicates of §13, and a Prolog resource (§14.1) is
reached this way:
```le
an id has designator a d if
    prolog (le_my_kb(KB), KB:le_source_element(the id, the d, the g)).

a postcode is in a region if
    prolog postcode_region(the postcode, the region).
```
- **Safety:** `library(sandbox)` checks every `prolog` goal before the goal
  runs (§14.1). A goal it rejects stops the query with an error.
- **Explanations** show the goal as a built-in step. The other target
  languages do not run such a goal; s(CASP) reports it as unsupported
  ([scasp.md](scasp.md)).
- **Remembered answers:** the verifier reports a memorable template (§2.4)
  whose rules call a `prolog` goal (`memorable_calls_prolog`), because a goal
  that changes something elsewhere could leave the remembered answers out of
  date.

See `examples/moreExamples/language/prolog/prolog_call.le`,
`language/includes/prolog_resources/` and `language/rules/rule_id_test.le`.

## 16. Humanizing LE
Lawyers and other domain experts read LE programs more often than they write
them. The guidelines below use the features above to keep a program close to
ordinary prose:

- **Use `only if` for necessary conditions.** Policy text says "we will pay
  only if the premium has been paid" — write exactly that, and declare the
  natural `; opposite:` form so the derived negative conclusion reads as the
  drafter would say it (`we will not pay ...`).
- **Use prepositional additions to chain within one sentence.** Declare
  `; prepositional` for relations that read as prepositional phrases, so a
  condition can flow as `we will make a payment under this policy in respect
  of a claim` instead of three stilted sentences repeating the subject.
- **Use `which` to continue a thought.** `a parent of a child which is an
  ancestor of the descendant` avoids inventing and repeating a second
  variable name.
- **Use `unless` for exceptions.** `unless the claim is fraudulent` reads far
  better than `and it is not the case that the claim is fraudulent` when the
  source text frames it as an exception.
- **Use `either:` / `any of:` blocks** for enumerated alternatives instead of
  deeply nested `or` lines — especially when the source text is itself a
  list.
- **Mirror the source document's structure**: name rules with `rule <label>:`
  after the clause they encode, use numbered bodies when the clause is a
  numbered list, group rules with `section ... is:` / the annexes header, and
  cite the clause in a `%` comment. Traceability is readability.
- **Declare `; synonym:` forms** so that a fact, a line of a scenario and a
  query can each use the phrasing most natural where it stands. An explanation
  shows each sentence in the wording it was written in.
- **Keep template wording close to the source text**, and let the ignorable
  words (a/an/the/is/are...) carry the grammar. Prefer several short templates,
  each with its parts in plain sight, over one template the length of a whole
  sentence, which hides the logic inside it.
- **Say how each statement is known**, with `; assumable` for a matter of
  expert judgment and `; undefined` for the data of a case. A reader then sees
  at once which statements are evidence, which are judgment calls, and which
  the rules work out.
- **Name individuals meaningfully**: determiner-free, descriptive constants
  (`claim one`, `wrist injury`, `United Kingdom`) — they appear verbatim in
  answers and explanations.

## 17. Regulatory-decision constructs
This section covers the constructs for programs that apply written rules to
recorded cases. Such a program has the shape of a regulatory decision: is the
rule applicable, what is the answer to the one contested question, and what
follows. Every fact has a source, and someone decides the contested question.
Examples live in `examples/regulatory/`, and `eu261_integration.le` uses all of
these constructs together on the facts of the Wallentin-Hermann judgment of the
Court of Justice of the European Union. Two larger applications
are there too. `examples/regulatory/customs/` classifies goods under a tariff —
the General Rules of Interpretation and the notes of Chapters 39, 61 and 62,
run on rulings of US Customs and Border Protection and on EU binding tariff
informations. `examples/regulatory/medicare/` holds the 58 coverage policies
for durable medical equipment, run on claims and on decisions of the Medicare
Appeals Council. Both are examples, provided "as is" and not advice: each
program's opening comment says so in full.

### 17.1 Provenance trailers and judged templates
Any fact of a scenario, and any fact of the knowledge base, may carry
**trailers**. Each trailer comes after a comma, and they may be written in any
order:

| Trailer | Meaning |
|---|---|
| `according to <source>` | who asserts the fact — a party, a witness, a document type, a service, a court. `<source>` is an ordinary constant. |
| `as stated in <document> at <locator>` | where it is written (`at <locator>` is optional). Without `according to`, the document is the source. |
| `because "<text>"` | the rationale. |
| `confer "<passage>"` | a quotation of the passage of the document that states the fact (the document is the one given by `as stated in`, or the scenario's default). |

```le
scenario decided is:
    claim one is for the burst pipe, as stated in the claim form at section 2.
    the burst pipe is accidental,
        according to the loss adjuster, as stated in report LA-17 at page 3,
        because "corrosion was not visible on inspection".
```
The trailers may begin on the fact's own line, or on the next line, in which
case the fact's line ends with the comma.

**A scenario's default provenance.** A scenario usually takes all its facts
from one document. The scenario's header then names that document once, and
each fact only points at its own passage:
```le
scenario ny_n362700 is, as stated in ruling NY N362700:
    style 1025AD is an upper body garment,
        confer "is a men’s upper body garment constructed from 92 percent polyester".
    style 1025AD is napped.
    style 1000AD has pockets below the waist,
        according to CBP, confer "a portion of each of these pockets is below the waist".
    style 1025AD is shown in the catalogue, as stated in the importer's catalogue at page 3.
```
A fact with no trailers takes the default. A fact whose trailers name no
document (`confer`, `according to`, `because`) takes the default document. A
fact with an `as stated in` of its own names another document instead. A comma
that is *not* followed by a trailer keyword stays part of the fact, as
always.

- **The proof is unaffected.** The system reads the fact exactly as it would
  without the trailers. It records the provenance beside the fact
  (`le_fact_provenance/4`, filed under the place in the source where the fact
  is written), and every session that loads the scenario is given
  `le_provenance(Fact, Source, Document, Locator, Rationale)`. A part that is
  missing is `none`, and where no `according to` is written the source is the
  document.
- **Explanations** show a proved fact with its trailers, as written:
  `the burst pipe is accidental, according to the loss adjuster, as stated in report LA-17 at page 3, because "..."`.
- **`scenario facts require provenance.`** — a statement about the program as
  a whole, written after the target-language line. Every scenario fact without
  a trailer then earns a `fact_without_provenance` warning.
- **`; judged`** (a template addition, §2): someone decides the matter, and
  the rules do not work it out. The system solves such a template as it solves
  `; assumable`, except for the rule about outcomes below. The effects
  are:
  - a rule that concludes a judged template is an **error**
    (`judged_with_rules`);
  - a judged fact in a scenario without `according to` or `because` gets a
    `judgment_without_provenance` warning;
  - a sentence still open, one the system has assumed, is shown in an
    explanation as `the burst pipe is accidental (judgment needed)`, while the
    answer's list of unknowns is unchanged (`"the burst pipe is
    accidental"`);
  - **the last argument is the outcome**, where the template has two arguments
    or more, just as it is for a service (§17.6). The template `the principal
    use of *a good* is *a use*; judged.` asks one question per good. Once an
    outcome has been recorded for a question (`the principal use of the bin is
    household use, according to CBP, ...`), the system assumes no other outcome
    of that question. A question with nothing recorded stays open, with one
    judgment needed for each outcome the rules try. So phrase a judged template
    with its outcome last (`the claim that *a good* is *a kind* is *an
    outcome*`), rather than as a bare relation between two things.

**Documents.** A document that a fact cites is an ordinary constant (`ruling
NY N362700`, `the benefit act`) or a quoted piece of text, such as a web
address. Two built-in templates say where the document is:
```le
ruling NY N362700 is published at "https://rulings.cbp.gov/ruling/N362700".
the text of ruling NY N362700 is at "sources/cbp/N362700.txt".
```
The first fact gives the page a reader opens. The second gives the plain text
of the document. That text is either a file beside the program, which the
system looks for in the program's folder and never outside it, or a web
address. At a web address the system reads the `text` field of a reply in JSON,
a common format for data passed between programs, or the text of the page where
the reply is a web page; it does not read a PDF. Neither fact needs a
provenance of its own. With the two facts in place:
- the verifier checks a **quotation** — `confer "a zipper garage at the top of
  the collar"`, or a quoted locator `at "..."` — against the document's text,
  where that text is a file beside the program. It ignores differences of white
  space, of no-break spaces and of letter case, and warns `quote_not_found`
  where it cannot find the passage;
- every step of an explanation proved by a cited fact, or by a labelled rule,
  carries its provenance (`provenance: {source, document, locator, quote,
  rationale, url, text}`, and `rule` as well for a rule), and the editor marks
  the step with a **§** badge. The source viewer then shows the document's text
  with the quoted passage highlighted, and *Open original* opens the published
  address; where that address has no anchor of its own, the editor adds a
  `#:~:text=` fragment so that the browser jumps to the quotation. The server's
  `documentText` operation delivers the text. A step also carries a `plain`
  field, its sentence without the trailers, for a screen that shows the
  citation apart — the executive view lists an answer's cited steps that
  way;
- in the program itself, the editor's context menu offers **Show original
  text** on any line that cites a document with an address: a fact with
  provenance, the `with provenance` label of a rule or a table and the lines
  under it, a scenario "as stated in" a document (its header and its facts),
  and a `... is published at` or `the text of ... is at` statement. The editor
  opens the same source viewer, on the passage the line quotes. Where only the
  published address is known, that page opens instead. The reply that loads the
  program lists these lines (`citations`), and the `provenanceAt` operation
  says which document the line under the cursor cites. That is the innermost
  citation, so a fact naming a document of its own is not shown its scenario's
  document.

**The values a place reads.** For each place of a scenario template, the
program itself says which values matter: the values its rules read in that
place. The system finds them one step along the rules — the facts of a relation
that shares the variable, the members of a list the variable is tested against
(`is in [...]`), the constants written where the value flows into a conclusion,
and the column of a decision table. The editor's fact forms, in the Scenario
Editor and in Scenario Variations, offer those values in the field as
suggestions, and the prompt that draws facts from a document lists them too.
The verifier warns **`unread_value`** where a scenario fact puts in such a
place a value that no rule, fact or table row of the program mentions, and one
of the values the rules do read is close to it: `the fabric construction of
style A is knit` where the rules read knitted, woven and so on — "Did you mean
knitted?". A value that resembles none of them, such as a free description or a
name, is not reported.

See `examples/regulatory/judged_damage.le`, and the customs and Medicare
programs (`examples/regulatory/customs/`,
`examples/regulatory/medicare/`), where every rule, table and fact cites its passage.

### 17.2 `otherwise` cascades
A line of conditions that **opens** with `otherwise` starts a new alternative.
The word binds more loosely than `and` and `or`: everything written before it,
in the same block, is the previous alternative.
```le
the discount rate for a customer is a rate
    if the customer is a member and the rate is 20
    otherwise the customer is a student and the rate is 10
    otherwise the rate is 0.
```
`A otherwise B` means `A`, or else — only where `A` fails — `B`. The system
turns the pair into `A or (it is not the case that A, and B)`, so the failure
of every earlier alternative guards each alternative, and exactly one of them
applies. Details:
- **The guard is the conditions of the earlier alternative.** A condition that
  only sets a result (`and the rate is 20`, which gives a value to a variable no
  other condition of the alternative uses) is left out of the guard. Asking "is
  the discount rate for ann 10?" therefore does not pass the guard merely
  because 10 is not 20. The system decides this from the words alone: it takes
  a variable for a result whenever no other condition of the alternative
  mentions it, even where the rule gave that variable a value *before* the
  cascade. So an alternative that ends by testing such a variable (`… and the
  code is equal to "X"`) loses that test from the next alternative's guard.
  Write the test with the constant first (`"X" is equal to the code`), and the
  guard keeps it.
- **Decide one case at a time.** The guard works by failing to prove
  something, so its variables should already have values when the cascade is
  reached. Find the individual first — in the rule that calls this one, for
  instance: `if the customer is a customer and the discount rate for the
  customer is the rate` — and then let the cascade decide.
- **Layout.** Only a line that *starts* with the keyword is a cascade line;
  `the claim is otherwise covered` is an ordinary sentence. Inside a nested
  block — under `it is not the case that`, say — indentation bounds a cascade as
  it bounds any other condition. The system splits a line such as `the customer
  is a member and the rate is 20` at its `and`, where reading the line whole
  would match only a catch-all pattern (`... is a ...`, `... is ...`, or a
  comparison such as `... = ...`) and each part reads on its own. This holds
  whichever side of the catch-all had swallowed the `and`. A one-line
  alternative (`otherwise the guest has an unbirthday today and the percentage
  is 10`) therefore means the same as the same alternative split over two
  lines.
- **Explanations** show a guard that failed as a negation pointing at the
  `otherwise` line: `it is not the case that cy is a member`.

See `examples/regulatory/otherwise_table.le`.

### 17.3 Decision tables
A **decision table** writes one relation as a grid, with a column for each
argument and a row for each case. A table belongs to the ONE template whose
words name it: the template says `under table <name>`, and the table says `the
table <name> is`:

```le
the templates are:
    the shipping cost for a weight of *a number* kg is *a cost* under table shipping.

the table shipping is, with first match:
    band | weight kg          | cost
    s    | <= 1               | 5
    m    | > 1 and <= 10      | 12
    l    | > 10               | 30
```

Read a row as a rule. The row `m` says *the shipping cost for a weight of a
weight kg is 12 if the weight > 1 and the weight <= 10*, and that is also what
the system turns the row into, so a query, an explanation and the verifier all
see ordinary rules about `the shipping cost …`. What the grid adds is what
rules cannot say in one place: the order in which to try the rows, and what to
do where more than one row fits (the **hit policy**, below).

**Where a table is written.** A table may stand wherever a rule may stand: as
a section of its own, as above, among the rules of a knowledge base, or,
indented with them, among the facts of a scenario. The table ends at the first
line that is not a row, that is, the first line without a `|`, and the rules or
facts after it go on as before.

A table written in a **scenario** belongs to that scenario, exactly as its
facts do. The table answers only while that scenario is the case, and it
**takes the place of** a table of the same name written elsewhere. That is how
a case brings its own rates, its own price list, its own schedule:

```le
scenario year 2025 is:
    the income of ann is 20000.
    the table rates is, with first match:
        band | income   | rate
        low  | <= 10000 | 5
        high | > 10000  | 30
```

Only an **indented** table belongs to a scenario, in the way its facts are
indented. A table written at the margin after a scenario is a section of its
own: the table for the whole program, as it has always been.

A table of a **single column** is the exception. With no `|` to go by, the
system cannot tell its rows from ordinary sentences, so the rows run on to the
next section. Write such a table as a section of its own.

**Asking the table.** `under table shipping` is part of the template's words,
so a rule (or a query) that consults the table writes them too:

```le
the shipping cost for a customer is a cost
    if the order of the customer weighs a number kg
    and the shipping cost for a weight of the number kg is the cost under table shipping.
```

**The header line.** `the table <name> is`, then, in this order and each of them optional:

| Written | Meaning |
|---|---|
| `loaded from <file>.csv` | the rows are in a CSV file — comma-separated values — and not in the section (*Rows in a file*, below) |
| `, with first match` / `, with unique match` / `, with all matches` | the hit policy, which says what to do when more than one row fits; saying nothing means `with unique match` |
| `, with provenance <document>` | the document this table encodes, exactly as for a labelled rule (§17.1) — and the document a `confer` column's passages are in |

and then `:`. The provenance may carry the passage that the table as a whole
puts into rules, just as a rule's provenance may:
`, with provenance <document>, confer "<passage>"`.

**Columns and arguments.** The columns are the template's arguments, **in
order**. The **last** column is the one the table concludes, and the columns
before it are what the table is given. Two columns are not arguments:

- **A row name**, in one extra column at the front. An explanation then cites
  the row by that name (`row m of table shipping`); without such a column, an
  explanation cites the row by its number (`row 2`).
- **A citation column**, anywhere (*Citing a passage per row*, below).

The system reports `table_arity_mismatch` where the columns that are left do
not match the template's arguments.

**What a cell may say.** A cell of an **input** column says what that argument has to be:

| Cell | Matches |
|---|---|
| a value — `silk`, `5`, `"Of silk"`, `2026-08-31` | that value, read exactly as the same words in a scenario would be |
| nothing at all, `-`, or `any` | anything: this column says nothing about this row |
| `silk or wool or cotton` | any one of those values |
| `> 1 and <= 10` | a condition: `<`, `<=`, `>`, `>=`, `=`, `!=` (`=<` and `==` are accepted too), joined by `and` / `or` |

A cell counts as a condition only where *every* part of it is a condition, so
a value whose own words include `and` or `or` is still that value (`with acute
and chronic bronchitis`).

A cell of the **last** column is the answer, not a test. Such a cell holds a
value, or several values joined by `or`, which then answer one at a time. The
system reports `table_bad_output` for anything else.

An input whose cell in some row is a **condition** must already have a value by
the time the table is consulted, because a condition can be checked against a
value but cannot produce one. Asking the table while such an input has no value
is an error while the query runs, and the message names that column.

**Hit policies.** The rows are tried from the top.

| Policy | When more than one row fits | For |
|---|---|---|
| `with first match` | the first one answers and the rest are not tried | bands and cascades, where the last rows are the general case |
| `with unique match` (the default) | a run-time error naming the rows: the table claimed the case was unambiguous, and it was not | tables whose rows are meant to be mutually exclusive |
| `with all matches` | every row that fits answers, one answer each | a relation rather than a function — a code list, a table of pairs |

`with unique match` complains only about a case the table was actually asked
about: several rows may well fit an input that is still unknown.

**Rows in a file.** A long table lives in a CSV file beside the program, or in
a directory under it. The section then holds the header line and the column
headings, and nothing else:

```le
the table postcode_region is loaded from postcodes.csv, with unique match:
    postcode | region
```

Cells are read as above, with two differences that matter for data:

- **The output cell of a CSV row is always a value**, even when its text
  contains `or` or `and` (`Duchenne or Becker muscular dystrophy` is one
  answer, not two).
- **Codes keep their shape.** A cell of text is re-quoted as it is read, so
  `012` or `G71.01` stays that code instead of becoming the number 12.

The system skips a first row of the CSV file that merely repeats the column
headings. It keeps the rows in memory, and reads them again when the file
changes. A table loaded from a file has no citation column, and the system
reports `table_csv_missing` where the file is not there. A scenario's table may
be loaded from a file too, so that a case can bring its own data file.

**Citing a passage per row.** One column of a table written in the program may cite, row by row, the passage
that row encodes — a band's line of a statute, a subheading's line of a
tariff. Its heading is `confer`, for passages of the document the table's
`with provenance` names, or `as stated in <document>`, for passages of another
one. Each cell is a quoted passage, or empty:

```le
the table woven is, with first match, with provenance HTSUS General Rules of Interpretation,
        confer "the classification of goods in the subheadings of a heading ...":
    row | heading | material | code      | as stated in HTSUS Chapter 62
    w93 | 6214    | silk     | "6214.10" | "Of silk or silk waste:6214.10"
```

The system sets the citation column aside before it matches the other columns
to the template's arguments, so the citation column is not one of them. Each
row's passage becomes that row's provenance, exactly as a fact's passage does
(§17.1). The explanation's step for the row carries the provenance, and its
**§** badge opens the passage; *View Original Text* on the row finds the
passage too; and the verifier checks the quotation against the document's text
(`quote_not_found`).

**What the system makes of a table.** It writes one rule for the template,
`Head :- le_table(Name, Args)`, and one record for each row (`le_table/6`,
`le_table_row/6`, filed under the table's name — or under
`in_scenario(<scenario>, <name>)` for a table written in a scenario, which is
how one name can hold different rows in different scenarios). The template is
tied to a table once, whichever table is written first. Which table answers is
decided while the query runs, from the scenario the session has loaded. An
explanation cites the row that answered — `row m of table shipping` — and for a
table written in the program that citation points at the row's own line.

The system reports these problems as it loads the program:
`table_without_template` (no template says `under table <name>`),
`table_arity_mismatch`, `table_row_width` (a row with the wrong number of
cells), `table_bad_cell`, `table_bad_output` and `table_csv_missing`.

See `examples/regulatory/otherwise_table.le`, `loaded_table.le`
(+ `shipping.csv`) and `scenario_table.le` (a table per scenario), and §16 of the [gentle
introduction](../tutorials/intro-to-le/intro-to-le.md#a-decision-table) for a
table in a worked program.

### 17.4 The decision skeleton: applicability, question, remedy
This needs no new keyword. The large-scale shape of a decision — *is the rule
applicable, what is the answer to the question, what follows* — is written with
the ordinary section markers (§3.1), using three reserved names. Each language
has its own three, listed in `i18n/keywords.csv`:
```le
section applicability is:
a person is in scope if the person is resident.
section question is:
a person is eligible for help if the person is in scope and the person is on a low income.
section remedy is:
the help for a person is an amount if the person is eligible for help and ...
```
Answering a query is unchanged. What the three names add is a way of reading a
query that **fails**:
- **`the query fails at section *a section*`** (also `the query fails at *a section*`)
  — a built-in template. It is true when the program's first query, called
  "the query", has no answer, and it names the section where the query fails.
  That section is the earliest one in checklist order (applicability, question,
  remedy, and then any other named section in the order it is written) that
  holds a rule for something the attempt tried to prove and could not. `the
  query *a name* fails at section *a section*` does the same for a named
  query.
  ```le
  query stage is:
      the query fails at which section.
  ```
  answers `the query fails at applicability` for a non-resident.
- **The explanation of a failure leads with the checklist**:
  `section checklist: applicability passed, question failed, remedy not reached`.
  A program that does not use the reserved names is unaffected.

See `examples/regulatory/sections_benefit.le`.

### 17.5 Source-scoped proof: `according to` in a rule
Among the conditions of a rule, or of a query, `according to <scope>` limits
the proof of the conditions before it to the evidence of one source. This is
how the burden of proof is written:
```le
a tenant owes the late penalty
    if the rent of the tenant is overdue
    and the notice was delivered to the tenant
        according to the landlord.

the courier is admissible under the landlord.
```
`G according to S` is true when, and only when, G can be proved from the
program's own rules and facts together with only those **scenario facts** whose
source is **admissible under S**. A fact's source is the one its `according to`
names, or failing that the document of its `as stated in` (§17.1). A scenario
fact with no provenance is never admissible inside a scoped proof. The facts of
the knowledge base always are, because they are rules rather than evidence.
- **Layout.** Write `according to <scope>` on its own line, indented under one
  condition, and it scopes that condition. Write it on a line after several
  conditions at the same level, and it scopes all of them — the conditions of
  an `it is not the case that` block, for instance. It may also be written at
  the end of the condition's own line.
- **Admissibility** is the built-in template `*a source* is admissible under *a scope*`.
  On its own it holds only where the source and the scope are the same, and a
  program adds facts or rules to widen it
  (`the maintenance log is admissible under the carrier.`).
- **The scope** is an ordinary value: a constant (`the landlord`), a variable
  the rule introduced earlier, or a new variable — `according to a party` gives
  the party whose evidence establishes the condition.
- **Presumptions** need no syntax: `G if it is not the case that <not-G>
  according to <the other side>`.
- **Explanations** show `the notice was delivered to ann according to the
  landlord`. A scoped proof that fails lists the evidence it could not use:
  `the notice was delivered to ann, according to ann, is not admissible under the landlord`.
- The s(CASP) engine does not offer this.

See `examples/regulatory/scoped_notice.le`.

### 17.6 Services and semantic predicates over text
Some questions cannot be decided by rules, because their arguments are free
text: "is this description a vehicle?". A program may declare **services** and
have them answer such templates:
```le
the knowledge base semantic match includes these services:
    matcher at https://models.example.org/match as a semantic matcher,
    classifier at llm:openai/gpt-oss-120b as a semantic matcher.

the templates are:
    the best match of *a text* among *a list* is *a category*; via service matcher.
```
- **Declaration**: write `the knowledge base <name> includes these services:`
  and then `<name> at <address> as a <kind>` for each service, separated by
  commas and ending with a full stop. An address takes one of three forms. With
  `http(s)://...` the system sends the question to that address as JSON, and
  the reply reads `{"answers": [[arg, ...], ...], "rationale": "..."}`. With
  `llm:<model>` the system asks a large language model through
  `llm/llm_client.pl` — `llm:openai/gpt-oss-120b` on Groq with `GROQ_API_KEY`,
  for example — giving it the template and the arguments already known. With
  `stub:matcher` or `stub:judge` the system asks a stand-in used for testing,
  which always answers the same way; the LE server offers these at
  `/test_services/<name>`.
- **`; via service <name>`** (a template addition): that service answers the
  questions asked of the template. The **last** argument may be unknown, and
  the service fills it in. Every other argument must already have a value when
  the question is reached; otherwise the query stops with an error. Where every
  argument is known, the service answers yes or no.
- **Built-in semantic templates**, backed by the program's first service
  declared `as a semantic matcher`:
  `*a text* is semantically similar to *a second text*`,
  `the best match of *a text* among *a list* is *an item*`,
  `*a text* satisfies the description *a description*`.
- **Ask once, keep the answer.** The system makes each distinct request
  **once per session**. Two requests differ when they differ in the service, in
  the template, in the inputs written in one standard way (spacing in text made
  regular, lists sorted), in the service's version (its address, or the model),
  or in the version of the request format. Where the Prolog setting
  `le_service_cache_dir` names a directory, the system also keeps the answers
  there, filed under the request itself rather than under the program, and
  reuses them in later sessions and in other programs. It refuses an answer
  stored for another model or another version.
- **Attribution.** An answer enters the proof credited to the service. Its
  explanation reads `the best match of ... is vehicle, according to service
  matcher, because "<the service's rationale>"`, and a scoped proof (§17.5)
  admits the answer only under `according to service matcher`, or under a scope
  the service is admissible under.
- **A service that cannot be reached**: with no answer kept from before, the
  question becomes an unknown. The query still answers, on that condition, and
  nothing breaks.
- **Writing the answers down**:
  `le_services:service_materialise(Session, KB, Lines)` writes the answers a
  session used as ordinary scenario facts (`the best match of "..." among [...]
  is vehicle, according to service matcher, as stated in cache at <hash>.`). A
  program that carries those facts runs without the service and without the
  kept answers, which is what makes a run reproducible.
- The verifier reports `service_undeclared` as an error where `; via service
  X` names a service X the program does not declare, and where a built-in
  semantic template is used with no semantic matcher declared.

See `examples/regulatory/semantic_match.le` (a stand-in service, with tests)
and `semantic_llm.le` (a classifier that uses a large language model; it states
no expected answers, because its answers depend on the model).

### 17.7 Flip queries: which minimal change flips the outcome
```le
query flip_rich is:
    which minimal change to the scenario makes it the case that
        rich gets help to pay rent.

query flip_bob is:
    which minimal change to the scenario makes it the case that
        it is not the case that bob gets help to pay rent.
```
The answers are the **smallest sets of changes** that do the job: the smallest
number of changes, and every set of that size that works. After such a set of
changes, the goal holds outright, with nothing assumed — or, for `it is not the
case that G`, G no longer has any proof at all. One change **adds** or
**removes** one fact of a scenario-element template, that is, of a template
marked `; undefined` or `; judged` (§17.1). In a program that marks none, a
change may touch any template that no rule concludes. A flip never changes what
the rules work out for themselves.
- An answer is written out as its changes: `add: rich is on a low income`.
  Several changes are joined with `and`, and an answer reads `no change is
  needed` where the goal already holds. The proof that the changed scenario
  gives explains the answer.
- An undecided instance of a judged template is a one-step change like any
  other, namely a judgment (`add: the burst pipe is accidental`).
- **Expectations**: `flip_bob expects changes [["remove: bob is on a low income"], ["remove: bob is on other benefits"]].`
  (order-insensitive, within and between sets).
- **How the search works.** The explanation guides it, and the system checks
  every answer it proposes. The changes it considers come only from what an
  attempt at the goal actually touched: a scenario-element sentence with all
  its values fixed that the attempt asked for and did not find as a fact (which
  it may add), or a scenario fact the attempt used (which it may remove). It
  never ranges over every fact the program could state. A set of changes grows
  one change at a time. The system applies each set to a copy of the session
  and solves the goal again, and each set's own attempt supplies the next
  changes to consider, so a change that opens a new path brings that path's
  conditions into play. Two Prolog settings bound the search:
  `le_flip_max_changes` (3 by default) and `le_flip_max_evaluations` (400).
- **Kept facts**: a request may name templates the flip is to leave alone (the
  `keep` field of `answeringQuery`, a list of template labels, and a view's
  `the flip keeps …`, §17.10). These are the facts that define the case, so
  that no answer proposes to change them into another item code or another
  beneficiary.
- **Without writing the query**: a flip may also be asked as a query of your
  own. The editor's custom query field, and the `customQuery` of
  `answeringQuery`, accept the sentence, as they accept any query body, whose
  conditions are joined by `and`, `or` and `it is not the case that`. The
  editor's **Flip…** button, beside **Query**, writes the sentence for you: the
  goal is the answer you selected, negated, which asks what would make it not
  so — or the query itself where the query has no answer. The author may edit
  the sentence before it runs. The goal may still hold variables (`the heading
  of which good is 3924`).

See `examples/regulatory/flip_housing.le`.

### 17.8 Factors and precedent: a pattern, not syntax
Deciding an open-textured issue, one marked `; judged`, from earlier
decisions needs no construct of its own. The method is Horty's *result model*
of precedential constraint. `examples/regulatory/precedent.le` is a library
written in plain LE, which a program includes as a resource, and the program
then supplies three things:
- **factors**, as rules that name them: `a damage has factor suddenness if the damage occurred suddenly.`
  and which way they point: `suddenness favours accidental.` / `wear and tear disfavours accidental.`;
- **the case base**, as facts about each decided case, cited with trailers
  (§17.1): `kitchen flood has factor suddenness, as stated in decision D-1 at paragraph 4.`
  / `kitchen flood decided for accidental, according to the ombudsman, ... because "...".`;
- **the link into the rules**, which is an `otherwise` cascade (§17.2) around
  the judged template:
  ```le
  a damage counts as accidental
      if the damage is forced for accidental by a case
      otherwise the damage is accidental
      and it is not the case that
          the damage is forced against accidental by a case.
  ```
A case that decided for an issue *forces* a new situation for that issue when
the new situation has at least the decided case's factors in favour and at most
its factors against. A case that decided against forces in the same way, the
other way round. Where a decision is forced, the explanation is the analogy
itself: the decision cited, and each factor the two share, with its source.
Where no decision is forced, the judged template stays open and is reported as
a judgment needed. To check that the case base does not contradict itself, ask
the library's `*an issue* has an inconsistent case base` as a query. See
`examples/regulatory/precedent_pattern.le`.

### 17.9 Facts from a document
The *Write it in English…* dialog of the Scenario Editor also draws facts out
of a document. Under *From a document*, give the document's name, which is the
constant the new facts will cite. You may also give the address of the
document's text, either a web address or a file beside the program, and *Fetch
text* loads it. Paste or fetch the text, then press *Generate*. Nothing here is
tied to a particular kind of document or program:
- each fact written is a sentence of one of the program's templates, the
  templates of the resources it includes among them, and each fact cites the
  passage that states it:
  `<fact>, confer "<passage copied from the text>"` under a scenario whose
  header names the document (or `as stated in <document>, confer "..."`);
- where the program marks its scenario templates, with `; undefined` or
  `; judged`, only those templates are offered, each with the values its rules
  read in each place (`the kind of *a good* is *a kind*    [*a kind*: coat,
  dress, jacket, ...]`, up to 200 values). The model then writes the rules' own
  words, rather than near-synonyms that no rule reads. Where the program marks
  none of its templates, every template is offered;
- the system asks the model for little reasoning (`reasoning(minimal)`) and
  allows long replies (`max_tokens(16384)`), so that a long document is not cut
  off in the middle of a fact. In the reply, a `%` outside a quoted passage
  becomes the word `percent`, because in LE a `%` starts a comment, and a full
  stop written before a fact's trailer is moved to after it;
- a `; judged` template is written only where the text reports someone's
  decision (`according to <who>`, `because "..."`). A template that the rules
  conclude is never written at all: the document's conclusions are what the
  rules must reproduce, and not facts to be fed in;
- the system checks every passage against the text, and warns
  `quote_not_in_text` where the model paraphrased instead of copying. It then
  checks the facts against the program, as it checks any *Write it in English*
  result;
- where an address was given, the system also adds the facts that say where
  the document is (§17.1, *Documents*), so that the § badges of the new facts
  show their passages.
The editor keeps each fact's provenance beside its row. In the software, this
is `nl_to_le:english_to_le/8` with the options `document(Name)` and
`base(Dir)`.

### 17.10 Views: how a screen shows a program
A **view** says how a screen that runs the program should look to the person
using it: which facts a case states and how they are grouped, which query gives
the result, and what is shown beside the result. A view is a section of fixed
sentences, written in the program or in a resource the program includes.
Nothing reasons with those sentences, just as nothing reasons with `scenario
facts require provenance.`:
```le
the view claim desk is:
    the title is "Passenger claim desk".
    the case is a scenario, with the documents it is stated in.
    the facts about "the booking" are
        a passenger is booked on a flight,
        the distance of a flight is a number km.
    the judgments are
        an event is beyond the actual control of a carrier.
    every fact shows who states it.
    the result is the answer to query claim, headed by the amount, in euros.
    the result shows the stage it reaches.
    the result shows its citations.
    the answers to "which case decided for which issue" are listed as "Precedents".
    the result is compared with scenario bird_strike.
    the result can be flipped.
    the documents of the case are shown beside the facts.
```
The executive view (`/executive?program=<program>&view=<name>`) draws the view
with ready-made parts on the screen, and a program that has views lists them
there. The facts, questions and results a view names are **sentences of the
program's own templates**, written as the conditions of a rule are. The
sentences a view may use are these. They belong to the category `view` of
`i18n/keywords.csv`, so a view is written in the program's own language:

| Sentence | What the screen shows |
|---|---|
| `the title is "<text>"` | the screen's title |
| `the case is a scenario[, with the documents it is stated in]` | a picker of the program's scenarios (or a new case); the documents its facts cite |
| `the case is about <constant>` | the subject of the facts an interview's answers state |
| `the facts about "<title>" are <instance>, <instance>, …` | a group of fact rows, editable, each with its citation; the group's facts the case does not state, one click to state |
| `the judgments are <instance>, …` | the `; judged` facts apart |
| `the other facts can be added` / `… cannot be added` | whether the case may state facts of other templates |
| `every fact shows who states it` | each fact's `according to` |
| `the result is the answer to query <name>[, headed by <the word>][, in <unit>]` | the query's answers, the value of its `which <word>` in large type |
| `the result is whether <instance>` | a yes/no result, the query written in the view |
| `the result reads "<text>" when it holds` / `… when it does not` | the result in the view's words |
| `the result shows its citations` | the cited steps of the proof, each opening its passage |
| `the result shows its reasons` | the facts the result rests on; for a result that FAILS, **why not**: the conditions it did not meet (below) |
| `the result shows the stage it reaches` | the checklist of the applicability / question / remedy sections (§17.4) |
| `the result asks what is missing` | the case facts the failed proof looked for, each one click to state |
| `the facts are asked one at a time` | an interview: the view's questions, each asked only while the answer can still depend on it |
| `the question for <instance> is "<text>"` | the question for a fact (and its wording in the reasons and the flip) |
| `the result can be flipped[, as "<text>"]` | the minimal changes that would change the result (§17.7) |
| `the flip keeps <instance>, <instance>, …` | facts the flip never adds, removes or changes: those that define the case (the item and its code, a date of service), so that no answer proposes another one |
| `the section <name> reads "<text>"` | the stage checklist and "fails at" in the view's words (`the section remedy reads "Conditions of payment"`) |
| `the answers to "<query body>" are listed as "<title>"` | a table of another query's answers, a column per `which` |
| `the result is compared with scenario <name>` | the result of another scenario, and where it fails |
| `the documents of the case are shown beside the facts` | the cited documents, the case's own open with its passages marked |
| `the cases are listed with their results` | every scenario, its result and its expectation, run one after another ("running case i of N", and a button to stop) |
| `the case is flagged as "<label>" when "<query body>"` / `… when query <name> has an answer` | a banner above everything else whenever the query has an answer for the case (a refusal, a referral: a decision that stops the process); the second form for a query with text values, which a quoted query body cannot hold |
| `the numbers are shown with <N> decimals` | the numbers of the screen written with N decimals (without it, only the noise of floating point is removed: 698.4000000000001 is shown as 698.4) |
| `the draft reads "<text with {the result}, {the answer}, {the answers}, {the facts}, {the citations}, {the reasons}, {the missing}, {the case}>"` | a text filled from the result, to copy |
| `the draft reads "<text>" when it holds` / `… when it does not` | a text for each outcome: an approval and a refusal |

- **Checked by the verifier.** These are errors: a sentence that matches no
  view form (`view_unknown_sentence`), a sentence of no template
  (`view_unknown_template`), a query or a scenario the program does not have
  (`view_unknown_query`, `view_unknown_scenario`), a question for a table that
  is not a query (`view_bad_question`), and two views of one name
  (`view_duplicate_name`). These are warnings: a judgment whose template is not
  marked `; judged` (`view_not_judged`), a fact offered for the case to state
  that the rules conclude anyway (`view_derived_fact`), no result at all
  (`view_no_result`), a sentence written twice (`view_said_twice`), a heading
  the query does not ask for (`view_headed_by_unknown`), the stage checklist in
  a program without the reserved sections (`view_stage_without_sections`),
  citations or documents in a program that cites nothing
  (`view_nothing_cited`), a section the program does not have
  (`view_unknown_section`), and a kept fact that the rules conclude
  (`view_keeps_derived`).
- **Why not.** Where a result fails, the reasons panel lists the
  **conditions that were not met** (`le_why_not.pl`; `answeringQuery` with
  `whyNot: true` replies `unmet`). The system reads them off the explanation of
  the failure, one rule for each attempt. Where several rules could have
  concluded something, it follows only the attempts that came CLOSEST: those in
  which the most conditions held before the condition that failed, and among
  those, the ones that met the largest part of themselves. The first test of
  another alternative — another policy's list of codes, say — is therefore
  never given as a reason. Each condition at the end of the list is either `not
  stated`, a fact the case could state and does not, so the record is silent,
  or `not met`: a comparison false on the case's values, a negation whose
  subject holds, a fact the case states with another value, a judgment recorded
  the other way, or something no rule concludes. Each one is shown with the
  rule that asks for it, that rule's provenance, and the facts the rule
  compared. The citations of a failed result are the passages of those rules,
  and `openQuestions` asks only for the facts the closest attempts lack. A
  draft names them as `{the reasons}`, all of them, and `{the missing}`, the
  facts to ask for. A list placeholder written on a line of its own gives one
  item per line, and `\n` in a draft starts a new line.
- **Editing the case.** A change to a fact marks the results out of date and
  lights a **Re-evaluate** button. Pressing Enter in a field does the same, and
  an *automatically* box re-evaluates on every change. After the re-evaluation,
  the editor highlights the answers that changed and strikes through those that
  went away. Some values the rules cannot read where they stand: a number
  written in quotation marks where the rules compare it with a number, text
  written as a number, or a near miss of a value the rules do read. The editor
  reports such a value above the result (`answeringQuery` replies
  `valueWarnings` for a case typed in by hand;
  le_verifier:fact_value_warnings/3; the same check on a program's own
  scenarios gives the `mistyped_value` warning). A fact that only gives a type
  (`vehicle 1 is a vehicle`) stays in the case, but is shown on one line rather
  than as a row of its own. Every part of the screen says what it is when the
  pointer rests on it.
- **When the editor loads a program**, the reply carries each view ready to
  use (`views`, le_views:program_views/2). The `answeringQuery` operation adds
  the section `checklist`, and `unmet` with it; `openQuestions` gives the facts
  a failed proof looked for; and `draftView` drafts a view.
- **The automatic view.** A program that declares no view of its own is
  offered one in the executive view (`view=*`). That is the draft described
  below, which the system works out only when the view is opened (the operation
  `automaticView`, le_views:automatic_view/3). A view the program declares
  replaces it.
- **The LE Assistant's *Generate LE view*** adds a first view drafted from the
  program itself: its case facts as one group, its judged templates, its first
  query (or its first conclusion) as the result, and whatever else the program
  can show. The assistant then proposes a request for refining that view.

A tutorial, building a view step by step: [IntroducingLEViews.md](../tutorials/views.md).
See the views of `examples/regulatory/eu261_integration.le` (a claims desk),
`flip_housing.le` (an interview), `judged_damage.le`, `sections_benefit.le`
(its view *rent decision*: sections in its own words, why not, a flip that
keeps a fact, a letter for each outcome) and
`examples/regulatory/customs/cbp_62.le` (a classification worksheet) and the
coverage desks of `examples/regulatory/medicare/pap_cases.le` and `pmd_cases.le`.

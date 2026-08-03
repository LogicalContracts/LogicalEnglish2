# Logical English (LE) Syntax Summary

This document provides a summary of the Logical English constructs supported by the parser in `le_grammar.pl`.

## Table of Contents
- [Logical English (LE) Syntax Summary](#logical-english-le-syntax-summary)
  - [Table of Contents](#table-of-contents)
  - [1. Document Sections](#1-document-sections)
  - [2. Templates](#2-templates)
    - [Template additions (after `;`)](#template-additions-after-)
    - [2.1 Prepositional templates](#21-prepositional-templates)
  - [3. Rules and Facts](#3-rules-and-facts)
    - [3.1 Rule Sections](#31-rule-sections)
    - [3.2 Query bodies](#32-query-bodies)
  - [4. Logical Operators](#4-logical-operators)
  - [5. Aggregates](#5-aggregates)
  - [6. Variables and Constants](#6-variables-and-constants)
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

## 1. Document Sections
Sections define the context of the code. Each section header ends with a colon `:`.

- **Included Resources:** `the knowledge base <name> includes these resources:` or `the contract <name> includes these resources:` (Used to include other LE files or URLs. Must precede the main knowledge base header).
- **Knowledge Base:** `the knowledge base <name> includes:` or `the contract <name> states that:`
- **Scenario:** `scenario <name> is:` (Used for defining facts for a specific test case)
  - Can include expectations: `<QueryName> expects answers [<List of Strings>] and unknowns [<List of Strings>].` (the word `answers` may be omitted)
- **Query:** `query <name> is:` (Used for defining the goals to be proven). The
  body of a query may be a **full body expression — just like a rule body** — not
  only a single template instance: it can combine conditions with `and`, `or`,
  negation (`it is not the case that …`) and `for all cases in which …` (see §3.2).
- **Ontology:** `the ontology is:` (Used for taxonomy and class hierarchies)
- **Templates:** `the predicates are:` or `the templates are:` (Used to define NL patterns)
- **Dynamics:** `the fluents are:` or `the events are:` (For temporal reasoning)
- **Meta:** `the target language is: prolog.` (Required for Prolog generation)

## 2. Templates
Templates map natural language sentences to Prolog predicates.
- **Pattern:** `*a person* is a friend of *another person*`
- **Variables:** Words enclosed in asterisks `*...*`.
- **Types:** The **head noun** of the variable phrase (e.g. `person`); see §6 for how names and types are separated.
- **Variable Scoping:** Multiple occurrences of the same variable name within a sentence (or query) refer to the same variable.
  - `which person is the father of which person` will only match if a person is their own father.
  - Use `which person is the father of which other person` to refer to two different people.

### Template additions (after `;`)
A template definition can be followed by one or more additions, each introduced by `;`:
- `; opposite: <template>` — declares the negation form, used for negative heads and for negation in proofs.
- `; synonym <template>` — declares an **equivalent surface form**. The synonym maps to the **same** Prolog predicate as the main template, so facts, rule heads, rule bodies and queries may be written with either form interchangeably. Several `; synonym ...` additions may be chained. Its `*variables*` are matched **positionally** to the main template's, so both forms must list their arguments in the same order.
  - Example: `*a payment* is in respect of *a claim*; synonym *a payment* covers *a claim*.` — writing `p covers c` is the same fact as `p is in respect of c`.
  - **Rendering:** the main (first) form is used by default. In explanations, a node is rendered with the form actually used at its source location (the surface form of the clause that proves it); a query renders its answers with the form used in the query.
  - **Restriction:** a template with a synonym **cannot carry any other addition** (`defines global`, `opposite`, `prepositional`, `unknown`, `undefined`); doing so raises a `synonym_with_other_additions` error.
- `; defines global <name>; defines global <name2>...` — declares a global abbreviation.
- `; prepositional` — marks a **prepositional** template (see §2.1). The synonym `; composite` is accepted and means the same thing.
- `; unknown` — marks the template as **assumable** (abducible): matching goals that cannot be proven are assumed true and reported as unknowns. The synonyms `; assumed` and `; assumable` are accepted and mean the same thing.
- `; undefined` — marks the template as a **scenario element**: its facts are expected to appear only in scenarios, never as facts or rule heads in the knowledge base. The synonym `; scenario element` (two words) is also accepted. Effect on verification:
  - The `undefined_predicate` warning is **suppressed** for this template (even though no KB clause exists for it).
  - A **`defined_scenario_element` warning** is raised if a fact or rule head with this template is found in the knowledge base.
  - Example: `*a person* has passed the test; undefined.`

### 2.1 Prepositional templates
A prepositional template is a binary template that **starts with an argument** and is used to extend a previous condition. When chaining, the leading argument can be omitted and is filled in automatically from the previous condition's type-compatible variable.
- **Declaration:**
  ```le
  *a payment* under *a policy*; prepositional.
  ```
- **Constraints:** must have exactly two `*variable*` arguments, and the first token of the template must be a `*variable*`. Otherwise the parser reports a `prepositional_arity` or `prepositional_first_arg` issue.
- **Chained usage** (omitting the first argument):
  ```le
  we will make a payment under this policy in respect of a claim
  ```
  expands to the conjunction
  ```le
  we will make a payment
  and the payment under this policy
  and the payment in respect of a claim
  ```
  The prepositional templates' goals become **additional conditions** in the Prolog body (for both rule heads and rule bodies).
- **Standalone usage** is still allowed: writing the leading argument explicitly (e.g. `the payment under this policy`) matches the template directly.

## 3. Rules and Facts
- **Fact:** A simple statement ending in a period.
  - `Alice is a person.`
- **Rule:** A statement with a head and a body.
  - `Head if Body.`
  - `*a person* is eligible if *a person* is a citizen.`
- **Unknown Fact:** A statement declaring that a specific instance of a template is unknown. These can appear in the knowledge base (applying to all scenarios) or within a specific `scenario` section.
  - `it is unknown whether *a payment* is in respect of claim 01.` (This binds the second argument to 'claim 01' and leaves the first argument unbound). The synonyms `it is assumed whether ...` and `it is assumable whether ...` are also accepted.

### 3.1 Rule Sections
The rules of a knowledge base can optionally be grouped into named **sections**. A section marker is a line of the form:
```le
section <name> is:
```
Every rule (or fact) that follows the marker belongs to section `<name>`, until the next marker. The mapping from section name to rule is recorded in `le_source_section/2` (see §13) and does not change how rules behave during reasoning — it is metadata.

Conventions:
- If a knowledge base has no section markers, all of its rules belong to the default section **`main`**.
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
The body of a `query <name> is:` section is parsed **exactly like a rule body** — it
is a goal expression, not merely a single template instance. It may combine
conditions using the operators of §4:

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

A query that is a single template instance (the common case, e.g.
`which dragon is happy.`) behaves as before. A multi-condition answer is rendered
from the query's goal with its bindings, e.g. `"bob is happy and bob is healthy"`.

> The same layout rules as rule bodies apply: a negated goal and the parts of a
> `for all cases` must be on their own nested lines. A single physical line such as
> `… and it is not the case that the person is sad` does **not** split the negation
> (the same limitation rule bodies have); put the negated goal on the next line.

## 4. Logical Operators
- **And:** `and` (or new line with same indentation)
- **Or:** `or`, `either`, `any of`, `all of`
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
Used to perform calculations over sets of results.
- **Operators:** `sum`, `count`, `average`, `min`, `max`
- **Syntax:** `<ResultVar> is the <Op> of each <Var> such that <Goal>`
- **Example:** `*Total* is the sum of each *Amount* such that *the account* has *Amount*`

## 6. Variables and Constants
- **Variables:**
  - Explicit: `*my variable*`
  - Implicit: `a person`, `the person`, `some person`, `each person`, `which person`
  - Special: `who`, `what`, `when`, `where`

### 6.1 Variable names and types
A variable phrase optionally carries a **name** in addition to its **type**, so that several variables of the same type can be distinguished:
- **Type** = the **head noun** of the phrase. The whole phrase is the variable's **name** (used for identity/co-reference and for display).
- **Leading qualifier:** an ordinal (`first`, `second`, …, `tenth`) or one of `other, another, new, previous, next, current, last, same, original, single, given` in front of the noun marks a distinct variable of the same type. So `a first person` and `a second person` are **two different variables, both of type `person`**, and a `person` value is accepted in either slot.
  - `*a first person* greets *a second person*` — two `person` arguments; see `examples/moreExamples/named_vars.le`.
- **All-caps id convention:** a trailing identifier (a single uppercase letter or a short ALL-CAPS token) is the variable's name, and the preceding noun(s) are the type. `a person X` and `a person Y` are two different variables of type `person`; likewise `a number N`, `a date D`.
- **Genuine multi-word types** (no leading qualifier / trailing id) are kept whole, e.g. `a bodily injury` has type `bodily injury`, `a repair cost` has type `repair cost`.
- Repeated occurrences of the *same* phrase co-refer (`a first person` … `the first person`), as in §2.

### 6.2 Type checking
A variable argument's **type** (§6.1) is used to reject values that do not belong to it. Type checking is **lazy** (it fires once the argument is bound) and **lenient** (it only rejects on a clear conflict — an argument of unknown type is always accepted). Both the **session** (scenario facts) and the **knowledge base** are consulted for `is_a` facts.

- **Instance values.** A value with a known type — i.e. there is an `is_a` fact for it (including a scenario fact such as `this payment is a payment`) — is accepted in a slot of type `T` only if it *is a* `T` (directly, or through the `is_a` taxonomy / a head-noun match). So a value declared a `payment` is **rejected** for an `amount` slot. A value with **no** known type imposes no constraint.
- **Type values.** When a value is itself a *type* (used in taxonomy reasoning, e.g. `*sub* isa *super*`), it is required to be a sub-type of the slot's type — but only when that slot type is **grounded** (it participates in the ontology: something is a `T`, or `T` is a something). A purely generic placeholder type like `super`, which nothing is a and which is not a sub/super of anything, imposes no constraint, so a real type value such as `dragon` is accepted there.
- **Universal types.** `any`, and the universal types `thing`, `object`, `entity`, `asset`, `element`, accept any value.
- **Disambiguating same-functor rules.** Rules whose heads share a predicate but declare **different argument types** are kept apart by type. For example, given both prepositional bridges
  ```le
  a payment in respect of a claim if the payment is in respect of the claim.
  an amount  in respect of a claim if the amount  is in respect of the claim.
  ```
  the fact `this payment is in respect of this claim` (with `this payment is a payment`) matches **only** the first rule, because `this payment` is rejected for the `amount`-typed head of the second. This per-rule head checking is applied **only at *ambiguous* argument positions** — positions where the predicate's templates disagree on the type (here, argument 1 is `payment` in one template and `amount` in another). At unambiguous positions the type is not a discriminator (e.g. a single `affiliate` template, where a `company` may legitimately act as an `affiliate`), so no head check is imposed. 

In an explanation tree, a type check renders like the assertion it verifies, e.g. `this payment is a payment`.

- **Constants:**
  - Proper names: `Alice`, `Bob`
  - Strings: `"Hello"`, `'World'`
  - Numbers: `42`, `3.14`
  - Dates: `2023-10-27`

## 7. Arithmetic and Comparisons
- **Math:** `+`, `-`, `*`, `/`, `( )`
- **Functions:** the unary arithmetic functions `ceiling`, `floor`, `round`, `truncate`, `integer`, `abs`, `sign`, `sqrt` may be applied to a parenthesised argument, e.g. `the result is the multiple * ceiling(the amount / the multiple)`. They are evaluated by Prolog's `is/2` at solve time.
- **Comparison:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=`
- **Variable names in expressions:** a bare word used in an arithmetic expression is recognised as a variable only if it is an **id** (a single uppercase letter, or a short ALL-CAPS token — see §6.1), e.g. `ENT = ETI * ATR - TO`. A descriptive lower-/mixed-case word like `amount` or `exposure` is treated as part of a *type*, not a variable name, so it will not co-refer with a head variable inside an expression. Use ids (e.g. `EXP`, `IAOR`, `A`) for variables that participate in arithmetic.
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
  - `*V1* is known`
  - `*V1* is in *V2*` (List membership)
  - `the minimum of *V1* and *V2* is *V3*` (for numbers)
  - `the maximum of *V1* and *V2* is *V3*` (for numbers)
- **There are no `min`/`max` FUNCTIONS.** "The least of the limit and the repair
  cost" is a condition, not an expression: write
  `and the minimum of L and R is P`, never `and P = min(L, R)` — the latter
  parses and then dies at solve time with "min(A,B)/0 is not a function". The
  same goes for `max`.

### 7.1 Date Handling and Comparisons
Dates are fully supported as a first-class type in Logical English:
- **Representation:** Dates are parsed by the tokenizer and represented internally as compound terms of the form `date(Year, Month, Day)` (e.g., `date(2021, 10, 9)`).
- **Type System:** `date` is treated as a regular type. When templates define variables like `*a date*`, the type `date` is automatically registered in the ontology/type system (??? to be confirmed).
- **Comparisons:** Dates can be compared chronologically using built-in comparison templates:
  - `*V1* is after *V2*` (maps to `le_gt`)
  - `*V1* is before *V2*` (maps to `le_lt`)
  - `*V1* is after or equal to *V2*` (maps to `le_ge`)
  - `*V1* is before or equal to *V2*` (maps to `le_le`)
  These map to standard Prolog term comparison operators (`@>`, `@<`, `@>=`, `@=<`), which naturally and correctly compare `date(Y, M, D)` terms chronologically.

## 8. Taxonomy (Ontology)
- **Is-a hierarchy:** `<Subtype> is a <Supertype>` or `<Subtype> is an <Supertype>`
- **Example:** `a student is a person.`

## 9. Ignorable Words
The parser skips certain "filler" words during template matching to allow for natural phrasing:
- `a`, `an`, `the`
- `is`, `are`, `was`, `were`
- `has`, `have`, `had`
- `do`, `does`, `did`, `been`

## 10. Comments
- **Line Comments:** `%` or `#`
- **Block Comments:** `/* ... */`

## 11. Meta-Templates
Logical English supports meta-predicates that can take other sentences as arguments.
- **Keywords:** `says`, `that`
- **Example:** `*the act* says that *the person* is liable.`
- **It is the case that:** Used to introduce the consequence in a universal quantification or to wrap a statement.

## 12. Testing and Expectations
Scenarios can define expected results for queries, which are used by the test runner.
- **Syntax:** `<QueryName> expects answers ["Answer 1", "Answer 2"] and unknowns ["Unknown 1"].` (The `and unknowns [...]` part is optional, and so is the word `answers`).
- The expectation names the query directly — it must **not** be prefixed with
  `query` (a leading section keyword is reported as a misplaced expectation).
- **Example:**
  ```le
  scenario alice is:
      John is born in the UK on 2021-10-09.
      one expects answers ["John acquires British citizenship on 2021-10-9T0:0:0.0"] and unknowns ["John is a good person"].
      two expects ["John is a British citizen"].
  ```

## 13. System Predicates
Logical English provides several system predicates that can be accessed via the `prolog` keyword or used for introspection.

- **`le_my_kb(KB)`**: Unifies `KB` with the name of the current knowledge base module.
- **`le_my_id(ID)`**: Unifies `ID` with the identifier of the current rule or fact.
- **`le_type(Type)`**: True if `Type` is a known type defined in the ontology or templates.
- **`is_a(Subtype, Supertype)`**: True if `Subtype` is a descendant of `Supertype` in the taxonomy.
- **`le_source_element(RuleID, Designator, Goal)`**: Maps hierarchical designators (e.g., `1.1.a`) to their corresponding goals within a numbered rule.
- **`le_source_section(SectionName, RuleID)`**: Maps each rule to the section it belongs to (see §3.1). Rules with no enclosing section marker are mapped to `main`.
- **`le_source_info(Ref, Start, End, ID)`**: Provides source file location (start/end character offsets) and ID for a given clause reference.
- **`le_issue(Severity, Type, Description, Fix, Start, End)`**: Represents a parsing or verification issue (error or warning).
- **`le_dict(dict(FunctorArgs, NamedTypes, WordsAndVars))`**: Stores the internal representation of a template.
- **`le_kb(Name)`**: Stores the name of the knowledge base as defined in the source.
- **`scenario(Name, Facts)`**: Stores the facts associated with a named scenario.
- **`query_info(Name, Goal, Items)`**: Stores information about a named query.
- **`le_expected(QueryName, ScenarioName, ExpectedAnswers)`**: Stores expected answers for a query in a scenario.
- **`ontology(Content)`**: Stores the raw content of the ontology section.

## 14. Included Resources
Logical English programs can include other LE programs using the `includes these resources:` header.
- **Syntax:**
  ```le
  the knowledge base myKB includes these resources:
      Resource1, Resource2.
  ```
- **Resources:** Can be relative file paths (e.g., `royal_family`) or URLs (e.g., `https://le2.logicalcontracts.com/source/royal_family`). The `.le` extension is implicit.
- **Behavior:** The included rules, facts, templates, and ontology are added to the local KB module and used during reasoning. Scenarios and queries from included resources are ignored.
- **Transitivity:** Includes are followed transitively, up to a depth cap (Prolog flag `le_include_max_depth`, default 5). Repeated resources and cycles are detected and skipped; each resource path is resolved **relative to the including file's own location** (URL directory or file directory).
- **Local-path restriction:** a local (file) resource may only be included when it lives under the including file's directory tree, or is a world-readable server file allowed by `restricted_paths`. External `http(s)` URLs are unrestricted.

### 14.1 Prolog resources (`.pl`)
A resource named with an explicit `.pl` extension (file or URL) is a **Prolog resource** — a way to back an LE knowledge base with a Prolog facts/predicates file (e.g. a large lookup table) exposed through a *thin LE layer*: a few templates plus rules with `prolog` bodies (§15.6). The main program includes the layer, and the layer includes the `.pl`:
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
- **Loading is assert-only** (never `consult`): clause terms are asserted into a dedicated, content-addressed cache module that reasoning sessions import. The only directives honoured at load time are `dynamic/1`, `discontiguous/1` and `use_module(library(...))`; a `:- module(...)` directive is stripped (with a warning) and its clauses load anyway; every other directive is skipped with a warning. So a remote `.pl` cannot execute code merely by being included.
- **Runtime safety:** every `prolog` body goal is checked by `library(sandbox)` before it runs (LE's own read-only metadata predicates are whitelisted). Trusted installations can disable the check with the flag `le_sandbox_prolog` set to `false`.
- **Caching:** a file `.pl` reloads when its modification time changes; a URL `.pl` is fetched once per server run — so editing the LE program does not re-load a large facts file.
- See `examples/moreExamples/prolog_resources/` (postcodes: main → thin layer → facts `.pl`).

## 15. LE Extensions
Features beyond the core constructs summarised above. Some are implemented in
the core grammar but were previously undocumented; the ones marked
**[requires le_extensions.pl]** are gated on the proprietary `le_extensions.pl`
module (installed as a symlink next to the LE2 sources — see the InsurLE2
README) and are unavailable without it.

### 15.1 `only if` rules (necessary conditions)
`Head only if Body.` states that Body is a **necessary** condition for Head —
the contrapositive rule. It compiles to *"opposite-of-Head if it is not the
case that Body"*:
- If Head's template declares an `; opposite:` form, that form is the derived
  rule's conclusion — so the program can literally conclude
  `we will not pay X` when a payment precondition fails.
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
Ordinary `if` rules give sufficient conditions; `only if` rules act as
constraints producing negative conclusions. See
`examples/moreExamples/only_if.le`.

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
`all of` groups them conjunctively (useful inside an `or` block).

### 15.5 Rule labels and numbered rule bodies **[numbering requires le_extensions.pl]**
A rule may be labelled: `rule <name>: Head if ...` — the label becomes the
rule's ID (visible in `le_source_element/3` and `le_source_info/4`, §13).
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
`examples/moreExamples/numbering_test.le`.

### 15.6 Embedded Prolog goals **[resolution requires le_extensions.pl]**
A body condition of the form `prolog <goal>` (parenthesise conjunctions:
`prolog (g1, g2)`) calls raw Prolog. LE variables are referenced inside the
goal as `the <name>` phrases, `*a name*` markers, or ALL-CAPS ids, and are
bound to the goal's results; the system predicates of §13 are commonly used:
```le
an id has designator a d if
    prolog (le_my_kb(KB), KB:le_source_element(the id, the d, the g)).
```
See `examples/moreExamples/prolog_call.le` and `rule_id_test.le`.

### 15.7 Prepositional chaining **[requires le_extensions.pl]**
The `; prepositional` template marker and its chained usage are described in
§2.1; note that the *chaining* itself (omitting the leading argument so one
sentence expands into a conjunction of conditions) is resolved by the
extensions module.

## 16. Humanizing LE
LE programs are read by lawyers and domain experts more often than they are
written. These guidelines use the features above to keep programs close to
natural prose:

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
- **Declare `; synonym:` surface forms** so facts, scenario lines and queries
  can each use the phrasing most natural in their context — explanations
  render each occurrence in the surface form it was written in.
- **Keep template wording close to the source text**, letting the ignorable
  words (a/an/the/is/are...) carry the grammar; prefer several short,
  structured templates over one long sentence-sized predicate that hides its
  logical parts.
- **Mark epistemic status** with `; assumable` (expert judgment) and
  `; undefined` (case data): readers immediately see which leaves are
  evidence, which are judgment calls, and which are derived.
- **Name individuals meaningfully**: determiner-free, descriptive constants
  (`claim one`, `wrist injury`, `United Kingdom`) — they appear verbatim in
  answers and explanations.

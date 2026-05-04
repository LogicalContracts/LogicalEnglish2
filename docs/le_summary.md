# Logical English (LE) Syntax Summary

This document provides a summary of the Logical English constructs supported by the parser in `le_grammar.pl`.

## 1. Document Sections
Sections define the context of the code. Each section header ends with a colon `:`.

- **Knowledge Base:** `the knowledge base <name> includes:`
- **Scenario:** `scenario <name> is:` (Used for defining facts for a specific test case)
  - Can include expectations: `<QueryName> expects answers [<List of Strings>].`
- **Query:** `query <name> is:` (Used for defining the goals to be proven)
- **Ontology:** `the ontology is:` (Used for taxonomy and class hierarchies)
- **Templates:** `the predicates are:` or `the templates are:` (Used to define NL patterns)
- **Dynamics:** `the fluents are:` or `the events are:` (For temporal reasoning)
- **Meta:** `the target language is: prolog.` (Required for Prolog generation)

## 2. Templates
Templates map natural language sentences to Prolog predicates.
- **Pattern:** `*a person* is a friend of *another person*`
- **Variables:** Words enclosed in asterisks `*...*`.
- **Types:** Extracted from the variable name (e.g., `person`).
- **Variable Scoping:** Multiple occurrences of the same variable name within a sentence (or query) refer to the same variable.
  - `which person is the father of which person` will only match if a person is their own father.
  - Use `which person is the father of which other person` to refer to two different people.

## 3. Rules and Facts
- **Fact:** A simple statement ending in a period.
  - `Alice is a person.`
- **Rule:** A statement with a head and a body.
  - `Head if Body.`
  - `*a person* is eligible if *a person* is a citizen.`

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
- **Constants:**
  - Proper names: `Alice`, `Bob`
  - Strings: `"Hello"`, `'World'`
  - Numbers: `42`, `3.14`
  - Dates: `2023-10-27`

## 7. Arithmetic and Comparisons
- **Math:** `+`, `-`, `*`, `/`, `( )`
- **Comparison:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=`
- **System Templates:**
  - `*V1* is equal to *V2*`
  - `*V1* is greater than or equal to *V2*`
  - `*V1* is less than or equal to *V2*`
  - `*V1* is after or equal to *V2*`
  - `*V1* is before or equal to *V2*`
  - `*V1* is known`
  - `*V1* is in *V2*` (List membership)

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
- **Syntax:** `<QueryName> expects answers ["Answer 1", "Answer 2"].`
- **Example:**
  ```le
  scenario alice is:
      John is born in the UK on 2021-10-09.
      query one expects answers ["John acquires British citizenship on 2021-10-9T0:0:0.0"].
  ```

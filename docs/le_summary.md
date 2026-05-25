# Logical English (LE) Syntax Summary

This document provides a summary of the Logical English constructs supported by the parser in `le_grammar.pl`.

## 1. Document Sections
Sections define the context of the code. Each section header ends with a colon `:`.

- **Included Resources:** `the knowledge base <name> includes these resources:` or `the contract <name> includes these resources:` (Used to include other LE files or URLs. Must precede the main knowledge base header).
- **Knowledge Base:** `the knowledge base <name> includes:` or `the contract <name> states that:`
- **Scenario:** `scenario <name> is:` (Used for defining facts for a specific test case)
  - Can include expectations: `<QueryName> expects answers [<List of Strings>] and unknowns [<List of Strings>].`
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

### Template additions (after `;`)
A template definition can be followed by one or more additions, each introduced by `;`:
- `; opposite: <template>` — declares the negation form, used for negative heads and for negation in proofs.
- `; defines global <name>; defines global <name2>...` — declares a global abbreviation.
- `; prepositional` — marks a **prepositional** template (see §2.1).

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
  - `it is unknown whether *a payment* is in respect of claim 01.` (This binds the second argument to 'claim 01' and leaves the first argument unbound).

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
- **Syntax:** `<QueryName> expects answers ["Answer 1", "Answer 2"] and unknowns ["Unknown 1"].` (The `and unknowns [...]` part is optional).
- **Example:**
  ```le
  scenario alice is:
      John is born in the UK on 2021-10-09.
      query one expects answers ["John acquires British citizenship on 2021-10-9T0:0:0.0"] and unknowns ["John is a good person"].
  ```

## 13. System Predicates
Logical English provides several system predicates that can be accessed via the `prolog` keyword or used for introspection.

- **`le_my_kb(KB)`**: Unifies `KB` with the name of the current knowledge base module.
- **`le_my_id(ID)`**: Unifies `ID` with the identifier of the current rule or fact.
- **`le_type(Type)`**: True if `Type` is a known type defined in the ontology or templates.
- **`is_a(Subtype, Supertype)`**: True if `Subtype` is a descendant of `Supertype` in the taxonomy.
- **`le_source_element(RuleID, Designator, Goal)`**: Maps hierarchical designators (e.g., `1.1.a`) to their corresponding goals within a numbered rule.
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

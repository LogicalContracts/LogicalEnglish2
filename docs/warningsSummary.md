# Logical English Load-Time Warnings

These apply only to syntactically correct programs

## Missing template for '...'

A multi-word phrase appears in a rule body but has no matching template declared.  
**Fix:** add a template for the phrase to the `the templates are:` section.

## Undefined predicate '...'

A predicate is used in a rule body but is never defined — no rule has it as its head, and no scenario provides facts for it.  
**Fix:** add a rule defining the predicate, or add fact sentences for it in the relevant scenarios.

## This predicate is not tested by any query: '...'

An intensional predicate (one defined by rules) is not reachable from any `query` in the program. The predicate is named by its template (`*a claim* is covered under *a section*`), and the warning is reported at its first rule head.  
**Fix:** add a query that exercises the predicate, and add expected answers using `expects answers` in a scenario.

## This template is never used: '...'

A template is declared but appears nowhere else — no rule head, no rule condition, no fact, no scenario fact, no query. Dead vocabulary costs the reader attention and is never checked against a use; generated programs often invent leaf classifications (`*a cost* is a cost; undefined.`) that no rule consults.  
**Fix:** delete the template, or use it.

## Test failed for query '...' in scenario '...'

The actual results of a query do not match the expected answers defined in the scenario or `.le.tests` file.  
**Fix:** check the logic of your rules or the facts in the scenario.

## Rule without variables: ...

Both the head and body of a rule are fully ground — they contain no variables, only concrete values.  
**Fix:** move the concrete data into a scenario; rules should use variables.

## Missing rules / Too many facts

- **Missing rules:** the program contains only facts and no rules.  
- **Too many facts:** facts outnumber rules by more than 5:1.  
**Fix:** add rules that derive conclusions from the facts.

---

**Note:** The editor provides **Quick Fixes** (lightbulb icon) for "Missing template" warnings, which automatically suggest and insert a template definition.

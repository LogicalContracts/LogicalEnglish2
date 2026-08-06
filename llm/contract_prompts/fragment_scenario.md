Turn the TEXT TO CONVERT into ONE Logical English scenario for THE PROGRAM.

Output exactly one fenced code block containing exactly one section:

```le
scenario <name> is:
    <fact>.
    <fact>.
```

and nothing else — no templates, no rules, no queries, no prose, no second
scenario. {{name}}

How to write it:

1. Read the program's `the templates are:` section and list, for yourself, the
   templates that are CASE DATA — the ones the program's rules read but no rule
   establishes (often marked `; undefined`). Those are the ones a scenario is
   made of.
2. Read one of the program's existing scenarios. Follow its conventions: how it
   names individuals, which constants it uses, how much it states.
3. Walk the text sentence by sentence and, for each thing it asserts, write the
   instance of the closest applicable template. Fill every placeholder the text
   gives a value for; where it gives none, leave the placeholder's own words
   ("a date") rather than inventing a value.
4. Anything the text asserts for which there is NO template: leave it out. It
   belongs in the coverage comment, not in an invented sentence.

{{expectations}}

Remember what a scenario is: a set of facts, each holding of a NAMED individual.
An indefinite article turns a fact into a universal law of the scenario.
{{instructions}}

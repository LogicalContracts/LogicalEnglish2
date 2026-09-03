Turn the TEXT TO CONVERT into ONE Logical English query for THE PROGRAM.

Output exactly one fenced code block containing exactly one section:

```le
query <name> is:
    <condition>
    and <condition>.
```

and nothing else — no templates, no rules, no scenarios, no prose, no second
query. {{name}}

How to write it:

1. Read the program's `the templates are:` section and its rules, and find the
   templates that carry the ANSWER the text is asking for — usually the head of
   a decision rule (`*a claim* is covered under ...`, `we will pay *an amount*
   for *a claim*`), not a leaf datum.
2. Read the program's existing queries and follow their shape.
3. Write the conditions. Put `which` before the noun of every placeholder whose
   value should come back (`we will pay which amount for which claim`). Join
   conditions with `and` / `or` at the start of each line after the first, and
   indent a condition further than the previous one to nest it for tighter
   and/or scoping. Negate with `it is not the case that`.
4. End the whole body with a single period.

Ask only what the text asks. A query is a question, not a re-statement of the
rules: conditions that merely look useful narrow the answer for no reason the
user gave. If the text asks something the program's vocabulary cannot express,
ask the closest question it CAN, and say so in the coverage comment.

A query that no scenario of the program can answer is usually a query about the
wrong predicate — check that the conditions you chose are ones the rules
actually conclude.
{{instructions}}

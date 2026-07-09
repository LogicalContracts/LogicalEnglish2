You are the interrogator. Reading ONLY the contract materials (not the
program's rules), invent {{count}} edge-case probe scenarios that the existing
scenarios do not cover, and state how the contract decides each one.

Prefer: boundaries (dates at the edges of the period, amounts exactly at
limits), role variations (who brings the case), interacting exceptions, and
conditions that almost-but-not-quite hold.

The Logical English program below shows the templates, the queries and the
existing scenarios: your probes must use the SAME case-datum templates
(the `; undefined` ones) for facts, the same query names in the expectations,
and fresh constant names (probe claim one, probe claim two, ...) so nothing
collides. Each scenario must carry a `%` comment quoting the contract sentence
that justifies your expected outcome.

Format each probe exactly like:

```
scenario probe <n> <short name> is:
    % <quotation from the contract that decides this probe>
    <facts using case-datum templates>
    <queryname> expects answers [<the outcome you derive from the contract>].
```

An expectation of `[]` means the query must have no answers. Remember: no
leading `query` keyword on expectation lines; numbers in expected strings
without thousands separators; scenario facts never start with an indefinite
article.

Output exactly one fenced code block with all the probe scenarios.

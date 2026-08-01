The rules of the computable twin are drafted (program below). Finish it:

1. add the schedule as facts (from the SCHEDULE material), using the
   program's schedule-datum templates;
2. add the scenarios permitted by the SCENARIOS section below (from the CASES
   material), with facts only from case-datum templates and embedded
   expectations (`<queryname> expects answers [...]` — no leading `query`
   keyword; numbers without thousands separators);
3. add the queries (`query <name> is:`) used by the expectations — plain
   `which` variables, never asterisks outside the templates section.

Keep every existing rule and comment. Output exactly one fenced code block
containing the FULL completed program.
{{existing}}
{{scenarios}}
{{instructions}}

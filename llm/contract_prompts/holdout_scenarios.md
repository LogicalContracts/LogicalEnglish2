You are the case writer. Below are a Logical English program and the
description of one case the program has never seen. Write the LE scenario for
this case: the facts, using ONLY the program's case-datum templates (the
`; undefined` ones), and the expected outcomes for the program's queries, as
you determine them by reading the case against the contract encoded in the
program's comments and rules.

Rules:
- Name the scenario and its constants after case {{casenumber}}
  (e.g. `scenario held out case {{casenumber}} is:`, `claim {{casenumber}}`)
  so nothing collides with existing scenarios.
- The case description may carry the schedule entry it refers to (its limits,
  deductibles, period and elections). Those are facts OF THIS CASE: state them
  in the scenario, using the program's schedule templates, unless the program
  already holds them as global facts.
- If the case states its own outcome (a decision, an amount payable, a reason),
  THAT is the expectation — write it as given, even where you would have
  decided otherwise. Only work the outcome out yourself when the case is silent
  about it.
- Include an expectation line per relevant query:
  `<queryname> expects answers ["..."].` — `[]` if the query must have no
  answers. No leading `query` keyword. Numbers without thousands separators.
- Facts never start with an indefinite article; use proper names or
  determiner-free constants.
- Do NOT modify the program; output only the scenario.

Output exactly one fenced code block containing the scenario section.

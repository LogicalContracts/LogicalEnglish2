# Logical Thinking in the Age of AI: example drafts (not reviewed)

Four programs for slides 5 to 8 of the talk *Logical Thinking in the Age of
AI: A Core Competency for Society*. Two are medical: they follow a heart
failure treatment guideline. Two are ethical: they write out an argument about
provocation and test standards of judgment against it. They are drafts that
nobody has reviewed yet, and the medical ones are illustrations, not
clinical advice.

## Start here

- [Which treatments does the guideline recommend?](heart_failure.le?scenario=paper_patient&query=treatments) — slides 5 and 6.
- [What if we know only a little about the patient?](heart_failure_what_if.le?scenario=what_we_know&query=combination) — a conditional answer.
- [The reasoning behind an argument](provocation_transposed.le?scenario=both_cases&query=leniency) — slide 7.
- [Is there a standard for judgment?](standard_for_judgment.le?scenario=three_cases&query=acceptable) — slide 8.

## Try this

1. Open [the guideline](heart_failure.le?scenario=paper_patient&query=treatments) and click **Query**: the treatments the guideline recommends for Ann, the patient of the paper.
2. Click "the guideline recommends ACE inhibitors with class 1 for Ann" to see why: Ann is in stage C, her ejection fraction is 35, and nothing rules the drug out.
3. Choose the scenario **ace_intolerant** and the query **alternatives**, and click **Query**: Bob, who cannot tolerate ACE inhibitors, should receive ARBs instead.
4. Open [the what-if program](heart_failure_what_if.le?scenario=what_we_know&query=combination) and click **Query**. The combination of hydralazine and isosorbide dinitrate is recommended, with one *unknown*, in amber: whether Dan has received standard therapy. That is what is still to be checked.
5. Open [the argument](provocation_transposed.le?scenario=both_cases&query=leniency) and click **Query**. The same rules grant leniency to Ron for rape and to Mark for murder: the unstated premise does the work.
6. Open [the standards](standard_for_judgment.le?scenario=three_cases&query=acceptable) and click **Query**: only the aggression standard is acceptable.

## More

- [Details](DETAILS.md) — the programs slide by slide, the slides' links, excerpts and sources.
- [The medical paper](https://arxiv.org/pdf/1610.08115) — Chen, Marple, Salazar, Gupta and Tamil, *A Physician Advisory System for Chronic Heart Failure Management Based on Knowledge Patterns* (2016).
- [The editor's manual](/docs/user/guide/editor) — scenarios, queries, explanations and unknowns.

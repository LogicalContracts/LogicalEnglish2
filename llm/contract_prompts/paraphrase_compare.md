You are the stability judge. Below are (A) the consensus vocabulary used to
build a computable twin of a contract, and (B) a vocabulary independently
extracted from a PARAPHRASE of the same contract. If the modelling is sound,
the two should agree in substance: the same decision predicates and the same
leaf templates, up to phrasing.

Compare them template by template (two templates match when they have the
same argument types in the same order and equivalent meaning). Then report,
as markdown:

1. A line `STABILITY: <n>%` — the percentage of vocabulary A's templates that
   have a match in B.
2. `Missing from B:` — A-templates with no counterpart (these depended on the
   original surface phrasing; worth a human look).
3. `New in B:` — B-templates with no counterpart in A (candidate omissions in
   the original modelling).
4. One short paragraph of assessment.

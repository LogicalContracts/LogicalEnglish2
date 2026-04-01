# Some experimentgs in vibe coding a new LE parser

You are an expert in Logical English (LE), a constrained natural language mapping to PROLOG. It is described in @docs/le_syntax.md. There are examples in @examples/moreExamples - all files with extension .le

Write me a Definite Clause Grammar into a single file le_grammar.pl, including auxiliary predicates if necessary, that is able to parse any of the given LE examples.

To execute PROLOG you must use command /Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl
# LE 2.0 language differences vs LE 1.0
* no target language nor
* no knowledge base name?
  * loading context dependent instead: 
* expects ListOfAnswers in Scenario, subordinated to query
* globals, e.g. the Insured: *The Insured* --> insured(I)...
* importing modules: perhaps just import(myModule:WordsOrInternalName); the party is an eligible party [according to seciton 1]
* prolog bridge: a party is an eligible party with a percentage if prolog eligible(the party,the percentage) because Explanation
* time argument: the party is an eligible party on TimeExpression; instants or durations (intervals) (exclusive??)
  * use timeExpression and time_interval_operators for testing
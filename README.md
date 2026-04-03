# Some experimentgs in vibe coding a new LE parser
## Initial prompt
You are an expert in Logical English (LE), a constrained natural language mapping to PROLOG. It is described in @docs/le_syntax.md. There are examples in @examples/moreExamples - all files with extension .le

Write me a Definite Clause Grammar into a single file le_grammar.pl, that is able to parse any of the given LE examples.
You must call the existing predicate tokenize(String,Tokens) in @tokenizer.pl, which returns these token terms:

1. Structural & Whitespace Tokens

indent(Count, Location): Generated specifically at the start of a new line. Count represents the number of leading spaces.
punctuation(Atom, Location): 

2. Literal & Value Tokens

word(Atom, Location): A sequence starting with an alphabetic character followed by alphanumeric characters.
number(Integer, Location): A sequence of one or more digits converted into a Prolog number.
date(date(Y, M, D), Location): Specifically matches the format YYYY-MM-DD. 

3. String & Quote Tokens

quoteString(String, Location): Content wrapped in single quotes ('...').
doubleQuoteString(String, Location): Content wrapped in double quotes ("...").

4. Comment Tokens

line_comment(String, Location): Text appearing after a % symbol until the end of the line.
multi_comment(String, Location): 


To execute SWI-PROLOG  use the shell command /Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl

## Next
Looks good. Now take the current le_grammar.pl and start adding semantics. First, in the rule for section(predicates(Ts)) , instead of Ts return a list of dict(FunctorArgs,NamesTypes,WordsAndVars), by calling a new predicate templatesToDicts/2 that you need to write. 
For example for a template 

    *an asset* was received for an injury at *a place* of *a taxpayer*. 

the dict term should be

    dict([was_received_for_an_injury_at_of,A,B,C], [asset-asset,place-place,taxpayer-taxpayer], [A,was,received,for,an,injury,at,B,of,C])

Notice how each template originates a precise predicate functor name, made of the template words concatenated with underscores.

## Next...
There is a confusion in the code, in that templates in declarations contain variables delimited by *, but template instances in rules do not use the *. So you should create a new rule for template, call it from  templates//1 ; it should call template_part which btw should not cover of date(_), list(_), expr(_) and punct(_) which can not be used in template declarations. Then template_instance should continue to be called from rule as now

## literals

We want to transform rules into Prolog clauses. So we need to refine the rule bodies to contain a term with any LE logical connectives, for example and(LiteralA,or(LiteralB,LiteralB)), as well as the literals (template instances).  So we need a "second pass", a new predicate called at the end of parse_le/2, already with the benefit of the templates being known, which takes the Doc AST and processes its kb list of rules into a list of clauses:
- Each rule head must match a template in the templates list; the PROLOG clause head will be dict/3's first argument
- Each rule body may have a tree logic structure as per the LE language, with expressions and literals in the leaves; each literal must match a template too

# fixing it
The parsing is not quite well yet. For example in citizenship.le the first rule...

a person acquires British citizenship on a date
if the person is born in the UK on the date
and the date is after commencement
and an other person is the mother of the person
    or the other person is the father of the person
and the other person is a British citizen on the date
    or the other person is settled in the UK on the date.

... is not being parsed correctly; instead of:

clause([acquires_British_citizenship_on,'a person','a date'],
		  or([is_born_in_on,'the person','the UK','the date'],
		     or([is_after_commencement,'the date'],
			or([is_the_mother_of,'an other person','the person'],
			   or([is_the_father_of,'the other person','the person'],
			      or([is_a_British_citizen_on,'the other person','the date'],[is_settled_in_the_UK_on,'the other person','the date']))))))

... it should parse instead to:

clause([acquires_British_citizenship_on,'a person','a date'],
		  and([is_born_in_on,'the person','the UK','the date'],
		     and([is_after_commencement,'the date'],
		        and(
                    or([is_the_mother_of,'an other person','the person'], [is_the_father_of,'the other person','the person']),
			      and(
                    or([is_a_British_citizen_on,'the other person','the date'],[is_settled_in_the_UK_on,'the other person','the date']))
                    ))))

There is a second problem, in the second rule:

a person is the father of an other person
    if a third person says 
    that the person is the father of the other person
    and the third person is qualified to determine fatherhood.

Its parse is wrong: 

	   clause([is_the_father_of,'a person','an other person'],
		  and(and(unknown_template([word(a),word(third),word(person),word(says)]),[is_the_father_of,'that the person','the other person']),
		      [is_qualified_to_determine_fatherhood,'the third person'])),

That unknoown_template is incorrect: "a third person" means just "a person"; second, third, etc. are auxiliaries just to allow different variables of the same type to be used. 

# more fixes
Better but not correct yet. For example in payg.le the first rule...

the estimated tax for an entity for a year is an amount ET
    if the estimated annual net tax payable for the entity for the year is ET
        and ET >= 0 
    or ET = 0
    	and it is not the case that
       		the estimated annual net tax payable for the entity for the year is an X.

...is not being parsed correctly; instead of:

clause([the_estimated_tax_for_for_is,'an entity','a year','an amount ET'],
		  and([the_estimated_annual_net_tax_payable_for_for_is,'the entity','the year','ET'],
		      or(unknown_tokens([word('ET',loc(5174,5176)),punct(>,loc(5177,5178)),punct(=,loc(5178,5179)),number(0,loc(5180,5181))]),
			 and(unknown_tokens([word('ET',loc(5190,5192)),punct(=,loc(5193,5194)),number(0,loc(5195,5196))]),
			     not([the_estimated_annual_net_tax_payable_for_for_is,'the entity','the year','an X'])))))

...it should parse instead to:

clause([the_estimated_tax_for_for_is,'an entity','a year','an amount ET'],
		  or( 
            and(
                [the_estimated_annual_net_tax_payable_for_for_is,'the entity','the year','ET'],
                '>='(ET,0) ),
			and(
                '='(ET,0),
			     not([the_estimated_annual_net_tax_payable_for_for_is,'the entity','the year','an X']))
            ))

# is_a
Much better, but the ontology clauses should use instead the is_a/2 predicate. 
Also, you should recognize Prolog's is/2, so for example payg.le's third rule ...

the applicable tax rate for an entity on a year is a number ATR
    if         the entity is under the aggregated turnover threshold in the year 
            or the entity is a base rate entity
        and ATR is 0.25
    or      ATR is 0.30
    	and it is not the case that
    		the entity is under the aggregated turnover threshold in the year
        and it is not the case that
        	the entity is a base rate entity.


should NOT parse to the following...:

	   clause(applicable_tax_rate_for_an_entity_on_a_year is number_ATR,
		  or([is_under_the_aggregated_turnover_threshold_in,entity,year],
		     or([is_a_base_rate_entity,entity],
			or(unknown_tokens([word('ATR',loc(6136,6139)),word(is,loc(6140,6142)),number(0,loc(6143,6144)),punctuation('.',loc(6144,6145)),number(25,loc(6145,6147))]),
			   or(unknown_tokens([word('ATR',loc(6160,6163)),word(is,loc(6164,6166)),number(0,loc(6167,6168)),punctuation('.',loc(6168,6169)),number(30,loc(6169,6171))]),
			      or(not([is_under_the_aggregated_turnover_threshold_in,entity,year]),not([is_a_base_rate_entity,entity])))))))

...but instead to:

	   clause(applicable_tax_rate_for_an_entity_on_a_year is number_ATR, or(
		  and(
            or(
                [is_under_the_aggregated_turnover_threshold_in,entity,year],
                [is_a_base_rate_entity,entity]
            ),
			is(ATR,0.25)
          ),
          and(
            is(ATR,0.30),
            and( not([is_under_the_aggregated_turnover_threshold_in,entity,year]),
                and(not([is_a_base_rate_entity,entity]))))))

# sums
Better, now we need to support aggregates properly. In rule

the year-to-date instalment adjustment for an entity E for an income year is an amount V
    if E is the taxpayer
    and the current quarter is a quarter C
    and the income year is a year under consideration
    and a number IR is the sum of each amount such that
            the amount with an ID was reported as an instalment on a quarter X of the income year
            and X is previous to C
    and a number IVC is the sum of each number such that
            the number with an other ID was reported as a variation on a quarter Y of the income year
            and Y is previous to C
    and V = IR - IVC.

... a subgoal such as ```a number IR is the sum of each amount such that INDENTED_GOAL``` needs to be parsed into something like:

    sum([each, amount], INDENTED_GOAL, [a number, IR])

# fixing sums

The fragment:

a number IR is the sum of each amount such that
            the amount with an ID was reported as an instalment on a quarter X of the income year
            and X is previous to C

...is being parsed into

sum([each,_],and([with_was_reported_as_an_instalment_on_of,amount,'an ID',quarter_X,income_year],[is_previous_to,'X','C']),[a,number,'IR']))

You're losing the aggregated variable; the forst argument needs to be [each,amount]

Also the following is failing to parse:

a number IVC is the sum of each number such that
            the number with an other ID was reported as a variation on a quarter Y of the income year
            and Y is previous to C

"the number with an other ID was reported as a variation on a quarter Y of the income year" is being parsed as unknown_tokens(..)

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
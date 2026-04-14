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

## fixing it
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

## more fixes
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

## is_a
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

## sums
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

## fixing sums

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

## simplify ontology and scenarios
In the ontology parse each fact as is_a(Type,SuperType) fact or clause

In scenarios and queries, instead of terms clause(Literal,true) keep simply Literal.

In scenarios, in general facts have no variables. For example "John is born in the UK on 2021-10-09" should be is_born_in_on('John',[the,'UK'],date(2021,10,09)); we can keep the date representation provided by out tokenizer.

## Error reporting
Let's add syntax error reporting, so we have a new last argument: parse_le(String, doc(NewSections), Issues), where Issues will be a list of error(Message,CharPosition); future versions may add warning(...) too. A normal parsing will return an empty Issues list. If errors exist, try keeping as much of the parsed doc as possible.
Also, any unknown_tokens(Tokens) in the parse result should be reported as errors too

To test this start by building variants of two examples: payg.le and citizenship.le, by introducing a few syntactic errors in each.

For the implementation, consider these optional suggestions: 
- CharPositions are in the tokens being parsed
- remainder(Tokens)//1 which returns the tokens not yet parsed; ans
- asserting errors, so that multiple errors can be noted in  thread_local temporary facts and collected at the end of the parse to include in the Issues list

  ---

There is a new bug:
?- test_all.
Parsing examples/moreExamples/1_cgt_assets_and_exemptions_3.le... 
ERROR: Type error: `text' expected, found `date(2015,10,24)' (a compound)
ERROR: In:
ERROR:   [72] atomic_list_concat([before,...],'_',_157872)
ERROR:   [69] le_grammar:extract_value_from_parts([word(before,...),...],_157916,[date-_157956,...|...],_157920,[dict(...,...,...),...|...],true,true) at /Users/mc/git/LogicalEnglish2/le_grammar.pl:547
ERROR:   [68] le_grammar:match_instance_to_template([word(before,...),...],[_158044],[date-_158058,...|...],_158018,[dict(...,...,...),...|...],true) at /Users/mc/git/LogicalEnglish2/le_grammar.p

## More clean up
The third argument of dict(..) should have simply the atoms and variable, not word(_) terms
Lists of atoms in ontology fact arguments should be concatenated into single atoms, e.g. [quarter,1] becoming quarter1

In payg.le the rule:

the year-to-date fraction for a quarter Q is a number F
    if Q is quarter 1 
        and F is 0.25
    or Q is quarter 2 
        and F is 0.5
    or Q is quarter 3 
        and F is 0.75
    or Q is quarter 4 
        and F is 1.0.

is not being parsed correctly: the head is resulting into unknown_template(...) when it should match the existing template: 
the year-to-date fraction for *a quarter* is *a fraction*.

The ontology rule

    a quarter X is previous or equal to a quarter Y 
        if X is previous to Y 
        or X is equal to Y.

should parse to

    clause(is_previous_or_equal_to(L6,M6),or(is_previous_to(L6,M6), equal_to(L6,M6) ))

This requires that a "system template" or "predefined template" exists, as if defined by 

    *a thing* is equal to *another thing*

, so let's have a le_system_template table, in a separate module file le_system_templates.le used by le_grammar

In the ontology fact arguments, when parsing token sequences to atoms you should concatenate the atoms with '_'. So for example "quarter 1 is a quarter" should produce is_a(quarter_1,quarter)

ontology facts should have no singleton variables, they typicall have only constants. So for example "Q1 is previous to Q2" should parse to is_previous_to('Q1','Q2')

## Restarting our vibe and build transtive_is_a
You are an expert in Logical English (LE), a constrained natural language mapping to PROLOG. It is described in @docs/le_syntax.md. There are examples in @examples/moreExamples - all files with extension .le
Consider the working LE parser in @le_grammar.pl, and related files le_system_templates.pl and tokenizer.pl

Using the information provided in the parsing of the ontology section, build a temporary (thread_local) is_a(Type,SuperType) predicate with all is_a facts and clauses; make also a validation agains loops in the is_a tree, so please write a loop checker and report a parsing issue if a loop is found; also define transitive_is_a(Type,SuperType) which calls is_a/2.


## multiple errors
It would be nice to report several parser errors, not just the first. For example, parsing moreExamples/payg_buggy.le should result in two errors

## le_kbs module

You are an expert in Logical English (LE), a constrained natural language mapping to PROLOG. It is described in @docs/le_syntax.md. There are examples in @examples/moreExamples - all files with extension .le.
Now create a simple LE knowledge bases manager, a new module file le_kbs.pl, importing le_grammar. Its main predicate is load(FilePath,NewModule) which:
1) Creates a new module name M, from a variant_sha1 of the FilePath and its modification date
2) calls parse_le, takes the doc AST term term and keeps its information in several relations in the new module M:
- a single fact le_kb(KBname)
- scenario(Name,FactsList),
- query(Name,Goal)
- PROLOG clauses with the LE program rules and is_a clauses; these will not be executable dirctly (we will introduce an interpreter later), but stored as is
- All previous asserts should keep the respective clause references, so that for each one you can add a fact le_source(ClauseRef, BeginPosition,EndPosition), preserving the information from the positions of the parsed tokens 

## Sessions

We'll now add session modules,  mutable counterparts to the imutable KBmodules. The session module will represent the mutable data of a LE program in its KBmodule, which is imutable. E.g. provide workspace specific to a session.  Later our future meta-interpreter will decide when it needs to use this data.

Add to le_kbs.pl these predicates:
 - createSection(KBmodule,NewSessionModule) , which given a KB module as produced by load/2 returns a new module (named with a new uuid) with working memory for a LE session. Assert in it a le_my_kb(KBmnodule) fact. Declare in it a single le_neg/1 dynamic relation for negated facts; 
 - addSessionFact(SessionModule,Fact), which asserts Fact into SessionModule, recording its clause ref in a relation sessionClause(Ref)
 - negateSessionFact(SessionModule,Fact), which will retract any matching facts from the session and assert a le_neg(Fact) fact
 - setScenarion(SessionModule,ScenarionName): this copies the facts in the scenarion in the session's kb into the session module, by calling addSessionFact
 - clearSession(SessionModule), which erases all facts previously asserted, by using their clause refs in sessionClause/1; it then reases all facts in sessionCluase/1
 - printSession(SessionModule), which prints the session id (module name), its kb name and the current facts 

Write a simple program exxample.pl which uses the parser and le_kbs.pl to create a simple session witn a scenarion for the citizenship.le example

## Running queries

We'll now add to le_kbs.pl a predicate query(SessionModule,Template, TemplateInstance) which:
- converts Template to a Prolog literal Goal, using dict(...) in the KB module of the session
- Calls Goal in the SessionModule
- Converts the bound Goal to TemplateInstance, again using dict(...)

Then another predicate queryScenario(SessionModule,ScenarioName,TemplateInstance), which sets a scenario and then calls the previous query(...)

for this to work we also need the session module to import its KB module - set that up  when you create the session; also we need these meta predicates defined in le_kbs.pl, so that the rule bodies can be executed in PROLOG:

and(A,B):- A,B.

or(A,_) :- A,
or(_,B) :- B.

not(A) :- \+ A.

Then alter examples/appExample1.pl so it runs a couple of queries

## Running queries (Take 2)
You are an expert in Logical English (LE), a constrained natural language mapping to PROLOG. It is described in @docs/le_syntax.md. There are examples in @examples/moreExamples - all files with extension .le. 
We already have a working parser in @le_grammar.pl and a loader in @le_kbs.pl, as well as an incomplete predicate query(SessionModule, Template, TemplateInstance, Unknowns, Why), which calls i(..)

Create a new module reasoner.pl defining the missing predicate i(Goal,SessionModule,Unknowns,Why), a PROLOG-like meta-interpreter for LE, where:
- Goal is a LE goal, expressed in PROLOG literals (not LE templates)
- SessionModule is the module containing facts to be considered prior to LE program clauses; it is created by createSession/2, and contains a fact le_my_kb(KBmodule) indicating in which module the LE program clauses are
- Unknowns is a (possibly empty) list of PROLOG literals that could not be evaluated either because of (a) floundering or (b) being declared as le_unknown(TemplateInstance) in the KBmodule; normal executions without floundering will return an empty Unknowns list; the Unknowns lisrt can be seen as the conditions for the returned Goal bindings to be true (a conditional answer)
- Why is an explanation tree, made of two kinds of nodes: success(IntermediateGoalAnswer,MatchingClauseRef,Children) and failure(IntermediateGoalCall,PredicateIndicator,Children). success(...) subtrees are built by the interpreter, they're proof trees basic ally; failure(..) subtrees are trees of failed goals and must be built at the end of execution from asserted facts

## Fixing it
I don't like the way failure trees are built. Do not use i_failure, but instead use a goal call counter, assert a binary relationship called(ParentID,ChildID,ChildCallTerm) when handling literals, and build the tree at the end of execution.

Please scrap that complicated build_failure_tree(...) predicate entirely, as well as the goal counter. Let's make this work first only with positive (success) explanations.

As one can see at the end of appExmple1.pl (which I have altered slightly), query answers miss variable bindings:

...
Current Facts:
  sd9d6317a-3783-11f1-9059-6ba83b5eedce:is_born_in_on(John,[the,UK],date(2021,10,9)) :- true
  sd9d6317a-3783-11f1-9059-6ba83b5eedce:is_after_commencement(date(2021,10,9)) :- true
  sd9d6317a-3783-11f1-9059-6ba83b5eedce:is_the_mother_of(Alice,John) :- true
  sd9d6317a-3783-11f1-9059-6ba83b5eedce:is_a_British_citizen_on(Alice,date(2021,10,9)) :- true
  sd9d6317a-3783-11f1-9059-6ba83b5eedce:le_neg(is_a(Alice,person)) :- true

Running queries:
Query 1 Result: [_22768,acquires,British,citizenship,on,_22798]
Query 2 Result: [_26672,is,the,mother,of,_26702]

## Running tests

Now let's add a test suite runner. The LE test suite  already exists, it is the set of all .le files in moreExamples/ for which there is a .le.tests file. Each of these files contains the expected answers for all program queries and scenarios, in PROLOG facts expected(QueryName,ScenarioName,ListOfTemplateInstances). Please add a runTestsFor(LE_tests_file,Result) predicate to le_kbs.pl which given a tests file loads the corresponding LE program, and runs the queries in  scenarios as dictated by expected(...). Then add a variant to accept a directory argument instead of LE_tests_file, which iterates over all test files in the directory

Now run the test suite and make sure all tests pass

## TBD: 


## use transitive_is_a
The matching of rule literals and scenario facts to existing templates should consider the ontology, making sure that the template instance in the rule head or body matches the template considering the type of the variables in there. So for example in scenarion test_quarter_2 of payg.le, "the current quarter is quarter 2" matches template "the current quarter is *a quarter*." only because transitive_is_a(quarter_2,quarter)



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
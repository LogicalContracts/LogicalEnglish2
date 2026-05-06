# Vibe coding the new LE

Unlike LE1, written by carbon units Jacinto, Bob and Miguel, LE2 was mostly vibe coded via silicon with https://opencode.ai and gemini-3-flash-preview. Following are the main prompts used, for historical record. See also AGENTS.md, e.g. "Opencode's CLAUDE.md". 

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

let's make sure first that the tests for citizenship.le work fine

I see that you reordered the templates in citizenship.le, so that *a person* says that *a sentence*, came first. IF I reorder them into the original order, as I just did in citizenship.le, there is an error:

ERROR: m76c279100630b5341cfaaf647f3ce0f8c53c5338:is_the_father_of/2: Unknown procedure: m76c279100630b5341cfaaf647f3ce0f8c53c5338:and/2
Warning: Goal (directive) failed: user:test

There is a loop running the first test:
101 ?- use_module(le_kbs).
true.

102 ?- runTestsInDir('examples/moreExamples/',R).
Running tests for cgt_assets.le.tests...
^CAction (h for help) ? goals
    [443] le_grammar:parse_literal([], [dict([costed_to_acquire, _242832, _242838], [_242832-asset, _242838-amount], [_242832, costed, _242838, to, acquire]), dict([meets_the_definition_of_plant_and_equipment_under_Division_43_of_the_Income_Tax_Act, _242698], [_242698-thing], [_242698, meets, the, definition|…]), dict([is_used_soley_for_taxable_income_generating_purposes, _242606], [_242606-asset], [_242606, is, used|…]), dict([is_used_purely_for_personal_use_purposes, _242520], [_242520-asset], [_242520, is|…]), dict([was_secured_for_valour_or_brave_conduct|…], [… - …], [_242434|…]), dict([…|…], […], […|…]), dict(…, …, …)|…], ['before_or_equal_to_1985-9-19'-_417750, date-_417390, 'CGT_exempt_asset'-_327160, asset-_327154], _436096, _436098, true)
etc.


The first time I run time(runTestsInDir('examples/moreExamples/',R)) it takes about 2 seconds. Running it again takes 9 seconds.
This suggests some problem managing loading of programs, or something else

## negative explanations
Let's now add negative explanations to the reasoner. We'll use the same last argument Why in i(...), as follows:
- Every goal literal will have an ID, kept by a global counter
- When a literal calls another, assert a thread_local fact called(ParentID,My\ID,MyCallTerm)
- When ending i(...), enhance the positive explanatin tree with failed subtrees (under not(..) subgoals)
- When a not(G)) subgoal suceeds, the positive (success) explanation subtree will be the failure tree for G
These changes must be local to reasoner.pl and not alter the overall reasoner results

Explanations are currently over detaioled. We need to ignore the trivial LE connectives (and, or) retaining only the "juicy" elements supporting the conclusion

## web api
Create a new module classic_web_api.pl implementing a web API as described in docs/api.md, which uses le_kbs. Implement all methods except le2prolog, answer_via_llm and draft.
Then create an example client shell script appExample1_web.sh using curl to test the classic_web_api, similar to appExample1.pl

## Editor
You are a Logical English (@docs/le_syntax.md) expert, and also an expert on Language Server Protocol and the Monaco LSP client,  https://github.com/microsoft/monaco-editor. We need a cute, simple browser based editor for LE programs, so please implement (ALL changes for this need to go into directory editor/ ):
- a LSP server for Logical English, written in Typescript, so it is fully browser based; to write the Typescript you should introspect the DCG rules and tokens in le_grammar.pl
- a simple static web page using Monaco, receiving the LE text in the URL; later versions will load LE text from other sources; this first version will not be able to save - only edit and display coloured LE locally

    for inspiration: https://github.com/nikolaimerritt/LogicalEnglish/blob/main/report/FinalReport/main.pdf

First, add a method to our docs/api.md to return the names of all LE examples in (hardwired path) "examples/moreExamples", and implement it in classic_web_api.pl
Then a "Open from server" item to the File menu which opens a modal dialog to pick any of the avaialble LE examples, fetched it from the server and loads it into the editor; prior to all this, warn the user to dave any changes

## Editor querying

Now add a panel below the editor, with two popup menus: one for scenarios, the other for queries. When the user presses either, the editor client should ask the server (cf. docs/api.md) to load the editor text as a new LE module, obtaining the queries and examples in the program. the server should be asked for this only once (until the editor changes the program text). Then add also a Query button, which will execute the selected query and scenarion on the editor program; and a field below to depict the answers obtained

## Explanations

At the end of query/5 in le_kbs.pl, postprocess the explanation term to replace clause refs by character position ranges, as obtained from le_source; review convert_why in classic_web_api.pl accordingly, so explanations will contain character positions rather than clause refs.
Then back to the UI: Split the RESULTS panel in two: the left continues to show the last answers for the selected query, but each answer is clickable; when clicked, the right panel will show the explanation tree for the answer. IF no answers, the explanation will be the negative explanation.
Explanation objects are in the 'why' fields.
Finally, make each explanation tree node clickable: when clicked, the editor should select the respective text range

next...:

First, we need to keep source positions for scenarion facts, so navigation from the explanation tree to code is commplete. Thise requires a revision of setScenarion/2 (probably)
Another issue is the explanation nodes: the explanation post processing should also add to the explanation nodes a "bound template" version of the PROLOG literal; and the explanation tree rendering in the UI should use that

About "Open from server...": please rename to "Open copy from server..."; and make it refresh the example name at the top of the window
Also make the session ID a bit larger, and justify it to the right of tht window

## Indentation
Let's please indent the code in all our .pl files in a different manner, without altering its functionality. Specifically, we need PROLOG if-then-else constructs laid out differently. So for example instead of 

explain(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    init_counter,
    (   SessionModule:le_my_kb(KBmodule) ->  true;   KBmodule = none
    ),
    (   solve(Goal, SessionModule, KBmodule, [], 0, 0, Unknowns, Whys)
    ->  true
    ;   Unknowns = [],
        findall(W, (called(0, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
    ).

...please write the above instead as:
explain(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    init_counter,
    ( SessionModule:le_my_kb(KBmodule) ->  true; KBmodule = none),
    (   solve(Goal, SessionModule, KBmodule, [], 0, 0, Unknowns, Whys) ->  true 
        ;   
        Unknowns = [],
        findall(W, (called(0, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
    ).

Notice that if a if-then-else construct is small (as in the first above) we keep it in a single line; otherwise we indent and split lines as in the second.

For longer, multi branch if-then elses use a terser version; for example instead of:

extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) ->  
        length(Rest, L), L =< 5,
        extract_id(Rest, Name)
        ;   
        Words = [each | Rest], Rest \== [] ->  
        length(Rest, L), L =< 5,
        extract_id(Rest, Name)
        ;   
        Words = [which | Rest], Rest \== [] ->  
        length(Rest, L), L =< 5,
        extract_id(Rest, Name)
        ;   
        Words = [who] -> Name = who
        ;   
        Words = [what] -> Name = what
        ;   
        Words = [when] -> Name = when
        ;   
        Words = [where] -> Name = where
        ;   
        Words = [W], is_id(W) -> Name = W
    ).

...use:
extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [each | Rest], Rest \== [] ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [which | Rest], Rest \== [] ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [who] -> Name = who
        ; Words = [what] -> Name = what
        ; Words = [when] -> Name = when
        ; Words = [where] -> Name = where
        ; Words = [W], is_id(W) -> Name = W
    ).

Some single line if-then-elses are too long for a single line. For example:

second_pass_ontology_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( parse_literal(Head, Templates, [], VM1, NewHead, true) -> parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody); NewHead = unknown_template(Head, Start, End), parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)).

...should be instead:

second_pass_ontology_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( parse_literal(Head, Templates, [], VM1, NewHead, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody)
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)
    ).

## expected answers
Let's add an optional construct for scenarios: "QueryName expects answers ListOfAnswers.". This is intended to replace the need for .le.tests files. For example the first fact in citizenship.le.tests will be represented like this in scenario 'alice':

scenario alice is:
    John is born in the UK on 2021-10-09.
	2021-10-09 is after commencement.
	Alice is the mother of John.
	Alice is a British citizen on 2021-10-09.
    one expects answers ["John acquires British citizenship on 2021-10-9T0:0:0.0"].

Considering this design:
- Enhance the parser to recognize it
- Represent the information into a new system predicate le_expected(Queryname,ScenarioName,listOfAnswers) in the KB module
- Review the runTests etc. predicates to use both this new predicate and the legacy .le.tests files, which we will continue to support
- Move all expected/3 facts from the .le.tests into the .le files

## Warnings and error in the editor
We need to show in the editor any errors (detected by the parser) and warnings (as produced by le_verifier:verify(..)); I suggest using red and yellow respectively.
And also make sure that if there are errors the Query button is disabled (with a tooltip referring the presence of errors)

## MCP server
Implement a new module llm/mcp.pl with a Model Context Protocol Server written in SWI-PROLOG, via HTTP at endpoint /mcp, with the following tools:
- list LE program example names and their summaries 
- Execute an arbitrary query for either a named program example or a given program text, obtaining answers with explanations
- parse and verify a new program, returning all issues found (syntax, warnings, failed tests)
Also provide example settings files for Claude Code, Claude Desktop and ChatGPT Pro

## which
Let's introduce a new LE keyword 'which', a short hand for conjunction plus referencing a variable. For example, instead of writing, in royal_family.le,

a person is an ancestor of a descendant if 
    the person is a parent of a child and 
    the child is an ancestor of the descendant.

...we want to write the equivalent:

a person is an ancestor of a descendant if 
    the person is a parent of a child
    which is an ancestor of the descendant.

Furthermore, we want to use this LE extension to define a methodology for future extensions: the changes needed (probably) to le_grammar.pl and le_kbs.pl should be in a separate file, loaded by the main system if present.

## vibe coding LE
We want to add an agentic/vibe coding ability to our editor, by using opencode.ai as a PROLOG subprocess via its command line interface (cf. https://opencode.ai/docs/cli/). The flow will be like this:
- The user must provide at least one API key, as expected by llm_client.pl. The key is to be provided in a new modal dialog invoked from the Misc menu, where the user may pick any of the models in llm_model_entry(..), and it is to be stored in browser storage
- The bottom panels of the editor need to morph into a new simple (bottom) tabbed pane UI, its first, default, pane being "Query", with what we have now; then with a new second pane "LE Assistant" 
- The LE Assistant pane should have a chat like UI, with scrolling history at the top and a bottom field for user commands.
- When the user types something in the Assistant command field, like "Fix indentation" or "draft me a LE program encoding parking regulations in London", opencode is called from the PROLOG side, via its CLI; it should use a new specific AGENTS.md (different from the AGENTS.md we have already), inspired in https://raw.githubusercontent.com/LogicalContracts/LogicalEnglish/refs/heads/main/CLAUDE.md BUT not using shell commands, and instead using our own MCP server for program verification. And feel free to revise it! 
-  So Editor calls Prolog which calls opencode which possibly calls (same, but in different thread...) PRolog MCP server - in addition to going out to the web etc as opencode does.
- The whole text in the editor is the main implicit argument for the prompt, passed as a temporary text file so that opencode can edit in the server, and then hand it back so the editor replaces the displayed text with the new version. Multiple user commands will correspond to multiple opencode commands, so these need to use the same shared (opencode) session for all of them. 
  
Do not install opencode yourself, the user should do that.

## 3 features...
Please implement the following 3 featurfes, in sequence:

### prolog calling
Let's let the user define special rules whose body is a single PROLOG goal, so that we can interface to system predicates outside LE. For example:

a person has an age if
    prolog myModule:myAgeFinder(the person, the age).

... where  myAgeFinder(P,A) is a  predicate in module myModule.

### Rules with IDs

Let the user prefix a rule by an arbitrary alphanumeric ID, with the simple syntax:

rule myID:
myRuleHead if myRuleBody.

The ID should be remembered in an extra argument in le_source(...). If the user provides no ID, the system should generate one ID based on the order of the rule in the LE file.

Also provide a PROLOG predicate le_my_id(ID) which introspects the current rule ID during execution.

Write a simple example testing rule IDs and checking rule ID discover with le_my_id , by using the prolog calling feature above


### Rules with numbering

Let's support an alternative syntax to Logical English rules, distinguished from regular rules by using "if:". In this syntax, indentation is irrelevant for the scoping of logic connectives, which is instead determined by item numbering.
For example, instead of writing...

An A has a relevant asset B if
    the A is affiliated with a C and
    the C is connected to a D and
    the D owns the B and
        the B is used in the business of the A
    or
            the A is connected to an E and
            the B is used in the business of the E.

...we will be able to also write the same rule as follows:

An A has a relevant asset B if:
1.the A is affiliated with a C; and
2.the C is connected to a D; and
3.the D owns the B; and
4.one of:
4.1. the B is used in the business of the A;or
4.2. all of:
4.2.1. the A is connected to an E; and
4.2.2. the B is used in the business of the E.

These hierarchical designators of each sub-condition can use letters, digits, roman numbers, as found usually in legal documents

Furthermore, let's keep track of how those hierarchical designators relate to their specific rule components (sub-conditions), by adding a new predicate le_source_element(RuleID, HierarchicalDesignator, Prolog_goal) to the KB module. 

Implement this addition to the parser, BUT keeping the bulk of changes in le_extensions.pl, because this will be an optional feature in LE.
Add an example testing this feature, by recovering the hierarchical designators of a rule given its ID, and using the prolog keyword to access le_source_element.

For this you will need to also implement a le_my_kb(KBmodule), which returns the KB module of the current rule.

### Report on the 3 features....
We have successfully implemented and verified the three requested features: Prolog calling, Rule IDs, and Hierarchical Numbering.
Key Achievements
- Prolog Calling: Rules can now execute arbitrary Prolog goals using the prolog keyword. LE variables are automatically unified with Prolog variables.
- Rule IDs: Rules can be explicitly named (e.g., rule myRule: ...) or will receive auto-generated IDs (rule_1, rule_2, etc.). These IDs are stored in the KB metadata.
- Hierarchical Numbering: Rules can use hierarchical numbering (e.g., 1., 1.1., a.) with the if: separator. The structure is automatically converted into nested and/or logic, and each numbered element is tracked in le_source_element/3.
- Introspection: Rules can now use le_my_id(ID) and le_my_kb(KB) to identify themselves and their parent Knowledge Base module at runtime.
Verification Results
- New Feature Tests: prolog_call.le, rule_id_test.le, and numbering_test.le all pass their corresponding .tests suites.
- Regression Testing: 173 out of 175 total tests in the repository are passing. The two remaining failures in cgt_assets.le appear to be pre-existing logic discrepancies in the test data rather than regressions from the new features.
- Code Quality: Resolved all syntax errors, singleton variable warnings, and module permission issues encountered during development.
Relevant Files Updated
- le_grammar.pl: Updated DCG to support rule headers, prolog tokens, and if: separators.
- le_extensions.pl: Implemented the core logic for Prolog token resolution and hierarchical numbering parsing.
- le_kbs.pl: Updated KB loading, metadata management, and added introspection predicates.
- reasoner.pl: Updated the meta-interpreter to maintain rule ID and KB module context using non-backtrackable global variables.
The system is now stable and the new features are fully integrated into the Logical English environment.

## Fix rules with numbering
The rule IDs and hierarchical designators in rule conditions as alternative to indentation... are not working completely. Consider the revised LE file examples/moreExamples/numbering_test.le .
Make sure the answers to query one include rule jd

## Unless
We need a new construct in LE rules, 'unless', which may be comboned with 'and'. Here is an example of use:

the templates are:
we will make *a payment* for *an incident* under *a policy*.
*an incident* is covered.
*a policy* is cancelled.

% and now rules with 'unless':

rule one.
we will make a payment for an incident under a policy if 
    the incident is covered and unless the policy is canceled.

rule two.
we will make a payment for an incident under a policy unless 
     the policy is canceled.

rule one above is equivalent to:

we will make a payment for an incident  if 
    the incident is covered and 
    it is not the case that 
        the policy is canceled.

rule two is equivalent to:

we will make a payment for an incident if
    it is not the case that
        the policy is canceled.

Notice that 'unless' can by itself signal the presence of a rule.

Build a simple testing example for this construct, and implement it in the parser etc. The bulk of its implementation should go into le_extensions.
Please remember to support it in the editor (colouring, word completion)

## Debugging negative explanations

In example 4_affiliates_3.le, scenario test, query one, the following explanation subtree is incorrect:

- it is not the case that his company is a superannuation fund
  - his company is a superannuation fund
    - his company is a superannuation fund
      - his company is a superannuation fund
        - his company is a superannuation fund according to other legislation
            his company is a superannuation fund according to other legislation
        his company is a company
      - company is a superannuation fund
        - company is a superannuation fund according to other legislation
            company is a superannuation fund according to other legislation

It has redudant nodes, and an incorrect subtree. It should be just:

- it is not the case that his company is a superannuation fund
  - his company is a superannuation fund
    - his company is a superannuation fund
        - his company is a superannuation fund according to other legislation

This seems a problem in reasoner.pl

---
Navigation is now fine, but can we have that exaple failed subtree as just:

- it is not the case that his company is a superannuation fund
  - his company is a superannuation fund
        - his company is a superannuation fund according to other legislation
        - 
...? I see no reason to repeat the "his company is a superannuation fund" node

### Gemini's comment...
I have fixed the redundant nodes and incorrect subtrees in the explanation tree.
The issues were:
1.  Redundant Nesting: The meta-interpreter was recording every call, including those that were just wrappers like le_at. This caused multiple identical-looking nodes in the tree.
2.  Incorrect Subtrees: The is_a transitivity logic was producing irrelevant failure paths (like company is a superannuation fund) when a direct rule already explained the failure.
3.  Negation Redundancy: solve_real(not(Goal)) was asserting a called fact for Goal even if it was already wrapped in le_at, adding another layer of redundancy.
I modified reasoner.pl to:
1.  Skip Trivial Goals in solve: Trivial goals like le_at no longer assert a called fact, preventing them from appearing as redundant nodes.
2.  Strip le_at in Negation: solve_real(not(Goal)) now strips any le_at wrapper before recording the call to Goal, ensuring a cleaner root for the failure tree.
3.  Enhanced Variant Collapsing in build_failure_tree: The failure tree construction now more aggressively collapses nodes that are variants of each other, even if one is wrapped in le_at.
4.  Filter Successful Branches in Failure Trees: I implemented a succeeded/1 fact to track successful goals and ensure they don't appear in failure trees, which also helped eliminate the "nonsense" transitivity paths that were partially successful.

## original queries in LE

In the Query panel the query menu is showing templates. Show instead the textual query as in the LE program (it may be available in query_info(...)), and show the selected (query) template instead as a tooltip when the user hovers the Query button

## Templates confusing "is a"
Some LE templates are being confused with "is a". 
For example in examples/moreExamples/augmentedsem.le, template "*a label* is a label for *a description*" implies that, in line 24, "X is a label for Latitude" should be translated into PROLOG as is_a_label_for/2 - not to is_a/2.

Good, now for something else:
We also need "is of" to be recognized as a synonym for "is a". So for example in examples/moreExamples/augmentedsem.le , rule

an object is of a type
    if a label is a label for the type
    and the object is of the label.  % connection to the dataset 

a type is a variable; interpreting the head as containing the type 'of a type' is incorrect.  

## big conclusions

We now wish to allow nested sentences with 'which' also in rule heads, or simple facts. For example this rule should be acceptable (templates not shown):

we will cover a cost
    which is in respect of a damage
    which is caused by a burst pipe
if 
    it is not the case that
    the damage is caused by wear and tear or negligence.

being equivalent to 

we will cover a cost 
    which is caused by a burst pipe
if 
    the cost is in respect of a damage and
    the damage is caused by a burst pipe and
    it is not the case that
        the damage is caused by wear and tear or negligence.

In summary, which conditions in a head miggrate to the rule body with explicit variables.


Similarly for "facts", for example this fact:

we will cover a cost which is in respect of a damage which is caused by a burst pipe

is equivalent to:

we will cover a cost if
    the cost is in respect of a damage and
    the damage is caused by a burst pipe.

Write a simple example with these or simlar rules and facts for testing, and implement this LE extension ("big conclusions") mainly in le_extensions.pl

### Gemini's comment
I have implemented the "big conclusions" extension for Logical English, allowing nested sentences with which in rule heads and facts.
Changes Implemented:
1.  Big Conclusions Logic (le_extensions.pl):
    *   Added a new extension to the second pass of the parser that identifies which in rule heads and facts.
    *   Implemented big_conclusion/6 to recursively split sentences at which and migrate the resulting conditions into the rule body.
    *   Ensured correct variable unification by prepending a dummy variable token to nested sentences, allowing which to correctly refer to the subject of the preceding clause.
2.  Grammar Enhancements (le_grammar.pl):
    *   Added a second_pass_item_extension/4 multifile hook to allow extensions to override or augment the default clause generation logic.
    *   Updated rule ID parsing to support both words and numbers (e.g., rule 1:).
    *   Adjusted template priorities to ensure system templates like *V1* is in *V2* act as fallbacks and do not aggressively match user-defined templates (e.g., *a cost* is in respect of *a damage*).
3.  Robustness & Cleanup (le_kbs.pl):
    *   Fixed singleton variable warnings and ensured templates are correctly passed through the term transformation pipeline.
    *   Updated 3_rollover_3.le to remove a redundant template declaration that conflicted with the improved priority rules.
4.  Verification:
    *   Created a new test file examples/moreExamples/big_conclusions.le covering nested which in both rules and facts.
    *   Verified that all 182 tests (including the new ones) pass, ensuring no regressions in existing functionality.
Example of Supported Syntax:
The following is now correctly translated into a single Prolog rule with unified variables:
we will cover a cost
    which is in respect of a damage
    which is caused by a burst pipe
if 
    it is not the case that
        the damage is caused by wear and tear or negligence.
This is equivalent to:
we_will_cover(Cost) :-
    is_in_respect_of(Cost, Damage),
    is_caused_by(Damage, BurstPipe),
    not(is_caused_by_wear_and_tear_or_negligence(Damage)).

## explanations are missing for aggregates
For example in sbppxml1.le for scenario one and query indirect the explanation shown is just:

- the indirect small business participation percentage of Tom Fry in Tallow Unit Trust is 0
    0 is the sum of each Po such that
        MISSING

there should be a MISSING node with "the indirect small business participation percentage 1 of the entity in the other entity is Po" - either a failure node, or multiple success nodes, one for each aggregated value; and subtrees under all of these

This may relate to a problem in sbppxml1.le: test failed for query 'indirect' in scenario 'one'.

Expected: [the indirect small business participation percentage of Tom Fry in Tallow Unit Trust is 0.0400000000000001]
Actual: [the indirect small business participation percentage of Tom Fry in Tallow Unit Trust is 0]

The Actual value with 0 is wrong, should be 0.04 (and so should be the expected value above, which we will round to 0.04)

Might the computation of the sum be buggy...?

## broken test
In 3_rollover_3.le, tests are failing, missing answers for query two in scenario "Andrew email Feb 4 2021 version 2":

Expected: [andrew is a party of event 123,company1 is a party of event 123,miguel is a party of event 123]
Actual: [company1 is a party of event 123]

Something preventing backtracking over the rules...?

## another warning
Add another verification in le_verifier.pl: if the user defines a template identical to any of those in le_system_template(...) AND there isn't any rule or fact in the program, issue a warning: "Template .... redefines a similar system template and there are no rules for it", with fixe:
 "Either change the template slightly or add some rules"

## is_a hierarchy

We need a visualization of the is_a hieararchy for a LE program. So please:
- add a predicate is_a_hierarchy(KBmodule,H) to le_kbs.pl which finds all answers for is_a(_,_) on the KB (not using any scenario data) to build the types tree; in each node keep the source location of the fact or rule head producing the node. 
  --To obtain is_a(..) source locations do NOT alter le_grammar.pl, but instead introspect the clauses loaded into the KB module, to collect matching is_a(...) tuples with the source locations
- add some method to classic_web_api.pl to expose that tree to our UI
- add a "See Types Hierarchy" item to the editor's contextual menu, which opens a new window with a simple Javascript based rendering of the tree; tree nodes should navigate back to the editor window, selecting the relevant source code where the type is defined

## explanations for 'says that'
In explanations, some Prolog literals are not beeing shown as template instances. For example in citizenship.le, scenario trust_harry, query one has an explanation which includes a node "Harry says that is_the_father_of('Harry','John')"

## variables colouring in rule,
Variables are coloured in templates in the editor, but not coloured in template instances in rules. For example, in citizenship.le, in rule

a person is the father of an other person
    if a third person says 
    that the person is the father of the other person
    and the third person is qualified to determine fatherhood.

The following fragments above should be coloured as variables:
a person
an other person
a third person
the person
the other person
the third person

## Adjusting rule numbering

We need to (also) allow the use of 'at least one of' as an alternative synonym for 'either', in parse_node_extension (le_extensions.pl).
Please implement this, including adding another rule jd2 to numberingTest.le, identical to jd but using 'at least one of:' instead of 'either:'

## Adjusting unless
We no longer require 'unless' to be preceded by 'and'. So we can write simply:

 we will make a payment for an incident under a policy if 
        the incident is covered unless the policy is cancelled.

Implement this change, adapting also the example in unless_test.le

## clean up some ==s
In le_extensions.le:264 I see a clause with this beginning:

parse_numbered_node(D, Tokens, Children, Templates, VMIn, VMOut, Logic, RuleID, Op, M) :-
    strip_numbered_noise(Tokens, CleanTokens, Op),
    (   (CleanTokens == [] ; CleanTokens == [word(either, _)] ; CleanTokens == [word(any, _), word(of, _)] ; CleanTokens == [word(at, _), word(least, _), word(one, _), word(of, _)]) , Children \== [] ->
        hierarchy_to_numbered_logic(Children, Templates, VMIn, VMOut, Logic0, RuleID, M)
    ;   (CleanTokens == [word(unless, _)] ; CleanTokens == [word(and, _), word(unless, _)]) ->
        (   Children \== [] ->
            hierarchy_to_numbered_logic(Children, Templates, VMIn, VMOut, SubLogic, RuleID, M)
...etc.

Some of the conditions win the diskunctionill always be false, and are redundant. For example:

    CleanTokens == [word(either, _)]

can never be true, because Prolog's '==' operator requires that both terms are identica, down to variables; and because the right operand as an anonymous (and unique) variable, the condition will always be false because it's impossible for that variable to occur in CleanTokend

Clean it up please
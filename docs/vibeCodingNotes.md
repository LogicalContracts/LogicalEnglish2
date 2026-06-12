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

### LE Assistant Light
The LE Assistant is described in @docs/le_assistant.md. We need an alternative, lighter implementation, which reuses the current LE Assistant ingredients (AGENTS_LE_template, LLM API keys, etc,), but differs in that:
- does not use Opencode; has a simpler agentic loop, Prolog based; use custom tools for ```verify```and ```query```, making direct PROLOG calls, instead of calling MCP
- Prolog calls LLMs directly, using llm_client.pl, and assembling a bigger prompt with all relevant LE examples, LE syntax etc. This may recommend some changes to AGENTS_LE_template, so that both generic agentic systems like Opencode and our new Prolog agentic loop can extract the relevant file paths
- No need for temporary directory nor myProgram.le; PROLOG iterates on an evolving version of myProgram.le

For now do not implement this, just write a docs/le_assistant_light.md describing the new assistant and its elements; this is to use the same chat UI as the current assistant (just with a checkbox to select "Light" vs "Deep").

#### Gemini 3.5 over optimistic response:
Summary of Changes
1. Shared In-Process Tools (le_tools.pl):
- Created a new module le_tools.pl containing shared, in-process implementations of le_tool_verify/2 and le_tool_query/2.
- Refactored llm/mcp.pl to import and use le_tools.pl, eliminating code duplication.
2. Prolog-Native Agentic Loop (le_assistant_light.pl):
- Implemented run_light_assistant/7 and agent_loop/8 to drive the LLM directly via llm/llm_client.pl.
- Added assemble_system_prompt/2 to inline instructions, the full docs/le_summary.md syntax summary, and curated examples (citizenship.le, numbering_test.le).
- Implemented the text-based JSON action protocol (verify, query, edit, finish) with robust parsing and nudge-and-retry logic.
3. API Key & Concurrency Safety (llm/llm_client.pl):
- Extended llm_request/4 to support an explicit api_key(Key) option, ensuring concurrency-safe key delivery without global state.
4. Dispatcher & Thread-Based Jobs (le_assistant.pl):
- Modified handle_assistant_command/2 to dispatch on mode ("light" vs "deep").
- Implemented thread-based execution for Light mode, asserting progress and final results into the existing assistant_job* dynamic facts to seamlessly integrate with the polling UI.
- Updated handle_assistant_interrupt/2 to support thread-based cooperative interrupts via thread_signal/2.
5. UI Integration (editor/index.html & editor/src/client.ts):
- Added a Light Mode checkbox toggle to the top of the Assistant panel.
- Persisted the toggle state in localStorage (le-assistant-mode).
- Included the mode field in the assistant_command request body.

*(some debugging followed)*

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

## Collecting and using types
Now for a refactoring on how we remember LE types.
In le_grammar.pl a table is built, is_a_type/1. Please:
- Make that a thread_local predicate, for multithreading safety
- When we load(...) a file in le_kbs.pl, obtain from the parse also the list of those types , and assert them into a new le_type/1 predicate in the new knowledge module being loaded.

We now need to use the types in the template for a rule head (when they mention types), so that sometimes (explained below) they be checked at runtime. Specifically, in the last branch of the last clause of solve_real_actual(..), just before calling solve(..), call a new predicate is_type_compatible(..,G) which, for each argument A of G with a type FormalType associated with it in the rule head, checks the following: (le_type(A) -> is_a(A,T) ; true)

Then create an example with a small ontology and two rules illustrating this runtime checking at work, meaning, the type checks acting as hidden conditions supporting different conclusion bindings

### Gemini comment
I have implemented the runtime type checking in the Logical English reasoner as requested.
Changes:
1.  Modified reasoner.pl:
    *   Updated solve_real_actual/8 to call is_type_compatible/3 before solving a rule body.
    *   Implemented is_type_compatible/3, which retrieves the template for a goal and checks if the actual arguments are compatible with the formal types defined in the template.
    *   The check follows the logic: (le_type(A) -> is_a(A, FormalType) ; true). This allows variables in queries to be bound to types that satisfy the hierarchy constraints.
    *   Implemented a robust is_a_simple/3 helper to handle type hierarchy checks (including transitivity) within the target module.
2.  Created Example examples/moreExamples/type_check_test.le:
    *   Ontology: Defines a hierarchy where boy is a man, man is a person, girl is a woman, and woman is a person.
    *   Rules:
        *   a person is happy if the person is strong.
        *   a person is happy if the person is wise.
    *   Facts: boy is strong. and girl is wise.
    *   Query: which person is happy.
    *   Result: The type checks act as hidden conditions. When solving is_happy(P), P is bound to boy (because boy is a person and boy is strong) and girl (because girl is a person and girl is wise).

## fixing the payg test failure

In line 137 of payg.le, the condition "the income year is a year under consideration" is being translated to PROLOG as 
is_a(B, 'year under consideration'), which is incorrect - it should be translated instead to 
"is_a_year_under_consideration(B)", considering the existing template "*a year* is a year under consideration"

I have pinpointed the precise reason of failure of payg.le, scenario ato_1_quarter_2 query 'test': the goal "the amount with an ID was reported as an instalment on a quarter X of the income year", in the rule on line 134, is failing, although there is a fact "3000 with idiAE202501 was reported as an instalment on quarter 1 of 2025". 


the varied amount payable for quarter 2 for 2025 by Australian entity is 9000.0
  the current quarter is quarter 2
  the estimated tax for Australian entity for 2025 is 18000.0
    the estimated annual net tax payable for Australian entity for 2025 is 18000.0
      the estimated taxable income for Australian entity for 2025 is 100000
      the applicable tax rate for Australian entity on 2025 is 0.25
        Australian entity is a base rate entity
        0.25 is 0.25
      the tax offsets for Australian entity for 2025 is 5000
      5000 is greater than or equal to 0
      the estimated tax credits for Australian entity for 2025 are 2000
      2000 is greater than or equal to 0
      18000.0 = 100000*0.25-5000-2000
    18000.0 is greater than or equal to 0
  the year - to - date fraction for quarter 2 is 0.5
    quarter 2 is quarter 2
    0.5 is 0.5
  the year - to - date instalment adjustment for Australian entity for 2025 is 0
    Australian entity is the taxpayer
    the current quarter is quarter 2
    2025 is a year under consideration
    IR is the sum of each amount such that
      RED:   an amount with an ID was reported as an instalment on a quarter of 2025
    IVC is the sum of each number such that
      an amount with an ID was reported as a variation on a quarter of 2025
    0 = 0-0
  9000.0 = 18000.0*0.5-0

## Explanations closer to LE1
In the EXPLANATION tree panel, let the user chose to optionally see an hierachical number prefix in each node, to make it easy to refer to them. Make this choice in the Misc menu, and persist the choice in browser storage
Also, make the theme choice of the editor reflect in the explanation tree and query panel too

## Blockly

We now wish to view and edit a LE program with a Blockly (https://developers.google.com/blockly) editor. First, before any coding, let's just draft a docs/le_blockly.md document describing functionality for Blockly-based editor for LE

## LE Source Graph
Implement a new panel to complement our editor, following specification in docs/graphDesign.md

### Gemini comment
I have implemented the new Graph panel for the Logical English editor, following the specification in docs/graphDesign.md.
Key Features Implemented:
- Interactive Graph Rendering: Built with Cytoscape.js and the fCoSE layout engine to handle compound nodes (Knowledge Bases and Scenarios).
- Node & Edge Types:
    - Nodes: Knowledge Base (compound), Template/Predicate, Rule, Fact, Type, Scenario (compound), and Query.
    - Edges: uses, defines, is-a, depends-on, negates, and expects.
- Bidirectional Navigation:
    - Graph to Editor: Clicking a node highlights its corresponding source range in the Monaco editor.
    - Editor to Graph: Moving the caret in the editor automatically focuses the most specific node in the graph containing that offset.
- Graph Controls:
    - Refresh: Manually reload the graph from the server.
    - Layout Selection: Choose between fCoSE, CoSE, Grid, and Circle layouts.
    - Type Filtering: Toggle visibility of Type nodes.
    - Search: Real-time search that highlights matching nodes and dims others.
- Server-Side Support:
    - New Prolog module le_graph.pl to generate the Cytoscape-compatible JSON structure.
    - Updated classic_web_api.pl with a new graph operation.
Technical Details:
- Frontend: Added cytoscape and cytoscape-fcose dependencies. Updated client.ts with graph logic and index.html with the new tabbed UI.
- Backend: Implemented robust node and edge collection in Prolog, ensuring deterministic IDs and stable source range mapping.
To see the changes, build the editor and start the server:
cd editor && npm install && npm run build

### Improve these
-Edge labels are fine, but add tooltips to provide some more detail, for example in 'uses' (from rules to templates) it should be 'rule uses template').
-Facts should exclude system facts like le_kb(..) etc
-I like the templates colour, so render rule nodes with the same colour
-LEt the "Open in new window" button have a normal aspect, like tthe other buttons; no need for the special color

## big conclusions

### global abbreviations
Let's a add a feature to our LE templates, the ability to abbreviate a reference to a "global" fact. Consider the following extended template, ending with ";" which indicates an addition, the defining of two abbreviations:

our policy is *a policy*;  
    defines global this policy; 
    defines global your policy.   

The template "our policy is *a policy*" continues to be handled as before. BUT wherever the LE program mentions the abbreviations 'this policy' or 'your policy', that will mean the value X determined by the condition "our policy is X"

In other words, p(this policy) <-> our policy is X and p(X)

Look into @examples/moreExamples/globals.le, which already includes tests (expectations in scenarios) to verify your implementation. 

### opposite and only if
Another feature please, actually a pair: 
- 'only if' rules (as alternative to the existing 'if' rules)
- 'opposite' template addition, indicating how a negated (predicate) template should be written

So for example:

the templates are:
    I will marry *a woman*; opposite I will not marry *a woman*.
    I love *a woman*.

I will marry a woman only if
    I love the woman.

This means (and will be translated to the PROLOG equivalent of):

I will not marry a woman if
    it is not the case that
        I love the woman.

Please create a new file examples/moreExamples/only_if.le with the above and a couple of other examples of your own, together with expected answers for testing... and implement this feature pair.

### prepositional additions
Another Logical English feature please : an optional additon to templates to let them define prepositional phrases, typically to be       
  combined with a simpler template. This is intended for binary predicates only; a "prepositional" template must start with an argument,    
  and it allows omitting that first argument when chaining to a type-compatible last arg of the previous condition. For example, consider   
  these templates:                                                                                                                          
                                                                                                                                            
  the templates are:                                                                                                                        
      we will make *a payment* ;                                                                                                            
      *a payment* under *a policy*;  prepositional.                                                                                         
                                                                                                                                            
  These will allow the following to be written:                                                                                             
                                                                                                                                            
      we will make a payment under this policy                                                                                              
                                                                                                                                            
  ...instead of the more verbose (also legitimate)                                                                                          
                                                                                                                                            
      we will make a payment and the payment under this policy                                                                              
                                                                                                                                            
                                                                                                                                            
  When this occurs in a rule head, the prepositional tamplates originate new conditions in the PROLOG body; when in a rule body, additional 
   conditions too.                                                                                                                          
  A template with a 'prepositional' additional must have strictly two arguments, and its string must start with an argument at the very     
  begining, otherwise it's an error to be reported.                                                                                         
                                                                                                                                            
  There is an expanded example in examples/moreExamples/big_conclusions.le.                                                                 
                                                                                                                                            
  First, improve our system to make sure it is able to parse it.                                                                            
                                                                                                                                            
  Then add it a few scenarios and queries and expected answers, so that you can test this... and implement it!                              

#### move to le_extensions.pl
The latest LE engine feature committed yesterday to git (ff951b132307ca573c723c490e6163c3fd881303), "prepositional template additions", needs to have some of its code moved into le_extensions.pl. Strong candidate for another multifile declaration: match_template_with_chaining/8. This feature is proprietary, and should not work if le_extensions.pl is not present - meaning LE should work normally but lacking that feature. Notice that le_extensions.pl in our directory is a link to ../InsurLE2/le_extensions.pl, which you are allowed to edit.

## hierarchical examples
the examles/moreExamples directory now has sub-directories. Revise the test runner to make sure it still runs tests in all files; and the web interface so it shows the example list with sub dir names and simple indentation

## unknowns
Add another prepositional addition, 'unknown', intended to specify facts for le_unknown/1. Here is a trivial example:

the templates are:
    *a person* knows that *a number* will win the lottery; unknown.
    *a person* becomes rich.
    *a person* bets *a number* timely.

the knowledge base unknowns includes:

a person becomes rich if
    the person knows that a number will win the lottery and
    the person bets the number timely.

Add something like that (be creative!) and a few small examples of your own to examples/moreExamples/unknowns.le, with expected results (read on). Then implement:
- parsing of the unknown addition
- extend scenario expectations' syntax: allow for optional 'and unknowns' complement, as in: "queryQ expects answers ListOfSentences and unknowns ListOfUnknownSentences"

In the EXPLANATION panel make the "unknown" explanation nodes yellow or orange, with a tooltip explaining it

Do NOT commit your changes to git. i will do it later.

### unknown instances
In addition to the 'unknown' addition to a template, let's add a related feature declaring a predicate instance as unknown, a 'it is unknown whether' statement. 

For example:

the templates are:
    *a payment* is in respect of *a claim*.
   ...

the knowledge base myKB includes:
    ...rules
    it is unknown whether any payment is in respect of claim 01. 
    ...more rules...

That "it is unknown whether..." statement should map to a le_unknown(...) fact with the second predicate argument for is_in_respect_of(..) bound to '01', and first argument unbound. 

Please add an example rule and scenarion for testing to unknowns.le, and implement this.

### unknowns in scenarios
Another Logical English language feature: a tweak to 'unknown facts"; let such statements occur only as part of scenarios. Because in some scenarios something may be unknown, but not in others.

So scenarios will continue to have facts, expected answers and unknonwns, and now.... also statements declaring that a specific instance of a template is unknown.

Add a simple example to unknowns.le and implement this feature: parser, scenario representation, reasoner. 
While you're at it, colour 'it is unknown whether' as reserve3d words (just like "scenario", "expects answers", etc.)
And update le_summary.md

## Modules

We now want to let one LE program include others. For this we'll have a new construct "...includes these resources",  which must precede our regular "the knowledge base myKB includes:" header:

the knowledge base myKB includes these resources:
    Resource1, ..., ResourceN.
the knowledge base myKB includes:
    <rules as usual>

Each of the named resources, separated by commas, must be a well formed LE designated as follows, alternatively:
- relative file path
- URL

In both cases the '.le' extension is implicit. So for example we could have an expanded citizenship_including.le like this:

<templates...>
the knowledge base citizenship_including includes these resources:
    royal_family, https://le2.logicalcontracts.com/source/royal_family .

the knowledge base citizenship_including includes:
<local rules..>

What does "include another LE program mean": 
- The included rules, facts, templates, ontology are added to the local KB module, after existing ones (assertz); and are used during reasoning
- Scenarios and queries are not included
- The including KB's meaning requires successful including of all the remote resources: expected answers assume that; syntactic colouring assumes that too (by colouring included template occurrences in local rules)

So please implement these steps:
- new citizenship_including.le example, including a local file (perhaps some variant of royal_family.le, or some new other one that you like doing) and a remote resource; also create a new small example citizenship_premier.le with facts a few about Premier League soccer players, to be included via URL. Include expected answers for each.
- classic_web_api change: new web endpoint /source to serve the raw LE source text of an example; the example path MUST be allowed in a new env var ALLOWED_LE_EXPORTS defining a list of strict paths to directories in the server's example dir; just "examples/moreExamples" for starters
- parser changes
  - in addition to "the knowledge base <name> includes these resources:", accept also the alternative form "the contract citizenship_including includes these resources:"
- le_kbs and reasoner: loading the includer KB entails immediately loading the included resources; add remote LE fetcher (for URL resources);later we may add some authentication mechanics, but not now
- editor changes: colouring, and also had tooltips to the included resources, showing rule and template counts of the included resource. Otherwise only local KB items are editable as usual
- update le_summary.md
  
...AND make sure all tests continue to run successfully.


## Bob's game

Now for a new feature:  an interactive display view for a Logical English program: a puzzle-solving like canvas surface where rules and facts (including one selected scenario) are represented by blocks, which a naive user can rearrange into a solution (proof tree). So in the example picture, 4 rules and 2 facts are represented on the left, a query on the top right, and an explanation of the solution (answer)  in the bottom right. In the picture blocks are colored and label-less, for pre-literate children, that will be a view mode;  but in another mode rather than color blocks we want blocks labeled LE literals (template instances). 
To recap, these are the UI elements :
- We invoke this new view in a separate window after selecting a scenario and query, and clicking a button "Proof Game", which will be near the Query and other existing buttons
- On the left a palette-like area with all rules of the program represented with head above and body conditions below, connected by arrows
- Another area on the left with program and scenario facts
- Top right, a block with the query
- In "pre-school" mode, literals are uniquely colored (tooltips showing the hidden LE literals); in "adult" mode, LE literals (template instances) appear

the user's goal is to drag and connect together enough rules and facts to support one answer to the query. the whole view is effectively, a manual proof builder/assistant.

Behind the scenes, we can use the explanations for the query answers to check whether the current proof is possible - or simply call our LE server to validate unification of literals. So the user proof has several states:
- still possible: compatible with some explanation
- impossible: some non matching rule head vs rule condition of parent above
- complete: provide some little animation to reward the user

It would be nice to have visual feedback when nodes match or not.

Use Rete.js (install it with npm) for the view UI in a first version, but keep things clean so we may move to React Flow or another library later.

Make an implementation plan... then execute it, I trust you!

### improvemments
- please improve the layout, nodes (for example for citizenship.le) are all together
- query node should display the actual LE query sentence, not its name
- Links betwen nodes should have arrows (body condition --> head)
- Ideally, if possible I would like lines between nodes to be alway vertical, as we want the proof to be built top down
- Add some zoom and panning controls
- When you select a node, highlight the corresponding source in the editor
  - add a button to rearrange nodes
- variables in rules should use the correct LE determiners
- when linking a head/fact to a rule body condition, we need to unify and propagate and retain the bindings in the whole tree fragment
- The PROOF game is not using negation as failure (NAF) in" Show Proof". For example in insureLE2/which_test2.le scenario 1 query 1 we need to consider that the failure of "the damage is caused by wear and tear or negligence" actually supports the proof. LEt's introduce a generic 'FAIL' node (stop sign in the children version) which can be connected to any node condition (and succeed IFF that condition has a "it is not the case that..." matching literal/template instance)


## Authentication
We now need to restrict web access to some example paths, with a minimal role-based system. We'll start with two access levels: anonymous users, and one user (support@logicalcontracts.com, initial password 'LE2rocks') with the 'insurLE2' role.

Things to do:
- (preliminary:) cleanup references to examples/moreExamples in the project. There should be only one reference, all other usage should refer to a single fact in le_kbs.pl
- Store user(Email, BcryptHash, Roles) in a Prolog fact file le_users.pl. Use library(crypto)'s crypto_password_hash/2 — never store plaintext or unsalted hashes.
- write predicate add_le_user(email,password,Roleslist) which adds to that file
- Create a file restricted_paths.pl with a predicate restricted_excel_for(Path,RolesList) where acess rights are stated. Initially has a single fact restricted_excel_for('examples/more/examples/insurLE2', [insurLE2]). ALL web endpoints must refuse access to files containing this path UNLESS the user is authenticated and has one of the indicated roles
- Review all web endpoints so they comply to the above restrictions. Go over docs/api.md for guidance. For now MCP endpoints should simply assume anonymous access
- is_allowed_export(..) remains unchanged, just an additional condition on processing the /source endpoint
- Add a minimal UI to our website, showing current logged-in user email or 'anonymous' in header, with a link to a simple form to authenticate, or alternatively link to logout 
- Setup Playwright tests: anonymous user should not see insureLE2/ examples in our home page; support@logicalcontracts.com user should

## Web extensions
Let's web serve some static resources that may extend LE, by HTTP serving all files under the existing directory /web_extensions/ (which is a sym link; no need to create it) 

## date tweaks
We need a new system template and builtin to test/generate a condition for two dates and a number. I already did put it in place, but the builtin is receiving date(...) terms instead of numbers/seconds. Can you fix this, so that the tests in dates.le work without errors? Currently I get this error thrown from my le_is_days_after/3 predicate:

ERROR: Arithmetic: `date/3' is not a function
ERROR: In:
ERROR:   [69] _84072 is 180*86400+date(2026,3,3)
ERROR:   [66] reasoner:solve_real_actual(le_is_days_after(_84142,180,date(2026,3,3)),'sff330352-5a70-11f1-a144-6763a902a272',m3a501f4e48a26c0911dd7757bcce70362a1c3531,[is_within_6_months_of(...,...),...],2,10,_84136,[success(...,_84184,_84186)]) at /Users/mc/git/LogicalEnglish2/reasoner.pl:177
...

## Sections
Let's now add a simple syntax to let a LE knowledge base (the rules part) be (optionally) split into sections:

    section MySection is:   

...meaning that all rules after this will belong to section MySection - until another "section S is:" instruction is found

We should add a complement to the le_source_element(RuleID, Designator, Goal) predicate , a new predicate le_source_section(SectionName, RuleID).

Some conventions will be followed:
- If there are no "section S is:" instructions, all rules belong to the default section 'main'
- All rules until the first "section S is:" instruction belong to section 'main'
- We need a specific syntactic construct to denote a frequently used section: "the annexes to the contract are:", which is shorthand for "section annexes is:", also accept the synonym "the annexes to the knowledge base are:"

Please implement parser changes, the new le_source_section/2 predicate, and extend example numbering_test.le to include a simple use and verification of "the annexes to the contract are:" construct.

## Not equals
In addition to recognizing "*a thing* is equal to *another thing*", already defined in le_system_template/1, we need to handle the opposite "*a thing* is not equal to *another thing*". 
And after that, please recognize also the synonym form "*a thing* is different from *another thing*".

## Prunning explanations
Running query 1, scenarion zero on insureLE2/hiscoxclaim1.le  has several problems:
- it gives a different result on the editor Query UI (failure), vs. the PROLOG command line (success), with goal "load('/Users/mc/git/LogicalEnglish2/examples/moreExamples/insureLE2/hiscoxclaim1.le',KB), createSession(KB, Session), queryScenario(Session, zero, 'we will make which payment under this policy in respect of this claim', TemplateInstance)."  
- The answers provided in the PROLOG command line are weird: rather than an instance of the query conjunction and(we_will_make(A), and(in_respect_of(A, 'this claim'), under(A, 'this policy'))), it provides fragments of it: [_A, in, respect, of, _A]; ['this claim', in, respect, of, 'this claim']; ...['this policy', under, 'this policy']
-  Perhaps some mixup caused by preprositional additions...?

- For the same example, scenario and query, query_explain(...) takes way too long to compute the negative explanation, and then returns a gigantic tree with MANY repeteated subtrees, see below. Let's avoid repeating  subtrees in the negative explanaitons, by detecting variants (to cater for different variables but similar patterns). When a subtree is repeated, the explanation rendering should display just its root node and a different colour and tooltip "Repeated sub-explanation")

we will make a payment
  it is not the case that we will not make a payment and a payment in respect of an incident and a payment under this policy
    we will not make a payment
      a payment under this policy
        a payment is under this policy
          le_type_check(_14156,payment)
      it is not the case that you have paid the premium
        you have paid the premium
    a payment in respect of an incident
      a payment is in respect of this claim
        le_type_check(_14280,payment)
    a payment under this policy
      a payment is under this policy
        le_type_check(_14340,payment)
  it is not the case that we will not make a payment and a payment in respect of an incident and a payment under this policy
    we will not make a payment
      a payment under this policy
        a payment is under this policy
          le_type_check(_14460,payment)
      it is not the case that you have paid the premium
        you have paid the premium
    a payment in respect of an incident
      a payment is in respect of this claim
        le_type_check(_14584,payment)
    a payment under this policy
      a payment is under this policy
        le_type_check(_14644,payment)
  it is not the case that we will not make a payment and a payment in respect of an incident and a payment under this policy
    we will not make a payment
      a payment under this policy
        a payment is under this policy
          le_type_check(_14764,payment)
      it is not the case that you have paid the premium
        you have paid the premium
    a payment in respect of an incident
      a payment is in respect of this claim
        le_type_check(_14888,payment)
    a payment under this policy
      a payment is under this policy
        le_type_check(_14948,payment)
    
    Etc...


## Undefined predicates
Let's add an optional addition to a template, added via the ';' separator as usual: 'undefined' (accept also synonym "scenario element"). The only effects of this addition are on verification. If a template is declared undefined:
- do not warn  about its undefined predicate
- do warn if there is a template fact or rule head in the program 

## Buggy forall

In the example program below, query 1 for scenario one should succeed (because forall(false,anything) succeeds), instead in the UI we see "Error: Operation failed or internal error", and the Prolog log has this:

% Setting scenario by name: one
ERROR: [Thread httpd@3050_7] '$set_predicate_attribute'/3: No permission to modify static procedure `true/0'

The example program:

the templates are:
    true.
    false.
    test. 

the knowledge base includes:

test if 
    for all cases in which
        false
        it  is the case that
        false. 

scenario one is: 
    true.

query 1 is: 
    test. 

### Negative explanation please

Still in forall_vacuous.le: the explanation for the answer to query one, scenarion one needs to be improved. It is currently:

test
  for all cases in which false
    it is the case that
      false

(all green nodes, as if all had succeeded)

We need two changes:
- split the Condition in "for all cases in which Condition" into a child node
- If it has failed, as is the case in this scenario, it should be a negative explanation, ergo red

so the explanation should be instead:

test
  for all cases in which
    false  % this node should be red
    it is the case that
      false

## Rules in scenarios
Scenarios need to be able to have rules too, not just facts. For example, in line 34 of examples/moreExamples/subset.le that rule is part of scenario lists.

## Problems with unless
query one with scenario exclusion in examples/moreExamples/insureLE2/hiscoxexcludingexclusion.le is producing an incomplete explanation:

we will make a payment
  it is not the case that we will not make a payment
    we will not make a payment (RED NODE, failing)

The last node should have some more nodes under it, namely "...in respect of...", the first (prepositional originated) condition in the body of the rule in line 28

Great, the explanation is much better. But now another problem: 
query one for scenario exclusion should actually fail! Notice that 'we will not make a payment' succeeds (even if with 2 unknown literals assumed true), therefore its parent node 'it is not the case that we will not make a payment' must fail. Cf. explanation, all nodes green/succeeded except where indicated:

we will make a payment
  it is not the case that we will not make a payment
    we will not make a payment
      a payment in respect of this claim % ASSUMED
      a payment under this policy % ASSUMED
      this claim or part of this claim or loss is directly or indirectly due to any act breach or omission you deliberately or recklessly commit , condone or ignore
      it is not the case that a payment and this claim are admissible by the laws of the United Kingdom in relation to compulsory employers ` liability insurance
        a payment and this claim are admissible by the laws of the United Kingdom in relation to compulsory employers ` liability insurance % FAILED

## lack of type checking
Now for a a problem with type checking. In example examples/moreExamples/insureLE2/TEMP_hiscoxhappypathcurrency.le, query 1 for scenario zero produces too many answers. Looking at their explanations, I diagnosed one of the reasons for this to be that both the rules in line 139,

    a payment in respect of a claim 
        if the payment is in respect of the claim.

and the rule in line 151,

    an amount in respect of a claim 
        if the amount is in respect of the claim.

match the scenario fact in line 264:

    this payment is in respect of this claim.

BUT only the first rule should match, because of argument types: 'this payment' is a payment, therefore it should be rejected by the typechecking vs type 'amount' in the second rule

### Opus 4.8 response
Your diagnosis was right: both in_respect_of annex rules (payment-typed and amount-typed) matched the scenario fact this payment is in respect of this claim, because the generated clauses carried no type information. Two changes make type-checking discriminate:

1. Instance-aware type checking (reasoner.pl)

The type checks (le_type_check, check_args_compatibility) previously only constrained arguments that were themselves types (le_type(AA)), never instances. They also only looked in the KB module, but scenario is_a facts (like this payment is a payment) live in the session. New helper type_arg_ok/4:
- accepts any and universal types (thing/object/entity/…);
- for a type value, requires sub-typing only when the formal type is grounded (preserves the earlier *sub* isa *super* fix);
- for an instance with a known type (an is_a fact in session or KB), requires it to actually be of the formal type — so a payment is rejected for an amount slot;
- otherwise accepts.

2. Per-rule head type checks at ambiguous positions (le_grammar.pl)

Each KB rule clause now gets le_type_check goals on its head variables (typed by the variable's own name) — but only at argument positions where the functor's templates disagree on the type. So in_respect_of/2 (arg 1 is payment in one template, amount in another) gets checked and the rules become … :- le_type_check(A, payment/amount), …; a single-template role like affiliate does not, so a company acting as an affiliate is still accepted.

The goal-level check_args_compatibility was kept lenient (type-values only, via type_value_ok) — instance discrimination happens solely through the gated head checks. That distinction is exactly what fixed the regression I first hit (4_affiliates_3 rejecting his_company as an affiliate).

Net result: in_respect_of(this_payment, this_claim) now matches only the payment rule.

Note: query 1 still returns 2 answers — you said the in_respect_of clash was one of the reasons for over-answering, so there may be other causes left to chase; this fix removes the one you diagnosed. Want me to dig into what's behind the remaining two?


Why query 1 had 2 answers (diagnosis)

Both answers are identical — same instance (we will make this payment) and same unknowns ([]). They come from two distinct proofs of the same answer: the annex rule

all claims and losses … will be regarded as parts of a single claim if
    … arise from the same original cause or source of the single claim
    or … arise from a repeated or continuing series of events for the single claim.

has an or, and in scenario zero both branches hold (each is a for all cases … that's vacuously true — there are no matching losses). So …fulfils all the general conditions… is proved two ways, yielding the same we will make this payment twice. This is correct reasoning, just redundant in the answer list.

Fix 1 — deduplicate answers (classic_web_api.pl)

run_answering_query/4 now collects answers keyed by (answer string + unknowns) and keeps the first proof of each via dedup_keep_first/2. So identical answers are listed once; answers that genuinely differ (different bindings or different unknowns) are preserved. (The test harness already deduped via sort, which is why the suite was unaffected.) → query 1 now returns 1 answer.

Fix 2 — render le_type_check nicely (le_kbs.pl)

Added an item_to_instance/3 case so a le_type_check(Arg, Type) node renders like the type assertion it checks, with a/an agreement:
- le_type_check('this payment', payment) → "this payment is a payment"
- le_type_check(X, amount) → "X is an amount"


Done. handle_explain/2 now applies the same answer deduplication as run_answering_query/4:

- It collects (answer string + unknowns)-JSONWhy pairs and runs them through the shared dedup_keep_first/2, so repeated proofs of the same answer yield a single explanation rather than one per proof path.
- Distinct answers (different bindings or different unknowns) are still all returned.

## Prunning positive explanations
First, an issue: "Copy Explanation" is copying just the clicked subtree, but it should copy the whole explanatin tree. For example insureLE2/testing/hiscoxhappypath.le, scenario zero, query 1, I am only able to copy the subtree rooted in "we will make this payment", missing the other two sibling subtrees

Second, an improvement: similarly as for negative explanations, let's please detect repeated subtrees in positive explanations. For the same LE program, for example the subtree rooted in "this payment in respect of this claim" is repeated; please render the repeated instances as you do with failed subtree repetitions (but omit the counting)

## Misguided negative explanation
Now for a problem navigating from negative explanations to source. In example insureLE2/testing/hiscoxhappypath2.le, query 1 on scenario zero fails with this explanation (all red nodes, prefix "it is not true that:"):

it is not true that: we will make a payment
  it is not true that: fractured wrist and soft-tissue injuries occurs during a period
  it is not true that: a claim against a person
    it is not true that: a claim is against a person

When I click "fractured wrist and soft-tissue injuries occurs during a period", it navigates correctly to line 101. BUT when i click  the first "a claim against a person" it navigates to line 148.
I would like it to navigate instead to the goal call at line 100

ok, let's make negative explanations more detailed, and try to keep track of  rule failures (when one rule fails and the interpreter backtracks to try the next rule). So in addition to storing called(...) facts, the interpreter should store called_clause(...), when starting to interpret a rule body. Then we want the negative explanation to have intermediate "failed rule" nodes under a failed predicate, with the rule names, and each rule's subgoal failures under it as children. The explanation rendering should allow navigation from these new nodes to the rule as a whole.
Also, when a predicate has only one rule don't bother to create the failed rule node.
This change may be computationally expensive, so let's have an explanation preference (stored in browser localStorage and in a LE session fact) to enable it (off by default, e.g. no failed rule nodes).

## Query timeouts
We need to deal with slow queries. In particular for failures and big negative explanation trees the user may be in for a long wait. So let's make UI queries interruptable by the user, with an interrupt button in the UI that appears after 2 seconds of waiting.

## Configurable explanation repetitions
We currently remove repeated subtrees from both positive (success) and negative (failures) explanations. Make this a preference for the user, persisting on LocalStorage; initial default "Hide repeated explanations"

## Meta-level proposition bugs
Meta variables in events are (1) always last and (2) preceded by 'that'. In example examples/moreExamples/tea_party.le the rule at line 13:

it is prohibited that a creature attends a tea party if 
	it is not the case that
	it is approved that the creature attends the tea party.

should NOT have the following PROLOG equivalent:

it_is_prohibited_that(_) :-
    and(le_at(not(true), 374, 397), le_at(it_is_approved_that(_), 399, 453)).

This should be instead something like (ommiting precise char ranges):

it_is_prohibited_that(attends(A,B)) :-
   le_at(not(le_at(it_is_approved_that(attends(A,B)), ..., ...)), ..., ...).


Another bug parsing  rules with "that". The following rule in examples/moreExamples/testing/tea_party2.le:

it is prohibited that a creature attends the tea party if
   the creature is a lofty creature
	and it is not the case that
it is approved that the creature attends the tea party.

, which has a weird indentation (but which we wish to tolerate) has this PROLOG equivalent:

it_is_prohibited_that(attends(A, B)) :-
    and(le_at(and(is_a_lofty_creature(A), le_at(not(true), 1327, 1350)),
              1289,
              1321),
        le_at(it_is_approved_that(attends(A, B)), 1351, 1405)).

This is incorrect, not(true) makes no sense. The parsing should be:

it_is_prohibited_that(attends(A, B)) :-
    le_at(and(is_a_lofty_creature(A),
              le_at(not(le_at(it_is_approved_that(attends(A, B)),
                              ...,
                              ...)),
                    ...,
                    ...)),
          ...,
          ...).

## Weird colouring of templates
In examples/moreExamples/AItest.le , "the  templates are:" is not properly coloured; notice that there is an extra space after "the". Also the templates in the following lines are coloured incorrectly, emphasizing words like "there", "are" etc. which are just elements of the templates. 
If we remove that extra space, all colouring becomes correct! Please fix this; extra spaces in section headers are admissible


## TBD

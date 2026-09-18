/** <module> Where a decision table may be written

    docs/user/reference/language.md §17.3. A table is written wherever a rule
    may be: as a section of its own, among the rules of a knowledge base, or,
    indented with them, among the facts of a scenario — and the rules or facts
    after it go on as before. A table written in a scenario is that scenario's:
    it answers only while that scenario is the case, and it shadows a table of
    the same name written elsewhere.

    Run with:  swipl -q -g run_tests -t halt testing/test_table_scope.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_table_scope, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_writer').

kb(Text, KB) :- le_kbs:load_text(Text, '.', KB).

%   The answers of a named query in a scenario, as strings, sorted.
answers(KB, Scenario, Query, Answers) :-
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    findall(A, ( le_kbs:query(SM, Query, Instance, _, _),
                 le_kbs:canonical_string(Instance, A) ), As),
    le_kbs:destroySession(SM),
    msort(As, Answers).

issues(KB, Issues) :-
    findall(Type, ( current_predicate(KB:le_issue/6), KB:le_issue(error, Type, _, _, _, _) ), Issues).

%   A table among the rules of a knowledge base, with rules on both sides of it.
in_a_knowledge_base("
the target language is: prolog.

the templates are:
    the order of *a customer* weighs *a number* kg; undefined.
    the shipping cost for a weight of *a number* kg is *a cost* under table shipping.
    the shipping cost for *a customer* is *a cost*.
    *a customer* ships cheaply.

the knowledge base tables includes:

the shipping cost for a customer is a cost
    if the order of the customer weighs a number kg
    and the shipping cost for a weight of the number kg is the cost under table shipping.

the table shipping is, with first match:
    band | weight kg     | cost
    s    | <= 1          | 5
    m    | > 1 and <= 10 | 12
    l    | > 10          | 30

a customer ships cheaply
    if the shipping cost for the customer is a cost
    and the cost < 10.

scenario two is:
    the order of ann weighs 0.5 kg.
    the order of bob weighs 4 kg.

query cost is:
    the shipping cost for which customer is which cost.

query cheap is:
    which customer ships cheaply.
").

:- begin_tests(table_scope).

test(a_table_among_the_rules_does_not_end_the_knowledge_base) :-
    in_a_knowledge_base(Text), kb(Text, KB),
    issues(KB, Issues),
    assertion(Issues == []),
    answers(KB, two, cost, Costs),
    assertion(Costs == ["the shipping cost for ann is 5",
                        "the shipping cost for bob is 12"]),
    %  the rule written AFTER the table is a rule, not a malformed row
    answers(KB, two, cheap, Cheap),
    assertion(Cheap == ["ann ships cheaply"]).

test(a_scenario_table_shadows_the_global_one_for_that_scenario_only) :-
    load('examples/regulatory/scenario_table.le', KB),
    answers(KB, 'this year', tax, T1),
    assertion(T1 == ["the tax due by ann is 4000", "the tax due by bob is 32000"]),
    answers(KB, 'the year the top band was cut', tax, T2),
    assertion(T2 == ["the tax due by ann is 5000", "the tax due by bob is 24000"]),
    %  a rule that reads the table sees the scenario's rows too
    answers(KB, 'this year', top, P1),
    assertion(P1 == ["bob pays the top rate"]),
    answers(KB, 'the year the top band was cut', top, P2),
    assertion(P2 == []).

test(the_scenario_row_is_the_one_the_explanation_cites) :-
    load('examples/regulatory/scenario_table.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, 'the year the top band was cut'),
    findall(Row-S,
            ( le_kbs:query(SM, tax, _, _, Why),
              sub_term(success(le_table_row(brackets, Row), range(S, _), _, _), Why) ),
            Cited0),
    le_kbs:destroySession(SM),
    msort(Cited0, Cited),
    findall(R, member(R-_, Cited), Rows),
    assertion(Rows == [middle, top]),
    %  the rows cited are the ones INSIDE the scenario, not the global table's
    read_file_to_string('examples/regulatory/scenario_table.le', Text, [encoding(utf8)]),
    once(sub_string(Text, Before, _, _, "scenario the year the top band was cut is:")),
    assertion(forall(member(_-S1, Cited), S1 > Before)).

test(a_table_at_the_margin_after_a_scenario_stays_global) :-
    kb("
the target language is: prolog.

the templates are:
    the order of *a customer* weighs *a number* kg; undefined.
    the shipping cost for a weight of *a number* kg is *a cost* under table shipping.
    the shipping cost for *a customer* is *a cost*.

the knowledge base margin includes:

the shipping cost for a customer is a cost
    if the order of the customer weighs a number kg
    and the shipping cost for a weight of the number kg is the cost under table shipping.

scenario one is:
    the order of ann weighs 0.5 kg.

scenario two is:
    the order of bob weighs 40 kg.

the table shipping is, with first match:
    band | weight kg     | cost
    s    | <= 1          | 5
    m    | > 1 and <= 10 | 12
    l    | > 10          | 30

query cost is:
    the shipping cost for which customer is which cost.
", KB),
    answers(KB, one, cost, A1),
    assertion(A1 == ["the shipping cost for ann is 5"]),
    answers(KB, two, cost, A2),
    assertion(A2 == ["the shipping cost for bob is 30"]).

test(a_table_written_only_in_scenarios_needs_no_global_one) :-
    kb("
the target language is: prolog.

the templates are:
    the price of *a thing* is *an amount* under table prices.
    *a thing* costs *an amount*.

the knowledge base only includes:

a thing costs an amount
    if the price of the thing is the amount under table prices.

scenario monday is:
    the table prices is, with all matches:
        thing | price
        tea   | 2
        cake  | 4

scenario tuesday is:
    the table prices is, with all matches:
        thing | price
        tea   | 3

query cost is:
    which thing costs which amount.
", KB),
    issues(KB, Issues),
    assertion(Issues == []),
    answers(KB, monday, cost, A1),
    assertion(A1 == ["cake costs 4", "tea costs 2"]),
    answers(KB, tuesday, cost, A2),
    assertion(A2 == ["tea costs 3"]).

test(the_writer_puts_a_scenario_table_back_in_its_scenario) :-
    load('examples/regulatory/scenario_table.le', KB),
    le_writer:le_write_kb(KB, Text),
    %  the scenario's table is written inside the scenario, indented with its facts
    once(sub_string(Text, Before, _, _, "scenario the year the top band was cut is:")),
    once(sub_string(Text, At, _, _, "    the table brackets is")),
    assertion(At > Before),
    %  and the knowledge base's own table is still written at the margin
    assertion(once(sub_string(Text, _, _, _, "\nthe table brackets is"))).

:- end_tests(table_scope).

/** <module> Unit tests for the `answer` and `explain` operations of /leapi.

    Both take a whole LE `document` with a query and a scenario name. They
    used to call load_le_text/2, which never existed, so every request failed
    with an unknown-procedure error; and they passed the scenario as the JSON
    string, which setScenarion/2 (keyed by atom) never matched.

    Run with:  swipl -q -g run_tests -t halt testing/test_answer_explain_api.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_answer_explain_api, []).

:- use_module(library(plunit)).
% classic_web_api.pl lives in the repo root, one level up from this file.
:- use_module('../classic_web_api').

citizenship(Doc) :-
    read_file_to_string('examples/moreExamples/citizenship.le', Doc, []).

%   The literal of the top node of each result.
result_literal(Result, Literal) :-
    ( is_list(Result) -> Result = [Node|_] ; Node = Result ),
    get_dict(literal, Node, Literal).

:- begin_tests(answer_explain_api).

test(explain_returns_explanations) :-
    citizenship(Doc),
    classic_web_api:handle_explain(_{document: Doc, theQuery: "one", scenario: "alice"}, R),
    get_dict(results, R, [First|_]),
    result_literal(First, Literal),
    assertion(Literal == "John acquires British citizenship on 2021-10-09").

test(answer_returns_one_explanation) :-
    citizenship(Doc),
    classic_web_api:handle_answer(_{document: Doc, theQuery: "one", scenario: "harry"}, R),
    get_dict(answer, R, Answer),
    result_literal(Answer, Literal),
    assertion(Literal == "John acquires British citizenship on 2021-10-09").

test(unknown_scenario_is_reported) :-
    citizenship(Doc),
    classic_web_api:handle_explain(_{document: Doc, theQuery: "one", scenario: "nobody"}, R),
    assertion(get_dict(error, R, "Scenario not found")).

% A document with relative includes finds them through `source`, as `load` does.
test(includes_resolve_against_source) :-
    Doc = "the target language is: prolog.\n\nthe knowledge base k includes these resources:\n    citizenship.\n\nthe knowledge base k includes:\n\nscenario s is:\n    Bob is born in the UK on 2021-10-09.\n    2021-10-09 is after commencement.\n    Ann is the mother of Bob.\n    Ann is a British citizen on 2021-10-09.\n\nquery q is:\n    which person acquires British citizenship on which date.\n",
    classic_web_api:handle_explain(_{document: Doc, theQuery: "q", scenario: "s", source: "citizenship"}, R),
    get_dict(results, R, [First|_]),
    result_literal(First, Literal),
    assertion(Literal == "Bob acquires British citizenship on 2021-10-09").

%   Every node of an explanation, with its children.
json_node(N, N).
json_node(N, D) :- is_dict(N), get_dict(children, N, Cs), member(C, Cs), json_node(C, D).
json_node(L, D) :- is_list(L), member(N, L), json_node(N, D).

% A FAILED node cites nothing: its range is where its predicate is defined —
% here the scenario fact "alice is a member", stated in the order book — and
% the hatter's failed "the hatter is a member" showed a badge citing that
% document although no such fact exists.
test(failed_node_has_no_fact_citation) :-
    Doc = "the target language is: prolog.

the templates are:
    *a guest* is a member.
    *a guest* orders tea.
    the discount of *a guest* is *a percentage*.

the knowledge base k includes:
the discount of a guest is a percentage
    if the guest orders tea
    and the guest is a member
        and the percentage is 20
        otherwise the percentage is 0.

scenario s is, as stated in the order book at page 12:
    alice is a member.
    alice orders tea.
    the hatter orders tea.

query q is:
    the discount of which guest is which percentage.
",
    classic_web_api:handle_explain(_{document: Doc, theQuery: "q", scenario: "s"}, R),
    get_dict(results, R, Results),
    findall(T-L-P, ( json_node(Results, N), is_dict(N), get_dict(literal, N, L), get_dict(type, N, T),
                     ( get_dict(provenance, N, P0) -> P = P0 ; P = none ) ), Nodes),
    assertion(memberchk("failure"-"the hatter is a member"-none, Nodes)),
    assertion(\+ ( member("failure"-_-P1, Nodes), P1 \== none )),
    %  the fact that did prove a node still cites its document
    assertion(( member("success"-L2-P2, Nodes), sub_string(L2, 0, _, _, "alice is a member"),
                get_dict(document, P2, "the order book") )).

:- end_tests(answer_explain_api).

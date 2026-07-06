/** <module> Tests for colouring user-assumed conditions in explanations.

    A condition the user explicitly assumes in a scenario ("it is unknown whether …",
    e.g. the Scenario-Variations Assume checkbox) must be shown in the explanation as
    an assumption (type "unknown" / yellow) EVEN WHEN it is independently provable —
    reflecting "consider this unknown, and assume it true". This is a display-only
    change in postprocess_why: the answers and the unknowns list (from i/4) are
    unchanged, so KB-level unknowns and the "definite proof wins" rule still hold.

    Uses examples/moreExamples/testing/assumed_coloring.le. Run with:
        swipl -g run_tests -t halt testing/test_assumed_coloring.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_assumed_coloring, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').
:- use_module('../classic_web_api').

% The type of the explanation node whose literal is exactly Lit, for query `happy`
% run against Scenario.
node_type_for(Scenario, Lit, Type) :-
    le_kbs:load('examples/moreExamples/testing/assumed_coloring.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    classic_web_api:run_answering_query(SM, happy, KB, Response),
    get_dict(results, Response, [R|_]),
    get_dict(why, R, Why),
    once(find_node_type(Why, Lit, Type)),
    le_kbs:destroySession(SM).

find_node_type(D, Lit, Type) :-
    is_dict(D), get_dict(literal, D, L), atom_string(La, L), La == Lit, !,
    get_dict(type, D, Type).
find_node_type(D, Lit, Type) :-
    is_dict(D), get_dict(children, D, Cs), find_node_type(Cs, Lit, Type).
find_node_type(L, Lit, Type) :- is_list(L), member(X, L), find_node_type(X, Lit, Type).

:- begin_tests(assumed_coloring).

% Not assumed: "alice is happy" is proven by the rule -> green (success).
test(derived_condition_is_success) :-
    node_type_for(derived, 'alice is happy', Type),
    assertion(Type == "success").

% Assumed in the scenario: the SAME provable condition is shown as an assumption
% (unknown / yellow), while its still-proven sub-condition stays green.
test(assumed_condition_is_unknown) :-
    node_type_for(assumed, 'alice is happy', Type),
    assertion(Type == "unknown").

test(assumed_subcondition_stays_success) :-
    node_type_for(assumed, 'alice is nice', Type),
    assertion(Type == "success").

% A type-guard goal le_type_check(Arg, Type) is recognised as assumed via the
% equivalent is_a(Arg, Type) session fact (the hiscox "this payment is a payment"
% case); an unrelated type guard is not.
test(type_check_maps_to_is_a_assumption) :-
    le_kbs:load('examples/moreExamples/testing/assumed_coloring.le', KB),
    le_kbs:createSession(KB, SM),
    assertz(SM:le_unknown(is_a('this payment', payment))),
    assertion(le_kbs:is_session_assumption(SM, le_type_check('this payment', payment))),
    assertion(\+ le_kbs:is_session_assumption(SM, le_type_check('this claim', claim))),
    le_kbs:destroySession(SM).

:- end_tests(assumed_coloring).

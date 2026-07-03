/** <module> Unit tests for prepositional-chain answer folding and ordering.

    A prepositional template used in a chain (e.g. "we will make *a payment* under
    *a policy* in respect of *a claim*") compiles into a main literal plus one
    prepositional goal per phrase. When rendering a query answer (or an explanation
    node) that goal conjunction is re-folded into the compact sentence the user
    wrote — dropping any leading `true` and ordering the phrases by source position.
    Separately, a rule head's prepositional goals are compiled in textual order.

    Uses examples/moreExamples/testing/template_folding.le, scenario zero, query 1
    ("we will make which payment under this policy in respect of this claim").

    Run with:  swipl -g run_tests -t halt testing/test_prep_fold.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_prep_fold, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

folding_kb(KB) :-
    le_kbs:load('examples/moreExamples/testing/template_folding.le', KB).

query1_answer(Answer) :-
    folding_kb(KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, zero),
    once(le_kbs:query(SM, '1', Instance, _U, _W)),
    le_kbs:canonical_string(Instance, A),
    atom_string(A, Answer),
    le_kbs:destroySession(SM).

:- begin_tests(prep_fold).

% Issues 1 + 3 + ordering: the answer is the compact folded sentence — no leading
% "true and", the prepositional phrases folded back in, in source (textual) order.
test(query1_answer_is_compact_and_folded) :-
    query1_answer(Answer),
    assertion(Answer == "we will make this payment under this policy in respect of this claim").

% Issue 2: the rule head's prepositional goals compile in textual order, so the
% first body conjunct of a "we will make ... under ... in respect of ..." rule is
% the `under` goal, not `in respect of`.
test(rule_head_prep_goals_in_textual_order) :-
    folding_kb(KB),
    once(( clause(KB:we_will_make(_A), Body), Body = and(_, _) )),
    Body = and(First0, _),
    ( First0 = le_at(First, _, _) -> true ; First = First0 ),
    functor(First, F, _),
    assertion(F == under).

:- end_tests(prep_fold).

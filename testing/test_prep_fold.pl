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

% "; composite" is accepted as a synonym for "; prepositional": the template's dict
% carries the prepositional marker just the same.
test(composite_is_synonym_for_prepositional) :-
    Text = "the templates are:\n    *a payment* under *a policy*; composite.\n",
    le_kbs:load_text(Text, KB),
    once(KB:le_dict(dict([under|_], _, _, _, _, Prep, _))),
    assertion(Prep == prepositional).

% A query that is a single template whose fixed words happen to contain the
% connective-like words "for", "or" and "under" must be parsed as that ONE template
% instance — not torn apart into a for(...)/or(...)/under(...) body structure.
% (Regression: hiscoxhappypath.le query "relevant".)
test(single_template_query_with_connective_words_is_not_split) :-
    Text = "the templates are:\n    \c
            *an amount* for all relevant claims or losses covered under *a section*.\n\c
            query q is:\n    \c
            which amount for all relevant claims or losses covered under which section.\n",
    le_kbs:load_text(Text, KB),
    once(KB:query_info(q, Goal, _)),
    functor(Goal, F, _),
    assertion(F == for_all_relevant_claims_or_losses_covered_under).

% The single-template preference must NOT swallow a genuine body-level connective:
% a query mixing a template with "and" / "it is not the case that" stays a
% multi-condition body. (Regression: tea_party3.le query "not_punishment", where the
% "*a creature* attends *an event*" template would otherwise greedily capture the
% trailing "... and it is not the case that ...".)
test(query_with_free_connective_stays_a_body) :-
    Text = "the templates are:\n    \c
            *a creature* attends *an event*.\n    \c
            *a creature* is punished with *a sanction*.\n\c
            query q is:\n    \c
            which creature attends the tea party and it is not the case that \c
            the creature is punished with a sanction.\n",
    le_kbs:load_text(Text, KB),
    once(KB:query_info(q, Goal, _)),
    functor(Goal, F, _),
    assertion(F == and).

:- end_tests(prep_fold).

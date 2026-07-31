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

% --- Definite "this <type>" anchors for prepositional chains -------------------
% "we will make this payment under this policy." — 'this payment' is a constant,
% so the under-chain used to find no anchor variable, chaining failed, and the
% whole phrase was absorbed into the head argument as a compound term:
%     we_will_make(under('this payment','this policy'))
% A definite phrase followed by a prepositional chain describes the entity the
% chain constrains, so it lifts into a shared variable (lift_this_anchors/7):
%     we_will_make(P) :- under(P, 'this policy')

strip_le_at_local(le_at(G, _, _), Out) :- !, strip_le_at_local(G, Out).
strip_le_at_local(G, G).

% A TRANSITIVE chain: "against" hangs off the CLAIM introduced by the previous
% phrase, not off the payment the sentence started with. Folding used to require
% every phrase to share the main literal's subject, so this sentence fell back to
% the generic conjunction rendering ("previous claim against person two and we
% will make ...") and an expectation written as the sentence itself could never
% match.
transitive_chain_text(
    "the target language is: prolog.\n\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n    *a payment* in respect of *a claim*; prepositional.\n    *a claim* against *a person*; prepositional.\n    *a payment* is valid.\n\nthe knowledge base chain includes:\n    we will make a payment under this policy in respect of a claim against a person\n        if the payment is valid.\n\nscenario zero is:\n    this payment is valid.\n    this payment under this policy.\n    this payment in respect of this claim.\n    this claim against bob.\n\nquery 1 is:\n    we will make which payment under this policy in respect of which claim against which person.\n").

transitive_chain_answer(Answer) :-
    transitive_chain_text(Text),
    le_kbs:load_text(Text, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, zero),
    once(le_kbs:query(SM, '1', Instance, _U, _W)),
    le_kbs:canonical_string(Instance, A),
    atom_string(A, Answer),
    le_kbs:destroySession(SM).

:- begin_tests(prep_this_anchor).

test(this_phrase_lifts_into_chain_anchor) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n\nthe contract states that:\n\nwe will make this payment under this policy.\n",
    le_kbs:load_text(Text, KB),
    once(( clause(KB:we_will_make(P), Body0), Body0 \== true )),
    strip_le_at_local(Body0, Body),
    assertion(var(P)),
    assertion(Body == under(P, 'this policy')).

% Without a chain the definite phrase keeps denoting the constant individual.
test(this_phrase_without_chain_stays_constant) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n\nthe contract states that:\n\nwe will make this payment.\n",
    le_kbs:load_text(Text, KB),
    assertion(clause(KB:we_will_make('this payment'), true)).

% An indefinite anchor ("a payment") keeps working as before, through the
% ordinary variable lookup.
test(indefinite_anchor_still_chains) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n\nthe contract states that:\n\nwe will make a payment under this policy.\n",
    le_kbs:load_text(Text, KB),
    once(( clause(KB:we_will_make(P), Body0), Body0 \== true )),
    strip_le_at_local(Body0, Body),
    assertion(var(P)),
    assertion(Body == under(P, 'this policy')).

% A multi-step chain shares the ONE lifted variable across all chained goals.
test(lifted_anchor_shared_across_chain) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n    *a payment* in respect of *a claim*; prepositional.\n\nthe contract states that:\n\nwe will make this payment under this policy in respect of this claim.\n",
    le_kbs:load_text(Text, KB),
    once(( clause(KB:we_will_make(P), Body0), Body0 \== true )),
    assertion(var(P)),
    Body0 = and(G1a, G2a),
    strip_le_at_local(G1a, G1), strip_le_at_local(G2a, G2),
    msort([G1, G2], Goals),
    assertion(Goals == [in_respect_of(P, 'this claim'), under(P, 'this policy')]).

% The answer to a transitively chained query renders as the one sentence the
% user wrote, in source order — not as a conjunction with the off-subject phrase
% hoisted to the front.
test(transitive_chain_answer_is_folded) :-
    transitive_chain_answer(Answer),
    assertion(Answer == "we will make this payment under this policy in respect of this claim against bob").

:- end_tests(prep_this_anchor).

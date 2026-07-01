/** <module> Unit tests for the ';synonym' template addition.

    A template may declare one or more equivalent surface forms after '; synonym';
    every form maps to the SAME Prolog predicate. Facts, rule heads, rule bodies
    and queries may be written with the main form or any synonym. Explanations
    render each node with the surface form used at its source location (the proving
    clause's head form), falling back to the main template.

    Uses examples/moreExamples/synonyms.le. Run with:
        swipl -g run_tests -t halt testing/test_synonyms.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_synonyms, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').

syn_session(KB, SM) :-
    le_kbs:load('examples/moreExamples/synonyms.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, friends).

% The set of answer strings for a query, rendered as the query itself is worded.
answers(SM, KB, QueryName, Strings) :-
    KB:query_info(QueryName, Goal, Items),
    findall(S,
        ( reasoner:i(Goal, SM, _U, _W),
          maplist(le_kbs:item_to_instance(KB), Items, Instances),
          flatten(Instances, TI),
          le_kbs:canonical_string(TI, A),
          atom_string(A, S) ),
        Strings0),
    sort(Strings0, Strings).

% Every node text appearing in any answer's explanation of QueryName.
why_texts(SM, KB, QueryName, Texts) :-
    KB:query_info(QueryName, Goal, _),
    findall(Txt,
        ( reasoner:i(Goal, SM, _U, Why0),
          le_kbs:postprocess_why(Why0, SM, Why),
          node_text(Why, Txt) ),
        Texts).

node_text(T, Txt) :-
    ( is_list(T) -> member(X, T), node_text(X, Txt)
    ; T = success(_, _, LE, Ch) -> ( to_str(LE, Txt) ; node_text(Ch, Txt) )
    ; T = failure(_, _, LE, Ch) -> ( to_str(LE, Txt) ; node_text(Ch, Txt) )
    ; fail
    ).

to_str(X, S) :- ( string(X) -> S = X ; atom(X) -> atom_string(X, S) ; term_string(X, S) ).

has_text(Texts, Want) :- member(X, Texts), to_str(X, S), S == Want, !.

:- begin_tests(synonyms).

% Both surface forms of a template parse to the SAME predicate, so a query written
% either way returns the same three people (alice/bob via rules, dave via a fact
% written with the synonym).
test(both_query_forms_return_the_same_people) :-
    syn_session(KB, SM),
    answers(SM, KB, happy, Happy),
    answers(SM, KB, content, Content),
    assertion(Happy == ["alice is happy", "bob is happy", "dave is happy"]),
    assertion(Content == ["alice is content", "bob is content", "dave is content"]).

% A synonym works as a rule head too: 'deserves a reward' / 'earns a prize'.
test(synonym_rule_head_and_query_form) :-
    syn_session(KB, SM),
    answers(SM, KB, reward, Reward),
    answers(SM, KB, prize, Prize),
    assertion(Reward == ["alice deserves a reward", "bob deserves a reward", "dave deserves a reward"]),
    assertion(Prize == ["alice earns a prize", "bob earns a prize", "dave earns a prize"]).

% In explanations, a node is rendered with the form used at its source location:
% 'dave is content' (fact written with the synonym) and 'bob is content' (proven by
% the 'is content' rule head) keep the synonym, while 'alice is happy' (proven by
% the main-form rule head) uses the main template.
test(explanation_uses_source_surface_form) :-
    syn_session(KB, SM),
    why_texts(SM, KB, reward, Texts),
    assertion(has_text(Texts, "dave is content")),
    assertion(has_text(Texts, "bob is content")),
    assertion(has_text(Texts, "alice is happy")),
    % the main form is never shown for the synonym-sourced nodes
    assertion(\+ has_text(Texts, "dave is happy")),
    assertion(\+ has_text(Texts, "bob is happy")).

:- end_tests(synonyms).

% A template carrying a synonym must not also carry another addition.
:- begin_tests(synonym_validation).

test(synonym_with_other_addition_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy; synonym *a person* is content; undefined.\n",
    le_kbs:load_text(Text, M),
    assertion(M:le_issue(error, synonym_with_other_additions, _, _, _, _)).

test(plain_synonym_has_no_issue) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy; synonym *a person* is content.\n",
    le_kbs:load_text(Text, M),
    assertion(\+ M:le_issue(error, synonym_with_other_additions, _, _, _, _)).

:- end_tests(synonym_validation).

% Tests for the editor's "Show occurrences" backing operation
% (classic_web_api:predicate_occurrences/4, reached from /leapi as
% predicateOccurrences). No server: the KB is loaded straight from text.
:- use_module('../le_kbs').
:- use_module('../classic_web_api').

:- begin_tests(predicate_occurrences).

program("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.
    *a person* is rich.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

the annexes to the contract are:

a person is healthy
    if the person is rich.

bob is rich.

scenario one is:
    alice is healthy.

query who is:
    which person is happy.
").

kb(KB) :- program(P), le_kbs:load_text(P, KB).

% The kinds of every occurrence of F/A, in document order.
kinds(KB, F, A, Kinds) :-
    classic_web_api:predicate_occurrences(KB, F, A, R),
    findall(K, member(_{start: _, end: _, kind: K, context: _, text: _}, R.occurrences), Kinds).

occurrences(KB, F, A, Occs) :-
    classic_web_api:predicate_occurrences(KB, F, A, R),
    Occs = R.occurrences.

% A predicate defined by one rule and asked about in a query: its declaration,
% its rule head and the query condition, in that (document) order.
test(head_declaration_and_query) :-
    kb(KB),
    kinds(KB, is_happy, 1, Kinds),
    assertion(Kinds == [template, head, query]).

% Uses in rule bodies are occurrences too — that is the whole point of the
% action, and what "Show definition" cannot give you.
test(conditions_are_occurrences) :-
    kb(KB),
    kinds(KB, is_rich, 1, Kinds),
    assertion(Kinds == [template, condition, fact]).

% A scenario fact carries its own source range, so it is a separate row.
test(scenario_facts_are_occurrences) :-
    kb(KB),
    kinds(KB, is_healthy, 1, Kinds),
    assertion(Kinds == [template, condition, head, scenario]).

% Each row carries the Logical English rendering of the literal found there —
% the client uses it to land on the right LINE inside a multi-line rule.
test(rows_carry_the_rendered_literal) :-
    kb(KB),
    occurrences(KB, is_rich, 1, Occs),
    forall(member(O, Occs), assertion(string(O.text))),
    member(Fact, Occs), Fact.kind == fact,
    assertion(Fact.text == "bob is rich"),
    !.

% Ranges are ordered and non-degenerate: the client turns them into positions.
test(occurrences_are_ordered_by_position) :-
    kb(KB),
    occurrences(KB, is_healthy, 1, Occs),
    findall(S, member(_{start: S, end: _, kind: _, context: _, text: _}, Occs), Starts),
    msort(Starts, Sorted),
    assertion(Starts == Sorted),
    forall(member(O, Occs), assertion(O.end >= O.start)).

% The context is a NAME, never an English word (the client owns the wording):
% the scenario's name, the query's name, or the rule's section.
test(context_names_the_scenario_query_and_section) :-
    kb(KB),
    occurrences(KB, is_healthy, 1, HOccs),
    member(Scenario, HOccs), Scenario.kind == scenario,
    assertion(Scenario.context == "one"),
    % the "is healthy" rule sits under `the annexes to the contract are:`
    member(Head, HOccs), Head.kind == head,
    assertion(Head.context == "§ annexes"),
    occurrences(KB, is_happy, 1, QOccs),
    member(Query, QOccs), Query.kind == query,
    assertion(Query.context == "who"),
    % a rule in the default section names nothing
    member(HappyHead, QOccs), HappyHead.kind == head,
    assertion(HappyHead.context == ""),
    !.

% The cursor resolves to a predicate the same way "Show definition" does: on a
% condition it is the condition's predicate, not the rule head's.
test(cursor_on_a_condition_finds_that_predicate) :-
    kb(KB),
    program(P),
    sub_string(P, Before, _, _, "if the person is healthy"), !,
    Pos is Before + 10,
    assertion(classic_web_api:predicate_at_pos(KB, Pos, "    if the person is healthy.", is_healthy, 1)).

% A position with nothing at it fails rather than inventing a predicate: the
% handler turns that into "No predicate at this position".
test(no_predicate_at_a_blank_position) :-
    kb(KB),
    assertion(\+ classic_web_api:predicate_at_pos(KB, 0, "", _, _)).

:- end_tests(predicate_occurrences).

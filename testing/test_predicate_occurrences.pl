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

% ---------------------------------------------------------------------------
% Which predicate is under the cursor when the rule head carries prepositional
% additions — the case "Fold all rules for this predicate" got wrong.
%
% `we will make a payment under this policy in respect of a claim` is the
% predicate `we will make *a payment*` folded with two composite templates, so
% the head literal renders as five words of that line while a condition further
% down the rule shares many more. The command folded the condition's predicate;
% it must fold both rules of `we will make *a payment*`.

:- begin_tests(predicate_at_cursor).

fold_program("the target language is: prolog.

the templates are:
    we will make *a payment* ; opposite: we will not make *a payment*.
    *a payment* under *a policy*; composite.
    *a payment* is under *a policy*.
    *a payment* in respect of *a claim*; composite.
    *a payment* is in respect of *a claim*.
    *a claim* against *a person*; composite.
    *a claim* is against *a person*.
    *a payment* in respect of *a claim* fulfills all the general conditions of *a policy*.
    *a claim* is covered by this section.
    *a person* is an employee.

the knowledge base tiny includes:

we will make a payment under this policy in respect of a claim
    if the claim is covered by this section
    and the payment in respect of the claim fulfills all the general conditions of this policy.

we will make a payment under this policy in respect of a claim against a person
    if the person is an employee
    and the payment in respect of the claim fulfills all the general conditions of this policy.

query who is:
    which payment is in respect of which claim.
").

fold_kb(KB) :- fold_program(P), le_kbs:load_text(P, KB).

% The offset and text of the line that STARTS with Prefix.
line_at(Program, Prefix, LineStart, Line, Pos) :-
    sub_string(Program, Before, _, _, Prefix), !,
    ( sub_string(Program, LS0, 1, _, "\n"), LS0 < Before,
      \+ ( sub_string(Program, LS1, 1, _, "\n"), LS1 < Before, LS1 > LS0 )
    ->  LineStart is LS0 + 1
    ;   LineStart = 0
    ),
    sub_string(Program, LineStart, _, 0, Rest),
    ( sub_string(Rest, NL, 1, _, "\n") -> sub_string(Rest, 0, NL, _, Line) ; Line = Rest ),
    Pos is LineStart + 5.

% The cursor on either head line resolves to the head's own predicate...
test(cursor_on_a_prepositional_head_finds_the_head_predicate) :-
    fold_kb(KB), fold_program(P),
    line_at(P, "we will make a payment under this policy in respect of a claim\n", LS1, L1, Pos1),
    assertion(classic_web_api:predicate_at_pos(KB, Pos1, L1, LS1, we_will_make, 1)),
    line_at(P, "we will make a payment under this policy in respect of a claim against", LS2, L2, Pos2),
    assertion(classic_web_api:predicate_at_pos(KB, Pos2, L2, LS2, we_will_make, 1)).

% ... and "Fold all rules" then has BOTH rules to fold, the second one being
% the head with the extra prepositional argument.
test(both_rules_of_the_folded_predicate_are_returned) :-
    fold_kb(KB), fold_program(P),
    classic_web_api:predicate_places(KB, we_will_make, 1, R),
    assertion(length(R.rules, 2)),
    findall(S, member(_{start: S, end: _}, R.rules), Starts),
    sub_string(P, First, _, _, "we will make a payment under this policy in respect of a claim\n"),
    sub_string(P, Second, _, _, "we will make a payment under this policy in respect of a claim against"),
    assertion(memberchk(First, Starts)),
    assertion(memberchk(Second, Starts)).

% Word overlap alone used to pick the longest condition of the rule. Scoring
% the FRACTION of each literal's words that the line contains fixes the head
% case even without the line offset (older clients send only the line text).
test(head_wins_on_word_fraction_without_the_line_offset) :-
    fold_kb(KB), fold_program(P),
    line_at(P, "we will make a payment under this policy in respect of a claim\n", _, L1, Pos1),
    assertion(classic_web_api:predicate_at_pos(KB, Pos1, L1, we_will_make, 1)).

% A condition still resolves to the condition, on both paths: the line offset
% says "not the head line", and the fraction score prefers the literal the line
% actually spells out.
test(cursor_on_a_condition_of_such_a_rule_finds_the_condition) :-
    fold_kb(KB), fold_program(P),
    line_at(P, "    and the payment in respect of the claim fulfills", LS, L, Pos),
    assertion(classic_web_api:predicate_at_pos(KB, Pos, L, LS,
                  in_respect_of_fulfills_all_the_general_conditions_of, 3)),
    line_at(P, "    if the claim is covered by this section", LS2, L2, Pos2),
    assertion(classic_web_api:predicate_at_pos(KB, Pos2, L2, LS2, is_covered_by_this_section, 1)).

:- end_tests(predicate_at_cursor).

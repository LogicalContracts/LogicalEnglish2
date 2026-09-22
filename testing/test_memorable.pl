/** <module> Unit tests for `; memorable` templates (memoization)

    docs/user/reference/language.md §2.4. A template marked `; memorable`
    has its calls cached for the duration of a query: the first call of each
    distinct (variant) call computes every answer, with its explanation, and
    the later variant calls replay them (reasoner:memo_solve/8). Pinned here:
      * the answers of a program are the same with and without the marker,
        and the marker is recorded (le_memorable/2) and replayed
        (memo_statistics/2 counts hits);
      * a replayed call's explanation is the sub-proof the first call built,
        not an empty node; a replayed FAILED call still explains its
        failure (memo_alias/2);
      * the cache does not outlive the query: a fact asserted between two
        queries is seen by the second;
      * the verifier warns about a memorable call under a negation and about
        a memorable predicate whose rule runs an embedded prolog goal, and
        stays quiet on the family example.
    The worked examples are examples/moreExamples/language/memoization/.

    Run with:  swipl -q -g run_tests -t halt testing/test_memorable.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_memorable, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').

example_dir('examples/moreExamples/language/memoization').

%   The KB of an example, as written, and with every `; memorable` removed.
kb(Name, KB) :- kb(Name, memorable, KB).
kb(Name, Variant, KB) :-
    example_dir(Dir),
    format(atom(File), "~w/~w.le", [Dir, Name]),
    read_file_to_string(File, Text0, []),
    (   Variant == plain
    ->  re_replace("; memorable\\."/g, ".", Text0, Text)
    ;   Text = Text0
    ),
    le_kbs:load_text(Text, Dir, KB).

%   The answers of a named query in a scenario, as strings, in proof order,
%   with their explanations.
answers(KB, Scenario, Query, Answers, Whys) :-
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    findall(A-W,
            ( le_kbs:query(SM, Query, Instance, _, W),
              le_kbs:canonical_string(Instance, A) ),
            Pairs),
    pairs_keys_values(Pairs, Answers, Whys).

issue(KB, Type) :-
    current_predicate(KB:le_issue/6),
    KB:le_issue(_, Type, _, _, _, _), !.

%   Every explanation node of the memorable predicate, with its children —
%   success/3 as the reasoner builds it, success/4 once le_kbs:query/5 has
%   rendered the node's text.
ancestor_node(Whys, Kids) :-
    sub_term(N, Whys), compound(N),
    ( N = success(G, _, Kids) ; N = success(G, _, _, Kids) ),
    compound(G), G = is_an_ancestor_of(_, _).

:- begin_tests(memorable).

test(marker_is_recorded) :-
    kb(family_relatives, KB),
    assertion(KB:le_memorable(is_an_ancestor_of, 2)),
    kb(family_relatives, plain, KB2),
    assertion(\+ ( current_predicate(KB2:le_memorable/2), KB2:le_memorable(_, _) )).

test(same_answers_with_and_without_the_marker, [forall(member(Q, [ancestors, relatives, count, everybody]))]) :-
    kb(family_relatives, KB),
    answers(KB, tudors, Q, With, _),
    kb(family_relatives, plain, KB2),
    answers(KB2, tudors, Q, Without, _),
    assertion(With == Without).

test(the_cache_is_used) :-
    kb(family_relatives, KB),
    answers(KB, tudors, everybody, _, _),
    memo_statistics(Hits, Misses),
    assertion(Hits > 0),
    assertion(Misses > 0),
    assertion(Hits > Misses).

test(the_lattice_counts) :-
    kb(lattice_paths, KB),
    answers(KB, grids, square, [A], _),
    assertion(A == "walking 7 blocks east and 7 blocks north can be done in 3432 ways"),
    memo_statistics(Hits, _),
    assertion(Hits > 0).

%   The explanation of a replayed call is the first call's sub-proof: every
%   node of the memorable predicate has children (its rule's conditions),
%   and there are more such nodes than distinct calls computed.
test(replayed_calls_keep_their_explanation) :-
    kb(family_relatives, KB),
    answers(KB, tudors, relatives, _, Whys),
    findall(Kids, ancestor_node(Whys, Kids), KidsList),
    assertion(KidsList \== []),
    assertion(\+ memberchk([], KidsList)),
    memo_statistics(_, Misses),
    length(KidsList, N),
    assertion(N > Misses).

%   A replayed call with no answer explains its failure like the first one:
%   both branches of the disjunction fail on "an ancestor of Owen", and both
%   failure nodes carry the sub-failures (the rules tried).
test(replayed_failure_is_explained) :-
    kb(family_relatives, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, tudors),
    Goal = or(is_an_ancestor_of(_, 'Owen'), is_an_ancestor_of(_, 'Owen')),
    reasoner:explain(Goal, SM, _, Whys),
    findall(Kids, ( sub_term(N, Whys), compound(N), N = failure(G, Kids),
                    compound(G), G = is_an_ancestor_of(_, 'Owen') ), KidsList),
    assertion(length(KidsList, 2)),
    assertion(\+ memberchk([], KidsList)),
    memo_statistics(Hits, _),
    assertion(Hits >= 1).

%   The cache lives for one query: a fact added afterwards is seen.
test(the_cache_does_not_outlive_the_query) :-
    kb(family_relatives, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, tudors),
    findall(A, le_kbs:query(SM, ancestors, A, _, _), Before),
    assertz(SM:is_a_parent_of('Arthur', 'Owen')),
    findall(A, le_kbs:query(SM, ancestors, A, _, _), After),
    length(Before, NB), length(After, NA),
    assertion(NA =:= NB + 1).

test(warnings_of_the_warnings_example) :-
    kb(memorable_warnings, KB),
    assertion(issue(KB, memorable_under_negation)),
    assertion(issue(KB, memorable_calls_prolog)).

test(no_warnings_on_the_family_example) :-
    kb(family_relatives, KB),
    assertion(\+ issue(KB, memorable_under_negation)),
    assertion(\+ issue(KB, memorable_calls_prolog)).

:- end_tests(memorable).

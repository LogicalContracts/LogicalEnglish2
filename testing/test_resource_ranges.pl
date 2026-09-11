/** <module> Source ranges of included resources

    An included .le resource is parsed with its offsets moved into a range of
    its own (le_grammar:resource_offset_unit/1, le_kbs:resource_base/2), so a
    range recorded for it — a clause, a condition, an issue — is never read as
    an offset of the including document: explanations, issues and every /leapi
    reply say which resource and which line (le_kbs:resource_range_info/3,
    annotate_resource_ranges/2).

    Run with:  swipl -q -g run_tests -t halt testing/test_resource_ranges.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_resource_ranges, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

lib_text("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is resident; undefined.

the knowledge base lib includes:

% a comment, so the rule is not on line 1
a person is eligible
    if the person is resident.
").

main_text("the target language is: prolog.

the knowledge base main includes these resources:
    lib.

the knowledge base main includes:

scenario s is:
    ann is resident.

query q is:
    which person is eligible.
").

with_programs(Goal) :-
    tmp_file(le_res, Dir),
    make_directory(Dir),
    directory_file_path(Dir, 'lib.le', Lib),
    directory_file_path(Dir, 'main.le', Main),
    lib_text(L), write_file(Lib, L),
    main_text(M), write_file(Main, M),
    setup_call_cleanup(true, call(Goal, Main), delete_directory_and_contents(Dir)).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S), write(S, Text), close(S)).

root_and_leaf(Main, Root, Leaf) :-
    load(Main, KB),
    createSession(KB, SM),
    setScenarion(SM, s),
    once(query(SM, q, _, [], [Why|_])),
    destroySession(SM),
    Why = success(_, Root, _, [Child|_]),
    Child = success(_, Leaf, _, _).

:- begin_tests(resource_ranges).

% The rule that proves the answer is in lib.le: its range is a moved offset
% that resolves to lib.le, line 10; the scenario fact stays in main.le.
test(explanation_ranges_name_their_resource) :-
    with_programs([Main]>>(
        root_and_leaf(Main, range(RS, RE), range(LS, _)),
        le_grammar:resource_offset_unit(Unit),
        RS >= Unit,
        LS < Unit,
        le_kbs:resource_range_info(RS, RE, Info),
        get_dict(resource, Info, 'lib.le'),
        get_dict(resourceLine, Info, 10),
        get_dict(resourceStart, Info, Local),
        lib_text(Text),
        sub_string(Text, Local, _, _, After),
        sub_string(After, 0, _, _, "a person is eligible")
    )).

% A reply dict gets the resource fields when its start is a moved offset,
% and is left alone otherwise.
test(replies_are_annotated) :-
    with_programs([Main]>>(
        root_and_leaf(Main, range(RS, RE), range(LS, LE)),
        le_kbs:annotate_resource_ranges(
            _{why: [_{start: RS, end: RE, children: [_{start: LS, end: LE}]}]}, J),
        get_dict(why, J, [Node]),
        get_dict(resource, Node, 'lib.le'),
        get_dict(resourceLine, Node, 10),
        get_dict(children, Node, [Leaf]),
        \+ get_dict(resource, Leaf, _)
    )).

% The resource's clauses are recorded at moved offsets, so their ranges and
% their "rule_<start>" ids cannot collide with the includer's.
test(resource_clauses_at_moved_offsets) :-
    with_programs([Main]>>(
        load(Main, KB),
        le_grammar:resource_offset_unit(Unit),
        forall(clause(KB:is_eligible(_), _, Ref),
               ( KB:le_source_info(Ref, S, _, ID),
                 S >= Unit,
                 format(atom(ID), 'rule_~w', [S]) ))
    )).

% A diagnostic raised inside the resource reads as "lib.le, line L".
test(issue_location_in_resource) :-
    with_programs([Main]>>(
        root_and_leaf(Main, range(RS, RE), _),
        le_kbs:issue_location(RS, RE, Where),
        Where == "lib.le, line 10",
        le_kbs:issue_location(5, 9, Local),
        Local == "chars 5-9"
    )).

% The same resource keeps its base across loads and knowledge bases.
test(resource_base_is_stable) :-
    le_kbs:resource_base('/nowhere/a.le', B1),
    le_kbs:resource_base('/nowhere/b.le', B2),
    le_kbs:resource_base('/nowhere/a.le', B3),
    B1 == B3,
    B1 \== B2.

:- end_tests(resource_ranges).

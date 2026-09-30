/** <module> Unit tests for the reasoner's loop check and memorable recursion

    reasoner:in_ancestors/2, note_loop_cut/1 and memo_fixpoint/10. Pinned
    here (lpsPlus docs/migration/l4.md §7, traps 6 and 7):
      * the loop check refuses only the same condition as one being proved
        further up (a variant, as that one was when its proof began), not
        one that merely unifies with it: a fact about a known date is found
        while a rule about an unknown date is being proved;
      * a recursion through a value not yet known still ends;
      * a memorable template's recursion through a value not yet known finds
        all its answers (the rounds of memo_fixpoint/10);
      * a memorable call whose computation met the loop check on an ancestor
        of the call is not remembered, so a later call of the same question
        elsewhere in the query is worked out again rather than replayed with
        answers that were cut short.

    Run with:  swipl -q -g run_tests -t halt testing/test_loop_check.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_loop_check, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').

load(Text, KB) :-
    le_kbs:load_text(Text, 'testing', KB).

%   The answers of a named query in a scenario, as sorted strings.
answers(KB, Scenario, Query, Answers) :-
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    findall(A,
            ( le_kbs:query(SM, Query, Instance, _, _),
              le_kbs:canonical_string(Instance, A) ),
            As),
    sort(As, Answers).

starts_program("the target language is: prolog.

the templates are:
    *a person* pays on *a day*; undefined.
    the obligation starts on *a day*.

the knowledge base starts includes:

the obligation starts on 0.

the obligation starts on a day if
    the obligation starts on an earlier day
    and a person pays on the day
    and the day > the earlier day.

query q is:
    the obligation starts on which day.

scenario s is:
    bob pays on 5.
    bob pays on 9.
").

%   Left recursion through an unknown node; Marker is \"\" or \"; memorable\".
reach_program(Marker, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    *a node* leads to *a node*; undefined.
    *a node* reaches *a node*~w.

the knowledge base reach includes:

a node reaches an other node if
    the node leads to the other node.

a node reaches an other node if
    the node reaches a middle node
    and the middle node leads to the other node.

query q is:
    which node reaches which other node.

scenario chain is:
    a leads to b.
    b leads to c.
    c leads to d.
    d leads to b.
", [Marker]).

marked_program("the target language is: prolog.

the templates are:
    *a node* leads to *a node*; undefined.
    *a node* is reachable.
    *a node* is marked; memorable.

the knowledge base marked includes:

a node is reachable if
    the node is marked.

a is reachable.

a node is marked if
    an other node is reachable
    and the other node leads to the node.

query both is:
    a first node is reachable
    and which second node is marked.

scenario chain is:
    a leads to b.
    b leads to c.
").

:- begin_tests(loop_check).

test(fact_under_an_unknown_ancestor) :-
    starts_program(Text),
    load(Text, KB),
    answers(KB, s, q, Answers),
    assertion(Answers == ["the obligation starts on 0",
                          "the obligation starts on 5",
                          "the obligation starts on 9"]).

test(left_recursion_ends) :-
    reach_program("", Text),
    load(Text, KB),
    answers(KB, chain, q, Answers),
    % the direct steps at least, and no endless descent
    forall(member(A, ["a reaches b", "b reaches c", "c reaches d", "d reaches b"]),
           assertion(memberchk(A, Answers))).

test(memorable_left_recursion_is_complete) :-
    reach_program("; memorable", Text),
    load(Text, KB),
    answers(KB, chain, q, Answers),
    findall(S, ( member(X, [a, b, c, d]), member(Y, [b, c, d]),
                 format(string(S), "~w reaches ~w", [X, Y]) ), Expected0),
    sort(Expected0, Expected),
    assertion(Answers == Expected).

test(cut_short_call_is_not_replayed) :-
    marked_program(Text),
    load(Text, KB),
    answers(KB, chain, both, Answers),
    assertion(memberchk("a is reachable and c is marked", Answers)),
    assertion(memberchk("a is reachable and b is marked", Answers)).

:- end_tests(loop_check).

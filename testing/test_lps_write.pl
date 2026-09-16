/** <module> LPS internal terms back to Logical English (le_lps_write.pl)

    The writer names each variable from the type of the place it first
    appears in: the first mention, in the order the sentence is written, is
    indefinite (`a sender`, `a second amount`) and every later one definite
    (`the sender`), as an author would write it. (The round trip over
    LPS2's examples/le/ is testing/lps_roundtrip.pl.)

    Run with:  swipl -q -g run_tests -t halt testing/test_lps_write.pl
*/

:- module(test_lps_write, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_lps_write').

bank("the target language is: lps.

the maximum time is 3.

the actions are:
    *a sender* transfers *an amount* to *a recipient*; known as transfer.

the fluents are:
    the balance of *an account* is *an amount*; known as balance.

the knowledge base bank includes:

when a sender transfers an amount to a recipient from a time to a second time
then the balance of the sender that is a second amount becomes second amount - amount.
").

sentence(Term, S) :-
    bank(Doc), le_kbs:load_text(Doc, KB),
    le_lps_sentence(KB, Term, S).

has(Text, Sub) :- sub_string(Text, _, _, _, Sub).

:- begin_tests(lps_write_mentions).

%   (A prospective constraint keeps its time: it reads the state the call
%   would produce, at the event's end — the prospective form `… to T`.)
test(later_mentions_are_definite) :-
    sentence(d_pre([happens(transfer(S, A, R), T1, T2), holds(balance(S, B), T2), B < A, R = zero]), Text),
    assertion(has(Text, "a sender transfers an amount to a recipient to a time")),
    assertion(has(Text, "and the balance of the sender is a second amount at the time")),
    assertion(has(Text, "and the second amount < the amount")),
    assertion(\+ has(Text, "at a time")),
    T1 = T1.

%   A constraint whose conditions all read the state at the start of its one
%   event needs no times (lps2's docs/user/reference/le-for-lps.md §3.1); it reads back as the
%   same term.
test(times_elided) :-
    T = d_pre([happens(transfer(S, A, R), T1, _), holds(balance(S, B), T1), B < A, R = zero]),
    sentence(T, Text),
    assertion(has(Text, "it must not be true that\n    a sender transfers an amount to a recipient\n    and the balance of the sender is a second amount\n")),
    assertion(\+ has(Text, "time")),
    assertion(reads_back(Text, T)).

%   A reactive rule whose conditions all read one state and whose
%   consequents start at that time needs no times either, and reads back as
%   the same term; one that relates two moments keeps them. (A variable seen
%   first under a negation is named from the negated fluent's place.)
test(reactive_times_elided) :-
    T = reactive_rule([holds(balance(S, B), T1), holds(not(balance(R, 0)), T1), B > 10],
                      [happens(transfer(S, 5, R), T1, _)]),
    sentence(T, Text),
    assertion(has(Text, "if the balance of an account is an amount\n    and it is not the case that the balance of a second account is 0\n")),
    assertion(has(Text, "then the account transfers 5 to the second account.")),
    assertion(\+ has(Text, "time")),
    assertion(reads_back(Text, T)),
    sentence(reactive_rule([holds(balance(S2, B2), T2)], [happens(transfer(S2, B2, S2), T3, _)]), Text2),
    assertion(has(Text2, "from a second time")),
    T2 = T2, T3 = T3.

%   An event whose end is named nowhere else is written `from T`, one whose
%   start is named nowhere else `to T`.
test(open_event_ends) :-
    sentence(d_pre([happens(transfer(S, A, R), T1, _), holds(balance(S, B), T0), B < A, R = zero, T0 < T1]), Text),
    assertion(has(Text, "a sender transfers an amount to a recipient from a time\n")),
    sentence(d_pre([happens(transfer(S2, A2, _), _, T3), holds(balance(S2, B2), T3), B2 < A2]), Text2),
    assertion(has(Text2, "a sender transfers an amount to a recipient to a time\n")).

%   An update's old value is written where it is first mentioned, in the
%   relative clause; inside the expression the names are bare.
test(update_relative_clause) :-
    sentence(updated(happens(transfer(S, A, _), T1, T2), balance(S, Old), Old-New, [New is Old - A]), Text),
    assertion(has(Text, "when a sender transfers an amount to a recipient\nthen")),
    assertion(has(Text, "then the balance of the sender that is a second amount becomes second amount - amount")),
    T1 = T1, T2 = T2.

%   `from T` alone, `at T` on an event, and both in observations.
test(short_event_times) :-
    bank(Doc0),
    string_concat(Doc0, "
it must not be true that
    a sender transfers an amount to a recipient from a time
    and the balance of the sender is a second amount at the time
    and the second amount < the amount.

scenario one is:
    alice transfers 5 to bob from 1 to 2.
    alice transfers 6 to bob from 2.
    alice transfers 7 to bob at 3.
", Doc),
    le_kbs:load_text(Doc, KB),
    le_lps:le_lps_module(KB, "", Internal, _, _),
    term_strings(Internal, Terms),
    assertion(memberchk(observe([transfer(alice, 5, bob)], 2), Terms)),
    assertion(memberchk(observe([transfer(alice, 6, bob)], 3), Terms)),
    assertion(memberchk(observe([transfer(alice, 7, bob)], 4), Terms)),
    member(d_pre([happens(transfer(S, A, _), T1, _), holds(balance(S2, B), T2), B2 < A2]), Terms), !,
    assertion(S == S2), assertion(T1 == T2), assertion(B == B2), assertion(A == A2).

:- end_tests(lps_write_mentions).

term_strings(Internal, Terms) :-
    setup_call_cleanup(open_string(Internal, In), read_terms(In, Terms), close(In)).
read_terms(In, Ts) :-
    read_term(In, T, []),
    ( T == end_of_file -> Ts = [] ; Ts = [T|Rest], read_terms(In, Rest) ).

%   A sentence added to the bank document gives back Term (up to variables).
reads_back(Sentence, Term) :-
    bank(Doc0), string_concat(Doc0, "\n", D1), string_concat(D1, Sentence, Doc),
    le_kbs:load_text(Doc, KB),
    le_lps:le_lps_module(KB, "", Internal, _, _),
    term_strings(Internal, Terms),
    once(( member(T, Terms), T =@= Term )).

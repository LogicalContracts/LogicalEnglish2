/** <module> LPS internal terms back to Logical English (le_lps_write.pl)

    The writer names each variable from the type of the place it first
    appears in: the first mention, in the order the sentence is written, is
    indefinite (`a sender`, `a second amount`) and every later one definite
    (`the sender`), as an author would write it. (The round trip over
    examples/lps/ is testing/lps_roundtrip.pl.)

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

test(later_mentions_are_definite) :-
    sentence(d_pre([happens(transfer(S, A, R), T1, _), holds(balance(S, B), T1), B < A, R = zero]), Text),
    assertion(has(Text, "a sender transfers an amount to a recipient from a time to a second time")),
    assertion(has(Text, "and the balance of the sender is a second amount at the time")),
    assertion(has(Text, "and the second amount < the amount")),
    assertion(\+ has(Text, "at a time")).

%   An update's old value is written where it is first mentioned, in the
%   relative clause; inside the expression the names are bare.
test(update_relative_clause) :-
    sentence(updated(happens(transfer(S, A, _), T1, T2), balance(S, Old), Old-New, [New is Old - A]), Text),
    assertion(has(Text, "when a sender transfers an amount to a recipient from a time to a second time")),
    assertion(has(Text, "then the balance of the sender that is a second amount becomes second amount - amount")),
    T1 = T1, T2 = T2.

:- end_tests(lps_write_mentions).

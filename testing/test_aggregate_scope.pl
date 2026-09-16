/** <module> Where an aggregate's `such that` ends

    `N is the sum of each I such that` takes as its goal the lines indented
    under it, and no more:
      - in a query section, a body whose first line is an aggregate is a body
        (it was read as ONE template instance, the aggregate swallowed into a
        place of the template its goal line matched);
      - a body that begins on its header's line (`… if N is the sum …`, and
        LE for LPS's `if … then` / `when … then`) ends the aggregate where the
        body's `and` lines begin (they were read as part of the aggregate).

    Run with:  swipl -q -g run_tests -t halt testing/test_aggregate_scope.pl
*/

:- module(test_aggregate_scope, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_service').

payments("the target language is: prolog.

the templates are:
    *a person* pays *an amount*.
    the total is *a number*.
    the total is large.

the knowledge base payments includes:

the total is N if
    N is the sum of each I such that
        a person pays I.

the total is large if N is the sum of each I such that
        a person pays I
    and N > 12.

scenario one is:
    alice pays 10.
    bob pays 5.

query total is:
    the total is which number.

query sum is:
    a number N is the sum of each I such that
        a person pays I.

query bare is:
    N is the sum of each I such that
        a person pays I.

query guarded is:
    a number N is the sum of each I such that
        a person pays I
    and N > 20.

query met is:
    a number N is the sum of each I such that
        a person pays I
    and N > 12.

query large is:
    the total is large.
").

%   The goal of a query, and how many answers it has in scenario one.
answers(Query, Goal, Count) :-
    payments(Doc),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    KB:query_info(Query, Goal, _),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, one),
    aggregate_all(count, le_kbs:query(SM, Query, _, _, _), Count).

is_sum_aggregate(G) :-
    sub_term(A, G), nonvar(A), A = sum([each|_], _, _), !.

:- begin_tests(aggregate_scope).

test(query_with_an_aggregate_is_a_body) :-
    answers(sum, G, C), assertion(is_sum_aggregate(G)), assertion(C == 1),
    assertion(\+ ( sub_term(L, G), nonvar(L), L = le_is(_, _) )),
    answers(bare, G2, C2), assertion(is_sum_aggregate(G2)), assertion(C2 == 1).

test(query_aggregate_then_condition) :-
    answers(guarded, G, C), assertion(G = and(_, _)), assertion(C == 0),
    answers(met, _, C2), assertion(C2 == 1).

test(rule_body_on_the_header_line_ends_the_aggregate) :-
    answers(large, _, C), assertion(C == 1).

test(lps_aggregate_first_condition_keeps_the_rest_outside) :-
    Doc = "the target language is: lps.\n\nthe maximum time is 3.\n\nthe events are:\n    *a customer* raises an alert.\n\nthe fluents are:\n    *a customer* orders *a value*.\n\nthe knowledge base k includes:\n\nif a total is the sum of each a value such that\n        a customer orders the value\n    and the total > 100\nthen zed raises an alert.\n\nwhen a customer raises an alert\n    and N is the count of each V such that\n        a second customer orders V\n    and N > 1\nthen the customer orders 0.\n",
    le_lps_text(Doc, Text, _, _),
    split_string(Text, "\n", "", Lines),
    assertion(member("reactive_rule([holds(findall(A,[holds(orders(B,A),C)],D),C),sum_list(D,E),E>100],[happens(raises_an_alert(zed),C,F)]).", Lines)),
    assertion(\+ sub_string(Text, _, _, _, "E>100],D")).

%   A negation on the header's line ends where the body's `and` lines
%   begin, as the aggregate does.
test(header_line_negation_ends_at_the_body_lines) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a person* is rich.\n    *a person* is famous.\n    *a person* is ordinary.\n\nthe knowledge base k includes:\n\na person is ordinary if it is not the case that\n        the person is rich\n    and it is not the case that\n        the person is famous.\n",
    le_kbs:load_text(Doc, KB),
    once(( clause(KB:is_ordinary(_), Body), Body \== true )),
    assertion(Body = and(le_at(not(_), _, _), le_at(not(_), _, _))).

%   An answer with an aggregate reads as a sentence: the result's value, and
%   the goal of `such that` with the element named in it.
test(aggregate_answer_reads_as_a_sentence) :-
    payments(Doc),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, one),
    forall(member(Q-Expected, [
               sum-"15 is the sum of each I such that a person pays I",
               met-"15 is the sum of each I such that a person pays I and 15 is greater than 12"]),
           ( once(le_kbs:query(SM, Q, TI, _, _)),
             le_kbs:canonical_string(TI, S),
             assertion(S == Expected) )),
    once(le_kbs:query_explain(SM, total, _, _, Why)),
    assertion(( sub_term(N, Why), nonvar(N),
                N = success(sum(_, _, _), _, "15 is the sum of each I such that a person pays I", _) )).

%   An element named by a noun reads "the <noun>" in the goal.
test(aggregate_explanation_names_a_noun_element) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a person* owes *an amount*.\n    *a person* has a debt of *an amount*.\n\nthe knowledge base t includes:\n\na person has a debt of a total if\n    the total is the count of each amount such that\n        the person owes the amount.\n\nscenario s is:\n    bob owes 3.\n    bob owes 4.\n\nquery q is:\n    bob has a debt of which amount.\n",
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, s),
    once(le_kbs:query_explain(SM, q, _, _, Why)),
    assertion(( sub_term(N, Why), nonvar(N),
                N = success(count(_, _, _), _, "2 is the count of each amount such that bob owes the amount", _) )).

%   In LE for LPS, an aggregate whose goal names its time (`at the first
%   time`) is evaluated at that time, not at the sentence's untimed-context
%   time, which nothing binds when the other conditions name their times.
test(lps_aggregate_takes_the_time_its_goal_names) :-
    Doc = "the target language is: lps.\n\nthe maximum time is 3.\n\nthe fluents are:\n    *a player* has played *a value*.\n\nthe actions are:\n    *a player* wins.\n\nthe knowledge base k includes:\n\nif a player has played a value at a first time\n    and N is the sum of each V such that\n        a second player has played V at the first time\n    and N > 5\nthen the player wins from the first time to a second time.\n\nit must not be true that\n    a player has played a value at a time\n    and S is the sum of each B such that\n        a second player has played B at the time\n    and S > 100.\n",
    le_lps_text(Doc, Text, _, _),
    split_string(Text, "\n", "", Lines),
    assertion(member("reactive_rule([holds(has_played(A,B),C),holds(findall(D,[holds(has_played(E,D),C)],F),C),sum_list(F,G),G>5],[happens(wins(A),C,H)]).", Lines)),
    assertion(member("d_pre([holds(has_played(A,B),C),holds(findall(D,[holds(has_played(E,D),C)],F),C),sum_list(F,G),G>100]).", Lines)).

:- end_tests(aggregate_scope).

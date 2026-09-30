/** <module> The values the aggregates give

    - The sum and the count of nothing are 0; the minimum, the maximum and
      the average of nothing do not exist, so the aggregate has no answer
      (until 29 September 2026 they were 0, and `the time is the min of each
      moment such that …` found a payment that never came at time 0).
    - `L is the list of each X such that …` gives the answers in the order
      they are found, repeats kept; the list of nothing is the empty list.

    Run with:  swipl -q -g run_tests -t halt testing/test_aggregate_values.pl
*/

:- module(test_aggregate_values, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_lps').

program("the target language is: prolog.

the templates are:
    *a person* pays *an amount* at *a time*.
    the smallest payment is *an amount*.
    the largest payment is *an amount*.
    the average payment is *an amount*.
    the total payment is *an amount*.
    the number of payments is *a number*.
    the first payment after *a time* is at *a moment*.
    the payments are *a list*.
    the payments by *a person* are *a list*.

the knowledge base values includes:

the smallest payment is A if
    A is the min of each X such that
        a person pays X at a time.

the largest payment is A if
    A is the max of each X such that
        a person pays X at a time.

the average payment is A if
    A is the average of each X such that
        a person pays X at a time.

the total payment is A if
    A is the sum of each X such that
        a person pays X at a time.

the number of payments is N if
    N is the count of each X such that
        a person pays X at a time.

the first payment after a time is at a moment if
    the moment is the min of each T such that
        a person pays an amount at T
        and T > the time.

the payments are L if
    L is the list of each X such that
        a person pays X at a time.

the payments by a person are L if
    L is the list of each X such that
        the person pays X at a time.

scenario none is:
    nobody pays 0 at 0.

scenario three is:
    ann pays 5 at 1.
    bob pays 7 at 2.
    ann pays 5 at 3.

query smallest is:
    the smallest payment is which amount.

query largest is:
    the largest payment is which amount.

query average is:
    the average payment is which amount.

query total is:
    the total payment is which amount.

query count is:
    the number of payments is which number.

query first is:
    the first payment after 10 is at which moment.

query list is:
    the payments are which list.

query ann is:
    the payments by ann are which list.

query carl is:
    the payments by carl are which list.
").

%   The answers of a query in a scenario, as the sentences LE prints.
answers(Scenario, Query, Sentences) :-
    program(Doc),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    findall(S, ( le_kbs:query(SM, Query, TI, _, _), le_kbs:canonical_string(TI, S) ), Sentences).

:- begin_tests(aggregate_values).

test(min_max_average_of_nothing_have_no_answer) :-
    answers(three, first, F), assertion(F == []),
    answers(three, smallest, S), assertion(S == ["the smallest payment is 5"]),
    answers(three, largest, L), assertion(L == ["the largest payment is 7"]).

test(sum_and_count_of_nothing_are_zero) :-
    answers(three, total, T), assertion(T == ["the total payment is 17"]),
    answers(three, count, C), assertion(C == ["the number of payments is 3"]),
    answers(three, average, A), assertion(A = [_]).

test(empty_scenario) :-
    answers(none, smallest, S), assertion(S == ["the smallest payment is 0"]),
    answers(none, first, F), assertion(F == []).

test(list_in_order_with_repeats) :-
    answers(three, list, L), assertion(L == ["the payments are [5, 7, 5]"]),
    answers(three, ann, A), assertion(A == ["the payments by ann are [5, 5]"]),
    answers(three, carl, C), assertion(C == ["the payments by carl are []"]).

test(list_explanation_reads_as_a_sentence) :-
    program(Doc),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Doc, KB), le_kbs:set_le_issue_reporting(true)),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, three),
    once(le_kbs:query_explain(SM, ann, _, _, Why)),
    assertion(( sub_term(N, Why), nonvar(N),
                N = success(list(_, _, _), _, "[5, 5] is the list of each X such that ann pays X at a time", _) )).

test(list_in_the_lps_target) :-
    Doc = "the target language is: lps.\n\nthe maximum time is 3.\n\nthe fluents are:\n    *a customer* orders *a value*.\n    the orders are *a list*.\n\nthe knowledge base k includes:\n\nthe orders are L at a time if\n    L is the list of each V such that\n        a customer orders V at the time.\n",
    le_lps:le_lps_text(Doc, Text, _, _),
    assertion(sub_string(Text, _, _, _, "l_int(holds(the_orders_are(A),B),[holds(findall(C,[holds(orders(D,C),B)],E),B),E=A])")).

:- end_tests(aggregate_values).

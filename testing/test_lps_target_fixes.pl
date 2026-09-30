/** <module> LE for LPS: four translation fixes of 29 September 2026

    Found while writing the L4 experiments (lpsPlus docs/migration/l4.md §7)
    and LPS2's execution-order documentation:

    - An untimed conclusion of `if <event> then <action>` starts where the
      event ENDS; it started where the event started, a moment already past
      when the rule fires, so the run always failed.
    - A place of a conclusion or an effect written as a sum (`… by the first
      time + 30`) is worked out: the fluent held `10+30`.
    - `the contract is fulfilled` is a template, not the header `the contract
      <name> states that:`.
    - A run observes one scenario: the only one, the first of several (with a
      warning), or the one le_lps_with_scenario/2 names. The events of every
      scenario were observed together.
    - `the list = [5, 7]` (a list, a text or a name on the right) is
      unification; it was lowered to `is`, a type error when run.

    Run with:  swipl -q -g run_tests -t halt testing/test_lps_target_fixes.pl
*/

:- module(test_lps_target_fixes, []).

:- use_module(library(plunit)).
:- use_module('../le_lps').

lines(Doc, Lines, Issues) :-
    le_lps_text(Doc, Text, _, Issues),
    split_string(Text, "\n", "", Lines).

door("the target language is: lps.

the maximum time is 6.

the events are:
    the door opens; known as opens.

the actions are:
    the guest enters; known as enters.

the fluents are:
    the guest is waiting; known as waiting.

the knowledge base door includes:

if the door opens
    and the guest is waiting
then the guest enters.

scenario one is:
    the door opens from 2 to 3.
").

sale("the target language is: lps.

the maximum time is 60.

the events are:
    *a party* delivers; known as deliver.

the actions are:
    *a party* pays *an amount*; known as pay.

the fluents are:
    *a party* must pay *an amount* by *a deadline*; known as must_pay.
    the contract is fulfilled; known as fulfilled.

the knowledge base sale includes:

when a party delivers from a first time to a second time
then buyer must pay 100 by the first time + 30.

if a party must pay an amount by a deadline
then the party pays the amount + 1.

when a party pays an amount
then the contract is fulfilled.

scenario late is:
    seller delivers from 10 to 11.

scenario on_time is:
    seller delivers from 1 to 2.
").

numbers("the target language is: lps.

the maximum time is 3.

the fluents are:
    the numbers are *a list*; known as numbers.
    the name is *a name*; known as name.
    the next is *a number*; known as next.

the knowledge base numbers includes:

the numbers are a list at a time if
    the list = [5, 7].

the name is a name at a time if
    the name = bob.

the next is a number at a time if
    the number = 2 + 3.

scenario s is:
").

:- begin_tests(lps_target_fixes).

test(event_condition_moves_the_conclusion_to_its_end) :-
    door(Doc),
    lines(Doc, Lines, _),
    assertion(member("reactive_rule([happens(opens,A,B),holds(waiting,A)],[happens(enters,B,C)]).", Lines)).

test(sums_in_places_are_worked_out) :-
    sale(Doc),
    lines(Doc, Lines, _),
    assertion(member("initiated(happens(deliver(A),B,C),must_pay(buyer,100,D),[D is B+30]).", Lines)),
    assertion(member("reactive_rule([holds(must_pay(A,B,C),D)],[E is B+1,happens(pay(A,E),D,F)]).", Lines)).

test(the_contract_is_a_template) :-
    sale(Doc),
    lines(Doc, Lines, Issues),
    assertion(\+ member(le_lps_issue(error, _, _, _, _), Issues)),
    assertion(member("fluents([fulfilled,must_pay(A,B,C)]).", Lines)).

test(first_of_several_scenarios_with_a_warning) :-
    sale(Doc),
    lines(Doc, Lines, Issues),
    assertion(member("observe([deliver(seller)],11).", Lines)),
    assertion(\+ member("observe([deliver(seller)],2).", Lines)),
    assertion(memberchk(le_lps_issue(warning, lps_several_scenarios, _, _, _), Issues)).

test(chosen_scenario) :-
    sale(Doc),
    le_lps_with_scenario(on_time, lines(Doc, Lines, Issues)),
    assertion(member("observe([deliver(seller)],2).", Lines)),
    assertion(\+ member("observe([deliver(seller)],11).", Lines)),
    assertion(\+ memberchk(le_lps_issue(warning, lps_several_scenarios, _, _, _), Issues)).

test(unknown_scenario_is_an_error) :-
    sale(Doc),
    le_lps_with_scenario(nope, le_lps_text(Doc, _, _, Issues)),
    assertion(memberchk(le_lps_issue(error, lps_no_such_scenario, _, _, _), Issues)).

test(a_list_is_unified_not_evaluated) :-
    numbers(Doc),
    lines(Doc, Lines, _),
    assertion(member("l_int(holds(numbers(A),B),[A=[5,7]]).", Lines)),
    assertion(member("l_int(holds(name(A),B),[A=bob]).", Lines)),
    assertion(member("l_int(holds(next(A),B),[A is 2+3]).", Lines)).

%   `the due amount = the amount`, the amount a variable: an assignment,
%   never a list pattern (a check for a list once bound the variable to
%   [_|_], and the promissory note of the L4 twins stopped registering
%   payments).
test(a_variable_is_not_taken_for_a_list) :-
    lines("the target language is: lps.

the maximum time is 2.

the fluents are:
    the copy of *an amount* is *a number*; known as copy.

the knowledge base copies includes:

the copy of an amount is a number at a time if
    the number = the amount.
", Lines, _),
    assertion(member("l_int(holds(copy(A,B),C),[B is A]).", Lines)).

:- end_tests(lps_target_fixes).

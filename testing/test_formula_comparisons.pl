/** <module> Formulas on either side of a comparison, `==` and `!=`

    `N mod 3 = 2`, `N mod 3 == 2` and `N mod 3 is equal to 2` were silently
    false: the left side was unified as a term with the number, never equal
    to it, while `2 = N mod 3` worked (docs/user/reference/language.md §7).
    `==` and `!=`, listed there among the comparisons, had no template. And a
    one-line body `if the guest orders N cups and N mod 3 = 2` read the whole
    line before `=` as the comparison's left side.

    Run with:  swipl -q -g run_tests -t halt testing/test_formula_comparisons.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_formula_comparisons, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program(Condition, Layout, Text) :-
    (   Layout == inline
    ->  format(string(Body), "    a guest is lucky if the guest orders a number N cups and ~w.", [Condition])
    ;   format(string(Body), "    a guest is lucky\n        if the guest orders a number N cups\n        and ~w.", [Condition])
    ),
    format(string(Text), "the target language is: prolog.

the templates are:
    *a guest* orders *a number* cups.
    *a guest* is lucky.

the knowledge base k includes:
~w

scenario s is:
    alice orders 5 cups.
    bob orders 6 cups.

query q is:
    which guest is lucky.
", [Body]).

lucky(Condition, Layout, Guests) :-
    program(Condition, Layout, Text),
    load_text(Text, KB),
    createSession(KB, SM),
    setScenarion(SM, s),
    findall(G, reasoner:i(is_lucky(G), SM, _, _), Gs0),
    destroySession(SM),
    sort(Gs0, Guests).

:- begin_tests(formula_comparisons).

test(formula_on_either_side,
     [forall(( member(C, ["N mod 3 = 2", "2 = N mod 3", "N mod 3 == 2", "N mod 3 is equal to 2",
                          "N + 1 = 6", "N * 2 != 12", "N mod 3 is different from 0"]),
               member(L, [lines, inline]) ))]) :-
    lucky(C, L, Guests),
    assertion(Guests == [alice]).

test(numbers_and_constants_unchanged) :-
    reasoner:call_reasoner_built_in(le_equal_to(abc, abc), none),
    \+ reasoner:call_reasoner_built_in(le_equal_to(abc, 2), none),
    reasoner:call_reasoner_built_in(le_equal_to(X, 3+1), none),
    assertion(X == 4),
    reasoner:call_reasoner_built_in(le_not_equal_to(date(2021,1,1), date(2021,1,2)), none),
    \+ reasoner:call_reasoner_built_in(le_not_equal_to(5+5, 10), none).

:- end_tests(formula_comparisons).

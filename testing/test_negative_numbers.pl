/** <module> Negative numbers in LE text

    A minus sign directly attached to a number is a negative number when it
    is not glued to a preceding word or number ("has -5 degrees", ">= -2",
    "[-1, 2]"); before, "-5" became the compound -(5), and comparisons with
    it were silently wrong (found by the Medicare model, September 2026:
    "initiated -1 hours after"). "ICD-10", "3-5", dates and a spaced binary
    minus are unchanged.

    Run with:  swipl -q -g run_tests -t halt testing/test_negative_numbers.pl
*/

:- module(test_negative_numbers, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../tokenizer').

values(Text, Values) :-
    once(tokenizer:tokenize(Text, Tokens)),
    exclude([T]>>(T = indent(_, _)), Tokens, Ts),
    maplist([T, V]>>(T =.. [_, V|_]), Ts, Values).

:- begin_tests(negative_numbers).

test(unary_minus_after_space_operator_or_bracket) :-
    values("has -5 degrees", V1), V1 == [has, -5, degrees],
    values(">= -2.5", V2), V2 == [>=, -2.5],
    values("[-1, 2]", V3), V3 == ['[', -1, ',', 2, ']'],
    values("(-3)", V4), V4 == ['(', -3, ')'].

test(glued_or_spaced_minus_is_unchanged) :-
    values("ICD-10", V1), V1 == ['ICD', -, 10],
    values("3-5", V2), V2 == [3, -, 5],
    values("the amount - 5", V3), V3 == [the, amount, -, 5],
    values("2026-03-01", V4), V4 == [date(2026, 3, 1)].

test(comparisons_with_negative_numbers) :-
    Program = "the target language is: prolog.

the templates are:
    *a thing* has *a number* degrees.
    *a thing* is cold.

the knowledge base negatives includes:

a thing is cold
    if the thing has a number degrees
    and the number >= -2
    and the number < 5.

scenario s is:
    ice has -5 degrees.
    snow has -1 degrees.
    tea has 60 degrees.

query q is:
    which thing is cold.
",
    load_text(Program, KB),
    createSession(KB, SM),
    setScenarion(SM, s),
    once(parse_custom_query(KB, "which thing is cold", Goal)),
    findall(A, ( query(SM, Goal, I, _, _), canonical_string(I, A) ), As),
    destroySession(SM),
    As == ["snow is cold"].

:- end_tests(negative_numbers).

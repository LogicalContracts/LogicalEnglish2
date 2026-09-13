/** <module> Values the rules can read, and how comparisons read

    A fact can look right and never match a rule: a number written in quotes
    where the rules compare the place with the number ("... is "2"" against
    "... is 2"), or text written as a number. The verifier reports it on a
    program's scenarios (`mistyped_value`), `answeringQuery` reports it on a
    typed-in case (`valueWarnings`), and "Write it in English" writes the
    number when the model quoted it. Also: a comparison over expressions reads
    in words in an explanation, not as the Prolog term.

    Run with:  swipl -q -g run_tests -t halt testing/test_value_checks.pl
*/

:- module(test_value_checks, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_verifier').
:- use_module('../nl_to_le').
:- use_module('../classic_web_api').

program("the target language is: prolog.

the templates are:
    the claims of *a policy* is *a value*; scenario element.
    the code of *a policy* is *a value*; scenario element.
    the loading of *a policy* is *a number*.

the knowledge base loading includes:

the loading of a policy is 3 if
    the claims of the policy is 2.

the loading of a policy is 5 if
    the code of the policy is \"7\".

scenario typed is:
    the claims of p1 is \"2\".
    the code of p1 is 7.

scenario right is:
    the claims of p2 is 2.
    the code of p2 is \"7\".
    loading expects answers [\"the loading of p2 is 3\", \"the loading of p2 is 5\"].

query loading is:
    the loading of which policy is which number.
").

issues_of(KB, Type, Descs) :-
    findall(D, KB:le_issue(_, Type, D, _, _, _), Descs).

:- begin_tests(value_checks).

test(mistyped_values_in_a_scenario) :-
    program(P), load_text(P, KB),
    verify_kb(KB),
    issues_of(KB, mistyped_value, Ds),
    length(Ds, 2),
    once(( member(D, Ds), sub_atom(D, _, _, _, 'the number 2') )),
    once(( member(D2, Ds), sub_atom(D2, _, _, _, 'the text "7"') )).

test(values_written_right_are_silent) :-
    program(P), load_text(P, KB),
    findall(H, ( KB:scenario(right, Ts), member(fact_with_source(H, _, _), Ts) ), Hs),
    fact_value_warnings(KB, Hs, Ws),
    assertion(Ws == []).

test(typed_in_case_reports_value_warnings, [nondet]) :-
    program(P), load_text(P, KB),
    createSession(KB, SM),
    classic_web_api:handle_answering_query(
        _{sessionModule: SM, customScenario: "the claims of p3 is \"2\".", query: "loading"}, R),
    get_dict(valueWarnings, R, [W]),
    assertion(W.kind == mistyped),
    assertion(W.value == "\"2\"").

test(english_numbers_lose_their_quotes) :-
    nl_to_le:unquote_known_numbers([2], ["7"],
        "the claims of p is \"2\".\nthe code of p is \"7\", confer \"it said \"2\"\".", LE),
    assertion(LE == "the claims of p is 2.\nthe code of p is \"7\", confer \"it said \"2\"\".").

% A template with no places, asked as a custom query: its goal is an atom,
% which query/5 once took for a query's name and then for text.
test(propositional_custom_query, [nondet]) :-
    load_text("the target language is: prolog.

the templates are:
    the business_event is valid.
    the input is complete; scenario element.

the knowledge base prop includes:

the business_event is valid if the input is complete.

scenario yes is:
    the input is complete.
", KB),
    createSession(KB, SM),
    classic_web_api:handle_answering_query(
        _{sessionModule: SM, scenario: "yes", customQuery: "the business_event is valid"}, R),
    assertion(\+ get_dict(error, R, _)),
    R.results = [_|_].

test(comparisons_over_expressions_read_in_words) :-
    le_kbs:builtin_goal_string(le_lt(300000-100000, 0), S),
    assertion(S == "300000 - 100000 is less than 0").

:- end_tests(value_checks).

verify_kb(KB) :-
    catch(le_verifier:verify(KB, _), _, true).

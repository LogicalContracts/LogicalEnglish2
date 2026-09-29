/* test_entitlements.pl — what a request may use of the licensed parts.

   le_entitlements.pl carries, per thread, the capabilities of the visitor a
   server is serving (the licences themselves are lpsPlus's). These tests
   check the carrier, that a program parsed for one visitor is never handed
   to another with a different licence (le_kbs:grammar_key/2), and that a
   numbered rule body read without the InsurLE licence is an error that says
   so, rather than a rule with no conditions.
*/

:- use_module(library(plunit)).
:- use_module('../le_entitlements').
:- use_module('../le_kbs').

numbered_program("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is a citizen.
    *a person* is a resident.

the knowledge base numbered includes:
    a person is eligible if:
    1. the person is a citizen; or
    2. the person is a resident.

scenario s is:
    ann is a resident.

query q is:
    which person is eligible.
").

extensions_installed :- current_predicate(le_extensions:parse_numbered_body/7).

issue_kinds(M, Kinds) :-
    findall(K, M:le_issue(error, K, _, _, _, _), Kinds).

:- begin_tests(entitlements, [setup(unsetenv('NO_RESTRICTIONS'))]).

test(default_is_everything) :-
    le_entitlements:clear_request_entitlements,
    entitled(converters), entitled(le_extensions).
test(request_limits) :-
    with_entitlements([converters], ( entitled(converters), \+ entitled(le_extensions) )).
test(request_restored_after) :-
    with_entitlements([], true),
    entitled(le_extensions).
test(server_default_is_nothing) :-
    setup_call_cleanup(set_default_entitlements(none),
                       \+ entitled(converters),
                       set_default_entitlements(all)).
test(no_restrictions_lifts_all) :-
    setup_call_cleanup(setenv('NO_RESTRICTIONS', true),
                       with_entitlements([], entitled(le_extensions)),
                       unsetenv('NO_RESTRICTIONS')).

test(same_program_other_licence_other_module) :-
    numbered_program(T),
    with_entitlements(all, load_text(T, M1)),
    with_entitlements([], load_text(T, M2)),
    (   extensions_installed
    ->  M1 \== M2
    ;   M1 == M2         % no extensions here: nothing to tell apart
    ).

test(numbered_body_without_licence_is_an_error) :-
    numbered_program(T),
    with_entitlements([converters], load_text(T, M)),
    issue_kinds(M, Kinds),
    memberchk(numbered_body_unlicensed, Kinds).

test(numbered_body_with_licence, [condition(extensions_installed)]) :-
    numbered_program(T),
    with_entitlements([le_extensions], load_text(T, M)),
    issue_kinds(M, Kinds),
    \+ memberchk(numbered_body_unlicensed, Kinds).

:- end_tests(entitlements).

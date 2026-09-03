% Tests for the English → Logical English conversion behind the Scenario and
% Query editors' "Write it in English…" dialog (nl_to_le.pl).
%
% The LLM is stubbed by routing le_llm through this file (set_le_llm_provider/1
% needs a module exporting llm_request/4), so the whole verify-and-refine loop
% runs offline against a tiny program.

:- use_module('../nl_to_le').
:- use_module('../llm/le_llm', [set_le_llm_provider/1]).

% ------------------------------- fixtures ------------------------------------

nl_program("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

scenario one is:
    bob is healthy.
    who expects answers [\"bob is happy\"].

query who is:
    which person is happy.
").

nl_templates(["*a person* is happy.", "*a person* is healthy."]).

% --- the stub -----------------------------------------------------------------
% `replies/1` holds the answers the model gives, in order; the last one is
% repeated once the list runs out. Every call is recorded so a test can prove
% how many rounds ran and what the correction prompt said.

:- dynamic replies/1, llm_calls/1, last_prompt/1.

stub_replies(List) :-
    retractall(replies(_)), assertz(replies(List)),
    retractall(llm_calls(_)), assertz(llm_calls(0)),
    retractall(last_prompt(_)),
    set_le_llm_provider(user).

llm_call_count(N) :- ( llm_calls(N) -> true ; N = 0 ).

user:llm_request(_Model, Messages, Answer, _Options) :-
    ( retract(llm_calls(N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(llm_calls(N)),
    last(Messages, LastMsg), get_dict(content, LastMsg, Content),
    retractall(last_prompt(_)), assertz(last_prompt(Content)),
    ( retract(replies(Rs)) -> true ; Rs = [] ),
    (   Rs = [A|Rest]
    ->  Answer = A, ( Rest == [] -> assertz(replies([A])) ; assertz(replies(Rest)) )
    ;   Answer = "", assertz(replies([]))
    ).

nl_convert(Kind, Sentence, LE, Issues) :-
    nl_program(P), nl_templates(T),
    english_to_le(Kind, Sentence, T, P, "stub-model", [], LE, Issues).

nl_has_issue(Issues, Type) :- member(I, Issues), get_dict(type, I, Type).

% ------------------------------ the happy path --------------------------------

:- begin_tests(nl_to_le).

test(a_clean_fact_costs_one_call, [setup(stub_replies(["alice is healthy."]))]) :-
    nl_convert(facts, "Alice is healthy.", LE, Issues),
    assertion(LE == "alice is healthy."),
    assertion(Issues == []),
    llm_call_count(N),
    assertion(N =:= 1).

test(a_clean_query_costs_one_call, [setup(stub_replies(["which person is happy"]))]) :-
    nl_convert(query, "Who is happy?", LE, Issues),
    assertion(LE == "which person is happy"),
    assertion(Issues == []),
    llm_call_count(N),
    assertion(N =:= 1).

% ---- the hole the baseline diff alone left open ------------------------------
% A fact or condition that matches NO template is parked in the knowledge base
% as an unknown_template term and reported by nobody: the verifier calls it
% clean. That was the one case where the fragment is certainly wrong, and it was
% the one case that came back with no warning at all.

test(a_fact_matching_no_template_is_an_error,
     [setup(stub_replies(["alice flies to mars."]))]) :-
    nl_convert(facts, "Alice flew to Mars.", _LE, Issues),
    assertion(nl_has_issue(Issues, "unknown_template")),
    member(I, Issues), get_dict(type, I, "unknown_template"), !,
    assertion(get_dict(severity, I, "error")),
    assertion(sub_string(I.message, _, _, _, "alice flies to mars")),
    assertion(I.line =:= 1).          % a line of the FRAGMENT, not of the spliced program

test(a_query_condition_matching_no_template_is_an_error,
     [setup(stub_replies(["which person flies to mars"]))]) :-
    nl_convert(query, "Who flew to Mars?", _LE, Issues),
    assertion(nl_has_issue(Issues, "unknown_template")).

% ---- traps that verify "clean" but change what the fragment means ------------

test(asterisks_around_a_phrase_are_an_error,
     [setup(stub_replies(["*alice* is healthy."]))]) :-
    nl_convert(facts, "Alice is healthy.", _LE, Issues),
    assertion(nl_has_issue(Issues, "asterisks_outside_templates")).

test(an_indefinite_article_is_reported_as_a_modelling_warning,
     [setup(stub_replies(["a person is healthy."]))]) :-
    nl_convert(facts, "Someone is healthy.", _LE, Issues),
    assertion(nl_has_issue(Issues, "single_variable_fact")).

test(an_empty_reply_is_an_error_not_a_clean_result,
     [setup(stub_replies([""]))]) :-
    nl_convert(facts, "Alice is healthy.", LE, Issues),
    assertion(LE == ""),
    assertion(nl_has_issue(Issues, "empty_fragment")).

% ---- refinement ---------------------------------------------------------------

test(a_broken_fragment_is_corrected_and_the_correction_is_returned,
     [setup(stub_replies(["alice flies to mars.", "alice is healthy."]))]) :-
    nl_convert(facts, "Alice is healthy.", LE, Issues),
    assertion(LE == "alice is healthy."),
    assertion(Issues == []),
    llm_call_count(N),
    assertion(N =:= 2).

% The correction prompt has to carry what is wrong, where, and the text being
% corrected — a round told only "Missing template" has nothing to act on.
test(the_correction_prompt_names_the_offending_text,
     [setup(stub_replies(["alice flies to mars.", "alice flies to mars."]))]) :-
    nl_convert(facts, "Alice is healthy.", _LE, _),
    last_prompt(P),
    assertion(sub_string(P, _, _, _, "alice flies to mars")),
    assertion(sub_string(P, _, _, _, "NEW problems")).

% Two corrections used to be the whole budget, whatever was happening.
test(refinement_keeps_going_while_it_is_still_improving,
     [setup(stub_replies(["*a* flies to mars.", "alice flies to mars.", "alice is healthy."]))]) :-
    nl_convert(facts, "Alice is healthy.", LE, Issues),
    assertion(LE == "alice is healthy."),
    assertion(Issues == []),
    llm_call_count(N),
    assertion(N =:= 3).

% ... and the BEST round is returned, not the last one. Here round 2 is worse
% than round 1, so round 1's fragment comes back — it used to be round 3's.
test(the_best_round_is_returned_not_the_last,
     [setup(stub_replies(["a person is healthy.",
                          "alice flies to mars.",
                          "zoe flies to mars."]))]) :-
    nl_convert(facts, "Someone is healthy.", LE, Issues),
    assertion(LE == "a person is healthy."),
    assertion(nl_has_issue(Issues, "single_variable_fact")),
    assertion(\+ nl_has_issue(Issues, "unknown_template")).

% A model that never improves must stop costing calls: patience 2 ends it.
test(a_model_that_never_improves_stops,
     [setup(stub_replies(["alice flies to mars."]))]) :-
    nl_convert(facts, "Alice is healthy.", _LE, Issues),
    assertion(nl_has_issue(Issues, "unknown_template")),
    llm_call_count(N),
    assertion(N =< 4).

% A block whose statements escape into the program at large would change every
% other scenario's answers. Off by default on this interactive path (it costs
% two runs of the program's tests); the option turns it on.
test(the_regression_check_is_available_on_request,
     [setup(stub_replies(["alice is healthy."]))]) :-
    nl_program(P), nl_templates(T),
    english_to_le(facts, "Alice is healthy.", T, P, "stub-model",
                  [check_regressions(true)], LE, Issues),
    assertion(LE == "alice is healthy."),
    assertion(Issues == []).            % the program's own test still passes

test(the_round_bounds_are_caller_settable,
     [setup(stub_replies(["alice flies to mars."]))]) :-
    nl_program(P), nl_templates(T),
    english_to_le(facts, "Alice is healthy.", T, P, "stub-model",
                  [max_rounds(1), patience(9)], _LE, Issues),
    assertion(Issues \== []),
    llm_call_count(N),
    assertion(N =:= 1).           % the guard stops it before any correction

% ---- what the program ALREADY has must not be reported as the user's problem --

test(pre_existing_issues_of_the_program_are_not_reported,
     [setup(stub_replies(["alice is healthy."]))]) :-
    % this program carries an unused template of its own
    P = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n    *a person* is rich.\n\nthe knowledge base tiny includes:\n\na person is happy\n    if the person is healthy.\n\nquery who is:\n    which person is happy.\n",
    nl_templates(T),
    english_to_le(facts, "Alice is healthy.", T, P, "stub-model", [], _LE, Issues),
    assertion(\+ nl_has_issue(Issues, "unused_template")),
    assertion(Issues == []).

% A program that does not parse at all is not the sentence's fault: the user
% asked about one sentence and must not be handed the wreckage.
test(a_program_that_does_not_load_does_not_blame_the_sentence,
     [setup(stub_replies(["alice is healthy."]))]) :-
    nl_templates(T),
    english_to_le(facts, "Alice is healthy.", T, "this is not Logical English at all {{{",
                  "stub-model", [], _LE, Issues),
    assertion(\+ nl_has_issue(Issues, "load_failure")).

% ---- ordering: the first line of the warning box is the one worth reading -----

test(errors_are_reported_before_warnings,
     [setup(stub_replies(["a person is healthy.\nzoe flies to mars."]))]) :-
    nl_convert(facts, "Someone is healthy and Zoe flew to Mars.", _LE, Issues),
    Issues = [First|_],
    assertion(get_dict(severity, First, "error")),
    assertion(nl_has_issue(Issues, "single_variable_fact")).

% ---- the prompt -------------------------------------------------------------
% The model is shown the conventions of the program it is writing into, not just
% a list of templates: constants, naming and the level of detail the user
% actually writes are all in the existing scenarios and in none of the templates.

test(the_system_prompt_shows_the_program_the_fragment_joins) :-
    nl_program(P), nl_templates(T),
    nl_to_le:system_prompt(facts, T, P, Prompt),
    assertion(sub_string(Prompt, _, _, _, "Scenarios already in the program: one")),
    assertion(sub_string(Prompt, _, _, _, "Queries already in the program: who")),
    assertion(sub_string(Prompt, _, _, _, "scenario one is:")),
    assertion(sub_string(Prompt, _, _, _, "bob is healthy.")).

% The traps that produce a fragment which verifies clean and means something
% else are named up front, so the loop does not spend a round discovering them.
test(the_system_prompt_names_the_traps_that_verify_clean) :-
    nl_program(P), nl_templates(T),
    nl_to_le:system_prompt(facts, T, P, Prompt),
    assertion(sub_string(Prompt, _, _, _, "asterisks")),
    assertion(sub_string(Prompt, _, _, _, "UNIVERSAL")),
    assertion(sub_string(Prompt, _, _, _, "YYYY-MM-DD")).

test(an_unknown_kind_is_rejected) :-
    nl_program(P), nl_templates(T),
    catch(english_to_le(rules, "x", T, P, "stub-model", [], _, _), E, true),
    assertion(nonvar(E)),
    assertion(E = error(type_error(nl_kind, rules), _)).

:- end_tests(nl_to_le).

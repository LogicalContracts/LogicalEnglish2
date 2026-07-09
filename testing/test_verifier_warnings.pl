% Tests for the reserved_word_in_template error and the single_variable_fact
% warning on scenario facts.

:- use_module('../le_kbs').
:- use_module('../le_verifier').

:- begin_tests(reserved_word_in_template).

% A template containing the reserved word 'if' is cut off at that word. It must
% be reported as a targeted error, not surface as missing_template noise on
% unrelated templates further down the section.
test(if_in_template_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we would have covered your liability if you had caused *a loss*.\n    *a person* is happy.\n",
    le_kbs:load_text(Text, M),
    assertion(M:le_issue(error, reserved_word_in_template, _, _, _, _)).

% Recovery: the templates that follow the offending one must still parse, so a
% rule using them is not flagged as missing its template.
test(templates_after_reserved_word_still_parse) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we would have covered your liability if you had caused *a loss*.\n    *a person* is happy.\n    *a person* is healthy.\nthe knowledge base recovery includes:\n\na person is happy if the person is healthy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, Issues),
    assertion(\+ member(issue(missing_template, _, _, _, _), Issues)).

test(unless_in_template_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is covered unless proven otherwise.\n",
    le_kbs:load_text(Text, M),
    assertion(M:le_issue(error, reserved_word_in_template, _, _, _, _)).

% Templates without reserved words must not be flagged.
test(clean_templates_are_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we would have covered your liability had you caused *a loss*.\n    *a person* is happy.\n",
    le_kbs:load_text(Text, M),
    assertion(\+ M:le_issue(_, reserved_word_in_template, _, _, _, _)).

:- end_tests(reserved_word_in_template).

:- begin_tests(single_variable_scenario_fact).

% "a person is happy" in a scenario quietly introduces a variable (it compiles
% to a clause guarded only by a type check); the verifier must warn, as it
% already does for knowledge-base facts.
test(scenario_fact_with_accidental_variable_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base svf includes:\n\nfluffy is happy.\n\nscenario one is:\n    a person is happy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, Issues),
    assertion((member(issue(single_variable_fact, D, _, _, _), Issues), sub_atom(D, _, _, _, 'scenario'))).

% In a scenario, "the individual" is a constant, and proper names too: neither
% must be flagged.
test(ground_scenario_facts_are_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base svf includes:\n\nfluffy is happy.\n\nscenario one is:\n    bob is happy.\n    the individual is happy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, Issues),
    assertion(\+ member(issue(single_variable_fact, _, _, _, _), Issues)).

:- end_tests(single_variable_scenario_fact).

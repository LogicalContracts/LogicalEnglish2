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

% Regression: a rule whose HEAD matches no template used to crash the whole
% parse ("Parsing failed", instantiation error in take_nested_hierarchy) when
% its body was multi-line, because second_pass_item passed an unbound indent
% to parse_body. It must instead yield per-sentence missing_template issues.
test(unmatched_head_with_multiline_body_does_not_abort_parse) :-
    Text = "the contract states that:\nthe policy conditions are satisfied for a claim\n    if the premium has been paid for the claim\n    and the claim was notified within 30 days of the date of loss.\n",
    le_kbs:load_text(Text, M),
    findall(Ty, M:le_issue(error, Ty, _, _, _, _), Types),
    assertion(memberchk(missing_template, Types)),
    aggregate_all(count, M:le_issue(error, missing_template, _, _, _, _), N),
    assertion(N >= 3).

% A SECTION KEYWORD is only a section keyword at the start of a line. "scenario"
% (and "query", "the contract", ...) are ordinary words inside a template — a
% claims file with a "scenarioTested" field leads models straight to templates
% like this one, and every such template used to be cut in half and the rest of
% the program reported as an unknown section.
test(a_section_keyword_inside_a_template_is_ordinary_vocabulary) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a claim* involves a scenario tested of *a description*.\n    *a claim* is answered by a query of *a name*.\n\nthe knowledge base tiny includes:\n\nclaim one involves a scenario tested of storm surge.\n\nquery who is:\n    which claim involves a scenario tested of which description.\n",
    le_kbs:load_text(Text, M),
    assertion(\+ M:le_issue(error, _, _, _, _, _)),
    assertion(\+ M:le_issue(_, reserved_word_in_template, _, _, _, _)),
    % the fact and the query are there, i.e. the section was not cut short
    assertion(M:query_info(who, _, _)),
    assertion(clause(M:involves_a_scenario_tested_of(_, _), _)).

% ... but a section header that really does start a line still ends the section.
test(a_section_keyword_starting_a_line_still_opens_a_section) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n\nscenario one is:\n    bob is happy.\n",
    le_kbs:load_text(Text, M),
    assertion(M:scenario(one, _)),
    assertion(\+ M:le_issue(error, _, _, _, _, _)).

% A near-miss knowledge-base header ("... is:" for "... includes:") discards
% everything under it, so the fix line has to name the header that works.
test(a_near_miss_kb_header_says_which_header_to_write) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny is:\n\na person is happy\n    if the person is healthy.\n",
    le_kbs:load_text(Text, M),
    M:le_issue(error, unknown_section, _, Fix, _, _),
    assertion(sub_atom(Fix, _, _, _, 'includes:')).

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

:- begin_tests(unmarked_meta_template).

% Chained non-prepositional templates absorb the tail of the sentence into a
% slot as a COMPOUND term (we_will_make(under('this payment','this policy'))),
% which the author of atomic payments/policies does not expect. The verifier
% must point at the likely intent: a meta-template ('that' before the slot).
test(compound_slot_without_that_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*.\n\nthe knowledge base fat includes:\n\nwe will make this payment under this policy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion((member(issue(unmarked_meta_template, D, _, _, _), Issues),
               sub_atom(D, _, _, _, 'meta-template'))).

% A genuine meta-template — the slot preceded by 'that' — legitimately holds an
% embedded literal and must NOT be flagged.
test(that_marked_meta_slot_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    it is prohibited that *an eventuality*.\n    *a person* smokes.\n\nthe knowledge base meta includes:\n\nit is prohibited that a person smokes.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unmarked_meta_template, _, _, _, _), Issues)).

% Atomic facts through the same templates carry no embedded term: no warning.
test(atomic_fact_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*.\n\nthe knowledge base thin includes:\n\nwe will make this payment.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unmarked_meta_template, _, _, _, _), Issues)).

% The intended prepositional design — inner template marked '; prepositional' —
% turns the chain into extra body conditions, not a compound argument: no warning.
test(prepositional_chain_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    we will make *a payment*.\n    *a payment* under *a policy*; prepositional.\n\nthe knowledge base prep includes:\n\nwe will make a payment\n    if the payment under a policy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unmarked_meta_template, _, _, _, _), Issues)).

:- end_tests(unmarked_meta_template).

% ---------------------------------------------------------------------------
% A predicate no query reaches is named by its TEMPLATE (the reader never wrote
% `is_happy/1`) and reported AT its first rule head, not at offset 0.
:- begin_tests(untested_predicate_reporting).

untested_program("the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nquery who is:\n    which person is healthy.\n").

test(named_by_its_template_not_by_functor_arity) :-
    untested_program(Text),
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    member(issue(untested_predicate, Desc, _, _, _), Issues),
    assertion(sub_string(Desc, _, _, _, "is happy")),
    assertion(\+ sub_string(Desc, _, _, _, "is_happy")),
    assertion(\+ sub_string(Desc, _, _, _, "/1")).

test(reported_at_the_rule_head) :-
    untested_program(Text),
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    member(issue(untested_predicate, _, _, Start, End), Issues),
    assertion(Start > 0),
    assertion(End > Start),
    % the range starts at the rule, not at the template declaration
    sub_string(Text, Start, 20, _, Head),
    assertion(Head == "a person is happy if").

:- end_tests(untested_predicate_reporting).

% ---------------------------------------------------------------------------
% Dead vocabulary: a template nothing uses. Generated programs are full of them
% ("*a cost* is a cost; undefined." that no rule ever consults).
:- begin_tests(unused_template).

test(template_used_nowhere_is_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a cost* is a cost; undefined.\n\nthe knowledge base tiny includes:\n\nbob is happy.\n\nquery who is:\n    which person is happy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    member(issue(unused_template, Desc, _, Start, _), Issues),
    assertion(sub_string(Desc, _, _, _, "is a cost")),
    assertion(Start > 0).

test(template_used_in_a_rule_body_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unused_template, _, _, _, _), Issues)).

% Facts supplied by a scenario are a use — this is the whole point of an
% `; undefined` template.
test(template_used_only_in_a_scenario_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy; undefined.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unused_template, _, _, _, _), Issues)).

% ... and so is being asked about in a query.
test(template_used_only_in_a_query_is_not_flagged) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy; undefined.\n\nthe knowledge base tiny includes:\n\nbob is happy.\n\nquery who is:\n    which person is healthy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    assertion(\+ member(issue(unused_template, _, _, _, _), Issues)).

% A general template shadowed by more specific ones reads as a false positive:
% the program is full of sentences that LOOK like uses, but each matches a
% longer template and so a different predicate. The warning is right; the fix
% text has to say why, or the reader hunts a bug in the verifier.
test(a_shadowed_template_says_which_templates_take_its_sentences) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a claim* is excluded from *a section*.\n    *a claim* is excluded from the liability section.\n    *a claim* is excluded from the liability section for fraud.\n\nthe knowledge base tiny includes:\n\na claim is excluded from the liability section\n    if the claim is excluded from the liability section for fraud.\n\nquery which is:\n    which claim is excluded from the liability section.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    member(issue(unused_template, Desc, Fix, _, _), Issues),
    sub_string(Desc, _, _, _, "is excluded from *section*"),
    !,
    assertion(sub_string(Fix, _, _, _, "open with the same words")),
    % the example is the CLOSEST shadowing template, not an arbitrary one
    assertion(sub_string(Fix, _, _, _, "*claim* is excluded from the liability section'")),
    assertion(sub_string(Fix, _, _, _, "2 other")).

% An ordinary dead template — nothing else opens with its words — keeps the
% plain advice, without a note about templates that do not exist.
test(an_unshadowed_dead_template_keeps_the_plain_fix) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n    *a person* is quixotic.\n\nthe knowledge base tiny includes:\n\nbob is happy.\n\nquery who is:\n    which person is happy.\n",
    le_kbs:load_text(Text, M),
    le_verifier:verify(M, [skip_tests], Issues),
    member(issue(unused_template, Desc, Fix, _, _), Issues),
    sub_string(Desc, _, _, _, "quixotic"),
    !,
    assertion(\+ sub_string(Fix, _, _, _, "open with the same words")).

:- end_tests(unused_template).

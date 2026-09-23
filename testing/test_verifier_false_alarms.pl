% The verifier's false alarms that the translated programs (docs/dev/migration.md)
% brought out, one test each: a predicate a Prolog resource defines, a predicate
% called on an instance no rule concludes, a template used only inside an
% embedded sentence, and a kind of issue the message printer did not list.

:- use_module('../le_kbs').
:- use_module('../le_verifier').

tmp_dir(Dir) :-
    tmp_file(le_falsealarm, Base),
    atom_concat(Base, '_d', Dir),
    ( exists_directory(Dir) -> true ; make_directory(Dir) ).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S, [encoding(utf8)]), write(S, Text), close(S)).

issue_types(KB, Types) :-
    le_verifier:verify(KB, Issues),
    findall(T-D, member(issue(T, D, _, _, _), Issues), Types).

:- begin_tests(verifier_false_alarms).

%   lib/temporal.le's way: a template whose predicate is defined in Prolog, in
%   a resource of an included library, and called directly by a rule.
test(predicate_of_a_prolog_resource_is_defined) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/dates.pl'], Pl),
    atomic_list_concat([Dir, '/dates.le'], Lib),
    atomic_list_concat([Dir, '/main.le'], Main),
    write_file(Pl, "the_double_of_is(X, Y) :- Y is 2 * X.\n"),
    write_file(Lib, "the knowledge base dates includes these resources:\n    dates.pl.\n\nthe templates are:\n    the double of *a number* is *a second number*.\n\nthe knowledge base dates includes:\n"),
    write_file(Main, "the target language is: prolog.\n\nthe knowledge base main includes these resources:\n    dates.\n\nthe templates are:\n    *a thing* weighs *a number*.\n    *a thing* is heavy.\n\nthe knowledge base main includes:\n\na thing is heavy if\n    the thing weighs a number\n    and the double of the number is a second number\n    and the second number > 10.\n\nscenario s is:\n    box weighs 6.\n\nquery q is:\n    which thing is heavy.\n"),
    load(Main, KB),
    issue_types(KB, Types),
    assertion(\+ memberchk(undefined_predicate-_, Types)).

%   A predicate with rules is defined even where no rule concludes the
%   instance a condition asks about.
test(predicate_with_rules_is_defined_for_any_instance) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a party* is obliged that *a sentence*.\n    *a thing* is a rel2.\n    *a thing* is a rel4.\n    *a thing* is good.\n\nthe knowledge base k includes:\n\na party is obliged that a thing is a rel4 if\n    the thing is a rel2\n    and the party is a rel2.\n\na thing is good if\n    a party is obliged that the thing is a rel2.\n\nscenario s is:\n    bob is a rel2.\n\nquery q is:\n    which thing is good.\n",
    le_kbs:load_text(Text, KB),
    issue_types(KB, Types),
    assertion(\+ memberchk(undefined_predicate-_, Types)).

%   `*a thing* is a rel4` is used, inside the sentence an obligation is about.
test(template_used_in_an_embedded_sentence_is_used) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a party* is obliged that *a sentence*.\n    *a thing* is a rel2.\n    *a thing* is a rel4.\n\nthe knowledge base k includes:\n\na party is obliged that a thing is a rel4 if\n    the thing is a rel2\n    and the party is a rel2.\n\nscenario s is:\n    bob is a rel2.\n\nquery q is:\n    which party is obliged that which sentence.\n",
    le_kbs:load_text(Text, KB),
    issue_types(KB, Types),
    assertion(\+ ( member(unused_template-D, Types), sub_atom(D, _, _, _, rel4) )).

%   An LPS fluent is defined by the program's laws and initial state, not by
%   Prolog clauses: `*a node* is visited` is not a system template redefined.
test(lps_fluent_is_not_a_redefined_system_template) :-
    Text = "the target language is: lps.\n\nthe maximum time is 3.\n\nthe actions are:\n    *a node* is entered.\n\nthe fluents are:\n    *a node* is visited.\n\nthe knowledge base k includes:\n\nwhen a node is entered\nthen the node is visited.\n\ninitially:\n    a is visited.\n",
    le_kbs:load_text(Text, KB),
    issue_types(KB, Types),
    assertion(\+ memberchk(redefined_system_template-_, Types)).

%   "policy level 1 is a policy level" states a type the program declares,
%   not a value its rules fail to read.
test(a_declared_type_is_not_an_unread_value) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a policy level* has limit *a number*.\n    *a thing* is insured.\n\nthe knowledge base k includes:\n\na thing is insured if\n    the thing is a policy.\n\nscenario s is:\n    contract one is a policy.\n    level one is a policy level.\n    level one has limit 5.\n\nquery q is:\n    which thing is insured.\n",
    le_kbs:load_text(Text, KB),
    issue_types(KB, Types),
    assertion(\+ memberchk(unread_value-_, Types)).

%   A rule stated inside a scenario defines its conclusion's predicate.
test(a_rule_in_a_scenario_defines_its_predicate) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a thing* is big.\n    *a thing* is heavy.\n    *a thing* is costly.\n\nthe knowledge base k includes:\n\na thing is costly if\n    the thing is heavy.\n\nscenario s is:\n    box is big.\n    a thing is heavy if the thing is big.\n\nquery q is:\n    which thing is costly.\n",
    le_kbs:load_text(Text, KB),
    issue_types(KB, Types),
    assertion(\+ memberchk(undefined_predicate-_, Types)).

%   Any kind of issue the verifier describes prints, whether or not
%   prolog:message//1 lists it (non_stratified was not listed).
test(any_issue_kind_prints) :-
    '$messages':translate_message(non_stratified - ['a text with ~ and %'], Lines, []),
    with_output_to(string(S), print_message_lines(current_output, '', Lines)),
    assertion(sub_string(S, _, _, _, "non_stratified: a text with ~ and %")).

:- end_tests(verifier_false_alarms).

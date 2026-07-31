% Tests for three ways a malformed LE program used to go by unnoticed:
%
%  1. "<query> expects [...]" — the 'answers' word omitted — matched no kb_item
%     at all, so the whole tail of the scenario fell to the unknown_section
%     fallback and the expectation simply never ran.
%  2. The unknown_section fallback asserted its diagnostic as le_issue/5, while
%     every reader (verify/1, load/3, the web API, le_tools, the editor) matches
%     le_issue/6 — so a malformed section, e.g. a query missing its trailing
%     dot, was detected and then silently dropped.
%  3. run_one_test returns fail/6 when it has unknowns to report, but the test
%     summary counted only fail/4, so failing files printed "0 Fail" and were
%     labelled [NONE] rather than [FAIL].
%
% Plus the suspicious_is check: the generic "*X* is *Y*" template is the last
% fallback of the literal parser, so a sentence whose wording does not match its
% declared template lands there as a constant assignment that can never succeed.

:- use_module('../le_kbs').
:- use_module('../le_verifier').

% Writes Text to a fresh .le path. load/3 keys its module cache on path and
% modification time, so a distinct path per test keeps them independent.
setup_le_text(Name, Text, Path) :-
    tmp_file_stream(text, Path0, Stream),
    close(Stream),
    atomic_list_concat([Path0, '_', Name, '.le'], Path),
    setup_call_cleanup(open(Path, write, Out), write(Out, Text), close(Out)).

% An expectation written without the optional 'answers' word, and wrong, so a
% full load must report a failed_test.
short_expects_text("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.

the knowledge base shortexpects includes:

a person is happy if the person is healthy.

scenario one is:
    bob is healthy.
    one expects [\"alice is happy\"].

query one is:
    which person is happy.
").

% A query whose body has no trailing dot: section(query(...)) cannot parse it
% and it falls to the unknown_section fallback.
dotless_query_text("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.

the knowledge base dotless includes:

a person is happy if the person is healthy.

scenario one is:
    bob is healthy.

query one is:
    which person is happy
").

% "the person is fond of a friend" against a template declared with "keen on":
% no template matches, so the body literal becomes le_is/2 over a constant.
mismatched_wording_text("the target language is: prolog.

the templates are:
    *a person* is sociable.
    *a person* is keen on *a friend*.

the knowledge base wording includes:

a person is sociable if the person is fond of a friend.

scenario one is:
    bob is keen on alice.

query one is:
    which person is sociable.
").

% A plain value assignment through the same generic template, which must NOT be
% reported: 'the amount is 100' is exactly what le_is/2 is for.
plain_value_text("the target language is: prolog.

the templates are:
    *a person* is rich.
    *a person* has *an amount*.

the knowledge base plainvalue includes:

a person is rich if the person has an amount and the amount is 100.

scenario one is:
    bob has 100.

query one is:
    which person is rich.
").

% Two templates share the functor is_part_of/2 with DIFFERENT argument types, and
% 'bodily injury' is a TYPE (the ontology puts an instance under it) as well as
% the name of an individual. The goal-level type check used to commit to the
% first declared template, so the fact stated through the second one could not be
% proved even though it sits in the session.
same_functor_types_text("the target language is: prolog.

the templates are:
    *a payment* is part of *a claim*.
    *a loss* is part of *a claim*.
    *a claim* is settled.

the ontology is:
    fractured wrist is a bodily injury.
    cheque is a payment.

the knowledge base samefunctor includes:

a claim is settled if a loss is part of the claim.

scenario one is:
    bodily injury is part of claim one.

query one is:
    which claim is settled.
").

:- begin_tests(silent_diagnostics).

% --- 1. 'answers' is optional after 'expects' ---

test(expects_without_answers_runs_the_test,
     [setup((short_expects_text(T), setup_le_text(shortexpects, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(M:le_expected(one, one, [string("alice is happy", _)], [])).

test(expects_without_answers_reports_the_failure,
     [setup((short_expects_text(T), setup_le_text(shortexpectsfail, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M),
    assertion(M:le_issue(warning, failed_test, _, _, _, _)),
    % and the scenario tail is no longer swallowed as an unknown section
    assertion(\+ M:le_issue(_, unknown_section, _, _, _, _)).

% --- 2. A malformed section reaches the reader ---

test(malformed_section_is_reported_at_arity_six,
     [setup((dotless_query_text(T), setup_le_text(dotless, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(M:le_issue(error, unknown_section, _, _, _, _)),
    % nothing may be left behind at the arity no reader looks at
    assertion(\+ current_predicate(M:le_issue/5)).

% The blank line between two well-formed sections also reaches the
% unknown_section fallback, carrying no words. Reporting it would be noise the
% author cannot act on.
test(blank_between_sections_is_not_reported,
     [setup((short_expects_text(T), setup_le_text(blanks, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(\+ M:le_issue(_, unknown_section, _, _, _, _)).

% --- 3. The summary counts fail/6 ---

test(summary_counts_six_argument_failures) :-
    Results = [test_file(afile, [fail(q, s, [expected], [actual], [], [])])],
    with_output_to(string(Out), le_kbs:print_test_summary(Results)),
    assertion(sub_string(Out, _, _, _, "Failed:          1")),
    assertion(sub_string(Out, _, _, _, "[FAIL]")).

test(summary_still_counts_four_argument_failures) :-
    Results = [test_file(afile, [fail(q, s, [expected], [actual])])],
    with_output_to(string(Out), le_kbs:print_test_summary(Results)),
    assertion(sub_string(Out, _, _, _, "Failed:          1")).

% --- 4. suspicious_is ---

test(mismatched_wording_is_reported,
     [setup((mismatched_wording_text(T), setup_le_text(wording, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(M:le_issue(_, suspicious_is, _, _, _, _)).

test(plain_value_assignment_is_not_reported,
     [setup((plain_value_text(T), setup_le_text(plainvalue, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(\+ M:le_issue(_, suspicious_is, _, _, _, _)).

% --- 5. Same-functor templates are all candidates for the type check ---

test(second_template_of_same_functor_is_usable,
     [setup((same_functor_types_text(T), setup_le_text(samefunctor, T, Path))),
      cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    le_kbs:createSession(M, SM),
    le_kbs:setScenarion(SM, one),
    % the fact is in the session under the 'loss' template ...
    assertion(clause(SM:is_part_of('bodily injury', 'claim one'), true)),
    % ... and the reasoner can now prove it, and the rule that depends on it
    assertion(reasoner:i(is_part_of('bodily injury', 'claim one'), SM, _, _)),
    assertion(reasoner:i(is_settled('claim one'), SM, _, _)),
    le_kbs:destroySession(SM).

:- end_tests(silent_diagnostics).

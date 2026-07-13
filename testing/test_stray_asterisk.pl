/** <module> Tests for flagging stray '*' tokens in rule/fact/query text.

    Outside the templates sections '*' is only valid as multiplication inside an
    arithmetic expression. A stray '*' (e.g. the typo "a claim*" in a rule head)
    is silently swallowed into a variable name, detaching the variable from its
    other occurrences and corrupting its type — so the second pass must report a
    stray_asterisk error at the offending token. A legitimate multiplication must
    NOT be flagged. (Regression: hiscoxhappypath.le annex rule "a payment in
    respect of a claim*".)

    Run with:  swipl -g run_tests -t halt testing/test_stray_asterisk.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_stray_asterisk, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

:- begin_tests(stray_asterisk).

% A '*' glued to a variable phrase in a rule head is an error, located at the
% '*' token itself.
test(stray_asterisk_in_rule_head_is_flagged) :-
    Text = "the templates are:\n    \c
            *a payment* in respect of *a claim*; composite.\n    \c
            *a payment* is in respect of *a claim*.\n\c
            the knowledge base t includes:\n    \c
            a payment in respect of a claim* \n                \c
            if the payment is in respect of the claim.\n",
    le_kbs:load_text(Text, KB),
    once(KB:le_issue(error, stray_asterisk, _Desc, _Fix, Start, End)),
    assertion(once(sub_string(Text, Start, 1, _, "*"))),
    assertion(End =:= Start + 1).

% A '*' used as multiplication in an arithmetic expression is legitimate.
test(multiplication_asterisk_is_not_flagged) :-
    Text = "the templates are:\n    \c
            *an amount* is the double of *an amount*.\n\c
            the knowledge base t includes:\n    \c
            an amount X is the double of an amount Y\n    \c
            if X = Y * 2.\n",
    le_kbs:load_text(Text, KB),
    assertion(\+ KB:le_issue(_, stray_asterisk, _, _, _, _)).

% A stray '*' in a scenario fact is flagged too.
test(stray_asterisk_in_scenario_fact_is_flagged) :-
    Text = "the templates are:\n    \c
            *a payment* is in respect of *a claim*.\n\c
            the knowledge base t includes:\n    \c
            a payment is in respect of a claim.\n\c
            scenario one is:\n    \c
            this payment is in respect of this claim*.\n",
    le_kbs:load_text(Text, KB),
    assertion(once(KB:le_issue(error, stray_asterisk, _, _, _, _))).

:- end_tests(stray_asterisk).

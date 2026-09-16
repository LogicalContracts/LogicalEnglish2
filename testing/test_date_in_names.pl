/** <module> A date inside a multi-word constant keeps its zero padding.

    `the run of 2026-09-14` names the constant 'the run of 2026-09-14', as
    written: tokenizer:tokens_to_string/2 used to write the month and day
    with a column stop (`~2|`) where a column width (`~2+`) was meant, so the
    constant became 'the run of 2026-9-14' (and every exporter keyed on it,
    LegalRuleML's LegalSource keys among them, lost the padding).

    Run with:  swipl -q -g run_tests -t halt testing/test_date_in_names.pl
*/

:- module(test_date_in_names, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../tokenizer').

:- begin_tests(date_in_names).

test(tokens_to_string_pads_dates) :-
    once(tokenize("the run of 2026-09-04", Tokens)),
    tokens_to_string(Tokens, S),
    assertion(sub_string(S, _, _, _, "2026-09-04")).

test(constant_keeps_padding) :-
    T = "the target language is: prolog.\n\nthe templates are:\n    *a thing* is fine.\n\nthe knowledge base k includes:\n\nthe run of 2026-09-14 is fine.\n",
    le_kbs:load_text(T, KB),
    findall(X, catch(KB:is_fine(X), _, fail), Xs),
    assertion(Xs == ['the run of 2026-09-14']).

:- end_tests(date_in_names).

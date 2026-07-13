/** <module> Tests for filtering type-guard nodes from explanations.

    A rule head's le_type_check guard (rendered "X is a Y") is lenient: it also
    succeeds when nothing at all is known about X's type. Reporting such a
    success as a true condition is unfounded (the hiscox "this claim is a claim"
    case), so postprocess_why keeps a type-guard node only when the type
    membership is actually derivable from is_a facts, or the user explicitly
    assumed it — and omits it otherwise.

    Run with:  swipl -g run_tests -t halt testing/test_type_check_explanation.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_type_check_explanation, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

% A KB where in_respect_of/2 has differently-typed templates at BOTH argument
% positions, so the annex-style rule gets a le_type_check guard on each: the
% payment guard is founded by the scenario's "this payment is a payment" fact,
% while nothing types 'this claim'.
kb_text("the target language is: prolog.\n\c
\n\c
the templates are:\n\c
    we will make *a payment*.\n\c
    *a payment* in respect of *a claim*; composite.\n\c
    *a payment* in respect of *an incident*; composite.\n\c
    *an amount* in respect of *a claim*; composite.\n\c
    *a payment* is in respect of *a claim*.\n\c
\n\c
the knowledge base t includes:\n\c
    we will make a payment\n\c
    if the payment is a payment.\n\c
\n\c
    a payment in respect of a claim\n\c
    if the payment is in respect of the claim.\n\c
\n\c
scenario one is:\n\c
    this payment is a payment.\n\c
    this payment is in respect of this claim.\n\c
\n\c
query q is:\n\c
    we will make which payment in respect of this claim.\n").

query_why(SetupGoal, Why) :-
    kb_text(Text),
    le_kbs:load_text(Text, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, one),
    call(SetupGoal, SM),
    once(le_kbs:query(SM, q, _Instance, _U, Why)),
    le_kbs:destroySession(SM).

no_setup(_SM).
assume_claim_type(SM) :- assertz(SM:le_unknown(is_a('this claim', claim))).

% All LE strings of the (postprocessed) explanation tree.
why_le_strings(success(_G, _R, LE0, Children), [LE|Ls]) :- !,
    atom_string(LE, LE0),
    why_le_strings(Children, Ls).
why_le_strings(failure(_G, _R, LE0, Children), [LE|Ls]) :- !,
    atom_string(LE, LE0),
    why_le_strings(Children, Ls).
why_le_strings(repeated_group(_N, Why), Ls) :- !,
    why_le_strings(Why, Ls).
why_le_strings(List, Ls) :-
    is_list(List), !,
    maplist(why_le_strings, List, Lss),
    append(Lss, Ls).
why_le_strings(_, []).

:- begin_tests(type_check_explanation).

% The founded payment guard stays; the unfounded claim guard is omitted.
test(unfounded_type_guard_is_omitted_and_founded_kept) :-
    query_why(no_setup, Why),
    why_le_strings(Why, LEs),
    assertion(memberchk('this payment is a payment', LEs)),
    assertion(\+ memberchk('this claim is a claim', LEs)).

% An explicitly assumed type membership keeps its node (shown as an assumption).
test(assumed_type_guard_is_kept) :-
    query_why(assume_claim_type, Why),
    why_le_strings(Why, LEs),
    assertion(memberchk('this claim is a claim', LEs)).

:- end_tests(type_check_explanation).

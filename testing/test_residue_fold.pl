/** <module> Folding translated residue into the rules that call it

    le_residue_fold.pl: each condition line naming a translated residue is
    replaced by the translation's conditions, a condition folded in twice is
    kept once, and a residue whose folding could change an answer stays a
    rule of its own. Also the provenance labels the splice gives a residue's
    rules (le_contract_assistant:residue_label_rules/4).

    Run with:  swipl -q -g run_tests -t halt testing/test_residue_fold.pl
*/

:- module(test_residue_fold, []).

:- use_module(library(plunit)).
:- use_module('../le_residue_fold').
:- use_module('../le_contract_assistant').
:- use_module('../le_kbs').

%   Two conditions translated the same way, one exclusion with a negation,
%   one translated as alternatives, one still unknown, one a scenario names.
program("the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* has entered administration.
    *a counterparty* is regulated; unknown.
    *a counterparty* is licensed; unknown.
    *a counterparty* meets *a condition*.
    *a counterparty* fails *a condition*; undefined.
    *a counterparty* is outside *an exclusion*.

the knowledge base k includes:

it must not be true that
    a counterparty meets a condition
    and the counterparty fails the condition.

rule r1 with provenance \"the opinion\", at \"p.1\":
a counterparty is covered if
    the counterparty holds a banking licence
    and the counterparty meets condition c1
    and the counterparty meets condition c2
    and the counterparty is outside exclusion e1
    and the counterparty meets condition c3
    and the counterparty meets condition c4
    and the counterparty meets condition c5.

% RESIDUE c1 BEGIN: condition c1 (rules r1)
% TODO: conclude \"a counterparty meets condition c1\" from the text below
%   source: p.8 (verified quote)
%   english:
%   | A regulated bank.
a counterparty meets condition c1 if
    the counterparty is regulated.
% RESIDUE c1 END

% RESIDUE c2 BEGIN: condition c2 (rules r1)
% TODO: conclude \"a counterparty meets condition c2\" from the text below
%   english:
%   | The bank must be regulated.
a counterparty meets condition c2 if
    the counterparty is regulated.
% RESIDUE c2 END

% RESIDUE e1 BEGIN: exclusion e1 (rules r1)
% TODO: conclude \"a counterparty is outside exclusion e1\"
%   english:
%   | a bank in administration
a counterparty is outside exclusion e1 if
    it is not the case that
        the counterparty has entered administration.
% RESIDUE e1 END

% RESIDUE c3 BEGIN: condition c3 (rules r1)
% TODO: conclude \"a counterparty meets condition c3\" from the text below
%   english:
%   | Regulated or licensed.
a counterparty meets condition c3 if
    the counterparty is regulated
    or the counterparty is licensed.
% RESIDUE c3 END

% RESIDUE c4 BEGIN: condition c4 (rules r1)
% TODO: conclude \"a counterparty meets condition c4\" from the text below
%   english:
%   | An assumption about the transaction.
% kept unknown: an assumption about the transaction
it is unknown whether a counterparty meets condition c4.
% RESIDUE c4 END

% RESIDUE c5 BEGIN: condition c5 (rules r1)
% TODO: conclude \"a counterparty meets condition c5\" from the text below
%   english:
%   | Licensed.
a counterparty meets condition c5 if
    the counterparty is licensed.
% RESIDUE c5 END

scenario s is:
    acme holds a banking licence.
    acme is regulated.
    acme is licensed.
    other holds a banking licence.
    other is regulated.
    other fails condition c5.

query q is:
    which counterparty is covered.
").

folded(Folded, Report) :-
    program(P),
    residue_fold(P, Folded, Report).

report_of(Report, Id, R) :- member(R, Report), R.id == Id, !.

answers(Program, Answers) :-
    le_kbs:load_text(Program, test_residue_fold, KB),
    le_kbs:createSession(KB, SM), le_kbs:setScenarion(SM, s),
    findall(A-Us, ( le_kbs:query(SM, q, I, Us0, _), le_kbs:canonical_string(I, A),
                    findall(U, ( member(U0, Us0), le_kbs:item_to_instance(KB, U0, UI),
                                 le_kbs:canonical_string(UI, U) ), Us1), sort(Us1, Us) ),
            Answers0),
    sort(Answers0, Answers).

:- begin_tests(residue_fold).

test(single_rule_translations_are_folded) :-
    folded(F, Report),
    forall(member(Id, [c1, c2, e1]), ( report_of(Report, Id, R), assertion(R.folded == true) )),
    assertion(\+ sub_string(F, _, _, _, "meets condition c1")),
    assertion(\+ sub_string(F, _, _, _, "% RESIDUE c1 BEGIN")),
    assertion(sub_string(F, _, _, _, "    and it is not the case that\n        the counterparty has entered administration")).

test(a_condition_folded_twice_is_kept_once) :-
    folded(F, _),
    aggregate_all(count, sub_string(F, _, _, _, "and the counterparty is regulated"), N),
    assertion(N =:= 1).

test(the_residue_text_is_kept_above_the_rule) :-
    folded(F, _),
    assertion(sub_string(F, _, _, _, "% folded in from residue c1 (p.8 (verified quote)):\n%   | A regulated bank.")),
    sub_string(F, B1, _, _, "% folded in from residue c1"),
    sub_string(F, B2, _, _, "rule r1 with provenance"),
    assertion(B1 < B2).

test(what_folding_could_change_stays_a_rule) :-
    folded(F, Report),
    report_of(Report, c3, R3), assertion(R3.folded == false),    % alternatives
    report_of(Report, c4, R4), assertion(R4.folded == false),    % the placeholder
    report_of(Report, c5, R5), assertion(R5.folded == false),    % a scenario names it
    assertion(sub_string(R5.reason, _, _, _, "other fails condition c5")),
    assertion(sub_string(F, _, _, _, "    and the counterparty meets condition c5.")).

test(folding_changes_no_answer) :-
    program(P), answers(P, A0),
    folded(F, _), answers(F, A1),
    assertion(A0 == A1),
    assertion(A0 \== []).

test(a_residue_with_provenance_labels_its_rules) :-
    le_contract_assistant:residue_label_rules(
        ["%   provenance: \"the opinion\", at \"p.80\", confer \"Yes, but only\""], c22,
        ["a counterparty meets condition c22 if", "    the counterparty is x.",
         "a counterparty meets condition c22 if", "    the counterparty is y."], L),
    assertion(L = ["rule c22 with provenance \"the opinion\", at \"p.80\", confer \"Yes, but only\":", _, _,
                   "rule c22_2 with provenance \"the opinion\", at \"p.80\", confer \"Yes, but only\":", _, _]).

test(a_residue_without_provenance_is_left_unlabelled) :-
    Ls = ["a counterparty meets condition c22 if", "    the counterparty is x."],
    le_contract_assistant:residue_label_rules(["%   english:"], c22, Ls, L),
    assertion(L == Ls).

:- end_tests(residue_fold).

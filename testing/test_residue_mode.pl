/** <module> The Contract Assistant's residue mode: a fixed skeleton, the residue filled in

    Phase 0, item 4 of InsurLE2/docs/MiggratingFromOtherSystems.md §8: the
    assistant accepts a deterministic skeleton with residue fragments and
    repairs only the residue (§4.4). The LLM is stubbed through ca_llm_hook/1.

    Run with:  swipl -q -g run_tests -t halt testing/test_residue_mode.pl
*/

:- module(test_residue_mode, []).

:- use_module(library(plunit)).
:- use_module('../le_contract_assistant').

skeleton("the target language is: prolog.

the templates are:
    the base premium of *a vehicle* is *an amount*; undefined.
    the age of *a vehicle* is *a number*; undefined.
    the premium of *a vehicle* is *an amount*.
% RESIDUE TEMPLATES BEGIN
% RESIDUE TEMPLATES END

the knowledge base rating includes:

% RESIDUE r1 BEGIN: the age surcharge in the rating plugin
%   source: plugins/rating.js lines 3-4
%   javascript:
%   | premium = base;
%   | if (age > 10) { premium = base * 1.2; }
% RESIDUE r1 END

scenario old is, as stated in \"rating tests\" at case 1:
    the base premium of car1 is 100.
    the age of car1 is 12.
    q expects answers [\"the premium of car1 is 120.0\"].

scenario young is, as stated in \"rating tests\" at case 2:
    the base premium of car2 is 100.
    the age of car2 is 3.
    q expects answers [\"the premium of car2 is 100\"].

query q is:
    the premium of which vehicle is which amount.
").

good_residue("```le residue r1
the premium of a vehicle is an amount P if
    the base premium of the vehicle is an amount B
    and the age of the vehicle is a number A
    and A > 10
    and P = B * 1.2.

the premium of a vehicle is an amount P if
    the base premium of the vehicle is an amount P
    and the age of the vehicle is a number A
    and A <= 10.
```").

%   The surcharge applied to every vehicle: a scenario fails.
wrong_residue("```le residue r1
the premium of a vehicle is an amount P if
    the base premium of the vehicle is an amount B
    and P = B * 1.2.
```").

hook_good(residue_draft(_), _, R) :- !, good_residue(R).
hook_good(P, _, _) :- throw(unexpected_llm_purpose(P)).

hook_repair(residue_draft(_), _, R) :- !, wrong_residue(R).
hook_repair(residue_repair(_, _), _, R) :- !, good_residue(R).
hook_repair(P, _, _) :- throw(unexpected_llm_purpose(P)).

%   A reply that tries to rewrite the whole program: only its residue block
%   is ever used.
hook_greedy(residue_draft(_), _, R) :- !,
    good_residue(G),
    format(string(R), "Here is the whole program, improved:~n```le~nthe target language is: prolog.~nthe knowledge base other includes:~nx is y.~n```~n~w", [G]).
hook_greedy(P, _, _) :- throw(unexpected_llm_purpose(P)).

hook_setup(Hook) :-
    tmp_file(resjobs, Tmp),
    setenv('LE_CONTRACT_JOBS_DIR', Tmp),
    retractall(le_contract_assistant:ca_llm_hook(_)),
    assertz(le_contract_assistant:ca_llm_hook(Hook)).

hook_cleanup :-
    retractall(le_contract_assistant:ca_llm_hook(_)),
    unsetenv('LE_CONTRACT_JOBS_DIR').

config(Config) :-
    skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model",
               budget: _{preset: "draft", minutes: 5}}.

%   Every line of the skeleton outside the residue blocks is in the result,
%   in order.
skeleton_kept(Skeleton, Result) :-
    split_string(Skeleton, "\n", "", SL),
    le_contract_assistant:residue_blocks(Skeleton, _),
    exclude(le_contract_assistant:comment_line, SL, Outside),
    split_string(Result, "\n", "", RL),
    subsequence(Outside, RL).

subsequence([], _).
subsequence([X|Xs], [Y|Ys]) :- ( X == Y -> subsequence(Xs, Ys) ; subsequence([X|Xs], Ys) ).

:- begin_tests(residue_mode).

test(blocks_found) :-
    skeleton(P),
    le_contract_assistant:residue_blocks(P, Blocks),
    assertion(Blocks = [res(r1, "the age surcharge in the rating plugin", _, [])]).

test(splice_keeps_the_source_comments) :-
    skeleton(P),
    le_contract_assistant:residue_splice(P, [r1-"x is y."], Out),
    assertion(sub_string(Out, _, _, _, "%   | if (age > 10) { premium = base * 1.2; }\nx is y.\n% RESIDUE r1 END")).

test(fills_read_from_labelled_fences) :-
    good_residue(R),
    le_contract_assistant:residue_fills(R, [r1], Fills),
    assertion(Fills = [r1-_]).

test(residue_translated_and_tests_pass,
     [setup(hook_setup(test_residue_mode:hook_good)), cleanup(hook_cleanup)]) :-
    config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(Result.mode == residue),
    Result.final_score = S,
    assertion(S.errors =:= 0),
    assertion(S.tests_passed =:= 2),
    assertion(S.tests_failed =:= 0),
    Result.residue = [R1],
    assertion(R1.status == "translated"),
    skeleton(Sk),
    assertion(skeleton_kept(Sk, Result.le)).

test(a_wrong_translation_is_repaired_by_the_source_tests,
     [setup(hook_setup(test_residue_mode:hook_repair)), cleanup(hook_cleanup)]) :-
    config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    Result.final_score = S,
    assertion(S.tests_failed =:= 0),
    assertion(S.tests_passed =:= 2).

test(the_skeleton_cannot_be_rewritten,
     [setup(hook_setup(test_residue_mode:hook_greedy)), cleanup(hook_cleanup)]) :-
    config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(\+ sub_string(Result.le, _, _, _, "the knowledge base other")),
    skeleton(Sk),
    assertion(skeleton_kept(Sk, Result.le)).

:- end_tests(residue_mode).

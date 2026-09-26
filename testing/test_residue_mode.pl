/** <module> The Contract Assistant's residue mode: a fixed skeleton, the residue filled in

    Phase 0, item 4 of InsurLE2/docs/migration/roadmap.md §8: the
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

%   A skeleton in the form a document-to-LE generator writes: each residue
%   names the sentence it must conclude, with its own constant, and holds an
%   `it is unknown whether` placeholder. No scenario tests it.
named_skeleton("the target language is: prolog.

the templates are:
    *a counterparty* meets *a condition*.
    *a counterparty* is organised under the law of *a jurisdiction*.
% RESIDUE TEMPLATES BEGIN
% RESIDUE TEMPLATES END

the knowledge base coverage includes:

% RESIDUE c1 BEGIN: condition c1
% TODO: conclude \"a counterparty meets condition c1\" from the text below
%   english:
%   | The counterparty is organised under the law of England.
it is unknown whether a counterparty meets condition c1.
% RESIDUE c1 END

% RESIDUE c2 BEGIN: condition c2
%   concludes: a counterparty meets condition c2
%   english:
%   | Opinion assumes neither party is able to avail itself of immunity.
it is unknown whether a counterparty meets condition c2.
% RESIDUE c2 END
").

%   What a model wrote for every residue of a 359-residue opinion: the
%   template with its constant replaced by "a condition".
general_residue("```le residue c1
a counterparty meets a condition.
```
```le residue c2
a counterparty meets a condition.
```").

named_residue("```le residue c1
a counterparty meets condition c1 if
    the counterparty is organised under the law of england.
```
```le residue c2
it is unknown whether a counterparty meets condition c2.
```").

hook_named(residue_draft(_), _, R) :- !, general_residue(R).
hook_named(residue_repair(_, _), _, R) :- !, named_residue(R).
hook_named(P, _, _) :- throw(unexpected_llm_purpose(P)).

conclusion_issues(Reply, Issues) :-
    named_skeleton(P),
    le_contract_assistant:residue_blocks(P, Rs),
    le_contract_assistant:residue_fills(Reply, [c1, c2], Fills),
    findall(I, ( member(Res, Rs), Res = res(Id, _, _, _), memberchk(Id-F, Fills),
                 le_contract_assistant:residue_conclusion_issue(P, Fills, Res, F, I) ),
            Issues).

%   A skeleton whose rule calls its residues, as a coverage matrix does: the
%   rule already checks the counterparty's kind and jurisdiction.
called_skeleton("the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* is a bank.
    *a counterparty* is organised under the law of *a jurisdiction*.
    *a counterparty* meets *a condition*.
% RESIDUE TEMPLATES BEGIN
% RESIDUE TEMPLATES END

the knowledge base coverage includes:

a counterparty is covered if
    the counterparty is a bank
    and the counterparty is organised under the law of england
    and the counterparty meets condition c1
    and the counterparty meets condition c2
    and the counterparty meets condition c3.

% RESIDUE c1 BEGIN: condition c1
% TODO: conclude \"a counterparty meets condition c1\" from the text below
%   english:
%   | A bank having its head office in England.
it is unknown whether a counterparty meets condition c1.
% RESIDUE c1 END

% RESIDUE c2 BEGIN: condition c2
% TODO: conclude \"a counterparty meets condition c2\" from the text below
%   english:
%   | The bank holds a deposit-taking permission.
it is unknown whether a counterparty meets condition c2.
% RESIDUE c2 END

% RESIDUE c3 BEGIN: condition c3
% TODO: conclude \"a counterparty meets condition c3\" from the text below
%   english:
%   | The opinion assumes the transaction is at arm's length.
it is unknown whether a counterparty meets condition c3.
% RESIDUE c3 END
").

called_config(Extra, Config) :-
    called_skeleton(P),
    le_contract_assistant:residue_blocks(P, Rs),
    findall(Id, member(res(Id, _, _, _), Rs), Ids),
    Config0 = _{program: P, residues: Rs, residue_ids: Ids, baseline: _{passing: []}},
    Config = Config0.put(Extra).

verify_fills(Reply, V) :-
    called_config(_{}, C),
    le_contract_assistant:residue_fills(Reply, [c1, c2, c3], Fills),
    le_contract_assistant:residue_verify(C, Fills, _, V).

%   The residue checks' issues (not the verifier's) as Type-Id.
issue_types(V, Types) :-
    findall(T-Id, ( member(I, V.issues), get_dict(residue, I, Id), get_dict(type, I, T),
                    string_concat("residue_", _, T) ), Types).

%   One answer per residue the prompt lists (its `- \`cN\`:` lines), and a
%   record of which residues each call asked for.
:- dynamic asked/1.
hook_batched(residue_draft(_), Messages, Reply) :- !,
    format(string(Prompt), "~w", [Messages]),
    findall(Id, ( sub_string(Prompt, B, _, _, "- `c"), B1 is B + 3,
                  sub_string(Prompt, B1, 2, _, IdS), atom_string(Id, IdS) ), Ids0),
    sort(Ids0, Ids),
    assertz(asked(Ids)),
    findall(Block, ( member(Id, Ids),
                     format(string(Block), "```le residue ~w~nit is unknown whether a counterparty meets condition ~w.~n% kept unknown: stub~n```", [Id, Id]) ),
            Blocks),
    atomic_list_concat(Blocks, "\n", Reply).
hook_batched(P, _, _) :- throw(unexpected_llm_purpose(P)).

%   Translations that add what the text requires: c1 and c2 are single rules
%   (folded into the calling rule), c3 stays unknown with its reason.
hook_translating(residue_draft(_), _, "```le residue templates
*a counterparty* has its head office in england; unknown.
*a counterparty* holds a deposit-taking permission; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    the counterparty has its head office in england.
```
```le residue c2
a counterparty meets condition c2 if
    the counterparty holds a deposit-taking permission.
```
```le residue c3
% kept unknown: an assumption about the transaction
it is unknown whether a counterparty meets condition c3.
```") :- !.
hook_translating(P, _, _) :- throw(unexpected_llm_purpose(P)).

%   A skeleton whose one test passes on the placeholders (the answer rests on
%   both conditions), and a model that keeps translating c1 as a negation of
%   an unknown: the row can then never answer, and the test breaks.
guarded_skeleton("the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* meets *a condition*.
% RESIDUE TEMPLATES BEGIN
% RESIDUE TEMPLATES END

the knowledge base coverage includes:

a counterparty is covered if
    the counterparty holds a banking licence
    and the counterparty meets condition c1
    and the counterparty meets condition c2.

% RESIDUE c1 BEGIN: condition c1
%   concludes: a counterparty meets condition c1
%   english:
%   | The bank is not in administration.
it is unknown whether a counterparty meets condition c1.
% RESIDUE c1 END

% RESIDUE c2 BEGIN: condition c2
%   concludes: a counterparty meets condition c2
%   english:
%   | The bank has its head office in England.
it is unknown whether a counterparty meets condition c2.
% RESIDUE c2 END

scenario acme is:
    acme holds a banking licence.
    q expects answers [\"acme is covered\"] and any unknowns.

query q is:
    which counterparty is covered.
").

hook_negating(P, _, "```le residue templates
*a counterparty* is in administration; unknown.
*a counterparty* has its head office in england; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    it is not the case that
        the counterparty is in administration.
```
```le residue c2
a counterparty meets condition c2 if
    the counterparty has its head office in england.
```") :- ( P = residue_draft(_) ; P = residue_repair(_, _) ), !.
hook_negating(P, _, _) :- throw(unexpected_llm_purpose(P)).

%   A model whose translation of c2 declares a template with a reserved word:
%   an error, so the editor would run no query. The line goes, and c2 goes
%   back to its placeholder.
hook_reserved(P, _, "```le residue templates
*a counterparty* has its head office in england; unknown.
*a counterparty* does not fall within any of the excluded types; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    the counterparty has its head office in england.
```
```le residue c2
a counterparty meets condition c2 if
    the counterparty does not fall within any of the excluded types.
```") :- ( P = residue_draft(_) ; P = residue_repair(_, _) ), !.
hook_reserved(P, _, _) :- throw(unexpected_llm_purpose(P)).

%   The draft translates c1 with an error and c2 well; the repair declines
%   both. The decline of c1 (blamed) is taken, that of c2 (not) refused.
hook_declining(residue_draft(_), _, "```le residue templates
*a counterparty* is in administration; unknown.
*a counterparty* has its head office in england; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    it is not the case that
        the counterparty is in administration.
```
```le residue c2
a counterparty meets condition c2 if
    the counterparty has its head office in england.
```") :- !.
hook_declining(residue_repair(_, _), _, "```le residue c1
% kept unknown: cannot be stated positively
it is unknown whether a counterparty meets condition c1.
```
```le residue c2
% kept unknown: giving up
it is unknown whether a counterparty meets condition c2.
```") :- !.
hook_declining(P, _, _) :- throw(unexpected_llm_purpose(P)).

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

test(a_conclusion_without_its_constant_is_an_error) :-
    general_residue(R),
    conclusion_issues(R, Issues),
    length(Issues, N),
    assertion(N =:= 2),
    Issues = [I|_],
    assertion(I.severity == "error"),
    assertion(sub_string(I.message, _, _, _, "it is unknown whether a counterparty meets condition c1")).

test(a_named_conclusion_or_the_placeholder_passes) :-
    named_residue(R),
    conclusion_issues(R, Issues),
    assertion(Issues == []).

test(a_block_concluding_something_else_is_an_error) :-
    conclusion_issues("```le residue c1\na counterparty meets condition c9.\n```", Issues),
    assertion(Issues = [_]).

test(the_general_fact_is_repaired,
     [setup(hook_setup(test_residue_mode:hook_named)), cleanup(hook_cleanup)]) :-
    named_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model",
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(\+ sub_string(Result.le, _, _, _, "a counterparty meets a condition")),
    assertion(Result.final_score.errors =:= 0),
    Result.residue = [R1, R2],
    assertion(R1.status == "translated"),
    assertion(R2.status == "open").

test(repeating_the_calling_rule_adds_nothing) :-
    verify_fills("```le residue c1
a counterparty meets condition c1 if
    the counterparty is a bank
    and the counterparty is organised under the law of england.
```", V),
    issue_types(V, Types),
    assertion(memberchk("residue_restates"-c1, Types)),
    assertion(V.open >= 1).

test(what_the_text_adds_is_a_translation) :-
    verify_fills("```le residue templates
*a counterparty* has its head office in england; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    the counterparty has its head office in england.
```", V),
    issue_types(V, Types),
    assertion(\+ memberchk(_-c1, Types)).

test(a_bare_placeholder_is_open_a_commented_one_is_not) :-
    verify_fills("```le residue c2
it is unknown whether a counterparty meets condition c2.
```
```le residue c3
% kept unknown: an assumption about the transaction
it is unknown whether a counterparty meets condition c3.
```", V),
    issue_types(V, Types),
    assertion(memberchk("residue_open"-c2, Types)),
    assertion(\+ memberchk(_-c3, Types)).

test(keeping_every_placeholder_ranks_below_translating) :-
    called_config(_{}, C),
    le_contract_assistant:residue_fills("```le residue c1
it is unknown whether a counterparty meets condition c1.
```", [c1, c2, c3], Lazy),
    le_contract_assistant:residue_fills("```le residue templates
*a counterparty* has its head office in england; unknown.
```
```le residue c1
a counterparty meets condition c1 if
    the counterparty has its head office in england.
```", [c1, c2, c3], Done),
    le_contract_assistant:residue_verify(C, Lazy, T0, V0),
    le_contract_assistant:residue_verify(C, Done, T1, V1),
    le_contract_assistant:best_of(cand(T0, V0, s0), cand(T1, V1, s1), Best),
    assertion(Best = cand(_, _, s1)).

test(residues_are_drafted_in_batches,
     [setup(( retractall(test_residue_mode:asked(_)), hook_setup(test_residue_mode:hook_batched) )),
      cleanup(( retractall(test_residue_mode:asked(_)), hook_cleanup ))]) :-
    called_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model", residue_batch: 2,
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    findall(A, test_residue_mode:asked(A), Asked),
    msort(Asked, Sorted),
    assertion(Sorted == [[c1, c2], [c3]]),
    assertion(Result.final_score.open =:= 0).

test(the_prompt_skeleton_leaves_out_other_residues) :-
    called_config(_{}, C),
    le_contract_assistant:residue_focus_program(C, C.program, [c2], F),
    assertion(sub_string(F, _, _, _, "% RESIDUE c2 BEGIN")),
    assertion(\+ sub_string(F, _, _, _, "% RESIDUE c1 BEGIN")),
    assertion(sub_string(F, _, _, _, "and the counterparty meets condition c2")).

test(the_delivered_program_is_folded,
     [setup(hook_setup(test_residue_mode:hook_translating)), cleanup(hook_cleanup)]) :-
    called_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model",
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    Fold = Result.fold,
    assertion(Fold.applied == true),
    assertion(Fold.folded =:= 2),
    assertion(sub_string(Result.le, _, _, _, "    and the counterparty has its head office in england\n    and the counterparty holds a deposit-taking permission\n    and the counterparty meets condition c3.")),
    assertion(\+ sub_string(Result.le, _, _, _, "% RESIDUE c1 BEGIN")),
    assertion(sub_string(Result.le, _, _, _, "% RESIDUE c3 BEGIN")),
    assertion(sub_string(Result.ledger, _, _, _, "into a counterparty is covered")).

test(folding_can_be_turned_off,
     [setup(hook_setup(test_residue_mode:hook_translating)), cleanup(hook_cleanup)]) :-
    called_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model", fold: false,
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(sub_string(Result.le, _, _, _, "% RESIDUE c1 BEGIN")).

test(a_translation_that_breaks_a_test_goes_back_to_its_placeholder,
     [setup(hook_setup(test_residue_mode:hook_negating)), cleanup(hook_cleanup)]) :-
    guarded_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model",
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    %  c1 is back to its placeholder, and says why; c2 stays translated (and folded)
    assertion(sub_string(Result.le, _, _, _, "% kept unknown: its translation was put back (scenario acme)\nit is unknown whether a counterparty meets condition c1.")),
    assertion(sub_string(Result.le, _, _, _, "and the counterparty has its head office in england")),
    assertion(Result.final_score.tests_failed =:= 0),
    member(R1, Result.residue), R1.id == "c1",
    assertion(sub_string(R1.status, 0, _, _, "reverted")).

test(no_error_is_delivered,
     [setup(hook_setup(test_residue_mode:hook_reserved)), cleanup(hook_cleanup)]) :-
    guarded_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model",
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(Result.final_score.errors =:= 0),
    assertion(\+ sub_string(Result.le, _, _, _, "any of the excluded types; unknown")),
    assertion(sub_string(Result.le, _, _, _, "it is unknown whether a counterparty meets condition c2.")),
    assertion(sub_string(Result.le, _, _, _, "and the counterparty has its head office in england")).

test(a_declined_residue_keeps_its_placeholder) :-
    guarded_skeleton(P),
    le_contract_assistant:residue_splice(P, [c1-"% kept unknown: an assumption about the transaction"], Out),
    assertion(sub_string(Out, _, _, _, "% kept unknown: an assumption about the transaction\nit is unknown whether a counterparty meets condition c1.\n% RESIDUE c1 END")).

test(a_repair_may_not_decline_a_translation_it_was_not_asked_about,
     [setup(hook_setup(test_residue_mode:hook_declining)), cleanup(hook_cleanup)]) :-
    guarded_skeleton(P),
    Config = _{mode: "residue", program: P, model: "stub-model", fold: false,
               budget: _{preset: "draft", minutes: 5}},
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    assertion(sub_string(Result.le, _, _, _, "% kept unknown: cannot be stated positively")),
    assertion(\+ sub_string(Result.le, _, _, _, "% kept unknown: giving up")),
    assertion(sub_string(Result.le, _, _, _, "the counterparty has its head office in england")).

:- end_tests(residue_mode).

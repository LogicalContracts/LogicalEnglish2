% Tests for the LE Contract Assistant (le_contract_assistant.pl).
% The LLM is stubbed through ca_llm_hook/1, so the whole pipeline runs
% offline on a tiny synthetic contract.

:- use_module('../le_contract_assistant').

% ------------------------------- fixtures ------------------------------------

good_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"bob is happy\"].\n\nquery who is:\n    which person is happy.\n").

% Same program with a wrong expectation: verifies but its test fails,
% forcing the repair loop to run.
broken_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"alice is happy\"].\n\nquery who is:\n    which person is happy.\n").

% The fixture programs already end in a newline, so the fence adds none.
fence(Program, Reply) :-
    format(string(Reply), "Here is the program:\n```le\n~w```\n", [Program]).

% Hook returning a correct draft straight away.
hook_good(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_good(architecture, _, "one branch: happiness") :- !.
hook_good(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_good(ledger, _, "LEDGER: all encoded") :- !.
hook_good(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook whose draft has a failing test; the repair call returns the fix.
hook_repair(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_repair(architecture, _, "one branch: happiness") :- !.
hook_repair(draft(_), _, Reply) :- !, broken_program(P), fence(P, Reply).
hook_repair(repair(_, _), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_repair(ledger, _, "LEDGER") :- !.
hook_repair(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

start_config(Config) :-
    good_wording(W),
    Config = _{wording: _{name: "contract.md", text: W},
               cases: [_{name: "case1.md", text: "Case 1: bob was healthy."}],
               model: "stub-model",
               budget: _{preset: "draft", minutes: 5}}.

good_wording("# Tiny contract\n\n## General terms\n\nBe nice.\n\n## Happiness section\n\nA person is happy if healthy.\n").

hook_setup(Hook) :-
    tmp_file(cajobs, Tmp),
    setenv('LE_CONTRACT_JOBS_DIR', Tmp),
    retractall(le_contract_assistant:ca_llm_hook(_)),
    assertz(le_contract_assistant:ca_llm_hook(Hook)).

hook_cleanup :-
    retractall(le_contract_assistant:ca_llm_hook(_)),
    unsetenv('LE_CONTRACT_JOBS_DIR').

% -------------------------------- unit tests ---------------------------------

:- begin_tests(contract_assistant_units).

test(segment_markdown_headings) :-
    segment_markdown("intro\n# One\naaa\n## Two\nbbb\nccc\n# Three\n", Sections),
    maplist([S, T]>>get_dict(title, S, T), Sections, Titles),
    assertion(Titles == ["One", "Two", "Three"]),
    Sections = [S1, S2, _],
    get_dict(start_line, S1, SL1), assertion(SL1 =:= 2),
    get_dict(end_line, S1, EL1), assertion(EL1 =:= 3),   % flat segmentation: ends at the next heading
    get_dict(start_line, S2, SL2), assertion(SL2 =:= 4).

test(segment_markdown_no_headings) :-
    segment_markdown("just\ntext\n", Sections),
    assertion(Sections = [_]),
    Sections = [S],
    get_dict(title, S, T), assertion(T == "document").

test(extract_le_code_fenced) :-
    extract_le_code("blah\n```le\nthe code.\n```\ntrailing", Code),
    assertion(Code == "the code.\n").

test(extract_le_code_unfenced) :-
    extract_le_code("no fences here", Code),
    assertion(Code == "no fences here").

test(verify_le_text_counts) :-
    good_program(P),
    verify_le_text(P, V),
    assertion(V.errors =:= 0),
    assertion(V.tests_passed =:= 1),
    assertion(V.tests_failed =:= 0).

% Garbage input must not throw; it comes back as a scored dict with no
% passing tests (the LE parser is lenient, so it may only warn).
test(verify_le_text_survives_garbage) :-
    verify_le_text("this is not even close to LE {{{", V),
    assertion(is_dict(V)),
    assertion(V.tests_passed =:= 0).

:- end_tests(contract_assistant_units).

% ------------------------------ pipeline tests -------------------------------

:- begin_tests(contract_assistant_pipeline).

test(happy_path_produces_result,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    assertion(Result.winner =:= 1),
    Scores = Result.scores,
    Scores = [Score],
    assertion(Score.tests_passed =:= 1),
    assertion(Score.errors =:= 0),
    Ledger = Result.ledger,
    assertion(sub_string(Ledger, _, _, _, "LEDGER")).

test(repair_loop_fixes_failing_test,
     [setup(hook_setup(user:hook_repair)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    Scores = Result.scores,
    Scores = [Score],
    assertion(Score.tests_failed =:= 0),
    assertion(Score.tests_passed =:= 1).

test(status_and_result_handlers,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    atom_string(JobID, JobStr),
    handle_contract_status(_{job: JobStr, since: 0}, Status),
    assertion(Status.status == "finished"),
    assertion(Status.log \== []),
    handle_contract_result(_{job: JobStr}, Result),
    good_program(P),
    assertion(Result.le == P),
    !.

test(unknown_job_is_reported) :-
    handle_contract_status(_{job: "nope"}, S),
    assertion(S.error == "Unknown job"),
    handle_contract_result(_{job: "nope"}, R),
    assertion(R.error == "Unknown job").

:- end_tests(contract_assistant_pipeline).

% --------------------- feature tests: diff repairs ----------------------------

:- begin_tests(contract_assistant_features).

test(extract_search_replace_two_blocks) :-
    extract_search_replace("x\n<<<<<<< SEARCH\nfoo\n=======\nbar\n>>>>>>> REPLACE\nmid\n<<<<<<< SEARCH\na\nb\n=======\nc\n>>>>>>> REPLACE\n", Edits),
    assertion(Edits == [edit("foo", "bar"), edit("a\nb", "c")]).

test(extract_tagged_blocks) :-
    Reply = "text\n```le\nPROGRAM\n```\nmore\n```ledger\nLINES\n```\n",
    extract_tagged_block(Reply, le, P),
    extract_tagged_block(Reply, ledger, L),
    assertion(P == "PROGRAM\n"),
    assertion(L == "LINES\n").

test(parse_stability_line) :-
    parse_stability("blah\nSTABILITY: 83%\nrest", N),
    assertion(N =:= 83).

:- end_tests(contract_assistant_features).

% Hook whose repair answers with a SEARCH/REPLACE edit instead of a full
% program: the edit fixes the wrong expectation of broken_program.
hook_diff(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_diff(architecture, _, "one branch") :- !.
hook_diff(draft(_), _, Reply) :- !, broken_program(P), fence(P, Reply).
hook_diff(repair(_, _), _,
    "<<<<<<< SEARCH\n    who expects answers [\"alice is happy\"].\n=======\n    who expects answers [\"bob is happy\"].\n>>>>>>> REPLACE\n") :- !.
hook_diff(ledger, _, "LEDGER") :- !.
hook_diff(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook for the full feature set: held-out case, one agreeing probe, and a
% paraphrase check reporting 83% stability.
hook_full(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_full(architecture, _, "one branch") :- !.
hook_full(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_full(holdout(_, _), _, Reply) :- !,
    fence("scenario held out case 101 is:\n    carol is healthy.\n    who expects answers [\"carol is happy\"].\n", Reply).
hook_full(probes, _, Reply) :- !,
    fence("scenario probe one boundary is:\n    dave is healthy.\n    who expects answers [\"dave is happy\"].\n", Reply).
hook_full(paraphrase, _, "the same tiny contract, reworded") :- !.
hook_full(vocabulary_paraphrase, _, "*a person* is happy. % from paraphrase") :- !.
hook_full(paraphrase_compare, _, "STABILITY: 83%\nMissing from B: none\n") :- !.
hook_full(ledger, _, "LEDGER") :- !.
hook_full(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook producing one DISAGREEING probe, with adjudication repairs disabled:
% the probes must be reverted and reported as open disagreements.
hook_disagree(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_disagree(architecture, _, "one branch") :- !.
hook_disagree(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_disagree(probes, _, Reply) :- !,
    fence("scenario probe one wrong is:\n    erin is healthy.\n    who expects answers [].\n", Reply).
hook_disagree(ledger, _, "LEDGER") :- !.
hook_disagree(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

two_case_config(Features, Config) :-
    good_wording(W),
    Config = _{wording: _{name: "contract.md", text: W},
               cases: [_{name: "case1.md", text: "Case 1: bob was healthy."},
                       _{name: "case2.md", text: "Case 2: carol was healthy."}],
               model: "stub-model",
               budget: _{preset: "draft", minutes: 5},
               features: Features}.

:- begin_tests(contract_assistant_feature_pipeline).

test(diff_repair_applies_edit,
     [setup(hook_setup(user:hook_diff)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    Scores = Result.scores, Scores = [Score],
    assertion(Score.tests_passed =:= 1),
    assertion(Score.tests_failed =:= 0).

test(holdout_probe_and_paraphrase,
     [setup(hook_setup(user:hook_full)), cleanup(hook_cleanup)]) :-
    two_case_config(_{probes: 1, paraphrase: true, holdout: "auto"}, Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    % held-out case scored blind and kept in the program
    Scores = Result.scores, Scores = [Score],
    assertion(Score.holdout_passed =:= 1),
    assertion(Score.holdout_failed =:= 0),
    LE = Result.le,
    assertion(sub_string(LE, _, _, _, "held out case 101")),
    % the agreeing probe stays as a regression scenario
    Interrogation = Result.interrogation,
    assertion(Interrogation.enabled == true),
    assertion(Interrogation.agreed =:= 1),
    assertion(Interrogation.disagreed =:= 0),
    assertion(sub_string(LE, _, _, _, "probe one boundary")),
    % paraphrase stability parsed from the judge's report
    Paraphrase = Result.paraphrase,
    assertion(Paraphrase.enabled == true),
    assertion(Paraphrase.stability =:= 83).

test(disagreeing_probe_is_reverted_and_reported,
     [setup(hook_setup(user:hook_disagree)), cleanup(hook_cleanup)]) :-
    start_config(Config0),
    Config = Config0.put(features, _{probes: 1, interrogation_repair: false}),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    Interrogation = Result.interrogation,
    assertion(Interrogation.disagreed =:= 1),
    Open = Interrogation.open,
    assertion(Open \== []),
    % the probes were NOT kept: the delivered program is the clean winner
    good_program(P),
    assertion(Result.le == P).

:- end_tests(contract_assistant_feature_pipeline).

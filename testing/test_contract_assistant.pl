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

% Models often emit a small preamble fence before the real program: the
% largest fence must win, and an explicit ```le tag must win over size.
test(extract_le_code_largest_fence) :-
    extract_le_code("intro\n```\n% short header comment\n```\nmiddle\n```\nthe much much much longer program body.\n```\n", Code),
    assertion(Code == "the much much much longer program body.\n").

test(extract_le_code_le_tag_wins) :-
    extract_le_code("```\nthe much much much longer other block here.\n```\n```le\nshort program.\n```\n", Code),
    assertion(Code == "short program.\n").

% A comments-only "program" must be flagged as an error, not score clean.
test(verify_le_text_flags_empty_program) :-
    verify_le_text("% just a header comment\n% and nothing else\n", V),
    assertion(V.errors >= 1),
    assertion((member(I, V.issues), get_dict(type, I, "empty_program"))).

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

test(parse_stability_bold_and_spaced) :-
    parse_stability("**STABILITY: 38 %**", N),
    assertion(N =:= 38).

% Policy wordings often start sections with a bare title line (no markdown
% heading), listing the titles in an initial TOC bullet list. The slicer must
% find such sections — with apostrophe-tolerant matching — and stop them at
% the next TOC title or level-1 heading.
test(target_slice_from_toc_titles) :-
    Text = "Guide\n\n- General terms\n- Employers’ liability\n- Property\n\nGeneral terms\n\ngeneral stuff here\n\nEmployers’ liability\n\nEL CONTENT LINE\n\n# Unrelated heading section\n\nUNRELATED CONTENT\n\nProperty\n\nPROPERTY CONTENT\n",
    segment_markdown(Text, Secs),
    le_contract_assistant:target_slice(Text, Secs, "Employers' liability", toc_test_job, Slice),
    assertion(sub_string(Slice, _, _, _, "EL CONTENT LINE")),
    assertion(sub_string(Slice, _, _, _, "general stuff here")),
    assertion(\+ sub_string(Slice, _, _, _, "UNRELATED CONTENT")),
    assertion(\+ sub_string(Slice, _, _, _, "PROPERTY CONTENT")).

% An unapplied SEARCH/REPLACE block (even inside a fence) must never become
% the program text.
test(unapplied_edit_block_never_becomes_the_program) :-
    Config = _{features: _{diff_repairs: true}},
    Reply = "```\n<<<<<<< SEARCH\ndoes not exist in the program\n=======\nreplacement\n>>>>>>> REPLACE\n```\n",
    le_contract_assistant:apply_repair_reply(Config, Reply, "the original program", NewText, _How),
    assertion(NewText == "the original program").

% A reply that elides sections ("% ... (all rules and templates)") must never
% replace the program: the previous iteration is kept.
test(elided_program_never_replaces_the_text) :-
    Config = _{features: _{diff_repairs: true}},
    Reply = "```le\n% ... (all rules and templates)\n\nscenario case1 is:\n    the claim occurs on 2026-02-12.\n```\n",
    le_contract_assistant:apply_repair_reply(Config, Reply, "the original program", NewText, How),
    assertion(NewText == "the original program"),
    assertion(sub_string(How, _, _, _, "elided")).

% A scenarios-only program (rules and templates elided) must be flagged as an
% error even though it has (failing) test expectations.
test(scenarios_only_program_is_an_error) :-
    verify_le_text("% ... elided\n\nscenario one is:\n    bob is healthy.\n    who expects answers [].\n", V),
    assertion(V.errors >= 1),
    assertion((member(I, V.issues), get_dict(type, I, "empty_program"))).

% Asterisked variables outside the templates section are always a mistake and
% must be reported as an error (arithmetic "X * Y" is not confused for one).
test(asterisks_outside_templates_flagged) :-
    verify_le_text("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base t includes:\n\nfluffy is happy.\n\nscenario one is:\n    *the claim* is happy.\n", V),
    assertion((member(I, V.issues), get_dict(type, I, "asterisks_outside_templates"))).

test(arithmetic_star_is_not_flagged) :-
    good_program(P),
    string_concat(P, "\nan amount X is the answer if X is equal to 2 * 3.\n", _),
    % simpler: scan directly
    assertion(\+ le_contract_assistant:asterisks_outside_templates(
        "the templates are:\n    *a person* is happy.\nthe knowledge base t includes:\nthe result R is ok if R is equal to 2 * 3.\n", _)).

% 3/6 tests passing must beat 0/2: net evidence, not raw failure counts.
test(rank_prefers_net_test_evidence) :-
    S1 = _{errors: 0, warnings: 3, tests_passed: 3, tests_failed: 3, test_details: [], summary: "b1"},
    S2 = _{errors: 0, warnings: 2, tests_passed: 0, tests_failed: 2, test_details: [], summary: "b2"},
    le_contract_assistant:select_winner(job, [branch(1, "aaa", S1), branch(2, "bbb", S2)], Winner),
    Winner = branch(WIdx, _, _),
    assertion(WIdx =:= 1).

% A 43-error program passing 16/18 tests must beat a clean-verifying program
% with NO scenarios at all (which demonstrates nothing).
test(rank_prefers_tested_over_untested_clean) :-
    S1 = _{errors: 43, warnings: 24, tests_passed: 16, tests_failed: 2, test_details: [], summary: "tested"},
    S2 = _{errors: 0, warnings: 0, tests_passed: 0, tests_failed: 0, test_details: [], summary: "untested"},
    le_contract_assistant:select_winner(job, [branch(1, "aaa", S1), branch(2, "bbb", S2)], Winner),
    Winner = branch(WIdx, _, _),
    assertion(WIdx =:= 1).

test(transient_errors_classified) :-
    assertion(le_contract_assistant:transient_llm_error(error(llm_api_error(503, x), c))),
    assertion(le_contract_assistant:transient_llm_error(error(llm_api_error(429, x), c))),
    assertion(\+ le_contract_assistant:transient_llm_error(error(llm_api_error(401, x), c))),
    assertion(le_contract_assistant:transient_llm_error(error(socket_error(a, b), c))),
    % A hung call (killed by the 15-min wall limit) and a socket inactivity
    % timeout are retried like any provider hiccup.
    assertion(le_contract_assistant:transient_llm_error(time_limit_exceeded)),
    assertion(le_contract_assistant:transient_llm_error(error(timeout_error(read, s), c))).

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

% Hook whose ledger call returns empty content (reasoning models can exhaust
% their output budget before emitting text): the result must explain that
% instead of carrying a blank ledger.
hook_empty_ledger(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_empty_ledger(architecture, _, "one branch") :- !.
hook_empty_ledger(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_empty_ledger(ledger, _, "  \n ") :- !.
hook_empty_ledger(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook whose draft never becomes a working program: with the repair budget at
% zero the winner keeps its errors, so the ledger must be skipped (the hook
% has no ledger clause: calling it would throw).
hook_broken(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_broken(architecture, _, "one branch") :- !.
hook_broken(draft(_), _, "```\n% only a comment, no program\n```\n") :- !.
hook_broken(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook whose repair calls always die (e.g. reasoning truncation after all
% retries): the branch must keep its best iteration instead of aborting.
hook_repair_dies(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_repair_dies(architecture, _, "one branch") :- !.
hook_repair_dies(draft(_), _, Reply) :- !, broken_program(P), fence(P, Reply).
hook_repair_dies(repair(_, _), _, _) :- !,
    throw(error(contract_assistant_error(llm_truncated(repair, stub)), _)).
hook_repair_dies(ledger, _, "LEDGER") :- !.
hook_repair_dies(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook whose probe generation dies: interrogation must degrade to a report
% note, never fail the job.
hook_probes_die(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_probes_die(architecture, _, "one branch") :- !.
hook_probes_die(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_probes_die(probes, _, _) :- !,
    throw(error(contract_assistant_error(llm_truncated(probes, stub)), _)).
hook_probes_die(ledger, _, "LEDGER") :- !.
hook_probes_die(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

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

test(ledger_skipped_when_winner_is_broken,
     [setup(hook_setup(user:hook_broken)), cleanup(hook_cleanup)]) :-
    good_wording(W),
    Config = _{wording: _{name: "contract.md", text: W},
               cases: [_{name: "case1.md", text: "Case 1."}],
               model: "stub-model",
               budget: _{preset: "draft", minutes: 5, repairs: 0}},
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    Ledger = Result.ledger,
    assertion(sub_string(Ledger, _, _, _, "skipped")),
    Scores = Result.scores, Scores = [Score],
    assertion(Score.errors >= 1).

test(status_reports_config_and_elapsed,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    atom_string(JobID, JobStr),
    handle_contract_status(_{job: JobStr, since: 0}, Status),
    C = Status.config,
    assertion(C.model == "stub-model"),
    assertion(C.k =:= 1),
    E = Status.elapsed,
    assertion(number(E)),
    !.

test(empty_ledger_reply_is_explained,
     [setup(hook_setup(user:hook_empty_ledger)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    Ledger = Result.ledger,
    assertion(sub_string(Ledger, _, _, _, "empty ledger reply")).

% A repair call dying (truncation after retries) must not abort the branch:
% the best iteration (here the broken-but-tested draft) is kept, and the job
% finishes with a result.
test(dead_repair_call_keeps_best_iteration,
     [setup(hook_setup(user:hook_repair_dies)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    broken_program(P),
    assertion(Result.le == P).

% Probe generation dying must degrade interrogation to a report note — the
% winner (16/18-style hard-won program) is delivered untouched.
test(dead_probe_generation_never_kills_the_job,
     [setup(hook_setup(user:hook_probes_die)), cleanup(hook_cleanup)]) :-
    start_config(Config0),
    Config = Config0.put(features, _{probes: 2}),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    Interrogation = Result.interrogation,
    Aborted = Interrogation.aborted,
    assertion(sub_string(Aborted, _, _, _, "llm_truncated")).

% The elapsed clock freezes when the job reaches a terminal state.
test(elapsed_stops_at_job_end,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:job_config_summary(JobID, _, E1),
    sleep(1.2),
    le_contract_assistant:job_config_summary(JobID, _, E2),
    assertion(E1 =:= E2).

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

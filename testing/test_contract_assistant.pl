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
    assertion(sub_string(Ledger, _, _, _, "LEDGER")),
    % ... followed by the deterministic provenance block.
    assertion(sub_string(Ledger, _, _, _, "## Technicalities")),
    assertion(sub_string(Ledger, _, _, _, "stub-model")),
    assertion(sub_string(Ledger, _, _, _, "branch 1")),
    assertion(sub_string(Ledger, _, _, _, "winner")),
    assertion(sub_string(Ledger, _, _, _, "Delivered program")).

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

% A provider that refuses the temperature parameter (400 naming it) until the
% assistant stops sending it. Counts its calls, so the test can prove the same
% model was simply called again.
:- dynamic temp_calls/1.

raw_hook_refuses_temperature(_Model, _Messages, Opts, Reply) :-
    ( retract(temp_calls(N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(temp_calls(N)),
    (   memberchk(temperature(_), Opts)
    ->  throw(error(llm_api_error(400,
            "{\"error\":{\"message\":\"Unsupported value: 'temperature' does not support 0.05 with this model. Only the default (1) is supported.\",\"param\":\"temperature\"}}"), c))
    ;   Reply = "the answer"
    ).

:- begin_tests(contract_assistant_features).

test(extract_search_replace_two_blocks) :-
    extract_search_replace("x\n<<<<<<< SEARCH\nfoo\n=======\nbar\n>>>>>>> REPLACE\nmid\n<<<<<<< SEARCH\na\nb\n=======\nc\n>>>>>>> REPLACE\n", Edits),
    assertion(Edits == [edit("foo", "bar"), edit("a\nb", "c")]).

% A reply that runs several edits together under ONE '<<<<<<< SEARCH' header
% (a real GLM-5.2 failure mode). Pairing every separator with every terminator
% used to yield N*(N+1)/2 edits, each spanning most of the reply — enough to
% blow the 1 Gb stack inside findall/3 and kill a 30-minute job.
test(extract_search_replace_runaway_is_linear) :-
    numlist(1, 300, Ns),
    findall(S, ( member(I, Ns),
                 format(string(S), "old text ~w\n=======\nnew text ~w\n>>>>>>> REPLACE\n", [I, I]) ),
            Parts),
    atomics_to_string(["<<<<<<< SEARCH\n"|Parts], Reply),
    extract_search_replace(Reply, Edits, Malformed),
    assertion(Edits == [edit("old text 1", "new text 1")]),
    assertion(Malformed =:= 299).

% A block the model never terminated must not swallow the well-formed one
% that follows it.
test(extract_search_replace_resyncs_after_malformed) :-
    extract_search_replace("<<<<<<< SEARCH\nlost\n<<<<<<< SEARCH\nfoo\n=======\nbar\n>>>>>>> REPLACE\n", Edits),
    assertion(Edits == [edit("foo", "bar")]).

% CRLF replies: without normalisation every SEARCH text ends in a stray '\r'
% and nothing ever matches the (LF) program.
test(extract_search_replace_crlf) :-
    extract_search_replace("<<<<<<< SEARCH\r\nfoo\r\n=======\r\nbar\r\n>>>>>>> REPLACE\r\n", Edits),
    assertion(Edits == [edit("foo", "bar")]).

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

% Providers that only accept their default temperature answer 400/422 naming
% the parameter; anything else about a 400 must stay a real error.
% Scenarios are fact patterns: with no case supplied the drafting prompt must
% forbid inventing them, and the user's instructions are the only way to ask.
test(scenario_policy_forbids_invention_when_no_case_is_supplied) :-
    le_contract_assistant:scenarios_block(_{existing: none}, 0, B),
    assertion(sub_string(B, _, _, _, "NO case was supplied")),
    assertion(sub_string(B, _, _, _, "write NO scenarios")),
    assertion(sub_string(B, _, _, _, "Do NOT invent extra scenarios")),
    assertion(sub_string(B, _, _, _, "ADDITIONAL INSTRUCTIONS")).

test(scenario_policy_counts_the_supplied_cases) :-
    le_contract_assistant:scenarios_block(_{existing: none}, 3, B),
    assertion(sub_string(B, _, _, _, "one scenario per supplied case (3 supplied)")).

test(instructions_block_is_empty_without_instructions) :-
    le_contract_assistant:instructions_block(_{instructions: none}, B),
    assertion(B == "").

test(instructions_reach_the_prompt) :-
    le_contract_assistant:instructions_block(_{instructions: "Please add boundary scenarios."}, B),
    assertion(sub_string(B, _, _, _, "ADDITIONAL INSTRUCTIONS FROM THE USER")),
    assertion(sub_string(B, _, _, _, "Please add boundary scenarios.")),
    le_contract_assistant:build_messages('stage2_draft',
        [existing-"", instructions-B, scenarios-"", materials-"M",
         vocabulary-"V", architecture-"A"],
        [_{role: system, content: Sys}|_]),
    assertion(sub_string(Sys, _, _, _, "Please add boundary scenarios.")).

% A target names a section AND its subsections — not the section up to its own
% first subsection, and not the rest of the document.
target_doc("# Guide\n\n## General terms\n\ngeneral stuff\n\n# Employers liability\n\nEL INTRO\n\n## What is covered\n\nEL COVERED\n\n# Property definitions\n\nPROPERTY STUFF\n\n# Motor\n\nMOTOR STUFF\n").

test(plain_target_takes_the_section_with_its_subsections) :-
    target_doc(D), segment_markdown(D, Secs),
    le_contract_assistant:target_slice(D, Secs, "Employers liability", tjob, Slice),
    assertion(sub_string(Slice, _, _, _, "EL INTRO")),
    assertion(sub_string(Slice, _, _, _, "EL COVERED")),        % subsection kept
    assertion(sub_string(Slice, _, _, _, "general stuff")),     % general terms added
    assertion(\+ sub_string(Slice, _, _, _, "PROPERTY STUFF")), % next section not swallowed
    assertion(\+ sub_string(Slice, _, _, _, "MOTOR STUFF")).

test(range_target_is_exclusive_by_default) :-
    target_doc(D), segment_markdown(D, Secs),
    le_contract_assistant:target_slice(D, Secs,
        "from Employers liability until Property definitions", tjob, Slice),
    assertion(sub_string(Slice, _, _, _, "EL COVERED")),
    assertion(\+ sub_string(Slice, _, _, _, "PROPERTY STUFF")),
    assertion(\+ sub_string(Slice, _, _, _, "general stuff")).  % a range is taken literally

test(range_target_can_be_inclusive) :-
    target_doc(D), segment_markdown(D, Secs),
    le_contract_assistant:target_slice(D, Secs,
        "from Employers liability until Property definitions (inclusive)", tjob, Slice),
    assertion(sub_string(Slice, _, _, _, "PROPERTY STUFF")),
    assertion(\+ sub_string(Slice, _, _, _, "MOTOR STUFF")).

test(target_expressions_are_parsed) :-
    le_contract_assistant:parse_target("from A until B", S1),
    assertion(S1 == range("A", "B", false)),
    le_contract_assistant:parse_target("from A to B (inclusive)", S2),
    assertion(S2 == range("A", "B", true)),
    % a title that merely contains "to" is not a range
    le_contract_assistant:parse_target("Guide to sections", S3),
    assertion(S3 == section("Guide to sections")).

test(temperature_rejection_classified) :-
    OpenAI = "{\"error\":{\"message\":\"Unsupported value: 'temperature' does not support 0.05 with this model. Only the default (1) is supported.\",\"param\":\"temperature\"}}",
    assertion(le_contract_assistant:temperature_rejected(error(llm_api_error(400, OpenAI), c))),
    assertion(le_contract_assistant:temperature_rejected(
        error(llm_api_error(422, "temperature is not supported with this model"), c))),
    assertion(\+ le_contract_assistant:temperature_rejected(
        error(llm_api_error(400, "invalid api key"), c))),
    assertion(\+ le_contract_assistant:temperature_rejected(
        error(llm_api_error(503, "temperature"), c))),
    % ... and it is not mistaken for a transient failure worth plain retries
    assertion(\+ le_contract_assistant:transient_llm_error(error(llm_api_error(400, OpenAI), c))).

% Once a provider has refused it, every later call of the job goes out without
% a temperature — the samples then vary by the model's own sampling.
test(no_temperature_tuning_strips_the_option,
     [cleanup(retractall(le_contract_assistant:ca_tune(temp_job, _)))]) :-
    Config = _{max_tokens: 4096, reasoning: default},
    le_contract_assistant:stage_options(temp_job, Config, "KEY",
                                        [temperature(0.4)], Opts0),
    assertion(memberchk(temperature(0.4), Opts0)),
    assertz(le_contract_assistant:ca_tune(temp_job, no_temperature)),
    le_contract_assistant:stage_options(temp_job, Config, "KEY",
                                        [temperature(0.4)], Opts1),
    assertion(\+ memberchk(temperature(_), Opts1)),
    assertion(memberchk(max_tokens(4096), Opts1)),
    assertion(memberchk(api_key("KEY"), Opts1)),
    % the log stops promising a temperature it no longer sends
    le_contract_assistant:sampling_note(temp_job, 0.25, Note),
    assertion(sub_string(Note, _, _, _, "default sampling")).

% The whole ladder, offline: the first call carries a temperature and is
% refused; the assistant drops it and calls the SAME model again, which
% answers. Nothing propagates to the caller but the reply.
test(temperature_rejection_is_retried_without_it,
     [setup(( retractall(user:temp_calls(_)),
              retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_refuses_temperature)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(user:temp_calls(_)),
                retractall(le_contract_assistant:ca_tune(temp_retry_job, _)),
                retractall(le_contract_assistant:ca_log(temp_retry_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(temp_retry_job, _)) ))]) :-
    get_time(Now), Deadline is Now + 600,
    Config = _{deadline: Deadline, max_tokens: 4096, max_tokens_cap: 4096,
               reasoning: default},
    le_contract_assistant:llm_try(temp_retry_job, Config, vocabulary, 'a-model',
                                  [_{role: user, content: "hi"}],
                                  [temperature(0.05), max_tokens(4096)], 1, Reply),
    assertion(Reply == "the answer"),
    user:temp_calls(Calls),
    assertion(Calls =:= 2),                                   % refused, then retried
    assertion(le_contract_assistant:ca_tune(temp_retry_job, no_temperature)).

test(transient_errors_classified) :-
    assertion(le_contract_assistant:transient_llm_error(error(llm_api_error(503, x), c))),
    assertion(le_contract_assistant:transient_llm_error(error(llm_api_error(429, x), c))),
    assertion(\+ le_contract_assistant:transient_llm_error(error(llm_api_error(401, x), c))),
    assertion(le_contract_assistant:transient_llm_error(error(socket_error(a, b), c))),
    % A hung call (killed by the 15-min wall limit), a socket inactivity
    % timeout, and a dropped TLS connection are retried like any provider
    % hiccup.
    assertion(le_contract_assistant:transient_llm_error(time_limit_exceeded)),
    assertion(le_contract_assistant:transient_llm_error(error(timeout_error(read, s), c))),
    assertion(le_contract_assistant:transient_llm_error(error(llm_http_error(error(ssl_error(x, y, z, w), ctx)), c))).

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

% Stateful hook proving the progress-aware repair loop: the draft fails two
% tests; repair 1 fixes one (improvement -> streak resets); repairs 2 and 3
% return the same program (no improvement) until the patience of 2 stops the
% loop. With the old fixed count of 2 the third repair call never happened.
:- dynamic progress_repair_calls/1.
progress_prog_fail2("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"wrong one\"].\n\nscenario two is:\n    carol is healthy.\n    who expects answers [\"wrong two\"].\n\nquery who is:\n    which person is happy.\n").
progress_prog_fail1("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"bob is happy\"].\n\nscenario two is:\n    carol is healthy.\n    who expects answers [\"wrong two\"].\n\nquery who is:\n    which person is happy.\n").

hook_progress(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_progress(architecture, _, "one branch") :- !.
hook_progress(draft(_), _, Reply) :- !, progress_prog_fail2(P), fence(P, Reply).
hook_progress(repair(_, _), _, Reply) :- !,
    retract(progress_repair_calls(N)), N1 is N + 1, assertz(progress_repair_calls(N1)),
    progress_prog_fail1(P), fence(P, Reply).
hook_progress(ledger, _, "LEDGER") :- !.
hook_progress(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook where branch 1's draft dies but branch 2's succeeds: one dead branch
% must not kill the job.
hook_branch1_dies(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_branch1_dies(architecture, _, "a branch") :- !.
hook_branch1_dies(draft(1), _, _) :- !,
    throw(error(contract_assistant_error(llm_truncated(draft, stub)), _)).
hook_branch1_dies(draft(2), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_branch1_dies(ledger, _, "LEDGER") :- !.
hook_branch1_dies(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook where EVERY branch's draft dies (e.g. the provider times out on a big
% wording). The job must end as an error, not hang: with two dead branches the
% old filter kept one `failed(_)` term, select_winner/3 had nothing to rank, and
% the pipeline failed silently with the job still marked "running".
hook_all_branches_die(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_all_branches_die(architecture, _, "a branch") :- !.
hook_all_branches_die(draft(_), _, _) :- !,
    throw(error(contract_assistant_error(llm_failed(draft, "read timeout")), _)).
hook_all_branches_die(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).


% A program that is RIGHT but not CLEAN: same as good_program plus a template
% nothing uses (the verifier's unused_template warning). The repair loop stops
% at "right"; the polish rounds are what remove the warning.
warnish_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n    *a cost* is a cost; undefined.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"bob is happy\"].\n\nquery who is:\n    which person is happy.\n").

:- dynamic polish_calls/1.
bump_polish :- ( retract(polish_calls(N)) -> true ; N = 0 ), N1 is N + 1, assertz(polish_calls(N1)).

% Polish that works: the dead template is dropped, nothing else changes.
hook_polish(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_polish(architecture, _, "one branch") :- !.
hook_polish(draft(_), _, Reply) :- !, warnish_program(P), fence(P, Reply).
hook_polish(polish(_, _), _, Reply) :- !, bump_polish, good_program(P), fence(P, Reply).
hook_polish(ledger, _, "LEDGER") :- !.
hook_polish(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Polish that would break a passing test: it must be thrown away.
hook_polish_breaks(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_polish_breaks(architecture, _, "one branch") :- !.
hook_polish_breaks(draft(_), _, Reply) :- !, warnish_program(P), fence(P, Reply).
hook_polish_breaks(polish(_, _), _, Reply) :- !, bump_polish, broken_program(P), fence(P, Reply).
hook_polish_breaks(ledger, _, "LEDGER") :- !.
hook_polish_breaks(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% A program with BOTH a stubborn failing expectation and a dead template.
stubborn_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n    *a cost* is a cost; undefined.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"alice is happy\"].\n\nquery who is:\n    which person is happy.\n").

% Same, with the dead template gone (what the polish round returns).
stubborn_clean_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy if the person is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"alice is happy\"].\n\nquery who is:\n    which person is happy.\n").

hook_polish_stubborn(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_polish_stubborn(architecture, _, "one branch") :- !.
hook_polish_stubborn(draft(_), _, Reply) :- !, stubborn_program(P), fence(P, Reply).
hook_polish_stubborn(polish(_, _), _, Reply) :- !, bump_polish, stubborn_clean_program(P), fence(P, Reply).
hook_polish_stubborn(ledger, _, "LEDGER") :- !.
hook_polish_stubborn(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Hook producing one DISAGREEING probe, with adjudication repairs disabled:
% the probes must be reverted and reported as open disagreements.
hook_disagree(vocabulary, _, "*a person* is happy. % vocabulary") :- !.
hook_disagree(architecture, _, "one branch") :- !.
hook_disagree(draft(_), _, Reply) :- !, good_program(P), fence(P, Reply).
hook_disagree(probes, _, Reply) :- !,
    fence("scenario probe one wrong is:\n    erin is healthy.\n    who expects answers [].\n", Reply).
hook_disagree(ledger, _, "LEDGER") :- !.
hook_disagree(Purpose, _, _) :- throw(unexpected_llm_purpose(Purpose)).

% Existing user-supplied LE code: every prompt that writes or repairs the
% program must carry it, and the delivered program must still contain it. The
% hook records which purposes saw the binding block.
:- dynamic saw_existing/1.

existing_fixture("the templates are:\n    *a person* is healthy.\n\nscenario one is:\n    bob is healthy.\n    who expects answers [\"bob is happy\"].\n").

hook_existing(Purpose, Messages, Reply) :-
    ( Messages = [_{role: system, content: Sys}|_],
      sub_string(Sys, _, _, _, "EXISTING LOGICAL ENGLISH CODE"),
      sub_string(Sys, _, _, _, "bob is healthy")
    -> assertz(saw_existing(Purpose))
    ;  true ),
    hook_good(Purpose, Messages, Reply).

existing_config(Config) :-
    start_config(Config0),
    existing_fixture(E),
    Config = Config0.put(existing_code, E).

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

% The repair loop extends beyond the patience count while iterations improve:
% with patience 2, an improving repair resets the streak, so a third repair
% call happens before two consecutive non-improving rounds stop the loop.
test(repair_loop_extends_while_improving,
     [setup(( hook_setup(user:hook_progress),
              retractall(user:progress_repair_calls(_)),
              assertz(user:progress_repair_calls(0)) )),
      cleanup(( hook_cleanup, retractall(user:progress_repair_calls(_)) ))]) :-
    start_config(Config0),
    Config = Config0.put(budget, _{preset: "draft", minutes: 5, repairs: 2}),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    progress_prog_fail1(P),
    assertion(Result.le == P),                    % the improved iteration won
    user:progress_repair_calls(N),
    assertion(N =:= 3),                           % patience 2 alone would stop at 2
    Scores = Result.scores, Scores = [Score],
    assertion(Score.tests_passed =:= 1),
    assertion(Score.tests_failed =:= 1).

% One branch dying (draft truncation after all retries) must not kill the
% job when a sibling branch delivers.
test(dead_branch_does_not_kill_the_job,
     [setup(hook_setup(user:hook_branch1_dies)), cleanup(hook_cleanup)]) :-
    start_config(Config0),
    Config = Config0.put(budget, _{preset: "draft", minutes: 5, w: 2}),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    assertion(Result.winner =:= 2).

% The elapsed clock freezes when the job reaches a terminal state.
test(elapsed_stops_at_job_end,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:job_config_summary(JobID, _, E1),
    sleep(1.2),
    le_contract_assistant:job_config_summary(JobID, _, E2),
    assertion(E1 =:= E2).

% The pasted code reaches the vocabulary, architecture and draft prompts, and
% the delivered program is checked against it (good_program contains the
% fixture's template and scenario lines, so coverage is 100%).
test(existing_code_reaches_the_prompts_and_is_checked,
     [setup(( hook_setup(user:hook_existing), retractall(user:saw_existing(_)) )),
      cleanup(( hook_cleanup, retractall(user:saw_existing(_)) ))]) :-
    existing_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    assertion(user:saw_existing(vocabulary)),
    assertion(user:saw_existing(architecture)),
    assertion(user:saw_existing(draft(1))),
    le_contract_assistant:ca_result(JobID, Result),
    E = Result.existing_code,
    assertion(E.enabled == true),
    assertion(E.lines =:= 5),
    assertion(E.kept =:= 5),
    assertion(E.percent =:= 100),
    % ... and it is echoed by the status poll, so the Run screen can show it
    atom_string(JobID, JobStr),
    handle_contract_status(_{job: JobStr}, Status),
    assertion(Status.config.existing_chars > 0),
    !.

% No existing code: the prompts must not carry the block, and the report says
% the check does not apply.
test(without_existing_code_nothing_is_injected,
     [setup(( hook_setup(user:hook_existing), retractall(user:saw_existing(_)) )),
      cleanup(( hook_cleanup, retractall(user:saw_existing(_)) ))]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(\+ user:saw_existing(_)),
    le_contract_assistant:ca_result(JobID, Result),
    E = Result.existing_code,
    assertion(E.enabled == false).

% A program that dropped one of the user's lines must be reported as such,
% ignoring comments and re-indentation.
test(existing_coverage_counts_missing_lines) :-
    Config = _{existing: "% a comment\nthe templates are:\n    *a person* is healthy.\n    *a person* is rich.\n"},
    le_contract_assistant:existing_coverage(
        Config, "the templates are:\n*a person* is healthy.\n", R),
    assertion(R.lines =:= 3),
    assertion(R.kept =:= 2),
    assertion(R.percent =:= 67),
    assertion(R.missing == ["*a person* is rich."]).

% Blank or whitespace-only input is no input.
test(blank_existing_code_is_none) :-
    le_contract_assistant:existing_code(_{existing_code: "   \n  "}, E1),
    assertion(E1 == none),
    le_contract_assistant:existing_code(_{}, E2),
    assertion(E2 == none),
    le_contract_assistant:existing_code(_{existing_code: "a person is happy."}, E3),
    assertion(E3 == "a person is happy.").

% Every branch dead: the job ends as an error the UI can show, and never stays
% "running" (which is what made a real job poll forever).
test(all_branches_dead_ends_the_job,
     [setup(hook_setup(user:hook_all_branches_die)), cleanup(hook_cleanup)]) :-
    start_config(Config0),
    Config = Config0.put(budget, _{preset: "draft", minutes: 5, w: 2}),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_status(JobID, Status),
    assertion(Status = finished(error(_))),
    Status = finished(error(Msg)),
    assertion(sub_string(Msg, _, _, _, "every branch failed")),
    atom_string(JobID, JobStr),
    handle_contract_status(_{job: JobStr}, S),
    assertion(S.status == "error"),
    !.

% The safety net under it: a pipeline that FAILS (rather than throwing) must
% still end the job. Here the job id has no config, so pipeline_stages/1 fails
% on its very first goal.
test(pipeline_failure_never_leaves_a_job_running,
     [cleanup(( retractall(le_contract_assistant:ca_status(ghost_job, _)),
                retractall(le_contract_assistant:ca_log(ghost_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(ghost_job, _)),
                retractall(le_contract_assistant:ca_ended(ghost_job, _)) ))]) :-
    asserta(le_contract_assistant:ca_status(ghost_job, running)),
    le_contract_assistant:run_contract_pipeline(ghost_job),
    le_contract_assistant:ca_status(ghost_job, Status),
    assertion(Status = finished(error(_))),
    Status = finished(error(Msg)),
    assertion(sub_string(Msg, _, _, _, "bug in the assistant")).

% The socket timeout the assistant asks for must be generous enough for a whole
% wording in and a whole program out — and the wall-clock guard looser still,
% or it fires first and hides the real error.
test(long_generations_get_a_long_timeout) :-
    le_contract_assistant:llm_socket_timeout(T),
    le_contract_assistant:llm_wall_limit(W),
    assertion(T >= 900),
    assertion(W > T),
    Config = _{max_tokens: 4096, reasoning: default},
    le_contract_assistant:stage_options(no_job, Config, "KEY", [temperature(0.1)], Opts),
    assertion(memberchk(timeout(T), Opts)).

% Once the program is right, the polish rounds clean the warnings — here the
% dead template goes and the delivered program is the clean one.
test(polish_removes_warnings_once_the_program_is_right,
     [setup(( hook_setup(user:hook_polish), retractall(user:polish_calls(_)) )),
      cleanup(( hook_cleanup, retractall(user:polish_calls(_)) ))]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    good_program(P),
    assertion(Result.le == P),
    user:polish_calls(N), assertion(N >= 1),
    Scores = Result.scores, Scores = [Score],
    assertion(Score.warnings =:= 0),
    assertion(Score.tests_passed =:= 1).

% A polish round that costs a passing test is rejected: the verified program
% survives with its warnings.
test(polish_that_breaks_a_test_is_rejected,
     [setup(( hook_setup(user:hook_polish_breaks), retractall(user:polish_calls(_)) )),
      cleanup(( hook_cleanup, retractall(user:polish_calls(_)) ))]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    le_contract_assistant:ca_result(JobID, Result),
    warnish_program(P),
    assertion(Result.le == P),
    Scores = Result.scores, Scores = [Score],
    assertion(Score.tests_passed =:= 1),
    assertion(Score.tests_failed =:= 0),
    assertion(Score.warnings >= 1).

% A stubborn failing test does not block the clean-up: the repair loop gave up
% on it, but the dead template still goes — and the failing test is never
% offered to the polish round as something to "fix".
test(polish_runs_even_when_a_test_is_still_failing,
     [setup(( hook_setup(user:hook_polish_stubborn), retractall(user:polish_calls(_)) )),
      cleanup(( hook_cleanup, retractall(user:polish_calls(_)) ))]) :-
    start_config(Config0),
    Config = Config0.put(budget, _{preset: "draft", minutes: 5, repairs: 0}),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    user:polish_calls(N), assertion(N >= 1),
    le_contract_assistant:ca_result(JobID, Result),
    stubborn_clean_program(P),
    assertion(Result.le == P).

test(failing_tests_are_not_offered_to_the_polish_round) :-
    broken_program(P),
    verify_le_text(P, V),
    assertion(V.warnings >= 1),                       % the failed test IS a warning
    le_contract_assistant:polishable_warnings(V, N, _),
    assertion(N =:= 0).                               % ... but not a polishable one

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

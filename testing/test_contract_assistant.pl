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

:- dynamic vocab_calls/1.

% Sample 2 fails the way a silent provider fails (after the retry ladder has
% given up); the others answer.
hook_flaky_vocabulary(vocabulary, _, Reply) :- !,
    ( retract(user:vocab_calls(N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(user:vocab_calls(N)),
    (   N =:= 2
    ->  throw(error(contract_assistant_error(llm_failed(vocabulary, "provider sent nothing")), _))
    ;   format(string(Reply), "vocabulary sample ~w", [N])
    ).
hook_flaky_vocabulary(vocabulary_merge, _, "merged vocabulary") :- !.
hook_flaky_vocabulary(P, _, _) :- throw(unexpected_llm_purpose(P)).

hook_all_vocabulary_fails(vocabulary, _, _) :- !,
    throw(error(contract_assistant_error(llm_failed(vocabulary, "provider sent nothing")), _)).
hook_all_vocabulary_fails(P, _, _) :- throw(unexpected_llm_purpose(P)).

vocab_config(Config) :-
    get_time(Now), Deadline is Now + 3600,
    Config = _{k: 3, existing: none, deadline: Deadline, minutes: 60,
               max_tokens: 4096, reasoning: default,
               model: "stub-model", judge_model: "stub-model"}.

:- dynamic silent_calls/1.

% A provider that fails once the cheap way (503) and answers on the retry.
% Silence is deliberately NOT used here: it takes the auto-tuning path instead
% of the plain ladder (see silence_switches_the_job_to_minimal_reasoning).
raw_hook_flaky_once(_Model, _Messages, _Opts, Reply) :-
    ( retract(user:silent_calls(N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(user:silent_calls(N)),
    (   N =:= 1
    ->  throw(error(llm_api_error(503, "service unavailable"), context(llm_client, "HTTP request failed")))
    ;   Reply = "the answer"
    ).

:- dynamic silent_until_minimal/1.

% A provider that answers only once the request stops asking for reasoning —
% the shape of the open-weights model that went silent on every call.
raw_hook_silent_until_minimal(_Model, _Messages, Opts, Reply) :-
    ( retract(user:silent_until_minimal(N0)) -> true ; N0 = 0 ),
    N is N0 + 1, assertz(user:silent_until_minimal(N)),
    (   memberchk(reasoning(minimal), Opts)
    ->  Reply = "the answer"
    ;   throw(error(llm_http_error(error(timeout_error(read, s), context(x, y))), context(llm_client, "HTTP request failed")))
    ).

% ... and one that stays silent until the completion budget is cut as well.
raw_hook_silent_until_small_budget(_Model, _Messages, Opts, Reply) :-
    (   memberchk(reasoning(minimal), Opts),
        memberchk(max_tokens(MT), Opts), MT =< 16384
    ->  Reply = "the answer"
    ;   throw(error(llm_http_error(error(timeout_error(read, s), context(x, y))), context(llm_client, "HTTP request failed")))
    ).

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

% ---- uploads: several schedule/case files, structured formats ----------------
% A schedule can be split over several documents, and either a schedule or a
% batch of cases often arrives as .json (or .csv) rather than prose. Both must
% survive ingestion untouched — no converter, no dropped file.

upload_dir(Dir) :-
    tmp_file(casources, Dir), make_directory_path(Dir).

test(uploads_take_several_schedules_and_structured_formats,
     [setup(upload_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    Req = _{wording: _{name: "policy.md", text: "# Tiny\n"},
            schedule: [_{name: "limits.json", text: "{\"limit\": 1000}"},
                       _{name: "elections.md", text: "Elections: none.\n"}],
            cases: [_{name: "claims.json", text: "[{\"claim\": 1}]"},
                    _{name: "case2.md", text: "Case 2.\n"}]},
    le_contract_assistant:save_uploads(Req, Dir, Wording, Schedules, Cases),
    assertion(exists_file(Wording)),
    assertion(Schedules = [_, _]), assertion(Cases = [_, _]),
    forall(member(F, [Wording|Schedules]), assertion(exists_file(F))),
    forall(member(F, Cases), assertion(exists_file(F))),
    % .json is text: kept as it is, never sent through pandoc/pdftotext
    Schedules = [S1|_], Cases = [C1|_],
    assertion(file_name_extension(_, json, S1)),
    assertion(file_name_extension(_, json, C1)),
    read_file_to_string(S1, S1Text, [encoding(utf8)]),
    assertion(S1Text == "{\"limit\": 1000}"),
    % the stored name keeps the user's, so a multi-file header can name it
    file_base_name(S1, S1Base),
    assertion(sub_atom(S1Base, _, _, _, limits)).

% Older clients (and hand-written /leapi calls) send a single schedule dict.
test(uploads_accept_a_single_schedule_dict,
     [setup(upload_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    Req = _{wording: _{name: "policy.md", text: "# Tiny\n"},
            schedule: _{name: "schedule.md", text: "Limit: 1000.\n"}},
    le_contract_assistant:save_uploads(Req, Dir, _, Schedules, Cases),
    assertion(Schedules = [_]), assertion(Cases == []).

% A hostile file name must not escape the job's sources directory.
test(uploads_sanitise_the_file_name,
     [setup(upload_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    Req = _{wording: _{name: "../../etc/passwd.md", text: "# Tiny\n"}},
    le_contract_assistant:save_uploads(Req, Dir, Wording, _, _),
    atomic_list_concat([Dir, '/sources/'], Prefix),
    assertion(atom_concat(Prefix, _, Wording)),
    assertion(\+ sub_atom(Wording, _, _, _, '..')).

% ---- structured cases: an array of claims is an array of CASES ---------------
% A claims file with seventeen claims must become seventeen scenarios, each
% carrying the schedule it names and the expected outcome recorded for it in a
% second file. (Observed: the FEMA run treated claims.json as ONE case and
% expected_outcomes.json as another, then held the second out — the delivered
% program had a single invented scenario.)

json_case_dir(Dir) :-
    tmp_file(cacases, Dir), make_directory_path(Dir).

write_json_file(Dir, Name, Text, Path) :-
    atomic_list_concat([Dir, '/', Name], Path),
    setup_call_cleanup(open(Path, write, S, [encoding(utf8)]),
                       write(S, Text), close(S)).

claims_json("{\"claims\": [
   {\"claimRef\": \"C1\", \"policyRef\": \"P1\", \"facts\": \"water everywhere\"},
   {\"claimRef\": \"C2\", \"policyRef\": \"P2\", \"facts\": \"a small puddle\"},
   {\"claimRef\": \"C3\", \"policyRef\": \"P1\", \"facts\": \"mud\"}]}").

outcomes_json("{\"note\": \"ground truth\", \"outcomes\": [
   {\"claimRef\": \"C1\", \"decision\": \"pay\", \"totalPayable\": 46200},
   {\"claimRef\": \"C2\", \"decision\": \"deny\", \"totalPayable\": 0},
   {\"claimRef\": \"C3\", \"decision\": \"pay\", \"totalPayable\": 1500}]}").

schedules_json("{\"schedules\": [
   {\"policyRef\": \"P1\", \"buildingLimit\": 250000, \"deductible\": 2000},
   {\"policyRef\": \"P2\", \"buildingLimit\": 120000, \"deductible\": 5000}]}").

test(json_case_array_becomes_one_case_each_with_its_schedule_and_outcome,
     [setup(json_case_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    claims_json(CJ), outcomes_json(OJ), schedules_json(SJ),
    write_json_file(Dir, 'claims.json', CJ, Claims),
    write_json_file(Dir, 'expected_outcomes.json', OJ, Outcomes),
    write_json_file(Dir, 'schedules.json', SJ, Scheds),
    le_contract_assistant:case_texts([Claims, Outcomes], [Scheds], Cases),
    assertion(length(Cases, 3)),                       % three claims, not two files
    Cases = [C1, C2, _],
    % the claim and its recorded outcome are ONE case
    assertion(sub_string(C1, _, _, _, "water everywhere")),
    assertion(sub_string(C1, _, _, _, "46200")),
    assertion(sub_string(C1, _, _, _, "claims.json, expected_outcomes.json")),
    % ... carrying the schedule it names, and only that one
    assertion(sub_string(C1, _, _, _, "250000")),
    assertion(\+ sub_string(C1, _, _, _, "120000")),
    assertion(sub_string(C2, _, _, _, "120000")),
    assertion(\+ sub_string(C2, _, _, _, "250000")),
    assertion(sub_string(C1, _, _, _, "belong in this scenario")).

test(a_non_structured_case_file_is_still_one_case,
     [setup(json_case_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    write_json_file(Dir, 'case.md', "Case 1: bob was healthy.", Case),
    % ... and so is JSON that holds no array of records
    write_json_file(Dir, 'meta.json', "{\"policy\": \"P1\", \"note\": \"x\"}", Meta),
    le_contract_assistant:case_texts([Case, Meta], [], Cases),
    assertion(length(Cases, 2)),
    Cases = [C1, _],
    assertion(C1 == "Case 1: bob was healthy.").

% Only DIFFERENT files merge, and only on a field that identifies a record:
% two claims of the same policy must not collapse into one case.
test(records_of_the_same_file_never_merge,
     [setup(json_case_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    claims_json(CJ),
    write_json_file(Dir, 'claims.json', CJ, Claims),
    le_contract_assistant:case_texts([Claims], [], Cases),
    assertion(length(Cases, 3)).

test(holdout_split_holds_out_a_quarter_of_the_cases) :-
    numlist(1, 17, Ns),
    findall(S, ( member(N, Ns), number_string(N, S) ), Cases),
    le_contract_assistant:holdout_split(_{features: _{holdout: auto}}, Cases, Dev, Held),
    length(Dev, NDev), length(Held, NHeld),
    assertion(NDev =:= 13), assertion(NHeld =:= 4),
    % the held-out ones are the last, and the two sets are the whole
    assertion(append(Dev, Held, Cases)),
    % ... and with two cases the split is still one and one
    le_contract_assistant:holdout_split(_{features: _{holdout: auto}}, ["a", "b"], D2, H2),
    assertion(D2 == ["a"]), assertion(H2 == ["b"]).

test(scenario_policy_demands_one_scenario_per_case) :-
    le_contract_assistant:scenarios_block(_{existing: none}, 17, B),
    assertion(sub_string(B, _, _, _, "17 cases were supplied")),
    assertion(sub_string(B, _, _, _, "must contain 17 scenarios")),
    assertion(sub_string(B, _, _, _, "Never merge two cases")).

% How much of the contract the ledger says is missing must be a number in the
% run log, not a discovery the user makes on page nine of the report.
test(ledger_coverage_counts_the_todo_rows) :-
    L = "# Coverage Ledger\n\n| Clause | Status | Notes |\n|--------|--------|-------|\n| I.A | **TODO** | not encoded |\n| I.B | procedural — skipped | no decision content |\n| I.C | encoded | rule one |\n| II.A | **TODO** | not encoded |\n\n## Known simplifications\n\n% TODO: II.A\n",
    le_contract_assistant:ledger_coverage(L, Todo, Rows),
    assertion(Rows =:= 4),        % header and |---| rule excluded
    assertion(Todo =:= 2).        % the prose TODO line is not a table row

% ---- mechanical de-duplication -----------------------------------------------
% Models fed a JSON array of similar claims write a template per claim (GLM-5.2
% produced pages of them). A repetition cannot change what the program decides,
% so it goes without an LLM call and without a verification gate — but only a
% real repetition: rules that share a head, and identical facts in DIFFERENT
% scenarios, are meant.

dup_program("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.
    *a person* is happy.
    *a claim* involves a scenario tested of *a description*.
    *a claim* involves a scenario tested of *a description*.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

a person is happy
    if the person is healthy.

bob is healthy.
bob is healthy.

query who is:
    which person is happy.
").

test(duplicate_templates_rules_and_facts_are_removed) :-
    dup_program(P),
    le_contract_assistant:dedup_program(_{existing: none}, P, Text, Report),
    assertion(Report.templates =:= 2),
    assertion(Report.rules =:= 2),          % the repeated rule and the repeated fact
    % one of each survives, in place
    once(sub_string(Text, _, _, _, "*a person* is happy.")),
    aggregate_all(count, sub_string(Text, _, _, _, "involves a scenario tested"), NT),
    assertion(NT =:= 1),
    aggregate_all(count, sub_string(Text, _, _, _, "bob is healthy."), NF),
    assertion(NF =:= 1),
    aggregate_all(count, sub_string(Text, _, _, _, "if the person is healthy."), NR),
    assertion(NR =:= 1).

% Two rules for one predicate share a head line, and two scenarios legitimately
% state the same fact: neither is a duplicate.
test(rules_sharing_a_head_and_per_scenario_facts_are_kept) :-
    P = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n    *a person* is rich.\n\nthe knowledge base tiny includes:\n\na person is happy\n    if the person is healthy.\n\na person is happy\n    if the person is rich.\n\nscenario one is:\n    bob is healthy.\n\nscenario two is:\n    bob is healthy.\n\nquery who is:\n    which person is happy.\n",
    le_contract_assistant:dedup_program(_{existing: none}, P, Text, Report),
    assertion(Report.deleted =:= 0),
    assertion(Text == P).

% ---- a program with no rules is an ERROR, not a clean program ----------------
% The FEMA run delivered a program whose knowledge base header read
% "the knowledge base NFIP is:" instead of "... includes:". LE reported the
% whole discarded knowledge base as ONE unknown_section, so the branch scored
% "1 error" and won — with no rule in it and 0 of 17 tests passing.
test(a_program_with_templates_but_no_rules_scores_an_error) :-
    P = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny is:\n\na person is happy\n    if the person is healthy.\n\nquery who is:\n    which person is happy.\n",
    verify_le_text(P, V),
    assertion((member(I, V.issues), get_dict(type, I, "no_rules"))),
    assertion(V.errors >= 2),      % the unknown section AND the missing rules
    % ... while a program that HAS a rule does not get it
    Q = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is healthy.\n\nthe knowledge base tiny includes:\n\na person is happy\n    if the person is healthy.\n\nquery who is:\n    which person is happy.\n",
    verify_le_text(Q, V2),
    assertion(\+ (member(I2, V2.issues), get_dict(type, I2, "no_rules"))).

% ---- a rewrite has to earn its place ----------------------------------------
% Once a branch is within a few errors of loading, a whole new program is not a
% repair: it is a fresh draft that throws away everything already working. One
% run went 82 → 36 → 1 error and the next full-program reply put it back to 77.

test(rewrite_policy_guards_only_when_the_program_is_close) :-
    Diff = _{features: _{diff_repairs: true}},
    le_contract_assistant:rewrite_policy(Diff, _{errors: 0}, P0),
    assertion(P0 = guarded(_)),
    le_contract_assistant:rewrite_policy(Diff, _{errors: 5}, P5),
    assertion(P5 = guarded(_)),
    % ... a program still far from loading may be rewritten freely
    le_contract_assistant:rewrite_policy(Diff, _{errors: 40}, P40),
    assertion(P40 == any),
    % ... and with diff repairs off, the full program IS the mechanism
    Full = _{features: _{diff_repairs: false}},
    le_contract_assistant:rewrite_policy(Full, _{errors: 0}, PF),
    assertion(PF == any).

test(a_rewrite_that_verifies_worse_is_refused) :-
    good_program(Good),
    verify_le_text(Good, V),
    Config = _{features: _{diff_repairs: true}},
    worse_program(Worse),
    fence(Worse, Reply),
    le_contract_assistant:apply_repair_reply(Config, guarded(V), Reply, Good, NewText, How),
    assertion(NewText == Good),
    assertion(sub_string(How, _, _, _, "refused")).

test(a_rewrite_that_verifies_better_is_used) :-
    broken_program(Broken),          % 0 errors, but its one test fails
    verify_le_text(Broken, V),
    assertion(V.errors =:= 0),
    assertion(V.tests_failed =:= 1),
    Config = _{features: _{diff_repairs: true}},
    good_program(Good),
    fence(Good, Reply),
    le_contract_assistant:apply_repair_reply(Config, guarded(V), Reply, Broken, NewText, How),
    assertion(NewText == Good),
    assertion(sub_string(How, _, _, _, "verifies better")).

test(schedule_text_of_no_file_is_empty) :-
    le_contract_assistant:schedule_text([], T),
    assertion(T == "").

test(schedule_text_joins_several_files_under_named_headers,
     [setup(upload_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    Req = _{wording: _{name: "policy.md", text: "# Tiny\n"},
            schedule: [_{name: "limits.json", text: "{\"limit\": 1000}"},
                       _{name: "elections.md", text: "Elections: none.\n"}]},
    le_contract_assistant:save_uploads(Req, Dir, _, Schedules, _),
    le_contract_assistant:schedule_text(Schedules, T),
    assertion(sub_string(T, _, _, _, "{\"limit\": 1000}")),
    assertion(sub_string(T, _, _, _, "Elections: none.")),
    assertion(sub_string(T, _, _, _, "### SCHEDULE 1")),
    assertion(sub_string(T, _, _, _, "### SCHEDULE 2")),
    assertion(sub_string(T, _, _, _, "limits.json")),
    % ... while a single schedule is still passed verbatim, as it always was
    Schedules = [S1|_],
    le_contract_assistant:schedule_text([S1], One),
    assertion(One == "{\"limit\": 1000}").

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

% A finished job survives the process that ran it: the dynamic facts are gone
% (as after a server restart) but the job directory still holds winner.le,
% ledger.md and scores.json, so status and result are served from disk.
test(finished_job_is_recovered_from_disk,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    atom_string(JobID, JobStr),
    forget_job_in_memory(JobID),
    handle_contract_status(_{job: JobStr, since: 0}, Status),
    assertion(Status.status == "finished"),
    assertion(Status.log \== []),
    handle_contract_result(_{job: JobStr}, Result),
    good_program(P),
    assertion(Result.le == P),
    assertion(Result.recovered == true),
    !.

% Same, for a job that was still running: nothing resumes it, and saying so
% beats "Unknown job" (its log explains where the money went).
test(interrupted_job_is_reported_as_lost,
     [setup(hook_setup(user:hook_good)), cleanup(hook_cleanup)]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    forget_job_in_memory(JobID),
    le_contract_assistant:job_dir(JobID, Dir),
    atomic_list_concat([Dir, '/winner.le'], Winner),
    delete_file(Winner),
    atom_string(JobID, JobStr),
    handle_contract_status(_{job: JobStr, since: 0}, Status),
    assertion(Status.status == "error"),
    assertion(sub_string(Status.error, _, _, _, "restarted")),
    !.

% Job IDs come from the browser and end up in a path: only the minted shape is
% accepted, so no request can read outside the jobs directory.
test(job_id_from_the_browser_cannot_escape_the_jobs_directory) :-
    forall(member(J, ["../../etc", "caj_../../etc/passwd", "caj_a/b", "caj_"]),
           ( handle_contract_result(_{job: J}, R),
             assertion(R.error == "Unknown job") )).

forget_job_in_memory(JobID) :-
    retractall(le_contract_assistant:ca_status(JobID, _)),
    retractall(le_contract_assistant:ca_result(JobID, _)),
    retractall(le_contract_assistant:ca_config(JobID, _)),
    retractall(le_contract_assistant:ca_stage(JobID, _, _)),
    retractall(le_contract_assistant:ca_branch(JobID, _, _)),
    retractall(le_contract_assistant:ca_log(JobID, _, _)),
    retractall(le_contract_assistant:ca_logseq(JobID, _)),
    retractall(le_contract_assistant:ca_ended(JobID, _)).

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

% A provider that knows `reasoning_effort` but not the level we send — gpt-5.5,
% which dropped the "minimal" its predecessors accept — and names the levels it
% does take. It answers as soon as one of those is used.
:- dynamic effort_calls/2.

raw_hook_refuses_minimal_effort(_Model, _Messages, Opts, Reply) :-
    ( retract(effort_calls(N0, _)) -> true ; N0 = 0 ),
    N is N0 + 1,
    (   memberchk(reasoning_effort(Level), Opts)
    ->  true
    ;   memberchk(reasoning(Level), Opts)
    ->  true
    ;   Level = absent
    ),
    assertz(effort_calls(N, Level)),
    (   memberchk(Level, [minimal, absent])
    ->  throw(error(llm_api_error(400,
            "{\"error\":{\"code\":\"unsupported_value\",\"message\":\"Unsupported value: 'reasoning_effort' does not support 'minimal' with this model. Supported values are: 'none', 'low', 'medium', 'high', and 'xhigh'.\",\"param\":\"reasoning_effort\"}}"), c))
    ;   Reply = "the answer"
    ).

% ... and one that rejects the parameter without saying what it would accept.
raw_hook_refuses_effort_silently(_Model, _Messages, Opts, Reply) :-
    (   le_contract_assistant:asks_for_less_reasoning(Opts)
    ->  throw(error(llm_api_error(400,
            "{\"error\":{\"message\":\"Unsupported parameter: 'reasoning_effort' is not supported with this model.\",\"param\":\"reasoning_effort\"}}"), c))
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
    le_contract_assistant:apply_repair_reply(Config, any, Reply, "the original program", NewText, _How),
    assertion(NewText == "the original program").

% A reply that elides sections ("% ... (all rules and templates)") must never
% replace the program: the previous iteration is kept.
test(elided_program_never_replaces_the_text) :-
    Config = _{features: _{diff_repairs: true}},
    Reply = "```le\n% ... (all rules and templates)\n\nscenario case1 is:\n    the claim occurs on 2026-02-12.\n```\n",
    le_contract_assistant:apply_repair_reply(Config, any, Reply, "the original program", NewText, How),
    assertion(NewText == "the original program"),
    assertion(sub_string(How, _, _, _, "elided")).

% A full-program reply that is a fraction of the program it would replace is a
% truncation or a quiet rewrite, not a repair. Regression from a FEMA run: a
% 52 kB program came back as 8 kB — no elision marker, no error — and four of
% the policy's five coverages were simply gone.
long_program(P) :-
    numlist(1, 400, Ns),
    findall(L, ( member(N, Ns),
                 format(string(L), "a claim ~w is covered if the claim ~w is qualifying.", [N, N]) ),
            Ls),
    atomic_list_concat(Ls, "\n", P0), atom_string(P0, P).

test(amputated_full_program_reply_never_replaces_the_text) :-
    Config = _{features: _{diff_repairs: true}},
    long_program(P),
    Reply = "```le\nthe templates are:\n    *a claim* is covered.\n```\n",
    le_contract_assistant:apply_repair_reply(Config, any, Reply, P, NewText, How),
    assertion(NewText == P),
    assertion(sub_string(How, _, _, _, "treated as truncation")).

% Same guard for the reply the provider cut off mid-program: its code fence
% never closes.
test(truncated_full_program_reply_never_replaces_the_text) :-
    Config = _{features: _{diff_repairs: true}},
    long_program(P),
    string_concat("```le\n", P, Head),
    sub_string(Head, 0, 900, _, Reply),      % cut off: no closing fence
    le_contract_assistant:apply_repair_reply(Config, any, Reply, P, NewText, How),
    assertion(NewText == P),
    assertion(sub_string(How, _, _, _, "cut off mid-program")).

% ... while a full program of comparable size still replaces the text, and a
% small program (an early draft) may still change freely.
test(a_full_sized_full_program_reply_is_still_accepted) :-
    Config = _{features: _{diff_repairs: true}},
    long_program(P),
    format(string(Reply), "```le\n~w\nand one more rule if it is so.\n```\n", [P]),
    le_contract_assistant:apply_repair_reply(Config, any, Reply, P, NewText, How),
    assertion(sub_string(NewText, _, _, _, "and one more rule")),
    assertion(sub_string(How, _, _, _, "replaced the full program")).

test(a_small_program_may_still_shrink) :-
    Config = _{features: _{diff_repairs: true}},
    Reply = "```le\nsmall.\n```\n",
    le_contract_assistant:apply_repair_reply(Config, any, Reply, "the original program", NewText, _),
    assertion(NewText == "small.\n").

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

% The held-out term is net too. Regression from a FEMA run: a branch that had
% amputated itself to 8 kB wrote 2 blind tests and failed 1, the complete 50 kB
% branch wrote 7 and failed 2 — and the raw failure count crowned the amputee.
test(rank_prefers_net_holdout_evidence) :-
    Big = _{errors: 0, warnings: 3, tests_passed: 7, tests_failed: 3, test_details: [],
            holdout_passed: 5, holdout_failed: 2, summary: "complete"},
    Small = _{errors: 0, warnings: 2, tests_passed: 2, tests_failed: 2, test_details: [],
              holdout_passed: 1, holdout_failed: 1, summary: "amputated"},
    le_contract_assistant:select_winner(job,
        [branch(1, "a program of fifty thousand characters", Big),
         branch(2, "a sketch", Small)], Winner),
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
    assertion(sub_string(B, _, _, _, "one scenario per supplied case")),
    assertion(sub_string(B, _, _, _, "3 cases were supplied")).

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
    assertion(S3 == section("Guide to sections")),
    % ... but "until" is a range marker on its own: dropping the leading "from"
    % is the obvious slip, and left unread it silently sends the WHOLE wording
    % into every call (observed: 62k tokens per call, and a provider timeout).
    le_contract_assistant:parse_target("Employers' liability until Property definitions", S4),
    assertion(S4 == range("Employers' liability", "Property definitions", false)),
    le_contract_assistant:parse_target("A until B (inclusive)", S5),
    assertion(S5 == range("A", "B", true)).

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
    le_contract_assistant:stage_options(temp_job, Config, draft(1), "KEY",
                                        [temperature(0.4)], Opts0),
    assertion(memberchk(temperature(0.4), Opts0)),
    assertz(le_contract_assistant:ca_tune(temp_job, no_temperature)),
    le_contract_assistant:stage_options(temp_job, Config, draft(1), "KEY",
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

% A rejection of the reasoning LEVEL is classified apart from a rejection of
% the temperature, and the levels the provider says it accepts are read off the
% message. (The two must not be confused: an "unsupported value" message can
% mention both parameters, and dropping the temperature would not have saved
% the gpt-5.5 job — every call would still have 400ed.)
test(reasoning_effort_rejection_classified) :-
    E = error(llm_api_error(400, "{\"error\":{\"code\":\"unsupported_value\",\"message\":\"Unsupported value: 'reasoning_effort' does not support 'minimal' with this model. Supported values are: 'none', 'low', 'medium', 'high', and 'xhigh'.\",\"param\":\"reasoning_effort\"}}"), c),
    assertion(le_contract_assistant:reasoning_effort_rejected(E, _)),
    le_contract_assistant:reasoning_effort_rejected(E, Supported),
    assertion(Supported == [none, low, medium, high, xhigh]),   % "minimal" is NOT offered
    le_contract_assistant:cheapest_effort(Supported, Level),
    assertion(Level == none),
    assertion(\+ le_contract_assistant:temperature_rejected(E)),
    % a plain temperature rejection is still one, and is not read as this
    T = error(llm_api_error(400, "Unsupported value: 'temperature' does not support 0.05 with this model."), c),
    assertion(le_contract_assistant:temperature_rejected(T)),
    assertion(\+ le_contract_assistant:reasoning_effort_rejected(T, _)),
    % ... and a rejection that names no levels parses as "none offered"
    S = error(llm_api_error(400, "Unsupported parameter: 'reasoning_effort' is not supported with this model."), c),
    le_contract_assistant:reasoning_effort_rejected(S, None),
    assertion(None == []),
    assertion(\+ le_contract_assistant:cheapest_effort(None, _)).

% The whole ladder, offline: the job has been switched to minimal reasoning,
% the provider refuses that level, and the assistant retries the SAME model at
% the cheapest level it does accept — sticky, so the next call starts there.
test(rejected_reasoning_level_is_retried_at_an_accepted_one,
     [setup(( retractall(user:effort_calls(_, _)),
              retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_refuses_minimal_effort)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(user:effort_calls(_, _)),
                retractall(le_contract_assistant:ca_tune(effort_job, _)),
                retractall(le_contract_assistant:ca_log(effort_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(effort_job, _)) ))]) :-
    get_time(Now), Deadline is Now + 600,
    Config = _{deadline: Deadline, max_tokens: 4096, max_tokens_cap: 4096,
               reasoning: minimal},
    le_contract_assistant:llm_try(effort_job, Config, architecture, 'gpt-5.5',
                                  [_{role: user, content: "hi"}],
                                  [reasoning(minimal), max_tokens(4096)], 1, Reply),
    assertion(Reply == "the answer"),
    user:effort_calls(Calls, LastLevel),
    assertion(Calls =:= 2),                    % refused, then retried at a good level
    assertion(LastLevel == none),
    assertion(le_contract_assistant:ca_tune(effort_job, reasoning_effort(none))),
    % ... and every later call of the job goes out at that level, with no
    % second `reasoning` field beside it
    le_contract_assistant:stage_options(effort_job, Config, draft(1), "KEY", [], Opts),
    assertion(memberchk(reasoning_effort(none), Opts)),
    assertion(\+ memberchk(reasoning(_), Opts)).

% A provider that refuses the parameter without naming an alternative: drop it
% and carry on, rather than failing the job.
test(unusable_reasoning_parameter_is_dropped,
     [setup(( retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_refuses_effort_silently)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(le_contract_assistant:ca_tune(effort_drop_job, _)),
                retractall(le_contract_assistant:ca_log(effort_drop_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(effort_drop_job, _)) ))]) :-
    get_time(Now), Deadline is Now + 600,
    Config = _{deadline: Deadline, max_tokens: 4096, max_tokens_cap: 4096,
               reasoning: minimal},
    le_contract_assistant:llm_try(effort_drop_job, Config, architecture, 'some-model',
                                  [_{role: user, content: "hi"}],
                                  [reasoning(minimal), max_tokens(4096)], 1, Reply),
    assertion(Reply == "the answer"),
    assertion(le_contract_assistant:ca_tune(effort_drop_job, no_reasoning)),
    le_contract_assistant:stage_options(effort_drop_job, Config, draft(1), "KEY", [], Opts),
    assertion(\+ le_contract_assistant:asks_for_less_reasoning(Opts)).

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

% Hook that answers a repair with a WHOLE PROGRAM twice: first a worse one
% (which must be refused), then the right one (which must be accepted). It also
% records the prompt of each repair round, so the test can check what the model
% was shown after its rewrite was thrown away.
:- dynamic saw_repair/2.

worse_program("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy if healthy.\n").

hook_rewrites(Purpose, Messages, Reply) :-
    (   Purpose = repair(_, Iter)
    ->  findall(C, ( member(M, Messages), get_dict(content, M, C) ), Cs),
        atomic_list_concat(Cs, "\n", Prompt),
        assertz(saw_repair(Iter, Prompt))
    ;   true
    ),
    hook_rewrites_(Purpose, Reply).

hook_rewrites_(vocabulary, "*a person* is happy. % vocabulary") :- !.
hook_rewrites_(architecture, "one branch: happiness") :- !.
hook_rewrites_(draft(_), Reply) :- !, broken_program(P), fence(P, Reply).
hook_rewrites_(repair(_, 0), Reply) :- !, worse_program(P), fence(P, Reply).
hook_rewrites_(repair(_, _), Reply) :- !, good_program(P), fence(P, Reply).
hook_rewrites_(ledger, "LEDGER") :- !.
hook_rewrites_(Purpose, _) :- throw(unexpected_llm_purpose(Purpose)).

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
hook_broken(ledger, _, "| Clause | Status | Notes |\n|---|---|---|\n| I.A | **TODO** | nothing encoded |\n") :- !.
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

% Several schedule files, one of them structured (.json): both must reach the
% drafting prompt, each under a header naming its file.
:- dynamic saw_prompt/1.

hook_schedules(Purpose, Messages, Reply) :-
    (   Purpose = draft(_)
    ->  findall(C, ( member(M, Messages), get_dict(content, M, C) ), Cs),
        atomic_list_concat(Cs, "\n", Prompt),
        assertz(saw_prompt(Prompt))
    ;   true
    ),
    (   Purpose = holdout(_, _)
    ->  fence("scenario held out case 101 is:\n    carol is healthy.\n    who expects answers [\"carol is happy\"].\n", Reply)
    ;   hook_good(Purpose, Messages, Reply)
    ).

two_schedules_config(Config) :-
    good_wording(W),
    Config = _{wording: _{name: "contract.md", text: W},
               schedule: [_{name: "limits.json", text: "{\"limit\": 1000}"},
                          _{name: "elections.md", text: "Elections: none.\n"}],
               cases: [_{name: "case1.md", text: "Case 1: bob was healthy."}],
               model: "stub-model",
               budget: _{preset: "draft", minutes: 5}}.

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

% A broken winner is exactly when the user most needs to know what the twin
% covers, so the ledger is written anyway — under a banner saying the program
% it audits does not load. (It used to say "(ledger skipped)", leaving the user
% with a broken program and no map of it.)
test(ledger_is_written_even_when_the_winner_is_broken,
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
    assertion(sub_string(Ledger, _, _, _, "does not load cleanly")),
    assertion(sub_string(Ledger, _, _, _, "**TODO**")),      % the audit itself
    assertion(\+ sub_string(Ledger, _, _, _, "ledger skipped")),
    Scores = Result.scores, Scores = [Score],
    assertion(Score.errors >= 1).

test(several_schedule_files_reach_the_drafting_prompt,
     [setup(( retractall(user:saw_prompt(_)), hook_setup(user:hook_schedules) )),
      cleanup(( retractall(user:saw_prompt(_)), hook_cleanup ))]) :-
    two_schedules_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    user:saw_prompt(Sys),
    assertion(sub_string(Sys, _, _, _, "{\"limit\": 1000}")),   % the .json, verbatim
    assertion(sub_string(Sys, _, _, _, "Elections: none.")),
    assertion(sub_string(Sys, _, _, _, "limits.json")),         % named in its header
    !.

% End to end: a JSON claims file is not one case, it is four, and the drafting
% prompt is told to write one scenario for each — with the schedule each claim
% names attached to it.
json_cases_config(Config) :-
    good_wording(W),
    Claims = "{\"claims\": [
       {\"claimRef\": \"C1\", \"policyRef\": \"P1\", \"facts\": \"bob was healthy\"},
       {\"claimRef\": \"C2\", \"policyRef\": \"P2\", \"facts\": \"carol was healthy\"},
       {\"claimRef\": \"C3\", \"policyRef\": \"P1\", \"facts\": \"dave was healthy\"},
       {\"claimRef\": \"C4\", \"policyRef\": \"P2\", \"facts\": \"eve was healthy\"}]}",
    Scheds = "{\"schedules\": [
       {\"policyRef\": \"P1\", \"buildingLimit\": 250000},
       {\"policyRef\": \"P2\", \"buildingLimit\": 120000}]}",
    Config = _{wording: _{name: "contract.md", text: W},
               schedule: [_{name: "schedules.json", text: Scheds}],
               cases: [_{name: "claims.json", text: Claims}],
               model: "stub-model",
               budget: _{preset: "draft", minutes: 5}}.

test(a_json_claims_array_becomes_one_case_per_claim_end_to_end,
     [setup(( retractall(user:saw_prompt(_)), hook_setup(user:hook_schedules) )),
      cleanup(( retractall(user:saw_prompt(_)), hook_cleanup ))]) :-
    json_cases_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    % four claims, the last quarter held out: three development cases
    le_contract_assistant:ca_config(JobID, C),
    assertion(C.n_dev_cases =:= 3),
    user:saw_prompt(Prompt),
    assertion(sub_string(Prompt, _, _, _, "### CASE 3")),
    assertion(\+ sub_string(Prompt, _, _, _, "### CASE 4")),   % the fourth is blind
    assertion(sub_string(Prompt, _, _, _, "3 cases were supplied")),
    % each case carries the schedule entry it names, and not the other one
    atom_string(PromptA, Prompt),
    atomic_list_concat(Chunks, '### CASE ', PromptA),
    nth1(3, Chunks, Case2),                     % chunk 1 is everything before CASE 1
    assertion(sub_atom(Case2, _, _, _, 'carol was healthy')),
    assertion(sub_atom(Case2, _, _, _, '120000')),
    assertion(\+ sub_atom(Case2, _, _, _, '250000')),
    !.

% End to end: the refused rewrite does not become the base of the next round,
% and the model is TOLD why — otherwise, at temperature 0, it sends the same
% program again and the branch burns its patience on identical refusals.
test(a_refused_rewrite_is_not_carried_forward_and_the_model_is_told,
     [setup(( retractall(user:saw_repair(_, _)), hook_setup(user:hook_rewrites) )),
      cleanup(( retractall(user:saw_repair(_, _)), hook_cleanup ))]) :-
    start_config(Config),
    start_contract_job(Config, [sync(true)], JobID),
    assertion(le_contract_assistant:ca_status(JobID, finished(ok))),
    le_contract_assistant:ca_result(JobID, Result),
    % the second rewrite (the right program) was accepted, so the branch ends clean
    good_program(Good),
    assertion(Result.le == Good),
    % round 1 was prompted with the program from round 0 — NOT the refused rewrite
    user:saw_repair(1, Prompt1),
    broken_program(Broken),
    sub_string(Broken, _, _, _, "alice is happy"),
    assertion(sub_string(Prompt1, _, _, _, "alice is happy")),
    worse_program(Worse),
    sub_string(Worse, _, _, _, "is happy if healthy"),
    assertion(\+ sub_string(Prompt1, _, _, _, "is happy if healthy")),
    % ... and it says why the previous reply was thrown away
    assertion(sub_string(Prompt1, _, _, _, "REFUSED")),
    assertion(sub_string(Prompt1, _, _, _, "SEARCH/REPLACE")),
    !.

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
    le_contract_assistant:llm_wall_limit(T, W),
    assertion(T >= 900),
    assertion(W > T),
    get_time(Now), Deadline is Now + 120*60,
    Config = _{max_tokens: 4096, reasoning: default, minutes: 120, deadline: Deadline},
    le_contract_assistant:stage_options(no_job, Config, draft(1), "KEY", [temperature(0.1)], Opts),
    assertion(memberchk(timeout(T), Opts)).

% ... but a SHORT job may not hand a single call the whole ceiling. A provider
% that accepts the request and then goes silent costs a full timeout per
% attempt: at 15 minutes each, the retry ladder alone consumed a 45-minute
% budget before stage 1 produced anything (observed with a slow open-weights
% model). No single call may take more than a sixth of the budget.
test(a_short_budget_shortens_the_call_timeout) :-
    get_time(Now), Deadline is Now + 45*60,
    le_contract_assistant:call_timeout(_{minutes: 45, deadline: Deadline}, T),
    assertion(T =:= 450),                       % a sixth of 45 minutes
    le_contract_assistant:llm_socket_timeout(Ceiling),
    assertion(T < Ceiling),
    % four attempts of this length still leave time for the rest of the job
    assertion(4 * T < 45 * 60).

% Near the deadline the timeout shrinks again: a call started with two minutes
% left must not run for seven.
test(call_timeout_shrinks_as_the_deadline_nears) :-
    get_time(Now), Deadline is Now + 300,
    le_contract_assistant:call_timeout(_{minutes: 45, deadline: Deadline}, T),
    assertion(T =< 150),
    % ... but never below the floor, or healthy calls would be killed too
    Deadline2 is Now + 10,
    le_contract_assistant:call_timeout(_{minutes: 45, deadline: Deadline2}, T2),
    assertion(T2 =:= 120).

% A silent provider gets a shorter ladder than a 503 when the budget is TIGHT:
% each of its attempts costs a whole timeout, while a rejected request comes
% back at once.
test(silent_providers_are_retried_less_when_the_budget_is_tight) :-
    Silent = error(llm_http_error(error(timeout_error(read, s), context(x, y))), c),
    assertion(le_contract_assistant:transient_llm_error(Silent)),
    assertion(le_contract_assistant:silent_provider_error(Silent)),
    get_time(Now), Deadline is Now + 600,          % ten minutes left
    Config = _{minutes: 45, deadline: Deadline},
    le_contract_assistant:max_attempts(Config, Silent, SilentAttempts),
    assertion(SilentAttempts =:= 2),
    RateLimit = error(llm_api_error(429, "slow down"), c),
    assertion(\+ le_contract_assistant:silent_provider_error(RateLimit)),
    le_contract_assistant:max_attempts(Config, RateLimit, RateAttempts),
    assertion(RateAttempts > SilentAttempts).

% ... but with the budget half unspent there is no reason to give up early: a
% 120-minute job died 46 minutes in, with 74 minutes unused, because the ladder
% was a flat two attempts.
test(a_roomy_budget_keeps_the_full_retry_ladder) :-
    Silent = error(llm_http_error(error(timeout_error(read, s), context(x, y))), c),
    get_time(Now), Deadline is Now + 74*60,
    Config = _{minutes: 120, deadline: Deadline},
    assertion(le_contract_assistant:room_for_long_attempts(Config)),
    le_contract_assistant:max_attempts(Config, Silent, Attempts),
    assertion(Attempts =:= 4).

% ---- one lost call must not lose the stage -----------------------------------

% Drawing K independent samples is pointless if losing one throws away the
% others: a K=5 job died on sample 2 with sample 1 already in hand.
test(a_failed_vocabulary_sample_does_not_kill_the_job,
     [setup(( retractall(user:vocab_calls(_)), hook_setup(user:hook_flaky_vocabulary) )),
      cleanup(( hook_cleanup, retractall(user:vocab_calls(_)),
                retractall(le_contract_assistant:ca_log(vocab_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(vocab_job, _)) ))]) :-
    vocab_config(Config),
    le_contract_assistant:vocabulary_consensus(vocab_job, Config, "materials", Vocabulary),
    assertion(Vocabulary == "merged vocabulary"),
    user:vocab_calls(Calls),
    assertion(Calls =:= 3),               % all three were attempted
    % and the log says which one was lost
    findall(L, le_contract_assistant:ca_log(vocab_job, _, L), Lines),
    assertion(( member(Line, Lines), sub_string(Line, _, _, _, "sample 2/3 failed") )),
    assertion(( member(L2, Lines), sub_string(L2, _, _, _, "2 of 3 vocabulary samples usable") )).

% Losing every sample IS fatal — with an error that says so, not the raw error
% of whichever call happened to be last.
test(losing_every_vocabulary_sample_ends_the_job,
     [setup(hook_setup(user:hook_all_vocabulary_fails)),
      cleanup(( hook_cleanup,
                retractall(le_contract_assistant:ca_log(vocab_job2, _, _)),
                retractall(le_contract_assistant:ca_logseq(vocab_job2, _)) ))]) :-
    vocab_config(Config),
    catch(le_contract_assistant:vocabulary_consensus(vocab_job2, Config, "materials", _),
          error(contract_assistant_error(Msg), _),
          true),
    assertion(sub_string(Msg, _, _, _, "every vocabulary sample failed")).

% The retry log must be self-consistent: attempt 1 waits 3s, and the line says
% how many attempts this error is worth. A field log showed "attempt 1 ...
% retrying in 20s", which this pairing makes impossible — if it recurs, the
% running build is not this code. (A 503 comes back at once, so the plain
% ladder is what handles it.)
test(the_retry_log_line_pairs_the_attempt_with_its_delay,
     [setup(( retractall(user:silent_calls(_)),
              retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_flaky_once)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(user:silent_calls(_)),
                retractall(le_contract_assistant:ca_log(silent_job, _, _)),
                retractall(le_contract_assistant:ca_logseq(silent_job, _)) ))]) :-
    get_time(Now), Deadline is Now + 120*60,
    Config = _{deadline: Deadline, minutes: 120, max_tokens: 4096, reasoning: default},
    le_contract_assistant:llm_try(silent_job, Config, vocabulary, 'a-model',
                                  [_{role: user, content: "hi"}],
                                  [max_tokens(4096), timeout(900)], 1, Reply),
    assertion(Reply == "the answer"),
    findall(L, le_contract_assistant:ca_log(silent_job, _, L), Lines),
    Lines = [Line|_], !,
    assertion(sub_string(Line, _, _, _, "attempt 1 of 4")),
    assertion(sub_string(Line, _, _, _, "retrying in 3s")).

% Silence is the same failure as a truncated reply — the model is thinking past
% the timeout — so it gets the same answer: think less. Retrying the identical
% request only buys another silence, and every call of a 45-minute job then
% times out even with a 4k-token prompt.
test(silence_switches_the_job_to_minimal_reasoning,
     [setup(( retractall(user:silent_until_minimal(_)),
              retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_silent_until_minimal)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(user:silent_until_minimal(_)),
                retractall(le_contract_assistant:ca_tune(silent_job2, _)),
                retractall(le_contract_assistant:ca_log(silent_job2, _, _)),
                retractall(le_contract_assistant:ca_logseq(silent_job2, _)) ))]) :-
    get_time(Now), Deadline is Now + 45*60,
    Config = _{deadline: Deadline, minutes: 45, max_tokens: 65536,
               max_tokens_cap: 65536, reasoning: default},
    le_contract_assistant:llm_try(silent_job2, Config, vocabulary, 'a-model',
                                  [_{role: user, content: "hi"}],
                                  [max_tokens(65536), timeout(450)], 1, Reply),
    assertion(Reply == "the answer"),
    user:silent_until_minimal(Calls),
    assertion(Calls =:= 2),                        % silent once, then answered
    % sticky: the rest of the job does not pay for the same discovery again
    assertion(le_contract_assistant:ca_tune(silent_job2, reasoning_minimal)).

% If minimal reasoning is not enough, the completion budget is cut too — a
% model cannot spend a timeout generating tokens it was never allowed.
test(persistent_silence_cuts_the_completion_budget,
     [setup(( retractall(le_contract_assistant:ca_raw_hook(_)),
              assertz(le_contract_assistant:ca_raw_hook(user:raw_hook_silent_until_small_budget)) )),
      cleanup(( retractall(le_contract_assistant:ca_raw_hook(_)),
                retractall(le_contract_assistant:ca_tune(silent_job3, _)),
                retractall(le_contract_assistant:ca_log(silent_job3, _, _)),
                retractall(le_contract_assistant:ca_logseq(silent_job3, _)) ))]) :-
    get_time(Now), Deadline is Now + 45*60,
    Config = _{deadline: Deadline, minutes: 45, max_tokens: 65536,
               max_tokens_cap: 65536, reasoning: default},
    le_contract_assistant:llm_try(silent_job3, Config, vocabulary, 'a-model',
                                  [_{role: user, content: "hi"}],
                                  [max_tokens(65536), timeout(450)], 1, Reply),
    assertion(Reply == "the answer"),
    assertion(le_contract_assistant:ca_tune(silent_job3, max_tokens(16384))).

% Calibration finds the largest completion the provider ACCEPTS; asking for it
% on a stage that writes a paragraph is what let a reasoning model think for
% twenty minutes. Small stages get a small budget; a program-writing stage
% still gets the ceiling.
test(small_stages_do_not_ask_for_a_whole_programs_worth_of_tokens,
     [cleanup(retractall(le_contract_assistant:ca_tune(mt_job, _)))]) :-
    get_time(Now), Deadline is Now + 45*60,
    Config = _{max_tokens: 65536, max_tokens_cap: 65536, reasoning: default,
               minutes: 45, deadline: Deadline},
    le_contract_assistant:stage_options(mt_job, Config, vocabulary, "KEY", [], VocabOpts),
    assertion(memberchk(max_tokens(16384), VocabOpts)),
    le_contract_assistant:stage_options(mt_job, Config, architecture, "KEY", [], ArchOpts),
    assertion(memberchk(max_tokens(16384), ArchOpts)),
    le_contract_assistant:stage_options(mt_job, Config, draft(1), "KEY", [], DraftOpts),
    assertion(memberchk(max_tokens(65536), DraftOpts)),
    % a cap BELOW the small budget is not raised to it
    Small = Config.put(_{max_tokens: 4096, max_tokens_cap: 4096}),
    le_contract_assistant:stage_options(mt_job, Small, vocabulary, "KEY", [], SmallOpts),
    assertion(memberchk(max_tokens(4096), SmallOpts)),
    % ... and a cap learned during the run still wins over both
    assertz(le_contract_assistant:ca_tune(mt_job, max_tokens(32768))),
    le_contract_assistant:stage_options(mt_job, Config, vocabulary, "KEY", [], TunedOpts),
    assertion(memberchk(max_tokens(32768), TunedOpts)).

% ---- the deterministic clean-up pass (no LLM) --------------------------------

junk_program("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is rich.
    *a person* is lucky.
    *a claim* is a claim for court attendance compensation.

the knowledge base tiny includes:

a person is happy
    if the person is rich.

a person is happy
    if the person is lucky.

% Default-false rules for cover-type predicates
a claim is a claim for court attendance compensation
    if the claim is a claim for court attendance compensation
    and the claim is a claim for court attendance compensation.

bob is rich.

scenario one is:
    bob is rich.

query who is:
    which person is happy.
").

% The tautology a drafting model writes to silence a warning ('P if P and P')
% is deleted without asking a model to do it — and the comment that announced
% it goes too, or it is left pointing at nothing.
test(clean_up_deletes_tautological_rules) :-
    junk_program(P),
    le_contract_assistant:prune_program(_{existing: none}, P, Text, Report),
    assertion(Report.tautologies =:= 1),
    assertion(\+ sub_string(Text, _, _, _, "if the claim is a claim for court attendance compensation")),
    assertion(\+ sub_string(Text, _, _, _, "Default-false rules")),
    % ... and nothing else was touched
    assertion(sub_string(Text, _, _, _, "a person is happy\n    if the person is rich.")),
    assertion(sub_string(Text, _, _, _, "a person is happy\n    if the person is lucky.")),
    % the result still loads, with no errors and the same tests
    le_contract_assistant:verify_le_text(P, V0),
    le_contract_assistant:verify_le_text(Text, V1),
    assertion(V1.errors =:= 0),
    assertion(le_contract_assistant:prune_accepted(V0, V1)).

% A self-recursive rule with a REAL condition is ordinary recursion, not junk.
test(clean_up_keeps_recursion_with_a_real_condition) :-
    Text0 = "the target language is: prolog.\n\nthe templates are:\n    *a person* is an ancestor of *a person*.\n    *a person* is a parent of *a person*.\n\nthe knowledge base tiny includes:\n\na person is an ancestor of an other person\n    if the person is a parent of the other person.\n\na person is an ancestor of an other person\n    if the person is a parent of a third person\n    and the third person is an ancestor of the other person.\n\nquery who is:\n    which person is an ancestor of which other person.\n",
    le_contract_assistant:prune_program(_{existing: none}, Text0, Text, Report),
    assertion(Report.deleted =:= 0),
    assertion(sub_string(Text, _, _, _, "if the person is a parent of the other person.")),
    assertion(sub_string(Text, _, _, _, "and the third person is an ancestor of the other person.")).

% The same rule written twice: the first stays, the copy goes.
test(clean_up_deletes_a_duplicated_rule) :-
    Text0 = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is rich.\n\nthe knowledge base tiny includes:\n\na person is happy\n    if the person is rich.\n\na person is happy\n    if the person is rich.\n\nbob is rich.\n\nquery who is:\n    which person is happy.\n",
    le_contract_assistant:prune_program(_{existing: none}, Text0, Text, Report),
    assertion(Report.duplicates =:= 1),
    aggregate_all(count, sub_string(Text, _, _, _, "if the person is rich."), N),
    assertion(N =:= 1),
    le_contract_assistant:verify_le_text(Text, V),
    assertion(V.errors =:= 0).

% The Logical English the USER supplied is binding — the program must contain
% it — so the clean-up may never delete it, however redundant it looks.
test(clean_up_never_deletes_supplied_code) :-
    junk_program(P),
    Existing = "a claim is a claim for court attendance compensation\n    if the claim is a claim for court attendance compensation\n    and the claim is a claim for court attendance compensation.",
    le_contract_assistant:prune_program(_{existing: Existing}, P, Text, Report),
    assertion(Report.deleted =:= 0),
    assertion(sub_string(Text, _, _, _, "if the claim is a claim for court attendance compensation")).

% Deleting the fake definition unmasks the warning it hid; the pass fixes that
% the way Logical English does — `; undefined` on the template — instead of
% leaving the next polish round to invent the tautology again.
test(clean_up_marks_unestablished_predicates_as_scenario_elements) :-
    Text0 = "the target language is: prolog.\n\nthe templates are:\n    *a claim* is covered.\n    *a claim* is a claim for court costs.\n\nthe knowledge base tiny includes:\n\na claim is covered\n    if the claim is a claim for court costs.\n\nquery which is:\n    which claim is covered.\n",
    le_contract_assistant:prune_program(_{existing: none}, Text0, Text, Report),
    assertion(Report.marked_undefined =:= 1),
    assertion(sub_string(Text, _, _, _, "*a claim* is a claim for court costs; undefined.")),
    % the head of a rule is established, so it is NOT marked
    assertion(sub_string(Text, _, _, _, "*a claim* is covered.")),
    le_contract_assistant:verify_le_text(Text, V),
    assertion(V.errors =:= 0),
    findall(T, ( member(I, V.issues), get_dict(type, I, T), T == "undefined_predicate" ), Undefined),
    assertion(Undefined == []).

% A template that already carries an addition is left alone: `undefined` does
% not combine with all of them (a synonym may carry no other addition at all).
test(clean_up_leaves_templates_that_already_have_additions) :-
    Text0 = "the target language is: prolog.\n\nthe templates are:\n    *a claim* is covered.\n    *a payment* is for *a claim*; prepositional.\n\nthe knowledge base tiny includes:\n\na claim is covered\n    if a payment is for the claim.\n\nquery which is:\n    which claim is covered.\n",
    le_contract_assistant:prune_program(_{existing: none}, Text0, Text, Report),
    assertion(Report.marked_undefined =:= 0),
    assertion(sub_string(Text, _, _, _, "; prepositional.")),
    assertion(\+ sub_string(Text, _, _, _, "; undefined")).

% Deleting every rule no query reaches is a judgement about what the twin is
% for, so it is off unless the flag asks for it.
test(untested_rules_are_pruned_only_behind_the_flag,
     [cleanup(set_prolog_flag(ca_prune_untested, false))]) :-
    Text0 = "the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n    *a person* is rich.\n    *a person* is spare.\n\nthe knowledge base tiny includes:\n\na person is happy\n    if the person is rich.\n\na person is spare\n    if the person is rich.\n\nbob is rich.\n\nquery who is:\n    which person is happy.\n",
    set_prolog_flag(ca_prune_untested, false),
    le_contract_assistant:prune_program(_{existing: none}, Text0, KeptText, Report0),
    assertion(Report0.untested =:= 0),
    assertion(sub_string(KeptText, _, _, _, "a person is spare")),
    set_prolog_flag(ca_prune_untested, true),
    le_contract_assistant:prune_program(_{existing: none}, Text0, PrunedText, Report1),
    assertion(Report1.untested =:= 1),
    assertion(\+ sub_string(PrunedText, _, _, _, "a person is spare\n    if")),
    le_contract_assistant:verify_le_text(PrunedText, V),
    assertion(V.errors =:= 0).

% A retry recomputes the timeout from what is LEFT, replacing the stale one.
test(retries_get_a_fresh_shorter_timeout) :-
    get_time(Now), Deadline is Now + 300,
    le_contract_assistant:refresh_timeout(_{minutes: 45, deadline: Deadline},
                                          [timeout(900), max_tokens(4096)], Opts),
    assertion(memberchk(max_tokens(4096), Opts)),
    findall(T, member(timeout(T), Opts), Timeouts),
    Timeouts = [Fresh],                  % exactly one: the stale 900 is gone
    assertion(Fresh =< 150).

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

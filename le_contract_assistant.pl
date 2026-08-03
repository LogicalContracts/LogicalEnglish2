/** <module> LE Contract Assistant

    Converts a contract — normative wording + schedule of parameters + concrete
    cases (e.g. an insurance policy + policy schedule + claims) — into a tested
    Logical English knowledge base, as designed in
    InsurLE2/docs/policyToLEAssistant.md.

    Pipeline (per that plan):
      0. ingest & segment      — uploads to text (pandoc/textutil/pdftotext for
                                 Word/PDF), markdown segmentation, target slice;
                                 held-out split of the cases (feature `holdout`)
      1. vocabulary consensus  — K template-inventory samples merged by a judge,
         + architectures         then W alternative architecture sketches
      2-4. draft (per branch)  — full LE draft (or clause-by-clause with a live
                                 ledger, feature `clausewise`): rules + schedule
                                 facts + case scenarios with expectations
      5. repair (per branch)   — verify/test loop; SEARCH/REPLACE diff edits
                                 with full-program fallback (feature
                                 `diff_repairs`); keeps the best iteration
      5a. polish (per branch)  — once the program loads clean, bounded rounds
                                 (feature `polish`) that remove WARNINGS — dead
                                 templates, rules no query reaches — accepted
                                 only when no test is lost
      5b. held-out evaluation  — blind scenarios for the held-out cases, scored
                                 above development tests in the fitness rank
      6. select & interrogate  — objective fitness; differential interrogation
                                 probes (feature `probes`) with adjudication
                                 repairs; paraphrase-invariance check (feature
                                 `paraphrase`); ledger for the winner

    The search is scaled by the user's budget preset (draft / standard /
    thorough); every feature is individually switchable through the request's
    `features` dict (see features_params/3).

    Two other things the user controls: ADDITIONAL INSTRUCTIONS (free text
    carried into every drafting/repair prompt, overriding the house defaults)
    and the TARGET, which is either a section title (that section and its
    subsections, plus the general terms) or a range — `from A until B`, with an
    optional `(inclusive)` — for the ill-formed markdown that policy wordings
    are made of. Scenarios are never invented: exactly the supplied cases, plus
    whatever the existing code brought, unless the instructions ask for more.

    The user may supply EXISTING LE CODE (templates, scenarios with expected
    answers, rules — any combination): a fragment the generated program must
    contain and stay coherent with, so the twin aligns with a program the user
    has already started. It is injected into every drafting/repair prompt and
    its survival in the delivered program is checked and reported.

    Jobs run in a background thread; progress is polled through the /leapi
    operations contract_start / contract_status / contract_result /
    contract_interrupt (see classic_web_api.pl), same conventions as the LE
    Assistant; contract_cost_estimate prices a configuration before it runs
    (prices from llm/llm_prices.pl). The web UI lives in
    web_extras/contract_assistant/.

    For tests, the LLM can be stubbed by asserting ca_llm_hook/1 with a closure
    called as call(Closure, Purpose, Messages, ReplyText), and jobs can be run
    synchronously with start_contract_job/3 option sync(true). One level lower,
    ca_raw_hook/1 (called as call(Closure, Model, Messages, Options, Reply))
    replaces the provider call itself, to exercise the retry/auto-tuning
    ladder of llm_outcome/9.
*/

:- module(le_contract_assistant, [
    handle_contract_start/2,
    handle_contract_status/2,
    handle_contract_result/2,
    handle_contract_interrupt/2,
    handle_contract_estimate/2,
    cost_estimate/2,
    start_contract_job/3,
    run_contract_pipeline/1,
    segment_markdown/2,
    extract_le_code/2,
    extract_tagged_block/3,
    extract_search_replace/2,
    extract_search_replace/3,
    parse_stability/2,
    verify_le_text/2
]).

:- use_module(library(http/json)).
:- use_module(le_i18n).
:- use_module(library(base64)).
:- use_module(library(process)).
:- use_module(library(uuid)).
:- use_module(le_kbs).
:- use_module(le_verifier).
:- use_module(llm/llm_client).
:- use_module(llm/llm_prices).

:- dynamic ca_status/2.      % JobID, running | finished(ok) | finished(error(Msg)) | interrupted | interrupt_requested
:- dynamic ca_config/2.      % JobID, ConfigDict (normalised)
:- dynamic ca_stage/3.       % JobID, StageIndex, StageLabel
:- dynamic ca_log/3.         % JobID, Seq, Text
:- dynamic ca_logseq/2.      % JobID, NextSeq
:- dynamic ca_branch/3.      % JobID, BranchIndex, InfoDict
:- dynamic ca_result/2.      % JobID, ResultDict
:- dynamic ca_ended/2.       % JobID, EndTime (job reached a terminal state)
:- dynamic ca_tune/2.        % JobID, Tuning (e.g. reasoning_minimal) — set on the fly
:- dynamic ca_llm_hook/1.    % Closure for tests: call(Closure, Purpose, Messages, Reply)
:- dynamic ca_raw_hook/1.    % Closure for tests: call(Closure, Model, Messages, Opts, Reply)

% ============================= HTTP-facing handlers ==========================
% All four take the /leapi request dict and produce a JSON-able response dict.

handle_contract_start(Dict, Response) :-
    catch(
        ( start_contract_job(Dict, [], JobID),
          Response = _{job: JobID}
        ),
        Error,
        ( term_string(Error, EStr),
          Response = _{error: EStr}
        )).

handle_contract_status(Dict, Response) :-
    get_dict(job, Dict, JobStr), atom_string(JobID, JobStr),
    ( get_dict(since, Dict, Since0), number(Since0) -> Since = Since0 ; Since = 0 ),
    (   ca_status(JobID, Status0)
    ->  status_string(Status0, StatusStr, ErrorMsg),
        ( ca_stage(JobID, StageIdx, StageLabel) -> true ; StageIdx = 0, StageLabel = "starting" ),
        findall(B, (ca_branch(JobID, I, Info), B = Info.put(branch, I)), Branches0),
        sort(branch, @=<, Branches0, Branches),
        findall(L, (ca_log(JobID, S, L), S >= Since), LogLines),
        ( ca_logseq(JobID, Next) -> true ; Next = 0 ),
        job_config_summary(JobID, Summary, Elapsed),
        Response0 = _{status: StatusStr, stage: StageIdx, stage_label: StageLabel,
                      branches: Branches, log: LogLines, next_seq: Next,
                      config: Summary, elapsed: Elapsed},
        ( ErrorMsg == none -> Response = Response0
        ; Response = Response0.put(error, ErrorMsg) )
    ;   disk_status(JobID, Since, Response)
    ->  true
    ;   Response = _{error: "Unknown job"}
    ).

handle_contract_result(Dict, Response) :-
    get_dict(job, Dict, JobStr), atom_string(JobID, JobStr),
    (   ca_result(JobID, Result)
    ->  Response = Result
    ;   ca_status(JobID, _)
    ->  Response = _{error: "Job has no result (yet)"}
    ;   disk_result(JobID, Result)
    ->  Response = Result
    ;   Response = _{error: "Unknown job"}
    ).

% ---------------------- Recovery after a server restart ----------------------
% The dynamic facts above live in memory only, so a restart would otherwise
% throw away a run that cost an hour of LLM calls. Everything needed to serve
% it again is in <jobdir>/ (winner.le, ledger.md, scores.json, job.log), so a
% job the process no longer knows is answered from disk.

%!  valid_job_id(+JobID) is semidet.
%
%   Job IDs reach us from the browser and end up in a path, so only the shape
%   start_contract_job_/3 mints is accepted: caj_ + UUID characters.
valid_job_id(JobID) :-
    atom(JobID),
    atom_concat(caj_, UUID, JobID),
    atom_length(UUID, Len), Len > 0, Len =< 40,
    forall(sub_atom(UUID, _, 1, _, C),
           ( char_type(C, alnum) ; C == '-' )).

job_artifact(JobID, Name, File) :-
    valid_job_id(JobID),
    job_dir(JobID, Dir),
    exists_directory(Dir),
    atomic_list_concat([Dir, '/', Name], File).

read_job_artifact(JobID, Name, Text) :-
    job_artifact(JobID, Name, File),
    exists_file(File),
    read_file_to_string(File, Text, [encoding(utf8)]).

%!  disk_status(+JobID, +Since, -Response) is semidet.
%
%   The status of a job this process never ran: finished if it left a program
%   behind, dead otherwise (the server went down mid-run — nothing resumes it).
%   The log comes from job.log in one go, so the client asks for it once.
disk_status(JobID, Since, Response) :-
    job_artifact(JobID, 'job.log', _),
    (   read_job_artifact(JobID, 'job.log', LogText)
    ->  split_string(LogText, "\n", "", Lines0),
        exclude(==(""), Lines0, Lines)
    ;   Lines = []
    ),
    ( Since =:= 0 -> LogLines = Lines ; LogLines = [] ),
    length(Lines, NLines),
    (   read_job_artifact(JobID, 'winner.le', _)
    ->  Response = _{status: "finished", stage: 6,
                     stage_label: "recovered from disk (the server has restarted since this run)",
                     branches: [], log: LogLines, next_seq: NLines,
                     config: _{}, elapsed: 0}
    ;   Response = _{status: "error", stage: 0,
                     stage_label: "lost",
                     error: "The server restarted while this job was running, so it was not finished. Its log is below; start a new run.",
                     branches: [], log: LogLines, next_seq: NLines,
                     config: _{}, elapsed: 0}
    ).

%!  disk_result(+JobID, -Result) is semidet.
%
%   Rebuilds the result dict of a finished job from its artifacts. scores.json
%   carries the reports; a missing or damaged one costs only the extra detail.
disk_result(JobID, Result) :-
    read_job_artifact(JobID, 'winner.le', LE),
    ( read_job_artifact(JobID, 'ledger.md', Ledger) -> true ; Ledger = "" ),
    (   job_artifact(JobID, 'scores.json', ScoresFile),
        exists_file(ScoresFile),
        catch(setup_call_cleanup(open(ScoresFile, read, S, [encoding(utf8)]),
                                 json_read_dict(S, Scores),
                                 close(S)),
              _, fail)
    ->  true
    ;   Scores = _{}
    ),
    Result0 = _{le: LE, filename: "contract.le", ledger: Ledger,
                winner: Scores.get(winner, 0),
                scores: Scores.get(scores, []),
                interrogation: Scores.get(interrogation, _{enabled: false}),
                paraphrase: Scores.get(paraphrase, _{enabled: false}),
                existing_code: Scores.get(existing_code, _{enabled: false})},
    Result = Result0.put(recovered, true).

handle_contract_interrupt(Dict, Response) :-
    get_dict(job, Dict, JobStr), atom_string(JobID, JobStr),
    (   ca_status(JobID, running)
    ->  retractall(ca_status(JobID, _)),
        asserta(ca_status(JobID, interrupt_requested)),
        Response = _{ok: true}
    ;   Response = _{ok: false, error: "Job is not running"}
    ).

%!  handle_contract_estimate(+Dict, -Response) is det.
%
%   Prices a configuration BEFORE it runs, for the Setup screen: same request
%   fields as contract_start (model, judge_model, budget, features) plus
%   `input_chars` — the total size of the materials the user has selected
%   (documents + existing LE code). Never throws: an unknown model or a price
%   table that has not loaded yet comes back as priced:false.
handle_contract_estimate(Dict, Response) :-
    catch(once(contract_cost_estimate(Dict, Response)),
          Error,
          ( term_string(Error, EStr), Response = _{error: EStr} )).

contract_cost_estimate(Dict, Est) :-
    ( get_dict(model, Dict, M0), M0 \== "", M0 \== null -> Model = M0 ; Model = "claude-sonnet" ),
    ( get_dict(judge_model, Dict, J0), J0 \== "", J0 \== null -> Judge = J0 ; Judge = Model ),
    ( get_dict(budget, Dict, B), is_dict(B) -> true ; B = _{} ),
    budget_params(B, Preset, K, W, Repairs, _Minutes),
    features_params(Dict, Preset, Features),
    ( get_dict(input_chars, Dict, IC), number(IC) -> Chars = IC ; Chars = 0 ),
    cost_estimate(_{model: Model, judge_model: Judge, k: K, w: W,
                    repairs: Repairs, probes: Features.probes,
                    input_chars: Chars},
                  Est).

% What the user chose, echoed with every status poll so the Run screen can
% show it even after a page reload, plus the elapsed wall-clock seconds.
job_config_summary(JobID, Summary, Elapsed) :-
    (   ca_config(JobID, C)
    ->  F = C.features,
        ( C.existing == none -> ExistingChars = 0 ; string_length(C.existing, ExistingChars) ),
        ( C.get(instructions, none) == none -> HasInstructions = false ; HasInstructions = true ),
        Summary = _{model: C.model, judge_model: C.judge_model,
                    k: C.k, w: C.w, repairs: C.repairs, minutes: C.minutes,
                    max_tokens: C.max_tokens, reasoning: C.reasoning,
                    probes: F.probes, holdout: F.holdout,
                    paraphrase: F.paraphrase, clausewise: F.clausewise,
                    diff_repairs: F.diff_repairs,
                    existing_chars: ExistingChars,
                    has_instructions: HasInstructions,
                    polish: F.get(polish, 0),
                    cost_usd: C.get(est_cost, null)},
        ( ca_ended(JobID, End) -> T = End ; get_time(T) ),
        Elapsed0 is T - C.started,
        Elapsed is round(Elapsed0)
    ;   Summary = _{}, Elapsed = 0
    ).

status_string(running, "running", none) :- !.
status_string(interrupt_requested, "running", none) :- !.
status_string(interrupted, "interrupted", none) :- !.
status_string(finished(ok), "finished", none) :- !.
status_string(finished(error(Msg)), "error", MsgStr) :- term_string(Msg, MsgStr).

% ================================ Job start ==================================

%!  start_contract_job(+Dict, +Options, -JobID) is det.
%
%   Creates the job directory, stores the uploads (converting Word/PDF to
%   text), normalises the configuration and starts the pipeline — in a
%   detached background thread, or in-line with option sync(true) (tests).
start_contract_job(Dict, Options, JobID) :-
    once(start_contract_job_(Dict, Options, JobID)).

start_contract_job_(Dict, Options, JobID) :-
    uuid(UUID), atom_concat(caj_, UUID, JobID),
    job_dir(JobID, Dir),
    make_directory_path(Dir),
    save_uploads(Dict, Dir, WordingFile, ScheduleFiles, CaseFiles),
    normalise_config(Dict, WordingFile, ScheduleFiles, CaseFiles, Config),
    retractall(ca_config(JobID, _)), assertz(ca_config(JobID, Config)),
    retractall(ca_logseq(JobID, _)), assertz(ca_logseq(JobID, 0)),
    asserta(ca_status(JobID, running)),
    ca_emit(JobID, "Job ~w created in ~w"-[JobID, Dir]),
    (   memberchk(sync(true), Options)
    ->  run_contract_pipeline(JobID)
    ;   thread_create(run_contract_pipeline(JobID), _, [detached(true)])
    ).

job_dir(JobID, Dir) :-
    ( getenv('LE_CONTRACT_JOBS_DIR', Base) -> true ; Base = 'contract_jobs' ),
    atomic_list_concat([Base, '/', JobID], Dir).

normalise_config(Dict, WordingFile, ScheduleFiles, CaseFiles, Config) :-
    ( get_dict(model, Dict, Model0), Model0 \== "", Model0 \== null -> Model = Model0
    ; Model = "claude-sonnet" ),
    ( get_dict(judge_model, Dict, JM0), JM0 \== "", JM0 \== null -> JudgeModel = JM0
    ; JudgeModel = Model ),
    ( get_dict(api_keys, Dict, Keys0), is_dict(Keys0) -> Keys = Keys0 ; Keys = _{} ),
    ( get_dict(target, Dict, Target0), Target0 \== "", Target0 \== null -> Target = Target0
    ; Target = none ),
    ( get_dict(budget, Dict, B), is_dict(B) -> true ; B = _{} ),
    budget_params(B, Preset, K, W, Repairs, Minutes),
    features_params(Dict, Preset, Features),
    (   get_dict(max_tokens, Dict, MT0), number(MT0), MT0 > 0
    ->  MaxTokens = MT0, MTMode = fixed
    ;   MaxTokens = 16000, MTMode = auto      % resolved by calibration
    ),
    ( get_dict(reasoning, Dict, R0), atom_string(Reasoning0, R0),
      memberchk(Reasoning0, [default, minimal]) -> Reasoning = Reasoning0
    ; Reasoning = default ),
    existing_code(Dict, Existing),
    free_text(instructions, Dict, Instructions),
    get_time(Now), Deadline is Now + Minutes * 60,
    Config = _{model: Model, judge_model: JudgeModel, api_keys: Keys,
               target: Target, k: K, w: W, repairs: Repairs,
               minutes: Minutes, started: Now, reasoning: Reasoning,
               deadline: Deadline, features: Features, existing: Existing,
               instructions: Instructions,
               max_tokens: MaxTokens, mt_mode: MTMode, max_tokens_cap: MaxTokens,
               wording: WordingFile, schedule: ScheduleFiles, cases: CaseFiles}.

%!  existing_code(+RequestDict, -Existing) is det.
%
%   The optional `existing_code` field: Logical English the user has already
%   written (templates, scenarios with their expected answers, rules — any
%   combination) which the generated program must incorporate. Blank input is
%   `none`.
existing_code(Dict, Existing) :- free_text(existing_code, Dict, Existing).

%!  free_text(+Field, +RequestDict, -Text) is det.
%
%   An optional free-text field of the request: the text, or `none` when it is
%   absent or blank.
free_text(Field, Dict, Text) :-
    (   get_dict(Field, Dict, T0), T0 \== null,
        ( string(T0) ; atom(T0) ),
        normalize_space(string(Norm), T0), Norm \== ""
    ->  atom_string(T0, Text)
    ;   Text = none
    ).

%!  budget_params(+BudgetDict, -Preset, -K, -W, -Repairs, -Minutes) is det.
%
%   K vocabulary samples, W architecture branches, repair iterations per
%   branch, wall-clock budget. Presets from the plan; each individually
%   overridable.
budget_params(B, Preset, K, W, Repairs, Minutes) :-
    ( get_dict(preset, B, P0) -> atom_string(Preset, P0) ; Preset = draft ),
    preset_params(Preset, K0, W0, R0, M0),
    ( get_dict(k, B, K) , number(K) -> true ; K = K0 ),
    ( get_dict(w, B, W), number(W) -> true ; W = W0 ),
    ( get_dict(repairs, B, Repairs), number(Repairs) -> true ; Repairs = R0 ),
    ( get_dict(minutes, B, Minutes), number(Minutes) -> true ; Minutes = M0 ).

preset_params(draft,    1, 1, 2, 15).
preset_params(standard, 3, 2, 3, 45).
preset_params(thorough, 5, 3, 4, 120).
preset_params(_,        1, 1, 2, 15).

%!  features_params(+RequestDict, +Preset, -Features:dict) is det.
%
%   Feature switches, each individually overridable through the request's
%   `features` dict. Defaults express confidence per the plan:
%   - diff_repairs (true): repairs as SEARCH/REPLACE edits, full-program
%     regeneration as automatic fallback.
%   - max_rewrite_errors (5): while the program has at most this many errors, a
%     full-program reply is re-verified and kept only if it comes out strictly
%     better than the program it would replace (see rewrite_policy/3). Raise it
%     to let rewrites through more freely; it has no effect with diff_repairs
%     off, where the full program is the repair mechanism.
%   - holdout (auto): with 2+ cases, develop against the first and score the
%     rest blind; auto-disabled with a single case.
%   - probes (per preset): differential interrogation probe count; 0 = off.
%   - interrogation_repair (true): let disagreements trigger repair rounds.
%   - paraphrase (thorough only): paraphrase-invariance check — informational
%     and expensive, hence off below thorough.
%   - clausewise (false): clause-by-clause drafting with a live ledger; more
%     calls and a fragile assembly, so off unless asked for.
%   - polish (2-3): rounds spent cleaning WARNINGS once the program is right —
%     dead templates, unreachable rules, accidental variables. A round is kept
%     only if it reduces warnings without losing a test; 0 disables.
features_params(Dict, Preset, Features) :-
    preset_features(Preset, F0),
    (   get_dict(features, Dict, FU0), is_dict(FU0)
    ->  dict_pairs(FU0, _, Pairs0),
        findall(K-V, ( member(K-V0, Pairs0), normalise_feature(V0, V) ), Pairs),
        dict_pairs(FU, _, Pairs),
        Features = F0.put(FU)
    ;   Features = F0
    ).

preset_features(draft,    _{probes: 0, interrogation_repair: true, holdout: auto,
                            paraphrase: false, clausewise: false, diff_repairs: true,
                            polish: 2}) :- !.
preset_features(standard, _{probes: 4, interrogation_repair: true, holdout: auto,
                            paraphrase: false, clausewise: false, diff_repairs: true,
                            polish: 2}) :- !.
preset_features(thorough, _{probes: 8, interrogation_repair: true, holdout: auto,
                            paraphrase: true, clausewise: false, diff_repairs: true,
                            polish: 3}) :- !.
preset_features(_, F) :- preset_features(draft, F).

normalise_feature(V, V) :- number(V), !.
normalise_feature(V, V) :- ( V == true ; V == false ), !.
normalise_feature(S, A) :- ( string(S) ; atom(S) ), !, atom_string(A, S).
normalise_feature(V, V).

% --------------------------------- Uploads -----------------------------------
% Uploads arrive inside the /leapi JSON: {name: "...", text: "..."} for text
% files or {name: "...", data: "<base64>"} for binary (Word, PDF). Each is
% stored under <jobdir>/sources/ and converted to a text/markdown twin.
% `wording` is a single upload; `schedule` and `cases` each accept one upload
% or a list of them.

save_uploads(Dict, Dir, WordingFile, ScheduleFiles, CaseFiles) :-
    atomic_list_concat([Dir, '/sources'], SrcDir),
    make_directory_path(SrcDir),
    ( get_dict(wording, Dict, WD), is_dict(WD)
    ->  save_one_upload(WD, SrcDir, wording, WordingFile)
    ;   throw(error(contract_assistant_error("A contract wording upload is required"), _))
    ),
    save_upload_list(schedule, Dict, SrcDir, ScheduleFiles),
    save_upload_list(cases, Dict, SrcDir, CaseFiles).

%!  save_upload_list(+Field, +RequestDict, +SrcDir, -Files) is det.
%
%   An upload field that may be absent, a single {name: ..., text|data: ...}
%   dict or a list of them: both the schedule and the cases accept several
%   files (a schedule split over a limits table and an elections annex, for
%   instance). Missing or malformed entries yield the empty list.
save_upload_list(Field, Dict, SrcDir, Files) :-
    (   get_dict(Field, Dict, U), U \== null
    ->  ( is_list(U) -> Uploads = U ; is_dict(U) -> Uploads = [U] ; Uploads = [] )
    ;   Uploads = []
    ),
    upload_tag_stem(Field, Stem),
    findall(F,
            ( nth1(I, Uploads, UD), is_dict(UD),
              atomic_list_concat([Stem, '_', I], Tag),
              save_one_upload(UD, SrcDir, Tag, F)
            ),
            Files).

upload_tag_stem(cases, case) :- !.
upload_tag_stem(Field, Field).

save_one_upload(UD, SrcDir, Tag, TextFile) :-
    ( get_dict(name, UD, Name0) -> true ; Name0 = "upload" ),
    atom_string(NameA, Name0),
    file_base_name(NameA, BaseA),
    file_name_extension(Stem0, Ext0, BaseA),
    ( Ext0 == '' -> Ext = md ; downcase_atom(Ext0, Ext) ),
    safe_stem(Stem0, Stem),
    atomic_list_concat([SrcDir, '/', Tag, '-', Stem, '.', Ext], RawFile),
    (   get_dict(text, UD, Text), Text \== null
    ->  write_text_file(RawFile, Text)
    ;   get_dict(data, UD, B64), B64 \== null
    ->  decode_base64_to_file(B64, RawFile)
    ;   throw(error(contract_assistant_error("Upload has neither text nor data"), _))
    ),
    ensure_text_file(RawFile, Ext, SrcDir, Tag, TextFile).

%!  safe_stem(+Name, -Stem) is det.
%
%   The uploaded file name, reduced to something safe to paste into a path:
%   lower case, only letters, digits, `_` and `-`, at most 40 characters. The
%   stored name keeps the user's wording ("schedule_2-limits.json") — which is
%   what the multi-file schedule header shows the model.
safe_stem(Name, Stem) :-
    downcase_atom(Name, Lower),
    atom_chars(Lower, Cs0),
    findall(C, ( member(C0, Cs0), ( safe_stem_char(C0) -> C = C0 ; C = '_' ) ), Cs1),
    length(Cs1, N),
    ( N =< 40 -> Cs = Cs1 ; length(Cs, 40), append(Cs, _, Cs1) ),
    ( Cs == [] -> Stem = file ; atom_chars(Stem, Cs) ).

safe_stem_char(C) :- char_type(C, alnum), char_code(C, Code), Code < 128.
safe_stem_char('_').
safe_stem_char('-').

write_text_file(File, Text) :-
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       write(S, Text), close(S)).

decode_base64_to_file(B64, File) :-
    atom_string(B64Atom, B64),
    base64_encoded(Data, B64Atom, [encoding(octet), as(string)]),
    string_codes(Data, Bytes),
    setup_call_cleanup(open(File, write, S, [type(binary)]),
                       maplist([B]>>put_byte(S, B), Bytes),
                       close(S)).

%!  ensure_text_file(+RawFile, +Ext, +SrcDir, +Tag, -TextFile) is det.
%
%   Text-ish files (including the structured ones — JSON, CSV — that a schedule
%   or a batch of cases often arrives in) are used as they are; Word documents
%   go through pandoc (falling back to macOS textutil), PDFs through pdftotext.
%   This is the plan's sanctioned use of UNIX subprocesses.
ensure_text_file(RawFile, Ext, _, _, RawFile) :-
    memberchk(Ext, [md, txt, le, text, markdown, json, csv, tsv, yaml, yml]), !.
ensure_text_file(RawFile, docx, SrcDir, Tag, TextFile) :- !,
    atomic_list_concat([SrcDir, '/', Tag, '.converted.md'], TextFile),
    (   run_converter(path(pandoc), [RawFile, '-t', 'markdown', '-o', TextFile])
    ->  true
    ;   run_converter(path(textutil), ['-convert', 'txt', RawFile, '-output', TextFile])
    ->  true
    ;   throw(error(contract_assistant_error("Cannot convert .docx: install pandoc (or textutil on macOS)"), _))
    ).
ensure_text_file(RawFile, doc, SrcDir, Tag, TextFile) :- !,
    ensure_text_file(RawFile, docx, SrcDir, Tag, TextFile).
ensure_text_file(RawFile, pdf, SrcDir, Tag, TextFile) :- !,
    atomic_list_concat([SrcDir, '/', Tag, '.converted.txt'], TextFile),
    (   run_converter(path(pdftotext), ['-layout', RawFile, TextFile])
    ->  true
    ;   throw(error(contract_assistant_error("Cannot convert .pdf: install pdftotext (poppler)"), _))
    ).
ensure_text_file(RawFile, _, _, _, RawFile).   % unknown extension: hope it is text

run_converter(Exe, Args) :-
    catch(
        ( process_create(Exe, Args, [stdout(null), stderr(null), process(PID)]),
          process_wait(PID, exit(0)) ),
        _, fail).

% ================================ The pipeline ================================

%!  run_contract_pipeline(+JobID) is det.
%
%   Runs the whole pipeline, updating status/log/branch dynamics as it goes.
run_contract_pipeline(JobID) :-
    catch(
        (   % A pipeline that FAILS (rather than throwing) used to kill the
            % thread with the job still marked `running` — the UI then polled a
            % dead job forever. Any failure is a bug, but it must still end the
            % job.
            (   once(pipeline_stages(JobID))
            ->  true
            ;   throw(error(contract_assistant_error(pipeline_failed), _))
            ),
          retractall(ca_status(JobID, _)),
          asserta(ca_status(JobID, finished(ok)))
        ),
        Error,
        (   Error == contract_interrupt
        ->  ca_emit(JobID, "Job interrupted by user"-[]),
            retractall(ca_status(JobID, _)),
            asserta(ca_status(JobID, interrupted))
        ;   friendly_error(Error, EStr),
            ca_emit(JobID, "Job failed: ~w"-[EStr]),
            retractall(ca_status(JobID, _)),
            asserta(ca_status(JobID, finished(error(EStr))))
        )),
    get_time(End),
    retractall(ca_ended(JobID, _)),
    assertz(ca_ended(JobID, End)).

friendly_error(error(contract_assistant_error(pipeline_failed), _), Msg) :- !,
    Msg = "the pipeline failed without an error message — this is a bug in the assistant, not in your materials. The run log above shows how far it got; the job's artifacts are on the server under contract_jobs/.".
friendly_error(error(contract_assistant_error(llm_failed(Purpose, ES)), _), Msg) :- !,
    format(string(Msg), "the LLM call for '~w' failed after retries: ~w", [Purpose, ES]).
friendly_error(error(contract_assistant_error(empty_reply(Purpose, Model)), _), Msg) :- !,
    format(string(Msg),
           "the model returned EMPTY content for '~w' (model ~w), repeatedly. This usually means the model spent its whole completion budget on internal reasoning, or the provider's reply format is not understood. RAISE Max completion tokens (Advanced) to give the reasoning room to finish, or pick a less reasoning-heavy model.",
           [Purpose, Model]).
friendly_error(error(contract_assistant_error(llm_truncated(Purpose, Model)), _), Msg) :- !,
    format(string(Msg),
           "the model (~w) hit the completion-token limit while still reasoning during '~w', even after being asked to think less (reasoning: minimal). RAISE Max completion tokens (Advanced), reduce the input (set a Target section), or pick a less reasoning-heavy model.",
           [Model, Purpose]).
friendly_error(error(contract_assistant_error(M), _), Msg) :- !,
    term_string(M, Msg).
friendly_error(error(resource_error(What), _), Msg) :- !,
    format(string(Msg),
           "the assistant ran out of a Prolog resource (~w) while processing a model reply — this is a bug in the assistant, not in your materials. The run log above shows how far it got; the job's artifacts are on the server under contract_jobs/.",
           [What]).
% The catch-all: an unexpected exception carries a stack trace whose frames
% quote their arguments, and one of those can be a 90 kB LLM reply. Cap it —
% the log is read by a human in a browser.
friendly_error(E, Msg) :- term_string(E, S), truncated(S, 600, Msg).

truncated(S, Max, Out) :-
    string_length(S, L),
    (   L =< Max
    ->  Out = S
    ;   Keep is Max - 3,
        sub_string(S, 0, Keep, _, Head),
        string_concat(Head, "...", Out)
    ).

pipeline_stages(JobID) :-
    ca_config(JobID, Config0),
    % ---- Stage 0: ingest & segment
    ca_set_stage(JobID, 0, "Ingest & segment"),
    read_text(Config0.wording, WordingText),
    segment_markdown(WordingText, Sections),
    save_json_artifact(JobID, 'sectionmap.json', _{sections: Sections}),
    target_slice(WordingText, Sections, Config0.target, JobID, WordingSlice),
    ( is_list(Config0.schedule) -> ScheduleFiles = Config0.schedule ; ScheduleFiles = [] ),
    schedule_text(ScheduleFiles, ScheduleText),
    % A JSON case file holds an ARRAY of cases: each element is one case, with
    % the schedule entry it names attached to it (see case_texts/3).
    case_texts(Config0.cases, ScheduleFiles, CaseTexts),
    holdout_split(Config0, CaseTexts, DevCases, HeldCases),
    % how many cases the drafting stages may write scenarios for — the repair
    % prompt needs it too, so it lives in the config rather than in the loop
    length(DevCases, NDevCases),
    Config = Config0.put(n_dev_cases, NDevCases),
    retractall(ca_config(JobID, _)), assertz(ca_config(JobID, Config)),
    materials_block(WordingSlice, ScheduleText, DevCases, Materials),
    length(Sections, NSections), length(CaseTexts, NCases), length(HeldCases, NHeld),
    length(ScheduleFiles, NSched),
    ca_emit(JobID, "Materials assembled (~w sections, ~w schedule file(s), ~w cases, ~w held out)"-
                   [NSections, NSched, NCases, NHeld]),
    % Every development case is a scenario the draft reply has to carry, and a
    % reply cut off by the completion cap is the one failure the pipeline
    % cannot repair its way out of. Say it before the money is spent.
    (   NDevCases >= 8
    ->  ca_emit(JobID, "Note: ~w development cases means ~w scenarios in every draft reply — if a draft comes back cut off, raise the completion-token cap or narrow the target section"-[NDevCases, NDevCases])
    ;   true
    ),
    note_existing_code(JobID, Config),

    calibrate_and_estimate(JobID, Config, Materials, Config1),

    % ---- Stage 1: vocabulary consensus + architectures
    ca_set_stage(JobID, 1, "Vocabulary & architectures"),
    vocabulary_consensus(JobID, Config1, Materials, Vocabulary),
    save_text_artifact(JobID, 'vocabulary.md', Vocabulary),
    architecture_sketches(JobID, Config1, Materials, Vocabulary, Sketches),

    % ---- Stages 2-5: per-branch draft + repair + blind held-out evaluation
    ca_set_stage(JobID, 2, "Drafting & repairing branches"),
    Ctx = _{materials: Materials, vocabulary: Vocabulary,
            wording: WordingSlice, schedule: ScheduleText,
            dev_cases: DevCases, held_cases: HeldCases},
    length(Sketches, NBranches),
    numlist(1, NBranches, Idxs),
    pairs_keys_values(Pairs, Idxs, Sketches),
    (   NBranches =:= 1
    ->  maplist(run_branch(JobID, Config1, Ctx), Pairs, Branches0)
    ;   concurrent_maplist(run_branch(JobID, Config1, Ctx), Pairs, Branches0)
    ),
    % Keep the branches that DELIVERED. (Filtering with exclude(=(failed(_)),...)
    % was a trap: the first unification binds the closure's variable, so with two
    % dead branches the second one survived the filter, select_winner/3 then had
    % nothing to rank, and the whole pipeline failed silently.)
    include(is_live_branch, Branches0, Branches),
    (   Branches == []
    ->  throw(error(contract_assistant_error("every branch failed — see the run log for the per-branch errors"), _))
    ;   true
    ),

    % ---- Stage 6: score, select, interrogate, ledger
    ca_set_stage(JobID, 6, "Selection, interrogation & ledger"),
    select_winner(JobID, Branches, Winner),
    Winner = branch(WIdx, WText0, WScore),
    ca_emit(JobID, "Winner: branch ~w (~w)"-[WIdx, WScore.summary]),
    % Enhancement stages must never destroy a finished winner: an LLM failure
    % here degrades to a note in the report, not a failed job.
    catch(interrogate(JobID, Config1, Ctx, WText0, WText, Interrogation),
          error(contract_assistant_error(IErr), _),
          ( term_string(IErr, IErrS),
            ca_emit(JobID, "Interrogation aborted (~w); keeping the winner as-is"-[IErrS]),
            WText = WText0,
            Interrogation = _{enabled: true, aborted: IErrS,
                              agreed: 0, disagreed: 0, initially_disagreed: 0, open: []} )),
    catch(paraphrase_check(JobID, Config1, Ctx, Paraphrase),
          error(contract_assistant_error(PErr), _),
          ( term_string(PErr, PErrS),
            ca_emit(JobID, "Paraphrase check aborted (~w)"-[PErrS]),
            Paraphrase = _{enabled: false, note: PErrS} )),
    ledger_for(JobID, Config1, WordingSlice, WText, Ledger0),
    ledger_coverage(Ledger0, NTodo, NRows),
    (   NRows > 0
    ->  Pct is round(100 * (NRows - NTodo) / NRows),
        ca_emit(JobID, "Coverage ledger: ~w of ~w clause row(s) still TODO (~w% encoded or deliberately skipped)"-
                       [NTodo, NRows, Pct])
    ;   true
    ),
    findall(SD, (member(branch(I, _, S), Branches), SD = S.put(branch, I)), AllScores),
    save_text_artifact(JobID, 'winner.le', WText),
    % The delivered program may differ from the branch final (interrogation can
    % adopt adjudication repairs): report ITS verification as the final score.
    verify_le_text(WText, VFinal),
    score_summary(VFinal, SummaryFinal),
    branch_score(VFinal, SummaryFinal, FinalScore),
    ca_emit(JobID, "Delivered program: ~w"-[SummaryFinal]),
    existing_coverage(Config1, WText, ExistingReport),
    (   ExistingReport.enabled == true
    ->  ca_emit(JobID, "Existing LE code: ~w of ~w supplied line(s) present in the delivered program (~w%)"-[ExistingReport.kept, ExistingReport.lines, ExistingReport.percent])
    ;   true
    ),
    technicalities(JobID, Config1, WIdx, SummaryFinal, Interrogation, Paraphrase,
                   ExistingReport, Tech),
    string_concat(Ledger0, Tech, Ledger),
    save_text_artifact(JobID, 'ledger.md', Ledger),
    Result = _{le: WText, filename: "contract.le", winner: WIdx,
               scores: AllScores, final_score: FinalScore, ledger: Ledger,
               interrogation: Interrogation, paraphrase: Paraphrase,
               existing_code: ExistingReport},
    save_json_artifact(JobID, 'scores.json',
                       _{winner: WIdx, scores: AllScores,
                         interrogation: Interrogation, paraphrase: Paraphrase,
                         existing_code: ExistingReport}),
    retractall(ca_result(JobID, _)),
    assertz(ca_result(JobID, Result)).

%!  calibrate_and_estimate(+JobID, +Config, +Materials, -Config1) is det.
%
%   One cheap look before spending real money:
%   - CALIBRATE the completion-token cap: a trivial request at the configured
%     max_tokens; if the provider rejects it (400 naming max_tokens/context),
%     halve and retry until accepted, and use the discovered cap for the whole
%     job. Providers that silently clamp keep the configured value.
%   - ESTIMATE the effort AND the cost from the materials size and the
%     K/W/repairs/probes settings, and say so in the log — including a warning
%     when the minute budget is clearly too small for the expected number of
%     calls. The cost estimate is kept in the config so status polls (and the
%     technicalities block) can show it.
%   Skipped when the LLM is stubbed (offline tests).
calibrate_and_estimate(JobID, Config, Materials, Config2) :-
    (   ca_llm_hook(_)
    ->  Config2 = Config
    ;   calibrate_max_tokens(JobID, Config, Config1),
        effort_estimate(JobID, Config1, Materials, Config2)
    ).

% Calibration is best-effort: any probe failure (unknown model, bad key,
% outage) keeps the configured value — the real pipeline stages will surface
% the real error with proper retries and messages.
calibrate_max_tokens(JobID, Config, Config1) :-
    catch(calibrate_max_tokens_(JobID, Config, Config1),
          _,
          Config1 = Config).

calibrate_max_tokens_(JobID, Config, Config1) :-
    resolve_model(draft(0), Config, Model, Key),
    (   Config.mt_mode == auto
    ->  % Nobody should have to guess a completion limit: probe the provider's
        % real cap from a generous ladder and use it (billing is per token
        % PRODUCED, so a high cap costs nothing until a call needs the room —
        % and a reasoning model that needs it fails without it).
        member(Candidate, [65536, 32768, 16384, 8192]),
        probe_max_tokens(Model, Key, Candidate, Accepted),
        Accepted =:= Candidate,
        !,
        ca_emit(JobID, "Calibration: completion-token limit auto-set to ~w (largest the provider accepts, up to 65536)"-[Accepted]),
        Config1 = Config.put(_{max_tokens: Accepted, max_tokens_cap: Accepted}),
        retractall(ca_config(JobID, _)),
        assertz(ca_config(JobID, Config1))
    ;   MT = Config.max_tokens,
        probe_max_tokens(Model, Key, MT, Accepted),
        (   Accepted =:= MT
        ->  Config1 = Config
        ;   ca_emit(JobID, "Calibration: the provider caps completion at ~w tokens (requested ~w); using ~w for this job"-[Accepted, MT, Accepted]),
            Config1 = Config.put(_{max_tokens: Accepted, max_tokens_cap: Accepted}),
            retractall(ca_config(JobID, _)),
            assertz(ca_config(JobID, Config1))
        )
    ).

probe_max_tokens(Model, Key, MT, Accepted) :-
    (   MT < 2000
    ->  Accepted = MT     % below this, calibration is moot
    ;   catch(
            ( llm_client:llm_request(Model,
                  [_{role: user, content: "Reply with exactly: OK"}],
                  % A two-token request: if the provider has not answered in two
                  % minutes it is not going to, and calibration must not spend
                  % the job's minutes finding that out (the default is ten).
                  _, [api_key(Key), max_tokens(MT), timeout(120)]),
              Accepted = MT ),
            error(llm_api_error(400, Body), _),
            (   term_string(Body, BS),
                ( sub_string(BS, _, _, _, "max_tokens") ; sub_string(BS, _, _, _, "max tokens") ; sub_string(BS, _, _, _, "completion_tokens") ; sub_string(BS, _, _, _, "context") )
            ->  MT2 is MT // 2,
                probe_max_tokens(Model, Key, MT2, Accepted)
            ;   Accepted = MT    % a 400 about something else: leave as configured
            ))
    ).

effort_estimate(JobID, Config, Materials, Config1) :-
    string_length(Materials, MChars),
    ( Config.existing == none -> EChars = 0 ; string_length(Config.existing, EChars) ),
    Chars is MChars + EChars,
    InTokens is Chars // 4,
    cost_estimate(_{model: Config.model, judge_model: Config.judge_model,
                    k: Config.k, w: Config.w, repairs: Config.repairs,
                    probes: Config.features.probes, input_chars: Chars},
                  Est),
    Calls = Est.calls,
    EstMinutes is max(1, (Calls * 45) // 60),   % ~45s per call, order of magnitude
    ca_emit(JobID, "Effort estimate: ~w tokens of materials per call, ~~~w LLM calls, roughly ~w min with a mid-speed model (budget: ~w min)"-[InTokens, Calls, EstMinutes, Config.minutes]),
    (   Est.priced == true
    ->  format_cost(Est.cost_usd, CostS),
        ca_emit(JobID, "Cost estimate: about ~w for the whole job (upper estimate, ~w tokens in / ~w out per call; prices from the LiteLLM table)"-[CostS, Est.input_tokens_per_call, Est.output_tokens_per_call]),
        Config1 = Config.put(est_cost, Est.cost_usd),
        retractall(ca_config(JobID, _)),
        assertz(ca_config(JobID, Config1))
    ;   ca_emit(JobID, "Cost estimate: unavailable (~w)"-[Est.note]),
        Config1 = Config
    ),
    (   EstMinutes > Config.minutes
    ->  ca_emit(JobID, "NOTE: the minute budget looks tight for these settings; the job will prune repairs/probes as the deadline nears (consider the Draft preset or more minutes)"-[])
    ;   true
    ).

%!  cost_estimate(+P:dict, -Est:dict) is det.
%
%   What this configuration will cost in LLM calls, in US dollars. P carries
%   model, judge_model, k, w, repairs, probes and input_chars (the size of
%   everything the model will be shown: documents plus any existing LE code).
%
%   Deliberately rough — 10% is plenty — and deliberately biased UPWARDS, so
%   the number the user sees is not exceeded in practice:
%   - the repair loop is counted at 1.5x its patience (it keeps going while it
%     improves), not at the patience itself;
%   - every call is charged the FULL materials as input, although repairs and
%     later stages send less;
%   - output is charged as a whole program per call;
%   - reasoning tokens (billed as output, invisible in the reply) and retries
%     are covered by a final safety factor;
%   - when a model matches several providers in the price table, the dearest
%     is used (see llm_prices.pl).
cost_estimate(P, Est) :-
    call_plan(P.k, P.w, P.repairs, P.probes, MainCalls, JudgeCalls),
    Calls is MainCalls + JudgeCalls,
    prompt_overhead_tokens(Overhead),
    MatTokens is round(P.input_chars / 4),
    InTok is Overhead + MatTokens,
    OutTok is min(16000, max(2500, MatTokens // 2)),
    Base = _{calls: Calls, input_tokens_per_call: InTok,
             output_tokens_per_call: OutTok},
    (   catch(llm_price(P.model, MIn, MOut), _, fail)
    ->  (   P.judge_model == P.model
        ->  JIn = MIn, JOut = MOut, Note = ""
        ;   catch(llm_price(P.judge_model, JIn, JOut), _, fail)
        ->  Note = ""
        ;   JIn = MIn, JOut = MOut,
            format(string(Note), "no price for the judge model ~w; charged at the main model's rate", [P.judge_model])
        ),
        Raw is MainCalls * (InTok * MIn + OutTok * MOut)
             + JudgeCalls * (InTok * JIn + OutTok * JOut),
        Cost is ceiling(Raw * 1.25 * 100) / 100.0,   % conservative, rounded up to the cent
        Est = Base.put(_{priced: true, cost_usd: Cost, currency: "USD", note: Note})
    ;   llm_prices_status(S),
        (   S.loaded == true
        ->  format(string(N), "no price listed for model ~w", [P.model])
        ;   N = "the model price table has not loaded yet"
        ),
        Est = Base.put(_{priced: false, cost_usd: null, currency: "USD", note: N})
    ).

%!  call_plan(+K, +W, +Repairs, +Probes, -MainCalls, -JudgeCalls) is det.
%
%   How many LLM calls the pipeline makes, split by which model pays for them
%   (the judge model writes the vocabulary consensus and the ledger).
call_plan(K, W, R, P, MainCalls, JudgeCalls) :-
    ( K > 1 -> Merge = 1 ; Merge = 0 ),
    ( number(P), P > 0 -> Probing = 2 + R ; Probing = 0 ),
    RepairRounds is max(R, (3 * R + 1) // 2),
    MainCalls is K + W + W * (1 + RepairRounds) + Probing + 1,
    JudgeCalls is Merge + 1.

% Every call carries the house style and the LE syntax summary in its system
% prompt: measure them rather than guessing.
prompt_overhead_tokens(T) :-
    ( catch(prompt_text(house_style, H), _, fail) -> true ; H = "" ),
    ( catch(le_syntax_summary(S), _, fail) -> true ; S = "" ),
    string_length(H, HL), string_length(S, SL),
    T is (HL + SL) // 4 + 400.        % + the stage prompt itself

%!  format_cost(+USD, -String) is det.
format_cost(C, S) :-
    (   number(C), C < 0.01
    ->  S = "less than $0.01"
    ;   number(C)
    ->  format(string(S), "$~2f", [C])
    ;   S = "an unknown amount"
    ).

%!  holdout_split(+Config, +CaseTexts, -DevCases, -HeldCases) is det.
%
%   Held-out-case scoring (feature `holdout`): develop against most of the
%   cases and keep the last quarter (at least one) blind for evaluation.
%   `auto`/true enable it when there are at least two cases; a single case is
%   never held out.
%
%   The split used to be "the first case develops, ALL the rest are blind",
%   which was defensible when a case was a whole file and there were two of
%   them. With a JSON claims file split into seventeen cases it starved the
%   drafting stage of examples (one case, sixteen blind) and cost an LLM call
%   per held-out case per branch.
holdout_split(Config, CaseTexts, DevCases, HeldCases) :-
    H = Config.features.holdout,
    length(CaseTexts, N),
    (   ( H == false ; N < 2 )
    ->  DevCases = CaseTexts, HeldCases = []
    ;   NHeld is max(1, N // 4),
        NDev is N - NHeld,
        length(DevCases, NDev),
        append(DevCases, HeldCases, CaseTexts)
    ).

% --------------------------- Existing LE code --------------------------------
% Optional user-supplied Logical English (templates, scenarios with expected
% answers, rules — any combination) that the generated program must contain:
% the user's way of forcing the twin to align with a program they have already
% started. It is injected into every prompt that writes or repairs the program
% (as the {{existing}} slot), and what became of it is checked and reported.

note_existing_code(_JobID, Config) :- Config.existing == none, !.
note_existing_code(JobID, Config) :-
    Text = Config.existing,
    string_length(Text, Chars),
    existing_lines(Text, Lines), length(Lines, NLines),
    save_text_artifact(JobID, 'existing.le', Text),
    ca_emit(JobID, "Existing LE code supplied: ~w chars, ~w significant line(s) — the program must incorporate them"-[Chars, NLines]).

%!  existing_block(+Config, -Block) is det.
%
%   The prompt fragment substituted for {{existing}}: empty when the user
%   supplied nothing, so the prompts read naturally in both cases.
existing_block(Config, Block) :-
    (   Config.existing == none
    ->  Block = ""
    ;   format(string(Block),
"\n\n## EXISTING LOGICAL ENGLISH CODE (supplied by the user — binding)\n\nThe user has already written the Logical English below. It is not a\nsuggestion: the program you produce MUST be a coherent whole that contains\nit.\n\n- Reuse these templates VERBATIM (same words, same argument order, same\n  epistemic markers); never rename, re-word or duplicate them under another\n  phrasing. Add new templates only for what is missing.\n- Keep the given scenarios, their facts and their `expects answers` lines\n  EXACTLY as written: they are the user's ground truth, and the rules must be\n  written so that these expectations hold. If an expectation seems to\n  contradict the contract, keep it and flag the conflict in a\n  `% Conflict with clause ...:` comment — never silently change or drop it.\n- Keep the given rules and facts, adapting only what the contract clearly\n  contradicts, and say so in a `%` comment.\n- Everything else you write must fit this vocabulary and these conventions.\n\n```le\n~w\n```\n",
               [Config.existing])
    ).

%!  instructions_block(+Config, -Block) is det.
%
%   The user's own additional instructions, verbatim, in every prompt that
%   writes or repairs the program. They are the escape hatch from the house
%   defaults (they can ask for extra scenarios, a particular decomposition, a
%   naming convention) — so they come LAST in the prompt and say plainly that
%   they win.
instructions_block(Config, Block) :-
    (   Config.get(instructions, none) == none
    ->  Block = ""
    ;   format(string(Block),
"\n\n## ADDITIONAL INSTRUCTIONS FROM THE USER\n\nThese are the user's own instructions for this job. Where they conflict with a\ndefault above (but never with the Logical English syntax rules), FOLLOW THEM.\n\n~w\n",
               [Config.instructions])
    ).

%!  scenarios_block(+Config, +NCases, -Block) is det.
%
%   Scenarios are FACT PATTERNS. Inventing one means inventing a case the user
%   never described and then asserting what the contract does with it — so the
%   default is: exactly the cases supplied, plus whatever scenarios came with
%   the user's own LE code, and nothing else. (A drafting model left to itself
%   produces a dozen plausible claims and their outcomes, which then read like
%   findings.) The user's additional instructions can lift this.
scenarios_block(Config, NCases, Block) :-
    ( Config.existing == none -> Existing = "" ; Existing = " plus any scenario already present in the EXISTING LOGICAL ENGLISH CODE (kept verbatim)" ),
    (   NCases =:= 0
    ->  format(string(What), "NO case was supplied, so write NO scenarios at all~w", [Existing])
    ;   format(string(What), "write EXACTLY one scenario per supplied case — ~w cases were supplied, so the program must contain ~w scenarios~w", [NCases, NCases, Existing])
    ),
    format(string(Block),
"\n\n## SCENARIOS — WHAT YOU MAY AND MAY NOT WRITE\n\n~w. Each case in the CASES material is a case in its own right, however\nshort it looks, and gets its own scenario named after its identifier where it\nhas one (`scenario SYN-01-C3 is:`). Never merge two cases into one scenario and\nnever leave a case without one. Where a case carries the schedule entry it\nrefers to, that entry's parameters are facts of that scenario. Where a case\nstates its own expected outcome, that outcome IS the expectation.\n\nDo NOT invent extra scenarios: no adversarial variants, no boundary cases,\nno \"illustrative\" claims. An invented scenario is a fact pattern the user never\ndescribed, together with an outcome nobody asked you to assert.\n\nThe only exception: if the ADDITIONAL INSTRUCTIONS section explicitly asks for\nmore scenarios, write those — and only those.\n\nThe queries themselves are NOT scenarios: write the queries the decision\nsurface needs, even when there are no scenarios to exercise them.\n",
           [What]).

%!  existing_coverage(+Config, +Program, -Report:dict) is det.
%
%   How much of the user's code survived into the delivered program: the
%   fraction of its significant lines (comments and blank lines ignored,
%   whitespace normalised) that appear in the program. Purely informational —
%   an LLM may legitimately re-indent or reword a line — but a low number is
%   exactly what the user wants to be told about.
existing_coverage(Config, _Program, _{enabled: false}) :- Config.existing == none, !.
existing_coverage(Config, Program, Report) :-
    existing_lines(Config.existing, Wanted),
    existing_lines(Program, Have),
    partition([L]>>memberchk(L, Have), Wanted, Kept, Missing),
    length(Wanted, N), length(Kept, K),
    ( N =:= 0 -> Pct = 100 ; Pct is round(100 * K / N) ),
    first_n(5, Missing, Shown),
    Report = _{enabled: true, lines: N, kept: K, percent: Pct, missing: Shown}.

first_n(N, List, Prefix) :-
    length(List, Len),
    Take is min(N, Len),
    length(Prefix, Take),
    append(Prefix, _, List).

% Significant lines of an LE fragment: no blanks, no comment lines, whitespace
% normalised so indentation changes do not count as a loss.
existing_lines(Text, Lines) :-
    split_string(Text, "\n", "", Raw),
    findall(L, ( member(R, Raw),
                 normalize_space(string(L), R),
                 L \== "",
                 \+ string_concat("%", _, L) ),
            Lines).

% ------------------------- Stage 1: vocabulary -------------------------------

%!  vocabulary_consensus(+JobID, +Config, +Materials, -Vocabulary) is det.
%
%   K samples, merged. A sample that FAILS is not fatal: the whole point of
%   drawing K of them is that they are independent, and a flaky provider that
%   drops one call must not throw away the ones that worked (a job with K=5 has
%   died on the second sample with a first sample already in hand). Only the
%   loss of every sample ends the job.
vocabulary_consensus(JobID, Config, Materials, Vocabulary) :-
    K = Config.k,
    existing_block(Config, Existing),
    instructions_block(Config, Instructions),
    numlist(1, K, Ks),
    findall(Sample,
            ( member(I, Ks),
              ca_check_alive(JobID),
              Temp is 0.05 + 0.2 * (I - 1),
              sampling_note(JobID, Temp, Note),
              ca_emit(JobID, "Vocabulary sample ~w/~w (~w)"-[I, K, Note]),
              catch(stage_llm(JobID, Config, vocabulary, 'stage1_vocabulary',
                              [existing-Existing, instructions-Instructions,
                               materials-Materials],
                              [temperature(Temp)], Sample),
                    error(contract_assistant_error(SErr), _),
                    ( short_stage_error(SErr, SShort),
                      ca_emit(JobID, "Vocabulary sample ~w/~w failed (~w); continuing with the samples that worked"-[I, K, SShort]),
                      fail ))
            ),
            Samples),
    (   Samples == []
    ->  throw(error(contract_assistant_error("every vocabulary sample failed — see the run log for the per-sample errors"), _))
    ;   Samples = [Vocabulary]
    ->  true
    ;   length(Samples, NS),
        ( NS < K -> ca_emit(JobID, "~w of ~w vocabulary samples usable"-[NS, K]) ; true ),
        ca_emit(JobID, "Merging ~w vocabulary samples (consensus)"-[NS]),
        atomic_list_concat(Samples, "\n\n===== NEXT SAMPLE =====\n\n", Joined),
        stage_llm(JobID, Config, vocabulary_merge, 'stage1_merge',
                  [existing-Existing, instructions-Instructions, samples-Joined],
                  [temperature(0)], Vocabulary)
    ).

% The one-line form of a stage error, for a log line that says what was lost
% without repeating a 300-character provider trace.
short_stage_error(llm_failed(_, ES), Short) :- !, first_chars(ES, 120, Short).
short_stage_error(empty_reply(_, Model), Short) :- !,
    format(string(Short), "empty reply from ~w", [Model]).
short_stage_error(llm_truncated(_, Model), Short) :- !,
    format(string(Short), "truncated reply from ~w", [Model]).
short_stage_error(E, Short) :- term_string(E, S), first_chars(S, 120, Short).

first_chars(S0, N, S) :-
    term_string(S0, Str),
    string_length(Str, L),
    ( L =< N -> S = Str ; sub_string(Str, 0, N, _, Cut), string_concat(Cut, "…", S) ).

% What makes this sample differ from its siblings — a temperature, or (once
% the provider has refused one) the model's own sampling.
sampling_note(JobID, Temp, Note) :-
    (   ca_tune(JobID, no_temperature)
    ->  Note = "provider default sampling"
    ;   format(string(Note), "temperature ~2f", [Temp])
    ).

architecture_sketches(JobID, Config, Materials, Vocabulary, Sketches) :-
    W = Config.w,
    existing_block(Config, Existing),
    instructions_block(Config, Instructions),
    architecture_angles(Angles0),
    length(Angles, W), append(Angles, _, Angles0),
    % As with the samples: one sketch lost to a flaky provider costs a branch,
    % not the job. Losing all of them is a real failure.
    findall(Sketch,
            ( nth1(I, Angles, Angle),
              ca_check_alive(JobID),
              ca_emit(JobID, "Architecture sketch ~w/~w (~w)"-[I, W, Angle]),
              Temp is 0.05 + 0.1 * (I - 1),
              catch(stage_llm(JobID, Config, architecture, 'stage1_architecture',
                              [existing-Existing, instructions-Instructions,
                               materials-Materials, vocabulary-Vocabulary, angle-Angle],
                              [temperature(Temp)], Sketch),
                    error(contract_assistant_error(SErr), _),
                    ( short_stage_error(SErr, SShort),
                      ca_emit(JobID, "Architecture sketch ~w/~w failed (~w); continuing with the sketches that worked"-[I, W, SShort]),
                      fail ))
            ),
            Sketches),
    (   Sketches == []
    ->  throw(error(contract_assistant_error("every architecture sketch failed — see the run log for the per-sketch errors"), _))
    ;   true
    ).

% Rotating decomposition angles for the beam (pattern library of the plan).
architecture_angles([
    "entitlement-style: decision = qualifies for a cover/right AND NOT excluded AND conditions met; exceptions as positive rules defeated by negation as failure",
    "obligation-style: model duties and breaches first; the decision predicates ask whether an obligation was breached and with what consequence",
    "computation-style: model the amount cascade first (limits, deductions, aggregations) and hang the qualitative tests off it",
    "event-style: model events and their temporal ordering first; decisions are queries over the event history",
    "definition-style: mirror the contract's defined terms one-to-one as derived predicates and compose decisions from them"
]).

% --------------------- Stages 2-5: draft and repair --------------------------

run_branch(JobID, Config, Ctx, Idx-Sketch, Out) :-
    catch(
        run_branch_(JobID, Config, Ctx, Idx-Sketch, Out),
        error(contract_assistant_error(BErr), _),
        ( term_string(BErr, BErrS),
          ca_emit(JobID, "Branch ~w FAILED (~w); the other branches continue"-[Idx, BErrS]),
          ca_set_branch(JobID, Idx, _{state: "failed", summary: BErrS}),
          Out = failed(Idx) )).

run_branch_(JobID, Config, Ctx, Idx-Sketch, branch(Idx, Final, Score)) :-
    ca_set_branch(JobID, Idx, _{state: "drafting"}),
    ca_check_alive(JobID),
    (   Config.features.clausewise == true
    ->  clausewise_draft(JobID, Config, Ctx, Idx, Sketch, Draft0)
    ;   existing_block(Config, Existing),
        instructions_block(Config, Instructions),
        length(Ctx.dev_cases, NCases),
        scenarios_block(Config, NCases, Scenarios),
        stage_llm(JobID, Config, draft(Idx), 'stage2_draft',
                  [existing-Existing, instructions-Instructions, scenarios-Scenarios,
                   materials-Ctx.materials,
                   vocabulary-Ctx.vocabulary, architecture-Sketch],
                  [temperature(0.05)], DraftReply),
        extract_le_code(DraftReply, Draft0),
        % A draft cut off by the provider's completion cap has no earlier
        % version to fall back on: say so, loudly, so the run log explains the
        % half-a-contract the repair loop is about to work on.
        (   unterminated_fence(DraftReply)
        ->  ca_emit(JobID, "Branch ~w: WARNING — the draft reply was cut off mid-program (unterminated code fence). Raise the completion-token cap, or narrow the target section."-[Idx])
        ;   true
        )
    ),
    branch_artifact_name(Idx, draft, DraftName),
    save_text_artifact(JobID, DraftName, Draft0),
    string_length(Draft0, DraftLen),
    ca_emit(JobID, "Branch ~w: draft extracted (~w chars)"-[Idx, DraftLen]),
    repair_loop(JobID, Config, Idx, Draft0, 0, none, 0, "", Repaired0, _),
    % Free, deterministic clean-up first, so the polish rounds spend their LLM
    % calls on warnings that actually need judgement.
    prune_pass(JobID, Config, Idx, Repaired0, Pruned),
    polish_loop(JobID, Config, Idx, Pruned, 0, Repaired, Score0),
    holdout_extend(JobID, Config, Ctx, Idx, Repaired, Score0, Final, Score),
    branch_artifact_name(Idx, final, FinalName),
    save_text_artifact(JobID, FinalName, Final),
    ca_set_branch(JobID, Idx, _{state: "done", summary: Score.summary,
                                errors: Score.errors, warnings: Score.warnings,
                                tests_passed: Score.tests_passed, tests_failed: Score.tests_failed}).

is_live_branch(branch(_, _, _)).

branch_artifact_name(Idx, Kind, Name) :-
    atomic_list_concat([branch_, Idx, '_', Kind, '.le'], Name).

% ----------------- Clause-wise drafting with a live ledger -------------------
% Feature `clausewise` (off by default: more calls and a fragile assembly, but
% the ledger is built as generation proceeds instead of post-hoc). The wording
% slice is walked block by block; each call extends the program and returns
% the block's ledger entries; a final call adds schedule facts, scenarios and
% queries.

clausewise_draft(JobID, Config, Ctx, Idx, Sketch, Draft) :-
    segment_markdown(Ctx.wording, Secs),
    split_string(Ctx.wording, "\n", "", Lines),
    findall(Blk, ( member(Sec, Secs), section_lines(Lines, Sec, Blk),
                   \+ normalize_space(string(""), Blk) ), Blocks),
    length(Blocks, NB),
    ca_emit(JobID, "Branch ~w: clause-wise drafting over ~w blocks"-[Idx, NB]),
    foldl(clausewise_block(JobID, Config, Ctx, Idx, Sketch, NB), Blocks,
          ""-[]-1, Program1-LedgerLines-_),
    ca_check_alive(JobID),
    findall(CB, ( nth1(I, Ctx.dev_cases, CT),
                  format(string(CB), "### CASE ~w\n\n~w", [I, CT]) ), CBs),
    atomic_list_concat(CBs, "\n\n", CasesBlock),
    existing_block(Config, Existing),
    instructions_block(Config, Instructions),
    length(Ctx.dev_cases, NCases),
    scenarios_block(Config, NCases, Scenarios),
    stage_llm(JobID, Config, finalize(Idx), 'stage2_finalize',
              [existing-Existing, instructions-Instructions, scenarios-Scenarios,
               program-Program1, schedule-Ctx.schedule,
               cases-CasesBlock, vocabulary-Ctx.vocabulary],
              [temperature(0.05)], Reply),
    extract_le_code(Reply, Draft),
    reverse(LedgerLines, Ordered),
    atomic_list_concat(Ordered, "\n", LiveLedger),
    branch_ledger_name(Idx, LedgerName),
    save_text_artifact(JobID, LedgerName, LiveLedger).

clausewise_block(JobID, Config, Ctx, Idx, Sketch, NB, Block, Prog0-Led0-I, Prog-Led-I1) :-
    ca_check_alive(JobID),
    ca_emit(JobID, "Branch ~w: clause block ~w/~w"-[Idx, I, NB]),
    existing_block(Config, Existing),
    instructions_block(Config, Instructions),
    stage_llm(JobID, Config, clause(Idx, I), 'stage2_clause',
              [existing-Existing, instructions-Instructions, program-Prog0, clause-Block,
               vocabulary-Ctx.vocabulary, architecture-Sketch],
              [temperature(0.05)], Reply),
    (   extract_tagged_block(Reply, le, Prog1) -> Prog = Prog1
    ;   extract_le_code(Reply, Prog)
    ),
    (   extract_tagged_block(Reply, ledger, L) -> Led = [L|Led0]
    ;   Led = Led0
    ),
    I1 is I + 1.

branch_ledger_name(Idx, Name) :-
    atomic_list_concat([branch_, Idx, '_ledger_live.md'], Name).

% -------------------- Blind held-out case evaluation -------------------------
% For each held-out case, an LLM call writes the scenario (facts + expected
% outcomes) from the case text and the contract — the repair loop never saw
% these. The scenarios are appended, the program is re-verified, and the score
% gains holdout_passed/holdout_failed, ranked ABOVE development test failures.

holdout_extend(_JobID, _Config, Ctx, _Idx, Text, Score0, Text, Score) :-
    Ctx.held_cases == [], !,
    Score = Score0.put(_{holdout_passed: 0, holdout_failed: 0}).
holdout_extend(JobID, Config, Ctx, Idx, Text, Score0, Final, Score) :-
    ca_set_branch(JobID, Idx, _{state: "held-out evaluation"}),
    length(Ctx.held_cases, NH),
    ca_emit(JobID, "Branch ~w: writing scenarios for ~w held-out case(s)"-[Idx, NH]),
    findall(Block,
            ( nth1(I, Ctx.held_cases, CT),
              ca_check_alive(JobID),
              HoldIdx is 100 * Idx + I,   % scenario names must not collide
              stage_llm(JobID, Config, holdout(Idx, I), 'holdout_scenarios',
                        [program-Text, case-CT, casenumber-HoldIdx],
                        [temperature(0)], Reply),
              extract_le_code(Reply, Block)
            ),
            Blocks),
    atomic_list_concat(Blocks, "\n\n", HoldBlock),
    format(string(Final), "~w\n\n% ── Held-out case scenarios (blind evaluation) ──\n\n~w\n",
           [Text, HoldBlock]),
    verify_le_text(Final, VAll),
    HP0 is VAll.tests_passed - Score0.tests_passed,
    HF0 is (VAll.tests_failed - Score0.tests_failed) + max(0, VAll.errors - Score0.errors),
    HP is max(0, HP0), HF is max(0, HF0),
    score_summary(VAll, Summary0),
    HT is HP + HF,
    format(string(Summary), "~w; held-out: ~w/~w", [Summary0, HP, HT]),
    branch_score(VAll, Summary, Score1),
    Score = Score1.put(_{holdout_passed: HP, holdout_failed: HF}),
    ca_emit(JobID, "Branch ~w held-out: ~w passed, ~w failed"-[Idx, HP, HF]).

%!  repair_loop(+JobID, +Config, +Idx, +Text, +Iter, +Best0, +Streak, +Note, -Final, -Score)
%
%   Iterates verify -> feedback -> LLM repair. Keeps the best-ranked version
%   seen so far (a repair can make things worse) and returns that one when
%   the loop ends without reaching a clean program.
%
%   It also WORKS FROM that best version. A round whose result ranks worse used
%   to become the base of every later round, so a branch that had reached one
%   error spent the rest of its budget patching the 77-error rewrite that
%   replaced it. Now the next prompt carries the best program, and says what
%   happened to the attempt that was thrown away — otherwise the model, at
%   temperature 0, would simply send it again.
%
%   Note is what to tell the model about the previous round (a refused rewrite);
%   "" for the first iteration.
%
%   The loop is progress-aware, not a fixed count: Config.repairs is the
%   PATIENCE — how many consecutive non-improving iterations are tolerated —
%   and iterating continues while repairs keep improving the rank, up to a
%   hard cap of max(3 x patience, 8) and always within the wall-clock budget.
%   (A fixed count wasted the budget: a Draft run would stop after 2 rounds
%   with 51 errors and 14 of its 15 minutes unused.)
repair_loop(JobID, Config, Idx, Text, Iter, Best0, Streak0, Note, Final, Score) :-
    verify_le_text(Text, V),
    score_summary(V, Summary),
    ca_set_branch(JobID, Idx, _{state: "repairing", iteration: Iter, summary: Summary,
                                errors: V.errors, warnings: V.warnings,
                                tests_passed: V.tests_passed, tests_failed: V.tests_failed}),
    ca_emit(JobID, "Branch ~w iteration ~w: ~w"-[Idx, Iter, Summary]),
    Cand = cand(Text, V, Summary),
    best_of(Best0, Cand, Best),
    (   ( Best0 == none ; Best == Cand )
    ->  Streak = 0                       % first iteration, or rank improved
    ;   Streak is Streak0 + 1
    ),
    Patience = Config.repairs,
    HardCap is max(3 * Patience, 8),
    (   ( V.errors =:= 0, V.tests_failed =:= 0, V.tests_passed > 0 )
    ->  Final = Text, branch_score(V, Summary, Score)
    ;   Streak >= Patience
    ->  ca_emit(JobID, "Branch ~w: no improvement in ~w consecutive repair round(s), keeping the best iteration"-[Idx, Streak]),
        best_result(Best, Final, Score)
    ;   Iter >= HardCap
    ->  ca_emit(JobID, "Branch ~w: hard repair cap (~w) reached, keeping the best iteration"-[Idx, HardCap]),
        best_result(Best, Final, Score)
    ;   deadline_exceeded(Config)
    ->  ca_emit(JobID, "Branch ~w: wall-clock budget exhausted, keeping the best iteration"-[Idx]),
        best_result(Best, Final, Score)
    ;   ca_check_alive(JobID),
        % Repair the BEST program known, not whatever the last round left.
        (   Best = cand(BestText, BestV, _), BestText \== Text
        ->  ca_emit(JobID, "Branch ~w: iteration ~w ranks worse than the best so far; continuing from the best version"-[Idx, Iter]),
            format(string(Rewind),
                   "\n\nYOUR PREVIOUS ATTEMPT WAS DISCARDED: it left the program with ~w error(s) and ~w failing test(s), worse than the version below. Do not send it again.\n",
                   [V.errors, V.tests_failed]),
            WorkText = BestText, WorkV = BestV
        ;   Rewind = "", WorkText = Text, WorkV = V
        ),
        rewrite_policy(Config, WorkV, Policy),
        format_verify_feedback(WorkV, Feedback0),
        atomics_to_string([Note, Rewind, Feedback0], Feedback),
        % A failed repair call (truncation, provider outage after retries)
        % must not abort the branch — the best iteration so far is a result.
        existing_block(Config, Existing),
        instructions_block(Config, Instructions),
        scenarios_block(Config, Config.get(n_dev_cases, 0), Scenarios),
        catch(
            ( stage_llm(JobID, Config, repair(Idx, Iter), 'stage5_repair',
                        [existing-Existing, instructions-Instructions,
                         scenarios-Scenarios, program-WorkText, feedback-Feedback],
                        [temperature(0)], Reply),
              Next = reply(Reply) ),
            error(contract_assistant_error(_), _),
            Next = failed),
        (   Next = reply(R)
        ->  safe_apply_repair_reply(Config, Policy, R, WorkText, Text1, How),
            ca_emit(JobID, "Branch ~w repair ~w: ~w"-[Idx, Iter, How]),
            refusal_note(How, WorkV, Note1),
            dedup_pass(JobID, Config, Idx, Text1, Text2),
            Iter1 is Iter + 1,
            repair_loop(JobID, Config, Idx, Text2, Iter1, Best, Streak, Note1, Final, Score)
        ;   ca_emit(JobID, "Branch ~w: repair call failed; keeping the best iteration"-[Idx]),
            best_result(Best, Final, Score)
        )
    ).

%!  refusal_note(+How, +V, -Note) is det.
%
%   What the next prompt must say when this round's reply was thrown away for
%   being a rewrite. Without it the model — asked the same question about the
%   same program at temperature 0 — sends the same whole program again, and the
%   branch burns its patience on identical refusals.
refusal_note(How, V, Note) :-
    (   sub_string(How, _, _, _, "refused")
    ->  format(string(Note),
"\n\nYOUR PREVIOUS REPLY WAS REFUSED. It replaced the whole program instead of editing it. The program below is ~w error(s) from loading cleanly, and a rewrite throws away everything that already works — every scenario, every rule that verifies. Reply with SEARCH/REPLACE edit blocks ONLY, one per thing you are fixing, each SEARCH copied EXACTLY from the program below. Do not output the program.\n",
               [V.errors])
    ;   Note = ""
    ).

atomics_to_string(Parts, String) :-
    exclude(==(""), Parts, Kept),
    atomic_list_concat(Kept, "", Joined),
    atom_string(Joined, String).

% ==================== Deterministic clean-up (no LLM call) ===================
%
% Some warnings need no judgement, and paying a polish round for them is slower
% AND less reliable than doing them here. Asked to silence an
% `undefined_predicate`, a drafting model has been observed inventing
%
%     a claim is a claim for court attendance compensation
%         if the claim is a claim for court attendance compensation
%         and the claim is a claim for court attendance compensation.
%
% under a comment announcing "default-false rules": a tautology that means
% nothing, cannot succeed, and silences the warning. The model spends tokens
% writing it and the reader spends attention discarding it.
%
% This pass removes that kind of rule outright, before the polish rounds see
% the program, and never calls an LLM. Everything it deletes is decided from
% the parsed program, and the result is verified: if the pruned program is
% worse by any measure, the original is kept (prune_accepted/2).

%!  dedup_pass(+JobID, +Config, +Idx, +Text0, -Text) is det.
%
%   Deletes what the program says twice — a template declared twice, a rule or
%   fact written twice — after EVERY repair round, without an LLM call and
%   without asking anyone.
%
%   Models fed a JSON array of seventeen similar claims write a template per
%   claim: GLM-5.2 produced page after page of `*a claim* involves a scenario
%   tested of *a description*` under different names. Duplicates cost tokens in
%   every later prompt, pull the vocabulary apart (two templates for one
%   predicate make its type ambiguous) and raise warning counts that the polish
%   rounds then spend LLM calls on. Removing an exact repetition cannot change
%   what the program decides, so this needs no verification gate: what stays is
%   the FIRST occurrence, in its place.
dedup_pass(JobID, Config, Idx, Text0, Text) :-
    catch(dedup_program(Config, Text0, Text1, Report), Error,
          ( term_string(Error, EStr),
            ca_emit(JobID, "Branch ~w: de-duplication skipped (~w)"-[Idx, EStr]),
            Report = none, Text1 = Text0 )),
    (   Report == none ; Report.deleted =:= 0
    ->  Text = Text0
    ;   ca_emit(JobID, "Branch ~w: removed ~w duplicate declaration(s) (~w template(s), ~w rule(s)/fact(s))"-
                       [Idx, Report.deleted, Report.templates, Report.rules]),
        Text = Text1
    ).

%!  dedup_program(+Config, +Text0, -Text, -Report) is det.
%
%   Report is _{deleted: N, templates: N1, rules: N2}.
dedup_program(Config, Text0, Text, Report) :-
    le_kbs:load_text(Text0, KB),
    protected_lines(Config, Protected),
    findall(Kind-(S-E),
            ( redundant_declaration(KB, Kind, Ref),
              clause(KB:le_source_info(Ref, S0, E, _), true),
              \+ range_is_protected(Text0, S0, E, Protected),
              extend_over_comment(Text0, S0, E, S) ),
            Found0),
    sort(2, @<, Found0, Found),         % one entry per source range
    pairs_keys_values(Found, Kinds, Ranges),
    delete_ranges(Text0, Ranges, Text1),
    collapse_blank_runs(Text1, Text2),
    dedup_statement_lines(Text2, Text, NF),
    length(Kinds, NC),
    N is NC + NF,
    count_reason(Kinds, template, N1),
    count_reason(Kinds, rule, N2),
    N2F is N2 + NF,
    Report = _{deleted: N, templates: N1, rules: N2F}.

%!  dedup_statement_lines(+Text0, -Text, -N) is det.
%
%   The same FACT written twice. The knowledge base stores it once — asserting
%   `bob is healthy.` twice yields one clause — so the KB pass above cannot see
%   the second line, but it is still there, still costing tokens in every later
%   prompt.
%
%   Textual, and deliberately timid about it: only a line that is a COMPLETE
%   statement (starts at column 0, ends with a period) is compared, and only
%   against earlier such lines of the SAME section. That excludes the two cases
%   where identical lines are meant: the head line of a rule (which does not end
%   with a period — several rules legitimately share one head) and the facts of
%   scenarios (indented, and each scenario states its own).
dedup_statement_lines(Text0, Text, N) :-
    split_string(Text0, "\n", "", Lines),
    foldl(dedup_line, Lines, s([], [], 0), s(RevKept, _, N)),
    reverse(RevKept, Kept),
    atomic_list_concat(Kept, "\n", Joined),
    atom_string(Joined, Text).      % the pipeline passes the program as a string

dedup_line(Line, s(Kept, Seen, N), State) :-
    (   section_header_line(Line)
    ->  State = s([Line|Kept], [], N)          % a new section: forget what was seen
    ;   complete_statement_line(Line, Norm)
    ->  (   memberchk(Norm, Seen)
        ->  N1 is N + 1, State = s(Kept, Seen, N1)
        ;   State = s([Line|Kept], [Norm|Seen], N)
        )
    ;   State = s([Line|Kept], Seen, N)
    ).

% A section header: unindented and ending with ':' (`the knowledge base X
% includes:`, `scenario one is:`, `query who is:`).
section_header_line(Line) :-
    \+ sub_string(Line, 0, 1, _, " "),
    \+ sub_string(Line, 0, 1, _, "\t"),
    normalize_space(string(T), Line),
    T \== "",
    string_concat(_, ":", T).

% An unindented, non-comment line that ends a statement.
complete_statement_line(Line, Norm) :-
    \+ sub_string(Line, 0, 1, _, " "),
    \+ sub_string(Line, 0, 1, _, "\t"),
    normalize_space(string(Norm), Line),
    Norm \== "",
    \+ string_concat("%", _, Norm),
    string_concat(_, ".", Norm).

redundant_declaration(KB, template, Ref) :- duplicate_template(KB, Ref).
redundant_declaration(KB, rule, Ref) :- prunable(KB, duplicate, Ref).

%!  duplicate_template(+KB, -Ref) is nondet.
%
%   A template declared twice — same predicate, same surface words, same
%   additions (`; undefined`, `; opposite`...). Compared as variants, since two
%   declarations of one template parse to dicts with different variables. The
%   EARLIEST declaration is the one that stays.
duplicate_template(KB, Ref) :-
    template_declaration(KB, Dict, Ref, S),
    template_declaration(KB, Dict2, Ref2, S2),
    Ref2 \== Ref,
    S2 < S,
    Dict =@= Dict2.

template_declaration(KB, Dict, Ref, Start) :-
    current_predicate(KB:le_source_info/4),
    KB:le_source_info(Ref, Start, _, template),
    Ref \== none,
    catch(clause(KB:le_dict(Dict), true, Ref), _, fail).

%!  prune_pass(+JobID, +Config, +Idx, +Text0, -Text) is det.
prune_pass(JobID, Config, Idx, Text0, Text) :-
    catch(prune_program(Config, Text0, Text1, Report), Error,
          ( term_string(Error, EStr),
            ca_emit(JobID, "Branch ~w: clean-up pass skipped (~w)"-[Idx, EStr]),
            Report = none, Text1 = Text0 )),
    (   Report == none
    ->  Text = Text0
    ;   Report.deleted =:= 0
    ->  Text = Text0
    ;   verify_le_text(Text0, V0),
        verify_le_text(Text1, V1),
        (   prune_accepted(V0, V1)
        ->  ca_emit(JobID, "Branch ~w clean-up (no LLM call): removed ~w rule(s) — ~w"-[Idx, Report.deleted, Report.summary]),
            Text = Text1
        ;   ca_emit(JobID, "Branch ~w clean-up rejected: removing ~w rule(s) would have left ~w errors, ~w failing test(s); keeping the program"-[Idx, Report.deleted, V1.errors, V1.tests_failed]),
            Text = Text0
        )
    ).

%!  prune_accepted(+Before, +After) is semidet.
%
%   The same rules as a polish round, minus the "strictly fewer warnings"
%   demand: deleting a tautology can leave the warning count unchanged (the
%   predicate it pretended to define becomes undefined instead) and the program
%   is still better off without the pretence.
prune_accepted(V0, V1) :-
    V1.errors =:= 0,
    V1.tests_failed =< V0.tests_failed,
    V1.tests_passed >= V0.tests_passed.

%!  prune_program(+Config, +Text0, -Text, -Report) is det.
%
%   Report is _{deleted: N, tautologies: N1, duplicates: N2, untested: N3,
%   summary: String}.
prune_program(Config, Text0, Text, Report) :-
    delete_junk_rules(Config, Text0, Text1, Reasons),
    % Deleting a fake definition unmasks the warning it was hiding, so fix that
    % properly in the same pass — otherwise the next polish round is invited to
    % invent the tautology all over again.
    mark_scenario_elements(Config, Text1, Text, Marked),
    length(Reasons, N),
    count_reason(Reasons, tautology, N1),
    count_reason(Reasons, duplicate, N2),
    count_reason(Reasons, untested, N3),
    length(Marked, N4),
    prune_summary(N1, N2, N3, N4, Summary),
    Report = _{deleted: N, tautologies: N1, duplicates: N2, untested: N3,
               marked_undefined: N4, summary: Summary}.

delete_junk_rules(Config, Text0, Text, Reasons) :-
    le_kbs:load_text(Text0, KB),
    protected_lines(Config, Protected),
    findall(Reason-(S-E),
            ( prunable(KB, Reason, Ref),
              clause(KB:le_source_info(Ref, S0, E, _), true),
              \+ range_is_protected(Text0, S0, E, Protected),
              extend_over_comment(Text0, S0, E, S) ),
            Found0),
    sort(2, @<, Found0, Found),         % one entry per source range
    pairs_keys_values(Found, Reasons, Ranges),
    delete_ranges(Text0, Ranges, Text1),
    collapse_blank_runs(Text1, Text).

%!  mark_scenario_elements(+Config, +Text0, -Text, -Marked) is det.
%
%   A predicate that rules ASK about but nothing in the program establishes is
%   an `undefined_predicate` warning, and the LE answer to it is one word: mark
%   its template `; undefined` (a scenario element), which says "this comes
%   from the facts of a scenario" and is exactly what the reader needs to know.
%   A drafting model told to clear the warning instead writes a rule that
%   pretends to define it. Doing it here costs nothing and cannot be gamed.
%
%   Only untouched templates are marked: one that already carries an addition
%   (`; opposite`, `; synonym`, `; prepositional`...) is left alone, because
%   `undefined` does not combine with all of them.
mark_scenario_elements(Config, Text0, Text, Marked) :-
    le_kbs:load_text(Text0, KB),
    protected_lines(Config, Protected),
    findall(Label-(S-E),
            ( needs_scenario_element_mark(KB, F, A),
              le_kbs:template_of(KB, F, A, Dict, Label),
              template_declaration_range(KB, Dict, S, E),
              \+ range_is_protected(Text0, S, E, Protected),
              markable_template_text(Text0, S, E) ),
            Found0),
    sort(2, @<, Found0, Found),
    pairs_keys_values(Found, Marked, Ranges),
    % Back to front, so the offsets still line up as the text grows.
    sort(0, @>=, Ranges, Descending),
    foldl(add_undefined_addition, Descending, Text0, Text).

%!  needs_scenario_element_mark(+KB, -F, -A) is nondet.
%
%   Asked about by a rule, established by nothing: no rule head, no fact, no
%   scenario fact (a scenario fact would already make it a scenario element in
%   practice, and marking it then risks nothing but says nothing either).
needs_scenario_element_mark(KB, F, A) :-
    le_kbs:template_of(KB, F, A, _, _),
    \+ le_kbs:is_system_predicate(F/A),
    functor(Head, F, A),
    \+ ( le_kbs:kb_own_predicate(KB, Head), clause(KB:Head, _) ),
    \+ scenario_establishes(KB, F, A),
    used_as_condition(KB, F, A).

scenario_establishes(KB, F, A) :-
    current_predicate(KB:scenario/2),
    KB:scenario(_, Facts),
    member(FactItem, Facts),
    ( FactItem = fact_with_source(Fact, _, _) -> true ; Fact = FactItem ),
    functor(Fact, F, A), !.

used_as_condition(KB, F, A) :-
    current_predicate(KB:le_source_info/4),
    user_rule(KB, _, Body, _),
    Body \== true,
    le_verifier:find_in_body(Body, Literal),
    functor(Literal, F, A), !.

template_declaration_range(KB, Dict, S, E) :-
    current_predicate(KB:le_source_info/4),
    KB:le_source_info(Ref, S, E, template),
    catch(clause(KB:le_dict(Dict), true, Ref), _, fail), !.

%!  markable_template_text(+Text, +S, +E) is semidet.
%
%   The declaration is a plain `... .` with no additions of its own.
markable_template_text(Text, S, E) :-
    template_text(Text, S, E, Decl),
    \+ sub_string(Decl, _, _, _, ";"),
    sub_string(Decl, _, 1, 0, ".").

template_text(Text, S, E, Decl) :-
    L is E - S + 1,
    string_length(Text, Len),
    S >= 0, L > 0, S + L =< Len,
    sub_string(Text, S, L, _, Decl).

add_undefined_addition(S-E, In, Out) :-
    (   template_text(In, S, E, Decl),
        string_concat(Body, ".", Decl)
    ->  string_concat(Body, "; undefined.", Marked),
        After is E + 1,
        sub_string(In, 0, S, _, Before),
        sub_string(In, After, _, 0, Rest),
        atomics_to_string([Before, Marked, Rest], Out)
    ;   Out = In
    ).

atomics_to_string(List, S) :- atomic_list_concat(List, A), atom_string(A, S).

count_reason(Reasons, Reason, N) :-
    include(==(Reason), Reasons, Rs), length(Rs, N).

prune_summary(N1, N2, N3, N4, Summary) :-
    findall(Part,
            ( member(Count-Word, [N1-"tautological", N2-"duplicate",
                                  N3-"reached by no query"]),
              Count > 0,
              format(string(Part), "~w ~w", [Count, Word]) ),
            Parts0),
    (   N4 > 0
    ->  format(string(MarkPart), "~w template(s) marked `; undefined`", [N4]),
        append(Parts0, [MarkPart], Parts)
    ;   Parts = Parts0
    ),
    ( Parts == [] -> Summary = "nothing" ; atomic_list_concat(Parts, ", ", Summary) ).

%!  prunable(+KB, -Reason, -Ref) is nondet.
%
%   A clause that can go without asking anyone.
%
%   `tautology`: every condition of the rule is the head again, so the rule can
%   never conclude anything the head did not already conclude.
prunable(KB, tautology, Ref) :-
    user_rule(KB, Head, Body, Ref),
    Body \== true,
    findall(L, le_verifier:find_in_body(Body, L), Ls),
    Ls \== [],
    forall(member(L, Ls), L =@= Head).
%   `duplicate`: the same rule written twice; the first one stays.
prunable(KB, duplicate, Ref) :-
    user_rule(KB, Head, Body, Ref),
    user_rule(KB, Head2, Body2, Ref2),
    Ref2 \== Ref,
    % Compared WITHOUT the le_at/3 source wrappers: the same rule written twice
    % carries different offsets, and would otherwise never look identical.
    strip_source_wrappers(Body, Plain),
    strip_source_wrappers(Body2, Plain2),
    (Head :- Plain) =@= (Head2 :- Plain2),
    clause(KB:le_source_info(Ref, S, _, _), true),
    clause(KB:le_source_info(Ref2, S2, _, _), true),
    S2 < S.                           % keep the first occurrence
%   `untested`: no query reaches this predicate, so no answer can depend on it.
%   Off unless the caller asks for it (feature `prune_untested`).
prunable(KB, untested, Ref) :-
    prune_untested_enabled,
    user_rule(KB, Head, _, Ref),
    functor(Head, F, A),
    \+ le_kbs:is_system_predicate(F/A),
    \+ le_verifier:is_reachable_from_query(KB, F, A).

%!  strip_source_wrappers(+Term, -Plain) is det.
%
%   Drops the le_at(Goal, Start, End) wrappers the parser adds, so two copies
%   of the same rule compare equal.
strip_source_wrappers(V, V) :- var(V), !.
strip_source_wrappers(le_at(G, _, _), P) :- !, strip_source_wrappers(G, P).
strip_source_wrappers(T, T) :- \+ compound(T), !.
strip_source_wrappers(T, P) :-
    T =.. [F|Args],
    maplist(strip_source_wrappers, Args, Args1),
    P =.. [F|Args1].

%!  user_rule(+KB, -Head, -Body, -Ref) is nondet.
%
%   A clause of the user's program — not a template, scenario, query or any
%   other bookkeeping term that le_source_info also indexes.
user_rule(KB, Head, Body, Ref) :-
    current_predicate(KB:le_source_info/4),
    KB:le_source_info(Ref, _, _, _),
    Ref \== none,
    catch(clause(KB:Head, Body, Ref), _, fail),
    functor(Head, F, A),
    \+ memberchk(F/A, [le_kb/1, le_dict/1, ontology/1, scenario/2, query_info/3,
                       le_expected/4, le_included_resource/3, le_lps_item/3,
                       le_lps_role/2, le_source_section/2, le_issue/6]).

%!  protected_lines(+Config, -Lines) is det.
%
%   The Logical English the USER supplied is binding: the program must contain
%   it (existing_coverage/3 reports on exactly that), so no automatic clean-up
%   may delete it, however unreachable it looks.
protected_lines(Config, Lines) :-
    (   is_dict(Config), Config.get(existing, none) \== none
    ->  split_string(Config.existing, "\n", "", Raw),
        findall(N, ( member(R, Raw), normalize_space(string(N), R), N \== "" ), Lines)
    ;   Lines = []
    ).

range_is_protected(Text, S, E, Protected) :-
    Protected \== [],
    L is E - S + 1,
    sub_string(Text, S, L, _, Chunk),
    split_string(Chunk, "\n", "", Raw),
    member(R, Raw),
    normalize_space(string(N), R), N \== "",
    memberchk(N, Protected), !.

%!  extend_over_comment(+Text, +Start0, +End, -Start) is det.
%
%   A comment left pointing at a rule that is gone is worse than no comment:
%   `% Default-false rules for cover-type predicates` above nothing at all
%   still tells the reader those rules exist. So a deletion swallows the
%   comment lines directly above it — but ONLY when the deleted rule was the
%   last thing they introduce (the line after it is blank or the file ends),
%   so a comment heading a group of rules survives losing one of them.
extend_over_comment(Text, Start0, End, Start) :-
    (   followed_by_blank(Text, End),
        comment_block_start(Text, Start0, Start1)
    ->  Start = Start1
    ;   Start = Start0
    ).

followed_by_blank(Text, End) :-
    string_length(Text, Len),
    After is End + 1,
    (   After >= Len
    ->  true
    ;   sub_string(Text, After, _, 0, Rest),
        split_string(Rest, "\n", "", [Next|_]),
        normalize_space(string(""), Next)
    ).

%!  comment_block_start(+Text, +Start0, -Start) is semidet.
%
%   Walks back over the contiguous comment lines immediately above Start0.
%   Fails when there are none, so nothing is extended.
comment_block_start(Text, Start0, Start) :-
    previous_line(Text, Start0, PS, Line),
    normalize_space(string(Trimmed), Line),
    sub_string(Trimmed, 0, 1, _, "%"),
    !,
    ( comment_block_start(Text, PS, Start) -> true ; Start = PS ).

%!  previous_line(+Text, +Pos, -LineStart, -Line) is semidet.
%
%   The line that ends just before Pos (which is itself a line start).
previous_line(Text, Pos, LineStart, Line) :-
    Pos > 0,
    End is Pos - 1,                     % the newline that ends the line above
    sub_string(Text, End, 1, _, "\n"),
    sub_string(Text, 0, End, _, Head),
    (   sub_string(Head, Before, 1, _, "\n"),
        \+ ( sub_string(Head, Later, 1, _, "\n"), Later > Before )
    ->  LineStart is Before + 1
    ;   LineStart = 0
    ),
    Len is End - LineStart,
    sub_string(Text, LineStart, Len, _, Line).

%!  delete_ranges(+Text0, +Ranges, -Text) is det.
%
%   Ranges are INCLUSIVE character offsets and are applied back to front, so
%   the earlier offsets stay valid as the text shrinks.
delete_ranges(Text0, Ranges, Text) :-
    sort(0, @>=, Ranges, Descending),
    foldl(delete_range, Descending, Text0, Text).

delete_range(S-E, In, Out) :-
    string_length(In, Len),
    S >= 0, S < Len,
    After is min(E + 1, Len),
    sub_string(In, 0, S, _, Before),
    sub_string(In, After, _, 0, Rest),
    string_concat(Before, Rest, Out).

% Deleting a rule leaves the blank lines that surrounded it; three in a row
% read as a missing section.
collapse_blank_runs(Text0, Text) :-
    split_string(Text0, "\n", "", Lines),
    collapse_blanks(Lines, Kept),
    atomic_list_concat(Kept, "\n", Atom),
    atom_string(Atom, Text).

collapse_blanks([], []).
collapse_blanks([L|Ls], Out) :-
    (   normalize_space(string(""), L)
    ->  drop_blanks(Ls, Rest),
        Out = [""|Out1],
        collapse_blanks(Rest, Out1)
    ;   Out = [L|Out1],
        collapse_blanks(Ls, Out1)
    ).

drop_blanks([L|Ls], Rest) :- normalize_space(string(""), L), !, drop_blanks(Ls, Rest).
drop_blanks(Ls, Ls).

%!  prune_untested_enabled is semidet.
%
%   Deleting every rule no query reaches is a judgement about what the twin is
%   FOR, not a clean-up: such a rule is dead for the queries at hand, but it is
%   also the part of the wording that no supplied case happened to exercise.
%   Off by default; the flag turns it on for a job.
prune_untested_enabled :-
    current_prolog_flag(ca_prune_untested, true).

%!  polish_loop(+JobID, +Config, +Idx, +Text0, +Iter, -Text, -Score) is det.
%
%   The repair loop stops as soon as the program is RIGHT: no errors, every
%   scenario expectation passing. That leaves the warnings — dead templates,
%   rules no query reaches, accidental variables — untouched, because nothing
%   in the loop's stopping condition mentions them. On a big generated program
%   that is dozens of trivially fixable warnings shipped to the user.
%
%   So: once the program is right, spend a few bounded rounds making it clean.
%   A polish round is accepted ONLY if it keeps the program right (no errors,
%   no failing test, no test lost) and strictly reduces the warning count;
%   otherwise the previous text is kept. Feature `polish` is the round budget
%   (0 disables).
polish_loop(JobID, Config, Idx, Text0, Iter, Text, Score) :-
    verify_le_text(Text0, V0),
    score_summary(V0, Summary0),
    branch_score(V0, Summary0, Score0),
    Rounds = Config.features.get(polish, 0),
    polishable_warnings(V0, NW0, _),
    (   \+ polish_worthwhile(V0)
    ->  Text = Text0, Score = Score0          % still broken: correctness first
    ;   NW0 =:= 0
    ->  Text = Text0, Score = Score0
    ;   ( \+ number(Rounds) ; Iter >= Rounds )
    ->  Text = Text0, Score = Score0
    ;   deadline_exceeded(Config)
    ->  ca_emit(JobID, "Branch ~w: budget exhausted, ~w warning(s) left unpolished"-[Idx, NW0]),
        Text = Text0, Score = Score0
    ;   ca_check_alive(JobID),
        ca_emit(JobID, "Branch ~w polish ~w: ~w warning(s) to clean up"-[Idx, Iter, NW0]),
        existing_block(Config, Existing),
        instructions_block(Config, Instructions),
        format_warning_feedback(V0, Feedback),
        catch(
            ( stage_llm(JobID, Config, polish(Idx, Iter), 'stage5_polish',
                        [existing-Existing, instructions-Instructions,
                         program-Text0, feedback-Feedback],
                        [temperature(0)], Reply),
              Next = reply(Reply) ),
            error(contract_assistant_error(_), _),
            Next = failed),
        (   Next = reply(R)
        ->  safe_apply_repair_reply(Config, any, R, Text0, Text1, How),
            verify_le_text(Text1, V1),
            (   polish_accepted(V0, V1)
            ->  polishable_warnings(V1, NW1, _),
                Cleaned is NW0 - NW1,
                ca_emit(JobID, "Branch ~w polish ~w: ~w (~w warning(s) gone, ~w left)"-[Idx, Iter, How, Cleaned, NW1]),
                Iter1 is Iter + 1,
                polish_loop(JobID, Config, Idx, Text1, Iter1, Text, Score)
            ;   ca_emit(JobID, "Branch ~w polish ~w rejected (would have left ~w errors, ~w passing / ~w failing tests, ~w warnings); keeping the verified program"-[Idx, Iter, V1.errors, V1.tests_passed, V1.tests_failed, V1.warnings]),
                Text = Text0, Score = Score0
            )
        ;   ca_emit(JobID, "Branch ~w: polish call failed; keeping the verified program"-[Idx]),
            Text = Text0, Score = Score0
        )
    ).

%!  polish_worthwhile(+V) is semidet.
%
%   The program loads and is stable (no errors). Failing tests do NOT block the
%   clean-up: when the repair loop has run out of patience with two stubborn
%   expectations, the other 79 warnings are still worth removing — and
%   polish_accepted/2 guarantees the stubborn tests cannot get worse.
polish_worthwhile(V) :-
    V.errors =:= 0.

%!  polish_accepted(+Before, +After) is semidet.
%
%   Cleaner, and no worse in any way that matters.
polish_accepted(V0, V1) :-
    V1.errors =:= 0,
    V1.tests_failed =< V0.tests_failed,
    V1.tests_passed >= V0.tests_passed,
    polishable_warnings(V0, NW0, _),
    polishable_warnings(V1, NW1, _),
    NW1 < NW0.

%!  polishable_warnings(+V, -Count, -Lines) is det.
%
%   Warnings worth a polish round. A FAILING TEST is reported as a warning too,
%   but the repair loop has already done what it could with those — listing them
%   here would only invite the model to "fix" an expectation it was told not to
%   touch.
polishable_warnings(V, Count, Lines) :-
    findall(L, ( member(I, V.issues),
                 get_dict(severity, I, "warning"),
                 get_dict(type, I, Type), Type \== "failed_test",
                 format(string(L), "- [~w] ~w", [Type, I.message]) ),
            Lines),
    length(Lines, Count).

%!  format_warning_feedback(+V, -Feedback) is det.
%
%   Only the warnings, grouped enough to be actionable and capped so a program
%   with a hundred of them does not blow up the prompt.
format_warning_feedback(V, Feedback) :-
    polishable_warnings(V, N, Ls0),
    first_n(60, Ls0, Ls),
    atomic_list_concat(Ls, "\n", Body),
    (   N > 60
    ->  Rest is N - 60,
        format(string(Feedback), "~w\n- ... and ~w more warning(s) of the same kinds", [Body, Rest])
    ;   Feedback = Body
    ).

%!  safe_apply_repair_reply(+Config, +Policy, +Reply, +OldText, -NewText, -How)
%
%   A reply we cannot digest costs one round, never the job: a 30-minute run
%   died with a stack overflow raised while parsing one malformed repair
%   reply, throwing away five finished branches.
safe_apply_repair_reply(Config, Policy, Reply, OldText, NewText, How) :-
    catch(apply_repair_reply(Config, Policy, Reply, OldText, NewText, How),
          E,
          ( E == contract_interrupt
          ->  throw(E)
          ;   friendly_error(E, ES),
              NewText = OldText,
              format(string(How), "the reply could not be applied (~w); text unchanged", [ES])
          )).

%!  rewrite_policy(+Config, +V, -Policy) is det.
%
%   Whether this round may accept a WHOLE NEW PROGRAM in place of edits.
%
%   Once a branch is within a few errors of loading, a rewrite is not a repair:
%   it is a fresh draft that happens to be prompted with the old one, and it
%   throws away everything that already works. Observed in one run: a branch
%   went 82 → 36 → **1** error, and the next reply — a full program again —
%   put it back to 77, then 21, then 18, and the four remaining rounds went on
%   patching that instead of the version that was one error from clean.
%
%   So while the program is close (at most `max_rewrite_errors`, 5 by default)
%   a rewrite has to EARN its place: `guarded(V)` carries the current
%   verification, and a whole new program is accepted only if it verifies
%   strictly better than the one it would replace (rewrite_accepted/4).
%
%   A guard rather than a refusal on purpose. A flat "edits only" rule
%   deadlocks the loop for a model that cannot produce SEARCH/REPLACE blocks at
%   all: every reply refused, no progress, patience spent on identical rounds.
%   With the feature off the full program IS the repair mechanism, so the policy
%   is `any` and nothing changes.
rewrite_policy(Config, V, Policy) :-
    (   Config.features.diff_repairs == true,
        Floor = Config.features.get(max_rewrite_errors, 5),
        V.errors =< Floor
    ->  Policy = guarded(V)
    ;   Policy = any
    ).

%!  rewrite_accepted(+V0, +OldText, +NewText, -How) is semidet.
%
%   The proposed whole program verifies strictly better than the current one,
%   by the same rank the loop uses to keep its best iteration. Equal is not
%   good enough: an equivalent rewrite is churn, and refusing it sends the model
%   back for edits.
rewrite_accepted(V0, OldText, NewText, How) :-
    verify_le_text(NewText, V1),
    verify_rank(V1, NewText, R1),
    verify_rank(V0, OldText, R0),
    R1 @< R0,
    score_summary(V1, S1), score_summary(V0, S0),
    format(string(How),
           "the whole program in the reply verifies better (~w) than the one it replaces (~w), so it was used",
           [S1, S0]).

rewrite_refused(V0, OldText, NewText, How) :-
    verify_le_text(NewText, V1),
    score_summary(V1, S1), score_summary(V0, S0),
    string_length(OldText, _),
    format(string(How),
           "reply rewrote the whole program instead of editing it, and the rewrite verifies no better (~w) than the program it would replace (~w); refused — text unchanged",
           [S1, S0]).

%!  apply_repair_reply(+Config, +Policy, +Reply, +OldText, -NewText, -How) is det.
%
%   Feature `diff_repairs` (default on): a repair reply may carry
%   SEARCH/REPLACE edit blocks; matching edits are applied to the old text.
%   A full fenced program is the automatic fallback when no edit matches or the
%   feature is off — unless Policy is `edits_only` (see rewrite_policy/3).
apply_repair_reply(Config, Policy, Reply, OldText, NewText, How) :-
    (   Config.features.diff_repairs == true,
        extract_search_replace(Reply, Edits, Malformed),
        Edits \== []
    ->  apply_edits(Edits, OldText, Text1, Applied, Failed),
        malformed_note(Malformed, Note),
        (   Applied > 0
        ->  NewText = Text1,
            format(string(How), "applied ~w edit(s), ~w did not match~w", [Applied, Failed, Note])
        ;   Policy = guarded(V0), first_fenced_block(Reply, Full0),
            \+ contains_edit_markers(Full0),
            \+ contains_elision_marker(Full0),
            \+ amputates(Reply, OldText, Full0, _)
        ->  (   rewrite_accepted(V0, OldText, Full0, How)
            ->  NewText = Full0
            ;   NewText = OldText, rewrite_refused(V0, OldText, Full0, How)
            )
        ;   first_fenced_block(Reply, Full),
            \+ contains_edit_markers(Full),
            \+ contains_elision_marker(Full),
            \+ amputates(Reply, OldText, Full, _)
        ->  NewText = Full, How = "edits did not match; used the full program from the reply"
        ;   first_fenced_block(Reply, Full2), amputates(Reply, OldText, Full2, Why)
        ->  NewText = OldText, How = Why
        ;   NewText = OldText, How = "no usable edit or full program in the reply; text unchanged"
        )
    ;   Policy = guarded(V0), extract_search_replace(Reply, [], _),
        extract_le_code(Reply, Whole),
        \+ contains_edit_markers(Whole),
        \+ contains_elision_marker(Whole),
        \+ amputates(Reply, OldText, Whole, _)
    ->  % Diff repairs are on, the model sent no edit block at all, and the
        % program is close to clean: the rewrite has to earn its place.
        (   rewrite_accepted(V0, OldText, Whole, How)
        ->  NewText = Whole
        ;   NewText = OldText, rewrite_refused(V0, OldText, Whole, How)
        )
    ;   extract_le_code(Reply, NewText0),
        % An unapplied edit block, a program with elided ("% ...") sections and
        % a program that lost most of itself must never masquerade as the
        % program.
        (   contains_edit_markers(NewText0)
        ->  NewText = OldText, How = "reply contained only unapplied edit blocks; text unchanged"
        ;   contains_elision_marker(NewText0)
        ->  NewText = OldText, How = "reply elided sections with '% ...'; text unchanged"
        ;   amputates(Reply, OldText, NewText0, Why)
        ->  NewText = OldText, How = Why
        ;   NewText = NewText0, How = "replaced the full program"
        )
    ).

%!  amputates(+Reply, +OldText, +NewText, -Why) is semidet.
%
%   True when accepting NewText as the whole program would throw most of the
%   program away. Two causes, both seen in one FEMA run: the provider's
%   completion cap cut the reply off mid-program (its code fence never
%   closes), and the model quietly rewrote a 52 kB program as an 8 kB sketch
%   of it — no elision marker, no error, just a contract missing four of its
%   five coverages, which then won the branch selection.
%
%   Small programs are exempt: an early draft legitimately doubles or halves.
amputates(Reply, OldText, NewText, Why) :-
    string_length(OldText, OldLen),
    OldLen > 4000,
    string_length(NewText, NewLen),
    (   unterminated_fence(Reply)
    ->  format(string(Why),
               "reply was cut off mid-program (unterminated code fence, ~w of ~w chars); text unchanged",
               [NewLen, OldLen])
    ;   NewLen < 0.6 * OldLen
    ->  Pct is round(100 * NewLen / OldLen),
        format(string(Why),
               "reply's program is only ~w% of the current one (~w of ~w chars) — treated as truncation, not repair; text unchanged",
               [Pct, NewLen, OldLen])
    ).

% An odd number of ``` fences means the last one was never closed: the reply
% stopped in the middle of the program.
unterminated_fence(Reply) :-
    atom_string(A, Reply),
    atomic_list_concat(Chunks, '```', A),
    length(Chunks, N),
    N > 1, (N - 1) mod 2 =:= 1.

malformed_note(0, "") :- !.
malformed_note(N, Note) :-
    format(string(Note), ", ~w unterminated edit block(s) ignored", [N]).

contains_edit_markers(Text) :-
    sub_string(Text, _, _, _, "<<<<<<< SEARCH").

% "% ... (all rules and templates)"-style placeholders: the model elided
% content instead of outputting the full program. Accepting such a reply as a
% full replacement amputates the program.
contains_elision_marker(Text) :-
    ( sub_string(Text, _, _, _, "\n% ...")
    ; sub_string(Text, 0, _, _, "% ...")
    ; sub_string(Text, _, _, _, "\n...\n")
    ; sub_string(Text, _, _, _, "rest unchanged")
    ; sub_string(Text, _, _, _, "as before)")
    ), !.

%!  extract_search_replace(+Reply, -Edits:list(edit(Search, Replace))) is det.
%!  extract_search_replace(+Reply, -Edits, -Malformed:integer) is det.
%
%   Parses blocks of the form
%       <<<<<<< SEARCH\n <text> \n=======\n <text> \n>>>>>>> REPLACE
%
%   The scan is strictly left-to-right and deterministic: each block ends at
%   the FIRST separator that follows it, and the next block is looked for
%   after that. This matters because models do produce malformed replies —
%   typically a run of '======='/'>>>>>>> REPLACE' pairs under a single
%   '<<<<<<< SEARCH' header. Searching such a chunk nondeterministically
%   pairs every separator with every terminator, so a reply with N stray
%   pairs yields N*(N+1)/2 edits whose texts each span most of the reply:
%   a 50 kB reply was enough to exhaust a 1 Gb stack inside findall/3.
%   A block we cannot parse is skipped (and counted) rather than guessed at,
%   and the scan resumes after its header so later well-formed blocks survive.
extract_search_replace(Reply, Edits) :-
    extract_search_replace(Reply, Edits, _).

extract_search_replace(Reply, Edits, Malformed) :-
    text_to_string(Reply, S0),
    % CRLF replies would otherwise leave a stray '\r' at the end of every
    % SEARCH text, and nothing would ever match.
    split_string(S0, "\r", "", Parts),
    atomics_to_string(Parts, S),
    scan_search_replace(S, Edits),
    % Every terminator we did not consume belonged to a block we could not
    % parse — typically several edits run together under one header. Report
    % them instead of dropping them silently.
    aggregate_all(count, sub_string(S, _, _, _, "\n>>>>>>> REPLACE"), Terminators),
    length(Edits, NEdits),
    Malformed is max(0, Terminators - NEdits).

scan_search_replace(S, Edits) :-
    (   split_once(S, "<<<<<<< SEARCH", _, Rest0)
    ->  skip_rest_of_line(Rest0, Rest),
        (   split_once(Rest, "\n=======", Search, Mid0),
            skip_rest_of_line(Mid0, Mid),
            split_once(Mid, "\n>>>>>>> REPLACE", Replace, Tail),
            Search \== "",         % an empty SEARCH would match anywhere
            % A header inside either half means the model abandoned this block
            % and started another: take the later one, not a text spanning both.
            \+ contains_edit_markers(Search),
            \+ contains_edit_markers(Replace)
        ->  scan_search_replace(Tail, More),
            Edits = [edit(Search, Replace)|More]
        ;   scan_search_replace(Rest, Edits)   % resync on the next header
        )
    ;   Edits = []
    ).

%!  split_once(+String, +Sep, -Before, -After) is semidet.
%
%   First occurrence only, and no choicepoint left behind.
split_once(S, Sep, Before, After) :-
    sub_string(S, B, L, _, Sep), !,
    sub_string(S, 0, B, _, Before),
    A is B + L,
    sub_string(S, A, _, 0, After).

skip_rest_of_line(S, Rest) :-
    ( split_once(S, "\n", _, Rest0) -> Rest = Rest0 ; Rest = "" ).

apply_edits([], Text, Text, 0, 0).
apply_edits([edit(Search, Replace)|Rest], Text0, Text, Applied, Failed) :-
    (   sub_string(Text0, Before, Len, _, Search)
    ->  sub_string(Text0, 0, Before, _, Pre),
        After is Before + Len,
        sub_string(Text0, After, _, 0, Post),
        atomics_to_string([Pre, Replace, Post], Text1),
        apply_edits(Rest, Text1, Text, A0, Failed),
        Applied is A0 + 1
    ;   apply_edits(Rest, Text0, Text, Applied, F0),
        Failed is F0 + 1
    ).

best_of(none, Cand, Cand) :- !.
best_of(cand(T0, V0, S0), cand(T1, V1, S1), Best) :-
    verify_rank(V0, T0, R0),
    verify_rank(V1, T1, R1),
    ( R1 @< R0 -> Best = cand(T1, V1, S1) ; Best = cand(T0, V0, S0) ).

verify_rank(V, Text, rank(NoTests, V.errors, Net, V.tests_failed, V.warnings, Len)) :-
    ( V.tests_passed + V.tests_failed =:= 0 -> NoTests = 1 ; NoTests = 0 ),
    Net is V.tests_failed - V.tests_passed,
    string_length(Text, Len).

best_result(cand(Text, V, Summary), Text, Score) :-
    branch_score(V, Summary, Score).

% The score kept per branch: the scalar fitness fields plus test details for
% the result view (the full issue dicts stay in the artifacts).
branch_score(V, Summary, _{errors: V.errors, warnings: V.warnings,
                           tests_passed: V.tests_passed, tests_failed: V.tests_failed,
                           test_details: V.test_details, summary: Summary}).

% ----------------------- Stage 6: selection & ledger -------------------------

select_winner(_JobID, Branches, Winner) :-
    map_list_to_pairs(branch_rank, Branches, Ranked),
    keysort(Ranked, [_-Winner|_]).

% Rank tuple, lexicographic (the plan's fitness function): having tests AT ALL
% comes first (a clean-verifying program with no scenarios demonstrates
% nothing and must not beat an erroneous one that passes 16/18 tests); then
% fewer errors; better NET held-out evidence (blind evaluation ranks above
% development tests); then better NET development evidence (failed - passed:
% 3/6 passing must beat 0/2); then fewer failures, fewer warnings, and — all
% that being equal — the LARGER program, which encodes more of the contract.
%
% Both evidence terms are NET on purpose. Raw failure counts reward writing
% fewer scenarios, and the held-out term used to be raw: an amputated branch
% that wrote 2 blind tests and failed 1 outranked a complete one that wrote 7
% and failed 2, and the 8 kB program was delivered instead of the 50 kB one.
branch_rank(branch(_, Text, S), rank(NoTests, S.errors, HNet, Net, S.tests_failed, S.warnings, NegLen)) :-
    HNet is S.get(holdout_failed, 0) - S.get(holdout_passed, 0),
    ( S.tests_passed + S.tests_failed =:= 0 -> NoTests = 1 ; NoTests = 0 ),
    Net is S.tests_failed - S.tests_passed,
    string_length(Text, Len), NegLen is -Len.

% ----------------------- Differential interrogation --------------------------
% Feature `probes` (count; 0 = off). The stone as oracle: an LLM reading only
% the raw contract invents probe scenarios with expected outcomes; the
% reasoner is confronted with them. Probes that pass raise confidence and stay
% in the program as extra regression scenarios. Probes that fail are
% disagreements: with `interrogation_repair` they trigger adjudication repair
% rounds (the repair prompt may fix the rules OR the probe's expectation,
% citing the contract). If disagreements survive, the program is reverted to
% its pre-probe state and they are reported as open disagreements/ambiguities.

interrogate(JobID, Config, Ctx, Text0, Text, Report) :-
    P = Config.features.probes,
    (   ( \+ number(P) ; P =< 0 )
    ->  Text = Text0, Report = _{enabled: false}
    ;   deadline_exceeded(Config)
    ->  Text = Text0, Report = _{enabled: false, note: "skipped: budget exhausted"},
        ca_emit(JobID, "Interrogation skipped: budget exhausted"-[])
    ;   verify_le_text(Text0, V0),
        V0.errors > 0
    ->  Text = Text0,
        Report = _{enabled: false, note: "skipped: the winning program still has errors, probes cannot be evaluated"},
        ca_emit(JobID, "Interrogation skipped: the winning program still has errors"-[])
    ;   ca_check_alive(JobID),
        ca_emit(JobID, "Interrogation: generating ~w probe scenario(s)"-[P]),
        verify_le_text(Text0, V0),   % cached load: cheap despite the re-verify above
        stage_llm(JobID, Config, probes, 'probe_scenarios',
                  [materials-Ctx.materials, program-Text0, count-P],
                  [temperature(0.2)], Reply),
        extract_le_code(Reply, ProbeBlock),
        format(string(Merged), "~w\n\n% ── Interrogation probes (LLM reading of the contract) ──\n\n~w\n",
               [Text0, ProbeBlock]),
        save_text_artifact(JobID, 'probes.le', ProbeBlock),
        verify_le_text(Merged, V1),
        probe_delta(V0, V1, Agreed0, Disagreed0),
        ca_emit(JobID, "Interrogation: ~w probe test(s) agree, ~w disagree"-[Agreed0, Disagreed0]),
        (   Disagreed0 =:= 0
        ->  FinalMerged = Merged, VF = V1
        ;   Config.features.interrogation_repair == true,
            \+ deadline_exceeded(Config)
        ->  ca_emit(JobID, "Interrogation: adjudicating ~w disagreement(s)"-[Disagreed0]),
            repair_loop(JobID, Config, probes, Merged, 0, none, 0, "", FinalMerged, _),
            verify_le_text(FinalMerged, VF)
        ;   FinalMerged = Merged, VF = V1
        ),
        probe_delta(V0, VF, AgreedF, DisagreedF),
        (   ( DisagreedF =:= 0, AgreedF > 0, VF.errors =< V0.errors )
        ->  Text = FinalMerged,
            open_disagreements(VF, V0, Open),
            ca_emit(JobID, "Interrogation: all probes agree; probes kept as regression scenarios"-[])
        ;   DisagreedF =:= 0
        ->  Text = Text0, Open = [],
            ca_emit(JobID, "Interrogation: the probes yielded no evaluable tests; probes NOT kept"-[])
        ;   Text = Text0,
            open_disagreements(VF, V0, Open),
            ca_emit(JobID, "Interrogation: ~w open disagreement(s); probes NOT kept (see report)"-[DisagreedF])
        ),
        Report = _{enabled: true, probes_requested: P,
                   agreed: AgreedF, disagreed: DisagreedF,
                   initially_disagreed: Disagreed0,
                   open: Open}
    ).

% Tests added by the probe block = totals of the merged program minus the
% winner's own; failures among them are disagreements (parse errors introduced
% by the probes count as disagreements too).
probe_delta(V0, V1, Agreed, Disagreed) :-
    Agreed0 is V1.tests_passed - V0.tests_passed,
    Agreed is max(0, Agreed0),
    D0 is (V1.tests_failed - V0.tests_failed) + max(0, V1.errors - V0.errors),
    Disagreed is max(0, D0).

% Failing test details that the winner alone did not have — the open
% disagreements shown in the result and worth a human look: either the twin is
% wrong or the contract is ambiguous.
open_disagreements(VF, V0, Open) :-
    findall(D, ( member(D, VF.test_details), D.status == "fail",
                 \+ memberchk(D, V0.test_details) ), Open0),
    (   VF.errors > V0.errors
    ->  NE is VF.errors - V0.errors,
        format(string(Msg), "~w probe sentence(s) did not match the program's templates (invalid probes, not genuine disagreements)", [NE]),
        append(Open0, [_{status: "error", message: Msg}], Open)
    ;   Open = Open0
    ).

% ------------------------- Paraphrase invariance ------------------------------
% Feature `paraphrase` (thorough preset only by default — informational and
% expensive). The wording is paraphrased/reordered, the vocabulary stage is
% re-run on the paraphrase, and a judge compares the result with the consensus
% vocabulary, reporting a stability percentage. A low score means the model
% depends on surface phrasing — worth a human look. Does not affect selection.

paraphrase_check(JobID, Config, Ctx, Report) :-
    (   Config.features.paraphrase \== true
    ->  Report = _{enabled: false}
    ;   deadline_exceeded(Config)
    ->  Report = _{enabled: false, note: "skipped: budget exhausted"},
        ca_emit(JobID, "Paraphrase check skipped: budget exhausted"-[])
    ;   ca_check_alive(JobID),
        ca_emit(JobID, "Paraphrase-invariance check: rewriting the wording"-[]),
        stage_llm(JobID, Config, paraphrase, 'paraphrase',
                  [wording-Ctx.wording], [temperature(0.6)], PText),
        existing_block(Config, Existing),
        instructions_block(Config, Instructions),
        stage_llm(JobID, Config, vocabulary_paraphrase, 'stage1_vocabulary',
                  [existing-Existing, instructions-Instructions, materials-PText],
                  [temperature(0.2)], Sample),
        stage_llm(JobID, Config, paraphrase_compare, 'paraphrase_compare',
                  [vocabulary-Ctx.vocabulary, sample-Sample], [temperature(0)], CmpText),
        ( parse_stability(CmpText, N) -> true ; N = -1 ),
        save_text_artifact(JobID, 'paraphrase_report.md', CmpText),
        ca_emit(JobID, "Paraphrase-invariance stability: ~w%"-[N]),
        Report = _{enabled: true, stability: N, report: CmpText}
    ).

%!  parse_stability(+Text, -Percent) is semidet.
%
%   Finds the first integer after the word STABILITY, however the judge
%   formatted the line (bold markers, spaces before %, ...).
parse_stability(Text, N) :-
    atom_string(TA, Text),
    sub_atom(TA, B, _, _, 'STABILITY'), !,
    sub_atom(TA, B, _, 0, Rest),
    atom_codes(Rest, Cs),
    first_integer(Cs, N).

first_integer(Cs, N) :-
    append(_, [C|Cs1], Cs), code_type(C, digit), !,
    take_digits(Cs1, Ds),
    number_codes(N, [C|Ds]).

take_digits([C|Cs], [C|Ds]) :- code_type(C, digit), !, take_digits(Cs, Ds).
take_digits(_, []).

%!  technicalities(+JobID, +Config, +WinnerIdx, +DeliveredSummary,
%!                  +Interrogation, +Paraphrase, +ExistingReport, -Text) is det.
%
%   A deterministic provenance block appended to the coverage ledger: model
%   and judge, search parameters, resolved completion limit, run date and
%   elapsed time, estimated cost, per-branch outcomes, auto-tunings applied,
%   what became of any user-supplied LE code, and the delivered program's
%   verification summary.
technicalities(JobID, Config, WIdx, DeliveredSummary, Interrogation, Paraphrase,
               ExistingReport, Text) :-
    F = Config.features,
    format_time(string(Date), '%Y-%m-%d %H:%M', Config.started),
    get_time(Now), El is round(Now - Config.started),
    Min is El // 60, Sec is El mod 60,
    format(string(Elapsed), "~w:~|~`0t~w~2+", [Min, Sec]),
    ( Config.judge_model == Config.model -> Judge = "same" ; Judge = Config.judge_model ),
    ( Config.mt_mode == auto -> MTNote = " (auto-calibrated)" ; MTNote = " (user-set)" ),
    ( F.diff_repairs == true -> RepairStyle = diff ; RepairStyle = "full-file" ),
    (   Config.get(instructions, none) == none
    ->  InstrLine = "none"
    ;   normalize_space(string(InstrLine), Config.instructions)
    ),
    format(string(ScenLine), "~w supplied case(s); no scenario invented beyond them",
           [Config.get(n_dev_cases, 0)]),
    findall(BLine,
            ( ca_branch(JobID, BIdx, Info), integer(BIdx),
              ( BIdx =:= WIdx -> Mark = " \u2190 winner" ; Mark = "" ),
              ( get_dict(summary, Info, BSum) -> true ; BSum = Info.get(state, "?") ),
              format(string(BLine), "  - branch ~w: ~w~w", [BIdx, BSum, Mark]) ),
            BLines0),
    msort(BLines0, BLines),
    atomic_list_concat(BLines, "\n", BranchBlock),
    findall(TLine,
            ( ca_tune(JobID, Tune),
              (   Tune == reasoning_minimal
              ->  TLine = "  - minimal reasoning enabled after a truncated call"
              ;   Tune == no_temperature
              ->  TLine = "  - temperature dropped: the provider rejects it for this model (samples varied by the model's own sampling instead)"
              ;   Tune = max_tokens(N)
              ->  format(string(TLine), "  - completion limit raised to ~w after truncation", [N])
              ;   Tune = reasoning_effort(L)
              ->  format(string(TLine), "  - reasoning effort pinned to ~w: the provider rejected the level we asked for", [L])
              ;   Tune == no_reasoning
              ->  TLine = "  - reasoning parameter dropped: the provider named no level it would accept"
              ) ),
            TLines),
    ( TLines == [] -> TuneBlock = "  - none" ; atomic_list_concat(TLines, "\n", TuneBlock) ),
    (   get_dict(enabled, Interrogation, true)
    ->  format(string(ILine), "~w probe test(s) agree, ~w disagree",
               [Interrogation.get(agreed, 0), Interrogation.get(disagreed, 0)])
    ;   ILine = "off"
    ),
    (   get_dict(enabled, Paraphrase, true)
    ->  format(string(PLine), "stability ~w%", [Paraphrase.get(stability, -1)])
    ;   PLine = "off"
    ),
    (   get_dict(enabled, ExistingReport, true)
    ->  format(string(ELine), "~w of ~w supplied line(s) present (~w%)",
               [ExistingReport.kept, ExistingReport.lines, ExistingReport.percent])
    ;   ELine = "none supplied"
    ),
    (   Cost = Config.get(est_cost), number(Cost)
    ->  format_cost(Cost, CostS0),
        format(string(CostS), "~w (estimated before the run, upper bound)", [CostS0])
    ;   CostS = "not estimated"
    ),
    format(string(Text),
"\n\n---\n\n## Technicalities\n\n- Generated: ~w (job ~w)\n- Model: ~w \u00b7 judge: ~w\n- Search: K=~w vocabulary samples \u00b7 W=~w branches \u00b7 repair patience ~w \u00b7 probes ~w \u00b7 holdout ~w\n- Options: ~w repairs \u00b7 reasoning ~w \u00b7 clause-wise ~w \u00b7 paraphrase ~w \u00b7 warning clean-up rounds ~w\n- Scenarios: ~w\n- Additional instructions: ~w\n- Completion limit: ~w tokens/call~w \u00b7 budget ~w min \u00b7 elapsed ~w\n- LLM cost: ~w\n- Target section: ~w\n- Existing LE code: ~w\n- Branches:\n~w\n- Auto-tuning during the run:\n~w\n- Interrogation: ~w \u00b7 Paraphrase: ~w\n- Delivered program: ~w\n",
           [Date, JobID, Config.model, Judge,
            Config.k, Config.w, Config.repairs, F.probes, F.holdout,
            RepairStyle, Config.reasoning, F.clausewise, F.paraphrase, F.get(polish, 0),
            ScenLine, InstrLine,
            Config.max_tokens, MTNote, Config.minutes, Elapsed,
            CostS, Config.target, ELine,
            BranchBlock, TuneBlock, ILine, PLine, DeliveredSummary]).

%!  ledger_coverage(+Ledger, -Todo, -Rows) is det.
%
%   How much of the contract the ledger itself says is still missing: the
%   clause rows of its coverage table whose status is TODO, out of all clause
%   rows. A count, not a judgement — but a twin whose ledger is half TODO is a
%   twin the user has to be told about, and that number was previously buried
%   in a 350-line report nobody reads to the end.
ledger_coverage(Ledger, Todo, Rows) :-
    split_string(Ledger, "\n", " \t\r", Lines),
    findall(L, ( member(L, Lines), string_concat("|", _, L), ledger_clause_row(L) ), Rows0),
    length(Rows0, Rows),
    findall(L, ( member(L, Rows0), sub_string(L, _, _, _, "TODO") ), Todos),
    length(Todos, Todo).

% A row of the coverage table that is about a clause: not the |---|---| rule,
% not the header.
ledger_clause_row(Line) :-
    split_string(Line, "|", " ", Cells),
    exclude(==(""), Cells, [First|_]),
    \+ string_concat("---", _, First),
    \+ separator_cells(Cells),
    First \== "Clause".

separator_cells(Cells) :-
    forall(( member(C, Cells), C \== "" ),
           forall(sub_string(C, _, 1, _, Ch), memberchk(Ch, ["-", ":"]))).

%!  ledger_for(+JobID, +Config, +WordingSlice, +WinnerText, -Ledger) is det.
%
%   The coverage ledger — one LLM call, and the only place the run says what of
%   the contract the twin actually encodes. It is written even when the program
%   still has errors: a clause-by-clause reading of a flawed program is exactly
%   what tells the user whether the flaw is local or whether the twin is empty,
%   and "(ledger skipped)" left them with a broken program and no map of it.
%   Only an exhausted wall-clock budget skips it now, and then the run is over
%   anyway.
ledger_for(JobID, Config, WordingSlice, WinnerText, Ledger) :-
    (   deadline_exceeded(Config)
    ->  Ledger = "(ledger skipped: budget exhausted)"
    ;   ledger_call(JobID, Config, WordingSlice, WinnerText, Ledger0),
        verify_le_text(WinnerText, VW),
        (   VW.errors > 0
        ->  ca_emit(JobID, "Ledger: the winning program still has ~w error(s); audited anyway"-[VW.errors]),
            Total is VW.tests_passed + VW.tests_failed,
            format(string(Ledger),
"> **The program this ledger audits does not load cleanly: ~w error(s), ~w of ~w test(s) passing.**\n> Read \"encoded\" below as \"written down\", not as \"working\": fix the errors first\n> — the run log and the scores say what they are — then re-read this table.\n\n~w",
                   [VW.errors, VW.tests_passed, Total, Ledger0])
        ;   Ledger = Ledger0
        )
    ),
    save_text_artifact(JobID, 'ledger.md', Ledger).

ledger_call(JobID, Config, WordingSlice, WinnerText, Ledger) :-
    catch(
        ( stage_llm(JobID, Config, ledger, 'stage6_ledger',
                    [materials-WordingSlice, program-WinnerText],
                    [temperature(0)], Ledger0),
          % Reasoning models can spend the whole completion budget on
          % reasoning and return empty content; say so instead of showing
          % the user a blank ledger.
          (   normalize_space(string(Norm), Ledger0), Norm == ""
          ->  ca_emit(JobID, "Ledger: the judge model returned an empty reply"-[]),
              Ledger = "(the judge model returned an empty ledger reply — it likely spent its whole output budget before emitting text; pick a different judge model in Setup, or rerun)"
          ;   Ledger = Ledger0
          )
        ),
        E,
        ( term_string(E, ES),
          format(atom(Ledger), "(ledger failed: ~w)", [ES]) )).

% ============================ Verification & scoring ==========================

%!  verify_le_text(+Text, -V:dict) is det.
%
%   Loads the program, collects verifier issues and runs the embedded
%   scenario expectations. Never throws: a program that does not even load
%   comes back as one error issue.
verify_le_text(Text, V) :-
    catch(verify_le_text_(Text, V), Error,
          ( term_string(Error, EStr),
            format(string(Msg),
                   "Program failed to parse/load at all: ~w. Usual causes: asterisked *variables* outside the templates section (rules, facts, scenarios and queries must use plain 'a claim'/'the claim' phrases or ALL-CAPS ids); a malformed section header (each ends with ':'); facts placed after scenarios or queries; a reserved word (if/unless/either) inside a template.",
                   [EStr]),
            V = _{errors: 1, warnings: 0, tests_passed: 0, tests_failed: 0,
                  issues: [_{severity: "error", type: "load_failure", message: Msg}],
                  test_details: []}
          )).

verify_le_text_(Text, V) :-
    le_kbs:load_text(Text, KB),
    findall(_{severity: SevS, type: TypeS, message: MsgS},
            ( KB:le_issue(Sev, Type, Msg, _Fix, _S, _E),
              term_string(Sev, SevS), term_string(Type, TypeS), term_string(Msg, MsgS) ),
            Issues),
    partition_severity(Issues, NErrors, NWarnings),
    (   current_predicate(KB:le_expected/4)
    ->  findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Tests)
    ;   Tests = []
    ),
    maplist(safe_run_test(KB), Tests, TestResults),
    partition(is_pass, TestResults, Passes, Fails),
    length(Passes, NPassed), length(Fails, NFailed),
    maplist(test_detail, TestResults, Details),
    (   \+ kb_has_substance(KB)
    ->  E1 is NErrors + 1,
        EmptyIssue = _{severity: "error", type: "empty_program",
                       message: "The program contains no templates, rules or facts (scenarios alone decide nothing). Output the FULL Logical English program — never elide sections with '% ...' placeholders."},
        Issues1 = [EmptyIssue|Issues]
    ;   \+ kb_has_rules(KB)
    ->  % Templates and scenarios but not one rule. Every query then has no
        % answer, so this is worth an ERROR of its own: an "unknown section"
        % swallowing the whole knowledge base counted as ONE error, which made
        % a twin with no logic in it look nearly clean and win its branch.
        E1 is NErrors + 1,
        NoRules = _{severity: "error", type: "no_rules",
                    message: "The program declares templates but contains NO RULES, so no query can have an answer. Check the knowledge base header: it must read `the knowledge base <name> includes:` or `the contract states that:` — `the knowledge base <name> is:` is not a section header, and everything under it is discarded."},
        Issues1 = [NoRules|Issues]
    ;   E1 = NErrors, Issues1 = Issues
    ),
    (   asterisks_outside_templates(Text, NBadLines)
    ->  NErrors1 is E1 + 1,
        format(string(AMsg),
               "Asterisked *variables* appear OUTSIDE the templates section (~w line(s)). In rules, facts, scenarios and queries write plain phrases ('a claim', 'the claim', 'which claim'), never *asterisks*.",
               [NBadLines]),
        AsteriskIssue = _{severity: "error", type: "asterisks_outside_templates", message: AMsg},
        Issues2 = [AsteriskIssue|Issues1]
    ;   NErrors1 = E1, Issues2 = Issues1
    ),
    V = _{errors: NErrors1, warnings: NWarnings,
          tests_passed: NPassed, tests_failed: NFailed,
          issues: Issues2, test_details: Details}.

%!  asterisks_outside_templates(+Text, -NLines) is semidet.
%
%   True (with a line count) when *variable* markers appear outside the
%   templates/predicates sections — always a mistake that quietly turns
%   scenario constants into variables or breaks rule parsing. Adjacency
%   distinguishes markers (*a claim*) from multiplication (X * Y).
asterisks_outside_templates(Text, NLines) :-
    split_string(Text, "\n", "", Lines),
    foldl(asterisk_line_check, Lines, out-0, _-NLines),
    NLines > 0.

asterisk_line_check(Line, In0-N0, In-N) :-
    normalize_space(string(T), Line),
    (   T == "" -> In = In0, N = N0
    ;   string_concat("%", _, T) -> In = In0, N = N0
    ;   string_concat(_, ":", T)     % a section header line
    ->  N = N0,
        (   ( sub_string(T, _, _, _, "templates are")
            ; sub_string(T, _, _, _, "predicates are")
            ; sub_string(T, _, _, _, "fluents are")
            ; sub_string(T, _, _, _, "events are") )
        ->  In = in
        ;   In = out
        )
    ;   In0 == out, has_asterisk_variable(T)
    ->  In = In0, N is N0 + 1
    ;   In = In0, N = N0
    ).

% A '*' immediately followed by a non-space, with a later '*' immediately
% preceded by a non-space: an *asterisked phrase*, not arithmetic.
has_asterisk_variable(T) :-
    sub_string(T, B, 1, _, "*"),
    B1 is B + 1,
    sub_string(T, B1, 1, _, C1), C1 \== " ",
    sub_string(T, B2, 1, _, "*"), B2 > B1,
    B3 is B2 - 1,
    sub_string(T, B3, 1, _, C2), C2 \== " ",
    !.

% A knowledge base with actual content: at least one user clause (rule or
% fact) or one user-declared template. Imported predicates and the system
% templates that load_text always asserts do not count.
kb_has_substance(KB) :-
    current_predicate(KB:F/A),
    \+ le_kbs:is_system_predicate(F/A),
    \+ sub_atom(F, 0, 3, _, le_),   % le_issue/5 and other engine metadata
    functor(H, F, A),
    \+ predicate_property(KB:H, imported_from(_)),
    clause(KB:H, _), !.
kb_has_substance(KB) :-
    current_predicate(KB:le_dict/1),
    KB:le_dict(D),
    \+ le_system_templates:le_system_template(D), !.

%!  kb_has_rules(+KB) is semidet.
%
%   At least one user clause with a body — a rule, not just a fact. A twin that
%   states only data decides nothing.
kb_has_rules(KB) :-
    current_predicate(KB:F/A),
    \+ le_kbs:is_system_predicate(F/A),
    \+ sub_atom(F, 0, 3, _, le_),
    functor(H, F, A),
    \+ predicate_property(KB:H, imported_from(_)),
    clause(KB:H, Body),
    Body \== true, !.

partition_severity(Issues, NErrors, NWarnings) :-
    partition([I]>>(get_dict(severity, I, "error")), Issues, Es, Ws),
    length(Es, NErrors), length(Ws, NWarnings).

safe_run_test(KB, Test, Result) :-
    catch(le_kbs:run_one_test(KB, Test, Result), E,
          ( Test = test(Q, S, _, _), term_string(E, ES), Result = error(Q, S, ES) )).

is_pass(pass(_, _)).

test_detail(pass(Q, S), _{status: "pass", query: QS, scenario: SS}) :- !,
    term_string(Q, QS), term_string(S, SS).
test_detail(fail(Q, S, E, A), _{status: "fail", query: QS, scenario: SS, expected: ES, actual: AS}) :- !,
    term_string(Q, QS), term_string(S, SS), term_string(E, ES), term_string(A, AS).
test_detail(fail(Q, S, E, A, EU, AU), D) :- !,
    test_detail(fail(Q, S, E-EU, A-AU), D).
test_detail(Other, _{status: "error", message: OS}) :- term_string(Other, OS).

score_summary(V, Summary) :-
    Total is V.tests_passed + V.tests_failed,
    format(string(Summary), "~w errors, ~w warnings, ~w/~w tests passing",
           [V.errors, V.warnings, V.tests_passed, Total]).

format_verify_feedback(V, Feedback) :-
    findall(L, ( member(I, V.issues),
                 format(string(L), "- [~w] ~w", [I.severity, I.message]) ), ILs),
    findall(L, ( member(T, V.test_details), T.status == "fail",
                 format(string(L), "- FAILED test: query '~w' in scenario '~w'~n    expected: ~w~n    actual:   ~w",
                        [T.query, T.scenario, T.expected, T.actual]) ), TLs),
    append(ILs, TLs, Ls0),
    (   V.tests_passed + V.tests_failed =:= 0
    ->  append(Ls0, ["- The program has NO scenario expectations at all: every case must have a scenario with `<queryname> expects answers [...]` lines, plus adversarial variants. A twin without tests demonstrates nothing."], Ls)
    ;   Ls = Ls0
    ),
    ( Ls == [] -> Feedback = "no issues" ; atomic_list_concat(Ls, "\n", Feedback) ).

% ================================ LLM plumbing ================================

%!  stage_llm(+JobID, +Config, +Purpose, +PromptName, +Slots, +Options, -Reply)
%
%   One LLM call: system prompt = house style + LE syntax summary + the stage
%   prompt (with {{slot}} substitutions); user message = remaining big slots.
%   Honors the test hook ca_llm_hook/1.
stage_llm(JobID, Config, Purpose, PromptName, Slots, Options, Reply) :-
    build_messages(PromptName, Slots, Messages),
    (   ca_llm_hook(Hook)
    ->  call(Hook, Purpose, Messages, Reply)
    ;   resolve_model(Purpose, Config, Model, Key),
        stage_options(JobID, Config, Purpose, Key, Options, Opts),
        llm_try(JobID, Config, Purpose, Model, Messages, Opts, 1, Reply)
    ).

%!  stage_options(+JobID, +Config, +Key, +Options, -Opts) is det.
%
%   The stage's own options (temperature...) plus the job-wide ones, honouring
%   the auto-tunings discovered during the run: a raised completion limit,
%   minimal reasoning, and a temperature the provider refuses to hear about
%   (see the temperature clause of llm_outcome/9).
stage_options(JobID, Config, Purpose, Key, Options, Opts) :-
    (   ca_tune(JobID, max_tokens(MT))     % learned during the run: it wins
    ->  true
    ;   purpose_max_tokens(Purpose, Config, MT)
    ),
    call_timeout(Config, T),
    Base = [api_key(Key), max_tokens(MT), timeout(T)],
    (   ca_tune(JobID, no_reasoning)          % the provider refused the parameter
    ->  Extra = Base
    ;   ca_tune(JobID, reasoning_effort(L))   % ... or refused the level we asked for
    ->  Extra = [reasoning_effort(L)|Base]
    ;   ( Config.reasoning == minimal ; ca_tune(JobID, reasoning_minimal) )
    ->  Extra = [reasoning(minimal)|Base]
    ;   Extra = Base
    ),
    ( ca_tune(JobID, no_temperature) -> drop_temperature(Options, Options1) ; Options1 = Options ),
    append(Options1, Extra, Opts).

drop_temperature(Opts0, Opts) :-
    exclude(is_temperature_option, Opts0, Opts).

is_temperature_option(temperature(_)).

drop_reasoning(Opts0, Opts) :-
    exclude(is_reasoning_option, Opts0, Opts).

is_reasoning_option(reasoning(_)).
is_reasoning_option(reasoning_effort(_)).

%!  asks_for_less_reasoning(+Opts) is semidet.
%
%   The request already tells the model to think less — either through our own
%   `reasoning(minimal)` or through the explicit `reasoning_effort(Level)` a
%   provider's rejection taught us to send. The truncation and silence ladders
%   check this before adding `reasoning(minimal)`: sending both would translate
%   to two `reasoning_effort` fields, and building the JSON body from duplicate
%   keys throws.
asks_for_less_reasoning(Opts) :-
    ( memberchk(reasoning(_), Opts) -> true ; memberchk(reasoning_effort(_), Opts) ).

%!  purpose_max_tokens(+Purpose, +Config, -MT) is det.
%
%   Calibration finds the LARGEST completion the provider accepts. That is the
%   right ceiling and the wrong request: at 65536 tokens a reasoning model can
%   think for twenty minutes before it emits anything, and then EVERY call of a
%   45-minute job times out — observed with an open-weights model whose
%   materials were only 4k tokens, so size was not the problem. A stage that
%   writes a template inventory or an architecture sketch cannot need a whole
%   program's worth of tokens; a stage that writes a program gets the ceiling.
%   If a small stage ever proves it needs more, the truncation ladder raises
%   the cap for the rest of the job (ca_tune/2), which is exactly its job.
purpose_max_tokens(Purpose, Config, MT) :-
    Cap = Config.max_tokens,
    (   small_output_purpose(Purpose)
    ->  small_output_tokens(Small),
        MT is min(Small, Cap)
    ;   MT = Cap
    ).

% A few thousand tokens of prose or a scenario block — never a program. (The
% largest vocabulary reply seen in the field was ~17k characters, about a third
% of this.)
small_output_tokens(16384).

small_output_purpose(vocabulary).
small_output_purpose(vocabulary_merge).
small_output_purpose(vocabulary_paraphrase).
small_output_purpose(architecture).
small_output_purpose(ledger).
small_output_purpose(paraphrase).
small_output_purpose(paraphrase_compare).
small_output_purpose(probes).
small_output_purpose(holdout(_, _)).

% Transient provider failures (503 Service unavailable, 429 rate limit,
% dropped sockets) must not kill a many-minute job on its first call: retry
% with backoff, up to 3 times, respecting the deadline and interrupts.
llm_try(JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    catch(
        ( llm_raw(Model, Messages, Opts, Reply0),
          Outcome = ok(Reply0) ),
        E,
        Outcome = err(E)),
    llm_outcome(Outcome, JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply).

%!  llm_socket_timeout(-Seconds) is det.
%
%   How long a provider may stay silent before we give up on the socket. The
%   default in llm_client is 10 minutes, which is fine for chat-sized calls and
%   far too short here: a drafting call carries the whole wording (tens of
%   thousands of tokens) and asks for a whole program back, and a thinking model
%   sends nothing at all until it has finished. Ten-minute silences are normal;
%   the previous default turned them into "transient" failures that then ate the
%   retry budget and killed the branch.
llm_socket_timeout(900).

%!  call_timeout(+Config, -Seconds) is det.
%
%   The socket timeout ACTUALLY used for the next call: the ceiling above,
%   lowered to fit the minute budget. A flat 15 minutes is wrong for a short
%   job — a provider that accepts the connection and then says nothing costs
%   15 minutes per attempt, and the three attempts of the retry ladder then eat
%   a 45-minute budget whole, before the first stage has produced anything (the
%   failure mode this predicate exists to prevent).
%
%   Two limits, whichever is tighter:
%     - a sixth of the WHOLE budget, so no single call can dominate the job
%       (45 min -> 7.5 min per attempt; three attempts and their backoff cost
%       about half the budget instead of all of it),
%     - half of what is LEFT, so a call started near the deadline cannot run
%       far past it.
%   Never below two minutes: below that even a healthy call would be killed.
call_timeout(Config, Seconds) :-
    llm_socket_timeout(Ceiling),
    get_time(Now),
    (   number(Config.get(deadline, none))
    ->  Remaining is max(0, Config.deadline - Now)
    ;   Remaining = Ceiling
    ),
    (   number(Config.get(minutes, none))
    ->  Budget is Config.minutes * 60
    ;   Budget is Ceiling * 6
    ),
    Share is min(Budget / 6, Remaining / 2),
    Seconds is max(120, min(Ceiling, integer(truncate(Share)))).

% The wall-clock guard must be LOOSER than the socket timeout, or it fires
% first and we never see the real error.
llm_wall_limit(Timeout, Wall) :- Wall is Timeout + 60.

%!  refresh_timeout(+Config, +Opts0, -Opts) is det.
%
%   Recompute timeout/1 for a retry: what is left of the budget has shrunk
%   since the options were built, and the next attempt must respect that.
refresh_timeout(Config, Opts0, [timeout(T)|Opts1]) :-
    call_timeout(Config, T),
    exclude(is_timeout_option, Opts0, Opts1).

is_timeout_option(timeout(_)).

% The one place that actually talks to a provider — and the seam the retry
% tests replace (ca_raw_hook/1) to exercise this ladder offline.
llm_raw(Model, Messages, Opts, Reply) :-
    (   ca_raw_hook(Hook)
    ->  call(Hook, Model, Messages, Opts, Reply)
    ;   ( memberchk(timeout(T), Opts) -> true ; llm_socket_timeout(T) ),
        llm_wall_limit(T, Wall),
        call_with_time_limit(Wall,
            llm_client:llm_request(Model, Messages, Reply, Opts))
    ).

% An EMPTY reply is a failure, not a result: models that spend their whole
% completion budget on internal reasoning (or whose reply format is not
% understood) return empty content, and letting "" cascade through the
% pipeline produces an empty program with clean-looking scores.
llm_outcome(ok(Reply0), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    (   normalize_space(string(Norm), Reply0), Norm == ""
    ->  (   Attempt < 3, \+ deadline_exceeded(Config)
        ->  ca_emit(JobID, "LLM call (~w) returned EMPTY content (attempt ~w); retrying"-[Purpose, Attempt]),
            sleep(3),
            ca_check_alive(JobID),
            Attempt1 is Attempt + 1,
            llm_try(JobID, Config, Purpose, Model, Messages, Opts, Attempt1, Reply)
        ;   ca_emit(JobID, "LLM call (~w) returned empty content repeatedly; giving up"-[Purpose]),
            throw(error(contract_assistant_error(empty_reply(Purpose, Model)), _))
        )
    ;   Reply = Reply0,
        string_length(Reply0, RL),
        ca_emit(JobID, "LLM reply (~w): ~w chars"-[Purpose, RL])
    ).
% Not every provider lets you set the temperature: several current models
% accept only their default and reject the parameter outright (HTTP 400
% "temperature is not supported with this model", "Only the default (1) ...").
% The pipeline uses temperature to VARY its samples, not to be exact, and such
% models sample nondeterministically anyway — so drop the parameter and call
% again, K times as before. Sticky for the rest of the job: one rejection is
% enough to learn it.
llm_outcome(err(E), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    temperature_rejected(E),
    memberchk(temperature(_), Opts),
    \+ deadline_exceeded(Config),
    !,
    ca_emit(JobID, "LLM call (~w): the provider rejects the temperature parameter for ~w; retrying without it"-[Purpose, Model]),
    (   ca_tune(JobID, no_temperature)
    ->  true
    ;   assertz(ca_tune(JobID, no_temperature)),
        ca_emit(JobID, "Auto-tuning: temperature dropped for the rest of the job — the samples that varied by temperature now vary by the model's own sampling"-[])
    ),
    ca_check_alive(JobID),
    drop_temperature(Opts, Opts1),
    llm_try(JobID, Config, Purpose, Model, Messages, Opts1, Attempt, Reply).
% The provider takes `reasoning_effort` but not the level we asked for (gpt-5.5
% dropped "minimal"). It says which levels it does take: switch to the cheapest
% of those and carry on — sticky, so one rejection costs one retry rather than
% one per call. Without this, a job that the truncation ladder had switched to
% minimal reasoning lost EVERY subsequent call to an HTTP 400.
llm_outcome(err(E), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    reasoning_effort_rejected(E, Supported),
    ( memberchk(reasoning(_), Opts) ; memberchk(reasoning_effort(_), Opts) ),
    \+ deadline_exceeded(Config),
    !,
    drop_reasoning(Opts, Opts1),
    (   cheapest_effort(Supported, Level)
    ->  Opts2 = [reasoning_effort(Level)|Opts1],
        Tune = reasoning_effort(Level),
        format(string(Note), "reasoning effort ~w (the cheapest ~w accepts)", [Level, Model])
    ;   Opts2 = Opts1,
        Tune = no_reasoning,
        Note = "no reasoning parameter at all"
    ),
    ca_emit(JobID, "LLM call (~w): ~w rejects the reasoning level we asked for; retrying with ~w"-[Purpose, Model, Note]),
    (   ca_tune(JobID, Tune)
    ->  true
    ;   assertz(ca_tune(JobID, Tune)),
        ca_emit(JobID, "Auto-tuning: the rest of the job uses ~w"-[Note])
    ),
    ca_check_alive(JobID),
    llm_try(JobID, Config, Purpose, Model, Messages, Opts2, Attempt, Reply).
% The model spent its whole completion budget reasoning. Deterministic, so a
% plain retry is pointless — but asking it to THINK LESS is not: retry once
% with reasoning(minimal). Only if the minimal-reasoning call also drowns in
% thought does the job fail.
llm_outcome(err(error(llm_truncated(_), _)), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    \+ asks_for_less_reasoning(Opts),
    \+ ca_tune(JobID, no_reasoning),      % this provider has already refused it
    \+ deadline_exceeded(Config),
    !,
    ca_emit(JobID, "LLM call (~w) was truncated mid-reasoning; retrying with minimal reasoning"-[Purpose]),
    % ... and remember: from now on EVERY call of this job starts with minimal
    % reasoning, instead of paying for one doomed full-reasoning attempt each.
    (   ca_tune(JobID, reasoning_minimal)
    ->  true
    ;   assertz(ca_tune(JobID, reasoning_minimal)),
        ca_emit(JobID, "Auto-tuning: all subsequent calls use minimal reasoning"-[])
    ),
    ca_check_alive(JobID),
    llm_try(JobID, Config, Purpose, Model, Messages, [reasoning(minimal)|Opts], Attempt, Reply).
llm_outcome(err(error(llm_truncated(_), _)), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    % Minimal reasoning was not enough: give the call the provider's full
    % completion cap (sticky for the rest of the job) before giving up.
    Cap = Config.max_tokens_cap,
    select_option(max_tokens(Cur), Opts, Opts1),
    Cur < Cap,
    \+ deadline_exceeded(Config),
    !,
    ca_emit(JobID, "LLM call (~w) still truncated; raising the completion limit to ~w (provider cap) for the rest of the job"-[Purpose, Cap]),
    (   ca_tune(JobID, max_tokens(_)) -> true
    ;   assertz(ca_tune(JobID, max_tokens(Cap)))
    ),
    ca_check_alive(JobID),
    llm_try(JobID, Config, Purpose, Model, Messages, [max_tokens(Cap)|Opts1], Attempt, Reply).
llm_outcome(err(error(llm_truncated(_), _)), JobID, _Config, Purpose, Model, _Messages, _Opts, _Attempt, _Reply) :- !,
    ca_emit(JobID, "LLM call (~w) was truncated even with minimal reasoning at the provider's completion cap"-[Purpose]),
    throw(error(contract_assistant_error(llm_truncated(Purpose, Model)), _)).
% A provider that accepts the request and then sends NOTHING for a whole
% timeout, on a prompt of a few thousand tokens, is almost always a reasoning
% model thinking past the deadline: the same failure as a truncated reply,
% arriving as silence instead of a truncation flag. Retrying the identical
% request just buys another silence — asking it to think less does not. (The
% one call that ever came back from such a model in the field did so
% immediately after this switch, reached by the truncation ladder by luck.)
llm_outcome(err(E), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    silent_provider_error(E),
    \+ asks_for_less_reasoning(Opts),
    \+ ca_tune(JobID, no_reasoning),
    \+ deadline_exceeded(Config),
    !,
    ca_emit(JobID, "LLM call (~w): ~w went silent for the whole timeout; retrying with minimal reasoning"-[Purpose, Model]),
    (   ca_tune(JobID, reasoning_minimal)
    ->  true
    ;   assertz(ca_tune(JobID, reasoning_minimal)),
        ca_emit(JobID, "Auto-tuning: all subsequent calls use minimal reasoning"-[])
    ),
    ca_check_alive(JobID),
    refresh_timeout(Config, Opts, Opts1),
    llm_try(JobID, Config, Purpose, Model, Messages, [reasoning(minimal)|Opts1], Attempt, Reply).
% Still silent with minimal reasoning: cut the completion budget too, so the
% model cannot spend the timeout generating. Sticky, like the other tunings.
llm_outcome(err(E), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    silent_provider_error(E),
    small_output_tokens(Small),
    select_option(max_tokens(Cur), Opts, Opts1),
    Cur > Small,
    \+ deadline_exceeded(Config),
    !,
    ca_emit(JobID, "LLM call (~w): still silent; cutting the completion budget from ~w to ~w tokens for the rest of the job"-[Purpose, Cur, Small]),
    (   ca_tune(JobID, max_tokens(_)) -> true
    ;   assertz(ca_tune(JobID, max_tokens(Small)))
    ),
    ca_check_alive(JobID),
    refresh_timeout(Config, [max_tokens(Small)|Opts1], Opts2),
    llm_try(JobID, Config, Purpose, Model, Messages, Opts2, Attempt, Reply).
llm_outcome(err(E), JobID, Config, Purpose, Model, Messages, Opts, Attempt, Reply) :-
    (   transient_llm_error(E),
        max_attempts(Config, E, MaxAttempts),
        Attempt < MaxAttempts,
        \+ deadline_exceeded(Config)
    ->  retry_delay(Attempt, Delay),
        short_error(E, Short),
        % The budget left has shrunk, so the next attempt gets a fresh (shorter)
        % timeout — otherwise a silent provider costs the same many minutes on
        % every attempt and the ladder alone can consume the whole job.
        refresh_timeout(Config, Opts, Opts1),
        memberchk(timeout(T1), Opts1),
        ca_emit(JobID, "LLM call (~w) failed transiently (attempt ~w of ~w: ~w); retrying in ~ws (next attempt waits at most ~ws)"-[Purpose, Attempt, MaxAttempts, Short, Delay, T1]),
        sleep(Delay),
        ca_check_alive(JobID),
        Attempt1 is Attempt + 1,
        llm_try(JobID, Config, Purpose, Model, Messages, Opts1, Attempt1, Reply)
    ;   term_string(E, ES),
        % Say WHY we stopped: "failed" after a "retrying" line reads like the
        % retry ladder gave up on its own, when usually the minute budget ran out.
        (   transient_llm_error(E), deadline_exceeded(Config)
        ->  ca_emit(JobID, "LLM call failed (~w) and the ~w-minute budget is exhausted, so it was not retried: ~w"-[Purpose, Config.minutes, ES])
        ;   silent_provider_error(E)
        ->  ( memberchk(timeout(T), Opts) -> true ; llm_socket_timeout(T) ),
            ( memberchk(max_tokens(MTUsed), Opts) -> true ; MTUsed = Config.max_tokens ),
            ca_emit(JobID, "LLM call failed (~w): ~w accepted the request and then sent nothing, on ~w attempts of up to ~ws each — including attempts with minimal reasoning and a ~w-token completion budget. Nothing here can make a provider answer: use another model. (Raising Max minutes only lengthens each wait.)"-[Purpose, Model, Attempt, T, MTUsed])
        ;   transient_llm_error(E)
        ->  ca_emit(JobID, "LLM call failed (~w) after ~w attempts: ~w"-[Purpose, Attempt, ES])
        ;   ca_emit(JobID, "LLM call failed (~w): ~w"-[Purpose, ES])
        ),
        throw(error(contract_assistant_error(llm_failed(Purpose, ES)), _))
    ).

%!  temperature_rejected(+Error) is semidet.
%
%   A parameter rejection naming `temperature`: the provider refuses the
%   sampling temperature for this model (OpenAI answers 400, others 422).
%   Anything else about a 400 is a real error and must not be swallowed.
temperature_rejected(error(llm_api_error(Status, Body), _)) :-
    integer(Status),
    memberchk(Status, [400, 422]),
    term_string(Body, BS0),
    string_lower(BS0, BS),
    sub_string(BS, _, _, _, "temperature"),
    \+ sub_string(BS, _, _, _, "reasoning_effort").

%!  reasoning_effort_rejected(+Error, -Supported:list(atom)) is semidet.
%
%   A parameter rejection naming `reasoning_effort`: the provider knows the
%   parameter but not the VALUE we sent. Observed with gpt-5.5, which dropped
%   the "minimal" level its predecessors accept:
%
%       Unsupported value: 'reasoning_effort' does not support 'minimal' with
%       this model. Supported values are: 'none', 'low', 'medium', 'high',
%       and 'xhigh'.
%
%   Providers say which values they DO take, so Supported is parsed out of the
%   message (empty when it says nothing useful) and the caller picks the
%   cheapest one it recognises. This is what makes a model list that has gone
%   stale cost one retry instead of the whole job: the truncation ladder had
%   switched every call to minimal reasoning, and every call then 400ed.
%   A 400/422 that names the parameter at all is about the parameter: whether
%   it is the value or the field itself the provider objects to, our reasoning
%   option is what has to change.
reasoning_effort_rejected(error(llm_api_error(Status, Body), _), Supported) :-
    integer(Status),
    memberchk(Status, [400, 422]),
    term_string(Body, BS0),
    string_lower(BS0, BS),
    sub_string(BS, _, _, _, "reasoning_effort"),
    supported_efforts(BS, Supported).

% The quoted values that follow "supported values are:".
supported_efforts(Message, Supported) :-
    (   sub_string(Message, Before, _, _, "supported values are")
    ->  sub_string(Message, Before, _, 0, Tail),
        findall(V, ( known_effort(V), quoted_in(Tail, V) ), Supported)
    ;   Supported = []
    ).

quoted_in(Text, Value) :-
    format(string(Quoted), "'~w'", [Value]),
    sub_string(Text, _, _, _, Quoted), !.

known_effort(none).
known_effort(minimal).
known_effort(low).
known_effort(medium).
known_effort(high).
known_effort(xhigh).

%!  cheapest_effort(+Supported, -Level) is semidet.
%
%   The least thinking the provider offers — the point of the retry is to spend
%   FEWER reasoning tokens, not to find any value it accepts.
cheapest_effort(Supported, Level) :-
    member(Level, [none, minimal, low, medium]),
    memberchk(Level, Supported), !.

transient_llm_error(error(llm_api_error(Status, _), _)) :-
    integer(Status),
    ( Status >= 500 ; Status =:= 429 ), !.
transient_llm_error(time_limit_exceeded) :- !.
transient_llm_error(error(llm_http_error(_), _)) :- !.   % dropped TLS/socket, DNS blips
transient_llm_error(error(timeout_error(_, _), _)) :- !.
transient_llm_error(error(socket_error(_, _), _)) :- !.
transient_llm_error(error(io_error(_, _), _)).

%!  silent_provider_error(+Error) is semidet.
%
%   A transient failure that cost a WHOLE timeout to discover: the provider
%   accepted the request and then said nothing. Unlike a 503 or a rate limit —
%   which come back in milliseconds and are worth several quick retries — each
%   of these costs minutes, so they get a shorter ladder (see max_attempts/2).
silent_provider_error(time_limit_exceeded) :- !.
silent_provider_error(error(timeout_error(_, _), _)) :- !.
silent_provider_error(error(llm_http_error(Inner), _)) :-
    nonvar(Inner), Inner = error(timeout_error(_, _), _), !.

%!  max_attempts(+Config, +Error, -Attempts) is det.
%
%   How many attempts this error is worth, given what is left of the budget.
%   A quick failure (503, rate limit) is worth the full ladder: retrying costs
%   milliseconds. A silent provider costs a WHOLE timeout per attempt, so it
%   gets two — unless the budget can comfortably afford more, in which case
%   there is no reason to give up early. A 120-minute job died 46 minutes in,
%   with 74 minutes unused, because this was a flat 2.
max_attempts(Config, E, Attempts) :-
    (   silent_provider_error(E)
    ->  ( room_for_long_attempts(Config) -> Attempts = 4 ; Attempts = 2 )
    ;   Attempts = 4
    ).

%!  room_for_long_attempts(+Config) is semidet.
%
%   Enough budget left for another full-length attempt AND the work after it:
%   three times the next timeout is the margin.
room_for_long_attempts(Config) :-
    number(Config.get(deadline, none)),
    call_timeout(Config, T),
    get_time(Now),
    Remaining is Config.deadline - Now,
    Remaining > 3 * T.

retry_delay(1, 3).
retry_delay(2, 8).
retry_delay(_, 20).

short_error(error(llm_api_error(Status, _), _), Short) :- !,
    format(atom(Short), "HTTP ~w", [Status]).
short_error(time_limit_exceeded, 'the call hung and was killed') :- !.
short_error(E, Short) :- E =.. [F|_], term_string(F, Short).

% Judging/merging purposes use the judge model; everything else the main one.
resolve_model(Purpose, Config, Model, Key) :-
    ( memberchk(Purpose, [vocabulary_merge, ledger]) -> ModelS = Config.judge_model
    ; ModelS = Config.model ),
    atom_string(Model0, ModelS), Model = Model0,
    key_for_model(Model, Config.api_keys, Key).

key_for_model(Model, Keys, Key) :-
    (   llm_client:llm_model(Model, Provider0, _)
    ->  ( Provider0 == gemini -> Provider = google ; Provider = Provider0 ),
        (   get_dict(Provider, Keys, Key), Key \== null, Key \== ""
        ->  true
        ;   catch(llm_client:api_key(Provider0, Key), _, Key = "")
        )
    ;   ( get_dict(openai, Keys, Key), Key \== null, Key \== "" -> true
        ; catch(llm_client:api_key(openai, Key), _, Key = "") )
    ).

build_messages(PromptName, Slots, [
        _{role: system, content: System},
        _{role: user, content: User}]) :-
    prompt_text(house_style, House),
    le_syntax_summary(Syntax),
    prompt_text(PromptName, Stage0),
    substitute_slots(Stage0, Slots, Stage, BigSlots),
    format(string(System), "~w\n\n## Logical English syntax\n~w\n\n## Your task\n~w",
           [House, Syntax, Stage]),
    findall(Part, ( member(K-VText, BigSlots),
                    format(string(Part), "## ~w\n\n~w", [K, VText]) ), Parts),
    ( Parts == [] -> User = "(all inputs are in the system prompt)"
    ; atomic_list_concat(Parts, "\n\n", User) ).

% Slots named in the stage prompt as {{name}} are substituted in place; the
% rest are appended as sections of the user message (the big documents).
substitute_slots(Text0, Slots, Text, Big) :-
    atom_string(TA, Text0),
    substitute_slots_(TA, Slots, Text, Big).

substitute_slots_(Text, [], Text, []).
substitute_slots_(Text0, [K-V|Rest], Text, Big) :-
    format(atom(Pat), "{{~w}}", [K]),
    (   sub_atom(Text0, _, _, _, Pat)
    ->  atomic_list_concat(Chunks, Pat, Text0),
        atomic_list_concat(Chunks, V, Text1),
        substitute_slots_(Text1, Rest, Text, Big)
    ;   substitute_slots_(Text0, Rest, Text, Big0),
        Big = [K-V|Big0]
    ).

prompt_text(Name, Text) :-
    atomic_list_concat(['llm/contract_prompts/', Name, '.md'], Rel),
    (   exists_file(Rel) -> read_file_to_string(Rel, Text, [])
    ;   atomic_list_concat(['../', Rel], Rel2), exists_file(Rel2)
    ->  read_file_to_string(Rel2, Text, [])
    ;   throw(error(contract_assistant_error(missing_prompt(Name)), _))
    ).

le_syntax_summary(Text) :-
    % The active language's variant (docs/le_summary.<lang>.md) when present;
    % see set_request_language/1 — the request's ?lang= parameter selects it.
    le_i18n:localized_asset('docs/le_summary', md, Path),
    (   exists_file(Path) -> read_file_to_string(Path, Text0, [])
    ;   % Without the syntax reference every generated program would be
        % garbage in mysterious ways: fail loudly, like a missing stage prompt.
        throw(error(contract_assistant_error(missing_syntax_summary(Path)), _))
    ),
    contract_language_directive(Directive),
    format(string(Text), "~w~w", [Directive, Text0]).

% An explicit output-language directive prepended to the syntax summary for
% non-English target languages.
contract_language_directive(Directive) :-
    le_i18n:le_active_language(Lang),
    (   Lang == en
    ->  Directive = ""
    ;   ( le_i18n:language_param(Lang, english_name, Name) -> true ; Name = Lang ),
        ( le_i18n:language_opener(Lang, OpenerWords), atomic_list_concat(OpenerWords, ' ', Opener) -> true ; Opener = '' ),
        format(string(Directive), "IMPORTANT: write the Logical English program in ~w, using the ~w keyword set summarised below. The program's first statement must be `~w: prolog.`~n~n", [Name, Name, Opener])
    ).

%!  extract_le_code(+Reply, -Code) is det.
%
%   Pulls the program out of an LLM reply: the ```le-tagged fence if there is
%   one, otherwise the LARGEST fenced block (models often emit a small
%   preamble fence — e.g. a header comment — before the real program), and
%   with no fence at all the whole reply.
extract_le_code(Reply, Code) :-
    (   extract_tagged_block(Reply, le, Code0)
    ->  Code = Code0
    ;   findall(B, any_fenced_block(Reply, B), Blocks),
        Blocks \== []
    ->  largest_block(Blocks, Code)
    ;   Code = Reply
    ).

% All fenced blocks of the reply, in order.
any_fenced_block(Reply, Block) :-
    fenced_blocks(Reply, Blocks),
    member(Block, Blocks).

fenced_blocks(Reply, Blocks) :-
    atom_string(RA, Reply),
    atomic_list_concat(Chunks, '```', RA),
    ( Chunks = [_|Rest] -> odd_chunks(Rest, Blocks0) ; Blocks0 = [] ),
    findall(B, ( member(C, Blocks0), strip_fence_info_line(C, B) ), Blocks).

% After splitting on ``` the fence contents are chunks 1, 3, 5, ...
odd_chunks([Content|Rest], [Content|Bs]) :- !, even_chunks(Rest, Bs).
odd_chunks([], []).
even_chunks([_|Rest], Bs) :- !, odd_chunks(Rest, Bs).
even_chunks([], []).

% Drop the info line ("le", "prolog", ...) that follows the opening fence.
strip_fence_info_line(Chunk, Block) :-
    atom_string(CA, Chunk),
    (   sub_atom(CA, NL, 1, _, '\n')
    ->  After is NL + 1,
        sub_atom(CA, After, _, 0, BA),
        atom_string(BA, Block)
    ;   Block = ""
    ).

largest_block(Blocks, Largest) :-
    map_list_to_pairs(block_size, Blocks, Pairs),
    keysort(Pairs, Sorted),
    last(Sorted, _-Largest).

block_size(B, L) :- string_length(B, L).

first_fenced_block(Reply, Block) :-
    sub_string(Reply, Open, 3, _, "```"), !,
    AfterOpen is Open + 3,
    sub_string(Reply, AfterOpen, _, 0, Rest0),
    sub_string(Rest0, NLPos, 1, _, "\n"), !,   % skip the fence's info line
    ContentStart is NLPos + 1,
    sub_string(Rest0, ContentStart, _, 0, Content0),
    (   sub_string(Content0, Close, 3, _, "```")
    ->  sub_string(Content0, 0, Close, _, Block)
    ;   Block = Content0
    ).

%!  extract_tagged_block(+Reply, +Tag, -Block) is semidet.
%
%   Finds the first code fence explicitly tagged with Tag (```le, ```ledger).
extract_tagged_block(Reply, Tag, Block) :-
    format(atom(Marker), "```~w\n", [Tag]),
    sub_string(Reply, Open, _, _, Marker),
    atom_length(Marker, MLen),
    ContentStart is Open + MLen,
    sub_string(Reply, ContentStart, _, 0, Rest),
    (   sub_string(Rest, Close, 3, _, "```")
    ->  sub_string(Rest, 0, Close, _, Block)
    ;   Block = Rest
    ),
    !.

% ============================ Segmentation & slicing ==========================

%!  segment_markdown(+Text, -Sections) is det.
%
%   Splits a markdown document into sections at its headings. Each section is
%   a dict {level, title, start_line, end_line} (1-based, end inclusive).
%   A document with no headings yields one section titled "document".
segment_markdown(Text, Sections) :-
    split_string(Text, "\n", "", Lines),
    length(Lines, NLines),
    findall(h(LineNo, Level, Title),
            ( nth1(LineNo, Lines, Line),
              heading_line(Line, Level, Title) ),
            Hs),
    (   Hs == []
    ->  Sections = [_{level: 0, title: "document", start_line: 1, end_line: NLines}]
    ;   heading_sections(Hs, NLines, Sections)
    ).

heading_line(Line, Level, Title) :-
    string_concat(Hashes, Rest, Line),
    string_length(Hashes, Level), Level > 0, Level =< 6,
    forall(sub_string(Hashes, _, 1, _, C), C == "#"),
    string_concat(" ", Title0, Rest),
    normalize_space(string(Title), Title0),
    Title \== "".

heading_sections([h(L, Lev, T)|Rest], NLines, [_{level: Lev, title: T, start_line: L, end_line: End}|Ss]) :-
    ( Rest = [h(L2, _, _)|_] -> End is L2 - 1 ; End = NLines ),
    heading_sections(Rest, NLines, Ss).
heading_sections([], _, []).

%!  target_slice(+Text, +Sections, +Target, +JobID, -Slice) is det.
%
%   If the user named a target section, slice the wording down to that section
%   plus any "general" sections (general terms/conditions/exclusions are
%   incorporated by reference into every section). Otherwise the full wording.
%   Two forms of Target:
%
%     Employers' liability
%         the section with that title AND ITS SUBSECTIONS — it ends at the next
%         heading of the same or a higher level (or the next table-of-contents
%         section), never at its own first subsection and never at the end of
%         the document just because the author forgot a heading. The general
%         terms are added, since they are incorporated by reference.
%
%     from Employers' liability until Property definitions
%     from Employers' liability until Property definitions (inclusive)
%         everything between those two titles, taken literally and with nothing
%         added. For the ill-formed markdown that policy wordings are made of
%         (missing headings, headings that are just bold text), naming both ends
%         is the only reliable way to say what you mean. The end is exclusive
%         unless `(inclusive)` says otherwise.
target_slice(Text, _, none, _, Text) :- !.
target_slice(Text, Sections0, Target, JobID, Slice) :-
    augment_sections_with_toc(Text, Sections0, Sections),
    parse_target(Target, Spec),
    (   target_lines(Spec, Sections, Text, JobID, Ranges, Note)
    ->  split_string(Text, "\n", "", Lines),
        findall(Part, ( member(From-To, Ranges),
                        section_lines(Lines, _{start_line: From, end_line: To}, Part) ),
                Parts),
        atomic_list_concat(Parts, "\n\n[...]\n\n", Slice),
        ca_emit(JobID, "Sliced wording to ~w"-[Note])
    ;   string_length(Text, TL), FullTokens is TL // 4,
        ca_emit(JobID, "WARNING: target '~w' not found (neither as a heading nor as a table-of-contents section title), so the FULL wording goes into every call — about ~w tokens each, which costs proportionally more and is what makes slow models time out. Check the spelling, or name both ends ('from X until Y')."-[Target, FullTokens]),
        Slice = Text
    ).

%!  parse_target(+Target, -Spec) is det.
%
%   `from A until B` / `from A to B`, with an optional `(inclusive)` /
%   `(exclusive)` on B — anything else is a plain section title.
%
%   " to " needs the leading "from", because section titles contain it ("Guide
%   to sections"); " until " does not, because they do not, and dropping the
%   "from" is the obvious slip. Left unread, `A until B` becomes a section
%   title that matches nothing, and the job silently carries the WHOLE wording
%   into every call — which is how a 62k-token-per-call run timed out.
parse_target(Target, Spec) :-
    normalize_space(string(T0), Target),
    string_lower(T0, Lower),
    (   sub_string(Lower, 0, 5, _, "from ")
    ->  sub_string(T0, 5, _, 0, Rest),
        (   split_on_marker(Rest, " until ", A, B0) -> true
        ;   split_on_marker(Rest, " to ", A, B0)
        ),
        end_boundary(B0, B, Inclusive),
        Spec = range(A, B, Inclusive)
    ;   split_on_marker(T0, " until ", A, B0)
    ->  end_boundary(B0, B, Inclusive),
        Spec = range(A, B, Inclusive)
    ;   Spec = section(T0)
    ).
parse_target(Target, section(T)) :- normalize_space(string(T), Target).

split_on_marker(Str, Marker, Left, Right) :-
    string_lower(Str, Lower),
    string_lower(Marker, LowerMarker),
    sub_string(Lower, Before, Len, _, LowerMarker), !,
    sub_string(Str, 0, Before, _, Left0),
    After is Before + Len,
    sub_string(Str, After, _, 0, Right0),
    normalize_space(string(Left), Left0),
    normalize_space(string(Right), Right0),
    Left \== "", Right \== "".

end_boundary(B0, B, Inclusive) :-
    string_lower(B0, Lower),
    (   sub_string(Lower, Before, _, 0, "(inclusive)")
    ->  Inclusive = true, cut_at(B0, Before, B)
    ;   sub_string(Lower, Before, _, 0, "(exclusive)")
    ->  Inclusive = false, cut_at(B0, Before, B)
    ;   Inclusive = false, B = B0
    ).

cut_at(Str, Before, Out) :-
    sub_string(Str, 0, Before, _, S0),
    normalize_space(string(Out), S0).

%!  target_lines(+Spec, +Sections, +Text, +JobID, -Ranges, -Note) is semidet.
target_lines(section(Title), Sections, _Text, _JobID, Ranges, Note) :-
    findall(F-T, ( member(S, Sections), title_contains(S.title, Title),
                   section_with_subsections(Sections, S, F, T) ), Matches),
    Matches \== [],
    findall(F-T, ( member(G, Sections), title_contains(G.title, "general"),
                   section_with_subsections(Sections, G, F, T) ), Generals),
    append(Generals, Matches, All0),
    sort(All0, Ranges),
    length(Ranges, N),
    format(string(Note), "~w block(s) for '~w' (+ general terms), lines ~w",
           [N, Title, Ranges]).
target_lines(range(A, B, Inclusive), Sections, Text, _JobID, [From-To], Note) :-
    member(SA, Sections), title_contains(SA.title, A),
    From = SA.start_line,
    (   member(SB, Sections), title_contains(SB.title, B), SB.start_line > From
    ->  (   Inclusive == true
        ->  section_with_subsections(Sections, SB, _, To)
        ;   To is SB.start_line - 1
        )
    ;   % the closing title is missing (ill-formed document): stop at the end,
        % but say so rather than pretending the boundary was found
        split_string(Text, "\n", "", Lines), length(Lines, To)
    ),
    To >= From,
    !,
    ( Inclusive == true -> Kind = "inclusive" ; Kind = "exclusive" ),
    format(string(Note), "lines ~w-~w: from '~w' until '~w' (~w)", [From, To, A, B, Kind]).

%!  section_with_subsections(+Sections, +Sec, -From, -To) is det.
%
%   A section runs until the next heading of the SAME or a HIGHER level (a
%   deeper heading is one of its own subsections). segment_markdown/2 stays flat
%   on purpose — clause-wise drafting needs non-overlapping blocks — so the
%   nesting is computed here, where it is wanted.
section_with_subsections(Sections, Sec, From, To) :-
    From = Sec.start_line,
    Level = Sec.level,
    findall(Start, ( member(S, Sections), S.start_line > From, S.level =< Level,
                     Start = S.start_line ), Starts),
    (   Starts == []
    ->  % nothing of the same rank follows: this section owns the rest of the
        % document (its own flat end would cut it at its first subsection)
        findall(E, ( member(S, Sections), S.start_line >= From, E = S.end_line ), Ends),
        max_list(Ends, To)
    ;   min_list(Starts, NextStart),
        To is NextStart - 1
    ).

% Case-insensitive containment, tolerant of typographic vs straight
% apostrophes ("Employers' liability" must match "Employers’ liability").
title_contains(Title, Needle) :-
    normalize_title(Title, TN),
    normalize_title(Needle, NN),
    sub_atom(TN, _, _, _, NN).

normalize_title(S, N) :-
    string_lower(S, L0),
    atom_string(A0, L0),
    atomic_list_concat(P1, '’', A0), atomic_list_concat(P1, '\'', A1),
    normalize_space(atom(N), A1).

%!  augment_sections_with_toc(+Text, +Sections0, -Sections) is det.
%
%   Policy wordings often list their major sections in an initial
%   table-of-contents bullet list ("Guide to sections") and then start each
%   section with the bare title on a plain line — no markdown heading — so
%   heading-based segmentation misses them (the Hiscox examplePolicy.md does
%   exactly this). Every non-heading line whose text equals a TOC bullet is
%   treated as a level-1 section start; such a section ends at the next
%   TOC-derived start (its markdown-heading subsections stay inside it).
augment_sections_with_toc(Text, Sections0, Sections) :-
    split_string(Text, "\n", "\r", Lines),
    length(Lines, NL),
    findall(TN, ( nth1(I, Lines, L), I =< 200,
                  string_concat("- ", T0, L),
                  normalize_title(T0, TN), TN \== '' ),
            Toc0),
    sort(Toc0, Toc),
    Toc \== [],
    findall(J-Title, ( nth1(J, Lines, L),
                       \+ string_concat("- ", _, L),
                       \+ heading_line(L, _, _),
                       normalize_space(string(T1), L), T1 \== "",
                       normalize_title(T1, TN), memberchk(TN, Toc),
                       Title = T1 ),
            Starts0),
    Starts0 \== [],
    !,
    msort(Starts0, Starts),
    % A TOC-derived section also ends at the next level-1 markdown heading:
    % the following major section may announce itself either way.
    findall(H, ( member(S, Sections0), S.level =:= 1, H = S.start_line ), H1s0),
    msort(H1s0, H1s),
    toc_sections(Starts, H1s, NL, TocSections),
    append(Sections0, TocSections, All0),
    sort(start_line, @<, All0, Sections).
augment_sections_with_toc(_, Sections, Sections).

toc_sections([J-T|Rest], H1s, NL, [_{level: 1, title: T, start_line: J, end_line: End}|Ss]) :-
    ( Rest = [J2-_|_] -> NextToc = J2 ; NextToc = NL + 1 ),
    ( member(H, H1s), H > J -> NextH1 = H ; NextH1 = NL + 1 ),
    End is min(NextToc, NextH1) - 1,
    toc_sections(Rest, H1s, NL, Ss).
toc_sections([], _, _, []).

section_lines(Lines, Sec, Part) :-
    findall(L, ( between(Sec.start_line, Sec.end_line, I), nth1(I, Lines, L) ), Ls),
    atomic_list_concat(Ls, "\n", Part).

%!  schedule_text(+Files, -Text) is det.
%
%   The schedule material handed to the model. No file gives the empty string
%   (materials_block/4 turns that into "no schedule provided"); one file is used
%   verbatim, as it always was; several are concatenated under a header naming
%   each one — the stored name carries both the user's wording and the format,
%   and a .json schedule reads very differently from a .md one.
schedule_text([], "") :- !.
schedule_text([File], Text) :- !, read_text(File, Text).
schedule_text(Files, Text) :-
    findall(B,
            ( nth1(I, Files, F), read_text(F, T), file_base_name(F, Base),
              format(string(B), "### SCHEDULE ~w (~w)\n\n~w", [I, Base, T]) ),
            Bs),
    atomic_list_concat(Bs, "\n\n", Text).

% ------------------------- Structured (JSON) case files -----------------------
% A .json case file is normally not ONE case: it is an ARRAY of them — a claims
% file holding seventeen claims. Seventeen claims must become seventeen
% scenarios, so the array is split, one case per element. Two more things come
% out of the same reading:
%
%   - records of the SAME case spread over several files (claims.json and
%     expected_outcomes.json, both keyed by "claimRef") are merged into one
%     case, so the expected outcome travels with the claim it belongs to;
%   - a case that NAMES a schedule (its "policyRef" is the key of an entry in
%     schedules.json) carries that entry with it: the limits, deductibles and
%     elections that decide the claim are per policy, so they belong in that
%     claim's scenario rather than in one global set of facts.
%
% The linking field is discovered, not configured: a field whose name reads
% like an identifier, or whose value identifies a record uniquely within its
% own file. Anything that is not JSON, or JSON without a record array, stays
% one case — the behaviour every non-structured upload had.

%!  case_texts(+CaseFiles, +ScheduleFiles, -CaseTexts) is det.
case_texts(CaseFiles, ScheduleFiles, CaseTexts) :-
    findall(Rs, ( member(F, CaseFiles), file_records(F, Rs) ), RecordLists),
    append(RecordLists, Records0),
    merge_case_records(Records0, Records),
    findall(Rs, ( member(F, ScheduleFiles), file_records(F, Rs) ), SchedLists),
    append(SchedLists, Schedules),
    findall(T, ( member(R, Records), case_record_text(R, Schedules, T) ), CaseTexts).

%!  file_records(+File, -Records) is det.
%
%   The records of one uploaded file: `rec(Source, Dict)` per element of its
%   JSON record array, or the single `text(Source, Text)` of anything else.
file_records(File, Records) :-
    read_text(File, Text),
    file_base_name(File, Base),
    (   json_record_array(File, Text, Dicts)
    ->  findall(rec(Base, D), member(D, Dicts), Records)
    ;   Records = [text(Base, Text)]
    ).

%!  json_record_array(+File, +Text, -Dicts) is semidet.
%
%   The array of records of a .json document: the document itself when it is a
%   list of objects, else its longest list-of-objects field (so `{"claims":
%   [...]}` and `{"note": "...", "outcomes": [...]}` both work).
json_record_array(File, Text, Dicts) :-
    file_name_extension(_, json, File),
    catch(atom_json_dict(Text, Term, [value_string_as(string)]), _, fail),
    record_array(Term, Dicts).

record_array(List, List) :-
    is_list(List), List \== [], forall(member(E, List), is_dict(E)), !.
record_array(Dict, Best) :-
    is_dict(Dict),
    findall(N-V, ( get_dict(_, Dict, V), is_list(V), V \== [],
                   forall(member(E, V), is_dict(E)), length(V, N) ),
            Pairs),
    Pairs \== [],
    keysort(Pairs, Sorted), last(Sorted, _-Best).

%!  merge_case_records(+Records, -Merged) is det.
%
%   Records from DIFFERENT files that share a linking field with the same
%   value describe one case; `merged(Sources, Dict)` is that case. The first
%   file's values win a conflict — the claim is the case, the outcome file
%   only adds to it.
merge_case_records(Records, Merged) :-
    findall(S-Ks, ( setof(Src, D^member(rec(Src, D), Records), Sources),
                    member(S, Sources), link_keys(S, Records, Ks) ),
            KeyMap),
    foldl(merge_one_record(KeyMap), Records, [], Rev),
    reverse(Rev, Merged).

merge_one_record(_, text(S, T), Acc, [text(S, T)|Acc]) :- !.
merge_one_record(KeyMap, rec(S, D), Acc0, Acc) :-
    (   select(merged(Sources, MD), Acc0, Rest),
        \+ memberchk(S, Sources),
        links_to(KeyMap, S, D, Sources, MD)
    ->  Joined = D.put(MD),          % the earlier file wins a clash
        Acc = [merged([S|Sources], Joined)|Rest]
    ;   Acc = [merged([S], D)|Acc0]
    ).

links_to(KeyMap, S, D, Sources, MD) :-
    memberchk(S-Keys, KeyMap), member(K, Keys),
    member(S2, Sources), memberchk(S2-Keys2, KeyMap), memberchk(K, Keys2),
    get_dict(K, D, V), get_dict(K, MD, V), !.

%!  link_keys(+Source, +Records, -Keys) is det.
%
%   The fields of a file that can identify one of its records: a field present
%   in every record with an atomic value, and either named like an identifier
%   (…ref, …id, …no, …code, …key) or holding a value unique across the file's
%   records. A one-record file has only the name rule to go on — with a single
%   record every field is trivially "unique", which would link anything to
%   anything.
link_keys(Source, Records, Keys) :-
    findall(D, member(rec(Source, D), Records), Ds),
    Ds = [First|_], length(Ds, N),
    findall(K,
            ( dict_pairs(First, _, Pairs), member(K-_, Pairs),
              forall(member(D, Ds), ( get_dict(K, D, V), atomic_field(V) )),
              ( id_like_key(K)
              ->  true
              ;   N > 1,
                  findall(V, ( member(D, Ds), get_dict(K, D, V) ), Vs),
                  sort(Vs, Unique), length(Unique, N)
              )
            ),
            Keys).

atomic_field(V) :- ( string(V) ; atom(V) ; number(V) ), V \== "", V \== '', !.

id_like_key(Key) :-
    downcase_atom(Key, L),
    member(Suffix, [ref, id, no, number, code, key]),
    atom_concat(_, Suffix, L), !.

%!  case_record_text(+Record, +Schedules, -Text) is det.
case_record_text(text(_, Text), _, Text) :- !.
case_record_text(merged(Sources, D), Schedules, Text) :-
    reverse(Sources, InOrder),
    atomic_list_concat(InOrder, ', ', SrcList),
    json_pretty(D, Body),
    findall(SB,
            ( member(rec(SSrc, SD), Schedules), schedule_matches(D, Schedules, SSrc, SD),
              json_pretty(SD, SBody),
              format(string(SB),
                     "\nThe schedule entry this case refers to (~w) — its parameters are\nfacts OF THIS CASE, and belong in this scenario:\n\n~w\n",
                     [SSrc, SBody]) ),
            SBs),
    atomic_list_concat(SBs, "\n", SchedBlock),
    format(string(Text), "(from ~w)\n\n~w\n~w", [SrcList, Body, SchedBlock]).

% A schedule entry belongs to a case when they agree on one of the schedule
% file's linking fields ("policyRef" here).
schedule_matches(D, Schedules, SSrc, SD) :-
    link_keys(SSrc, Schedules, Keys),
    member(K, Keys),
    get_dict(K, SD, V), get_dict(K, D, V), !.

json_pretty(Dict, Text) :-
    with_output_to(string(Text), json_write_dict(current_output, Dict, [width(76)])).

materials_block(Wording, Schedule, CaseTexts, Materials) :-
    findall(CB, ( nth1(I, CaseTexts, CT),
                  format(string(CB), "### CASE ~w\n\n~w", [I, CT]) ), CBs),
    atomic_list_concat(CBs, "\n\n", CasesBlock),
    ( Schedule == "" -> SB = "(no schedule provided)" ; SB = Schedule ),
    ( CBs == [] -> CaB = "(no cases provided)" ; CaB = CasesBlock ),
    format(string(Materials),
           "## CONTRACT WORDING\n\n~w\n\n## SCHEDULE\n\n~w\n\n## CASES\n\n~w",
           [Wording, SB, CaB]).

% =============================== Small helpers ================================

read_text(File, Text) :- read_file_to_string(File, Text, [encoding(utf8)]).

ca_set_stage(JobID, Idx, Label) :-
    retractall(ca_stage(JobID, _, _)),
    assertz(ca_stage(JobID, Idx, Label)),
    ca_emit(JobID, "── Stage ~w: ~w"-[Idx, Label]).

ca_set_branch(JobID, Idx, Info) :-
    retractall(ca_branch(JobID, Idx, _)),
    assertz(ca_branch(JobID, Idx, Info)).

ca_emit(JobID, Fmt-Args) :-
    format(string(Line), Fmt, Args),
    with_mutex(ca_log,
        ( ( retract(ca_logseq(JobID, Seq)) -> true ; Seq = 0 ),
          Seq1 is Seq + 1,
          assertz(ca_logseq(JobID, Seq1)),
          assertz(ca_log(JobID, Seq, Line)) )),
    append_job_log(JobID, Line),
    print_message(informational, format("[contract_assistant ~w] ~w", [JobID, Line])).

% Mirror the log into <jobdir>/job.log so post-mortems survive the process.
append_job_log(JobID, Line) :-
    catch(
        ( job_dir(JobID, Dir),
          atomic_list_concat([Dir, '/job.log'], File),
          setup_call_cleanup(open(File, append, S, [encoding(utf8)]),
                             format(S, "~w~n", [Line]), close(S)) ),
        _, true).

ca_check_alive(JobID) :-
    ( ca_status(JobID, interrupt_requested) -> throw(contract_interrupt) ; true ).

deadline_exceeded(Config) :-
    get_time(Now), Now > Config.deadline.

save_text_artifact(JobID, Name, Text) :-
    job_dir(JobID, Dir),
    atomic_list_concat([Dir, '/', Name], File),
    write_text_file(File, Text).

save_json_artifact(JobID, Name, Dict) :-
    job_dir(JobID, Dir),
    atomic_list_concat([Dir, '/', Name], File),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       json_write_dict(S, Dict, [width(120)]),
                       close(S)).

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
      5b. held-out evaluation  — blind scenarios for the held-out cases, scored
                                 above development tests in the fitness rank
      6. select & interrogate  — objective fitness; differential interrogation
                                 probes (feature `probes`) with adjudication
                                 repairs; paraphrase-invariance check (feature
                                 `paraphrase`); ledger for the winner

    The search is scaled by the user's budget preset (draft / standard /
    thorough); every feature is individually switchable through the request's
    `features` dict (see features_params/3).

    Jobs run in a background thread; progress is polled through the /leapi
    operations contract_start / contract_status / contract_result /
    contract_interrupt (see classic_web_api.pl), same conventions as the LE
    Assistant. The web UI lives in web_extras/contract_assistant/.

    For tests, the LLM can be stubbed by asserting ca_llm_hook/1 with a closure
    called as call(Closure, Purpose, Messages, ReplyText), and jobs can be run
    synchronously with start_contract_job/3 option sync(true).
*/

:- module(le_contract_assistant, [
    handle_contract_start/2,
    handle_contract_status/2,
    handle_contract_result/2,
    handle_contract_interrupt/2,
    start_contract_job/3,
    run_contract_pipeline/1,
    segment_markdown/2,
    extract_le_code/2,
    extract_tagged_block/3,
    extract_search_replace/2,
    parse_stability/2,
    verify_le_text/2
]).

:- use_module(library(http/json)).
:- use_module(library(base64)).
:- use_module(library(process)).
:- use_module(library(uuid)).
:- use_module(le_kbs).
:- use_module(le_verifier).
:- use_module(llm/llm_client).

:- dynamic ca_status/2.      % JobID, running | finished(ok) | finished(error(Msg)) | interrupted | interrupt_requested
:- dynamic ca_config/2.      % JobID, ConfigDict (normalised)
:- dynamic ca_stage/3.       % JobID, StageIndex, StageLabel
:- dynamic ca_log/3.         % JobID, Seq, Text
:- dynamic ca_logseq/2.      % JobID, NextSeq
:- dynamic ca_branch/3.      % JobID, BranchIndex, InfoDict
:- dynamic ca_result/2.      % JobID, ResultDict
:- dynamic ca_llm_hook/1.    % Closure for tests: call(Closure, Purpose, Messages, Reply)

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
        Response0 = _{status: StatusStr, stage: StageIdx, stage_label: StageLabel,
                      branches: Branches, log: LogLines, next_seq: Next},
        ( ErrorMsg == none -> Response = Response0
        ; Response = Response0.put(error, ErrorMsg) )
    ;   Response = _{error: "Unknown job"}
    ).

handle_contract_result(Dict, Response) :-
    get_dict(job, Dict, JobStr), atom_string(JobID, JobStr),
    (   ca_result(JobID, Result)
    ->  Response = Result
    ;   ca_status(JobID, _)
    ->  Response = _{error: "Job has no result (yet)"}
    ;   Response = _{error: "Unknown job"}
    ).

handle_contract_interrupt(Dict, Response) :-
    get_dict(job, Dict, JobStr), atom_string(JobID, JobStr),
    (   ca_status(JobID, running)
    ->  retractall(ca_status(JobID, _)),
        asserta(ca_status(JobID, interrupt_requested)),
        Response = _{ok: true}
    ;   Response = _{ok: false, error: "Job is not running"}
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
    save_uploads(Dict, Dir, WordingFile, ScheduleFile, CaseFiles),
    normalise_config(Dict, WordingFile, ScheduleFile, CaseFiles, Config),
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

normalise_config(Dict, WordingFile, ScheduleFile, CaseFiles, Config) :-
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
    get_time(Now), Deadline is Now + Minutes * 60,
    Config = _{model: Model, judge_model: JudgeModel, api_keys: Keys,
               target: Target, k: K, w: W, repairs: Repairs,
               deadline: Deadline, features: Features,
               wording: WordingFile, schedule: ScheduleFile, cases: CaseFiles}.

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
%   - holdout (auto): with 2+ cases, develop against the first and score the
%     rest blind; auto-disabled with a single case.
%   - probes (per preset): differential interrogation probe count; 0 = off.
%   - interrogation_repair (true): let disagreements trigger repair rounds.
%   - paraphrase (thorough only): paraphrase-invariance check — informational
%     and expensive, hence off below thorough.
%   - clausewise (false): clause-by-clause drafting with a live ledger; more
%     calls and a fragile assembly, so off unless asked for.
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
                            paraphrase: false, clausewise: false, diff_repairs: true}) :- !.
preset_features(standard, _{probes: 4, interrogation_repair: true, holdout: auto,
                            paraphrase: false, clausewise: false, diff_repairs: true}) :- !.
preset_features(thorough, _{probes: 8, interrogation_repair: true, holdout: auto,
                            paraphrase: true, clausewise: false, diff_repairs: true}) :- !.
preset_features(_, F) :- preset_features(draft, F).

normalise_feature(V, V) :- number(V), !.
normalise_feature(V, V) :- ( V == true ; V == false ), !.
normalise_feature(S, A) :- ( string(S) ; atom(S) ), !, atom_string(A, S).
normalise_feature(V, V).

% --------------------------------- Uploads -----------------------------------
% Uploads arrive inside the /leapi JSON: {name: "...", text: "..."} for text
% files or {name: "...", data: "<base64>"} for binary (Word, PDF). Each is
% stored under <jobdir>/sources/ and converted to a text/markdown twin.

save_uploads(Dict, Dir, WordingFile, ScheduleFile, CaseFiles) :-
    atomic_list_concat([Dir, '/sources'], SrcDir),
    make_directory_path(SrcDir),
    ( get_dict(wording, Dict, WD), is_dict(WD)
    ->  save_one_upload(WD, SrcDir, wording, WordingFile)
    ;   throw(error(contract_assistant_error("A contract wording upload is required"), _))
    ),
    ( get_dict(schedule, Dict, SD), is_dict(SD)
    ->  save_one_upload(SD, SrcDir, schedule, ScheduleFile)
    ;   ScheduleFile = none
    ),
    ( get_dict(cases, Dict, Cases0), is_list(Cases0) -> Cases = Cases0 ; Cases = [] ),
    findall(CF,
            ( nth1(I, Cases, CD), is_dict(CD),
              atomic_list_concat([case_, I], Tag),
              save_one_upload(CD, SrcDir, Tag, CF)
            ),
            CaseFiles).

save_one_upload(UD, SrcDir, Tag, TextFile) :-
    ( get_dict(name, UD, Name0) -> true ; Name0 = "upload" ),
    atom_string(NameA, Name0),
    file_name_extension(_, Ext0, NameA),
    ( Ext0 == '' -> Ext = md ; downcase_atom(Ext0, Ext) ),
    atomic_list_concat([SrcDir, '/', Tag, '.', Ext], RawFile),
    (   get_dict(text, UD, Text), Text \== null
    ->  write_text_file(RawFile, Text)
    ;   get_dict(data, UD, B64), B64 \== null
    ->  decode_base64_to_file(B64, RawFile)
    ;   throw(error(contract_assistant_error("Upload has neither text nor data"), _))
    ),
    ensure_text_file(RawFile, Ext, SrcDir, Tag, TextFile).

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
%   Text-ish files are used as they are; Word documents go through pandoc
%   (falling back to macOS textutil), PDFs through pdftotext. This is the
%   plan's sanctioned use of UNIX subprocesses.
ensure_text_file(RawFile, Ext, _, _, RawFile) :-
    memberchk(Ext, [md, txt, le, text, markdown]), !.
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
        ( once(pipeline_stages(JobID)),
          retractall(ca_status(JobID, _)),
          asserta(ca_status(JobID, finished(ok)))
        ),
        Error,
        (   Error == contract_interrupt
        ->  ca_emit(JobID, "Job interrupted by user"-[]),
            retractall(ca_status(JobID, _)),
            asserta(ca_status(JobID, interrupted))
        ;   term_string(Error, EStr),
            ca_emit(JobID, "Job failed: ~w"-[EStr]),
            retractall(ca_status(JobID, _)),
            asserta(ca_status(JobID, finished(error(EStr))))
        )).

pipeline_stages(JobID) :-
    ca_config(JobID, Config),
    % ---- Stage 0: ingest & segment
    ca_set_stage(JobID, 0, "Ingest & segment"),
    read_text(Config.wording, WordingText),
    segment_markdown(WordingText, Sections),
    save_json_artifact(JobID, 'sectionmap.json', _{sections: Sections}),
    target_slice(WordingText, Sections, Config.target, JobID, WordingSlice),
    ( Config.schedule == none -> ScheduleText = "" ; read_text(Config.schedule, ScheduleText) ),
    findall(CT, (member(CF, Config.cases), read_text(CF, CT)), CaseTexts),
    holdout_split(Config, CaseTexts, DevCases, HeldCases),
    materials_block(WordingSlice, ScheduleText, DevCases, Materials),
    length(Sections, NSections), length(CaseTexts, NCases), length(HeldCases, NHeld),
    ca_emit(JobID, "Materials assembled (~w sections, ~w cases, ~w held out)"-[NSections, NCases, NHeld]),

    % ---- Stage 1: vocabulary consensus + architectures
    ca_set_stage(JobID, 1, "Vocabulary & architectures"),
    vocabulary_consensus(JobID, Config, Materials, Vocabulary),
    save_text_artifact(JobID, 'vocabulary.md', Vocabulary),
    architecture_sketches(JobID, Config, Materials, Vocabulary, Sketches),

    % ---- Stages 2-5: per-branch draft + repair + blind held-out evaluation
    ca_set_stage(JobID, 2, "Drafting & repairing branches"),
    Ctx = _{materials: Materials, vocabulary: Vocabulary,
            wording: WordingSlice, schedule: ScheduleText,
            dev_cases: DevCases, held_cases: HeldCases},
    length(Sketches, NBranches),
    numlist(1, NBranches, Idxs),
    pairs_keys_values(Pairs, Idxs, Sketches),
    (   NBranches =:= 1
    ->  maplist(run_branch(JobID, Config, Ctx), Pairs, Branches)
    ;   concurrent_maplist(run_branch(JobID, Config, Ctx), Pairs, Branches)
    ),

    % ---- Stage 6: score, select, interrogate, ledger
    ca_set_stage(JobID, 6, "Selection, interrogation & ledger"),
    select_winner(JobID, Branches, Winner),
    Winner = branch(WIdx, WText0, WScore),
    ca_emit(JobID, "Winner: branch ~w (~w)"-[WIdx, WScore.summary]),
    interrogate(JobID, Config, Ctx, WText0, WText, Interrogation),
    paraphrase_check(JobID, Config, Ctx, Paraphrase),
    ledger_for(JobID, Config, WordingSlice, WText, Ledger),
    findall(SD, (member(branch(I, _, S), Branches), SD = S.put(branch, I)), AllScores),
    save_text_artifact(JobID, 'winner.le', WText),
    Result = _{le: WText, filename: "contract.le", winner: WIdx,
               scores: AllScores, ledger: Ledger,
               interrogation: Interrogation, paraphrase: Paraphrase},
    save_json_artifact(JobID, 'scores.json',
                       _{winner: WIdx, scores: AllScores,
                         interrogation: Interrogation, paraphrase: Paraphrase}),
    retractall(ca_result(JobID, _)),
    assertz(ca_result(JobID, Result)).

%!  holdout_split(+Config, +CaseTexts, -DevCases, -HeldCases) is det.
%
%   Held-out-case scoring (feature `holdout`): develop against the first case,
%   keep the rest blind for evaluation. `auto`/true enable it when there are
%   at least two cases; a single case is never held out.
holdout_split(Config, CaseTexts, DevCases, HeldCases) :-
    H = Config.features.holdout,
    length(CaseTexts, N),
    (   ( H == false ; N < 2 )
    ->  DevCases = CaseTexts, HeldCases = []
    ;   CaseTexts = [First|Rest],
        DevCases = [First], HeldCases = Rest
    ).

% ------------------------- Stage 1: vocabulary -------------------------------

vocabulary_consensus(JobID, Config, Materials, Vocabulary) :-
    K = Config.k,
    numlist(1, K, Ks),
    findall(Sample,
            ( member(I, Ks),
              ca_check_alive(JobID),
              Temp is 0.15 + 0.2 * (I - 1),
              ca_emit(JobID, "Vocabulary sample ~w/~w (temperature ~2f)"-[I, K, Temp]),
              stage_llm(JobID, Config, vocabulary, 'stage1_vocabulary',
                        [materials-Materials], [temperature(Temp)], Sample)
            ),
            Samples),
    (   Samples = [Vocabulary]
    ->  true
    ;   ca_emit(JobID, "Merging ~w vocabulary samples (consensus)"-[K]),
        atomic_list_concat(Samples, "\n\n===== NEXT SAMPLE =====\n\n", Joined),
        stage_llm(JobID, Config, vocabulary_merge, 'stage1_merge',
                  [samples-Joined], [temperature(0)], Vocabulary)
    ).

architecture_sketches(JobID, Config, Materials, Vocabulary, Sketches) :-
    W = Config.w,
    architecture_angles(Angles0),
    length(Angles, W), append(Angles, _, Angles0),
    findall(Sketch,
            ( nth1(I, Angles, Angle),
              ca_check_alive(JobID),
              ca_emit(JobID, "Architecture sketch ~w/~w (~w)"-[I, W, Angle]),
              stage_llm(JobID, Config, architecture, 'stage1_architecture',
                        [materials-Materials, vocabulary-Vocabulary, angle-Angle],
                        [temperature(0.3)], Sketch)
            ),
            Sketches).

% Rotating decomposition angles for the beam (pattern library of the plan).
architecture_angles([
    "entitlement-style: decision = qualifies for a cover/right AND NOT excluded AND conditions met; exceptions as positive rules defeated by negation as failure",
    "obligation-style: model duties and breaches first; the decision predicates ask whether an obligation was breached and with what consequence",
    "computation-style: model the amount cascade first (limits, deductions, aggregations) and hang the qualitative tests off it",
    "event-style: model events and their temporal ordering first; decisions are queries over the event history",
    "definition-style: mirror the contract's defined terms one-to-one as derived predicates and compose decisions from them"
]).

% --------------------- Stages 2-5: draft and repair --------------------------

run_branch(JobID, Config, Ctx, Idx-Sketch, branch(Idx, Final, Score)) :-
    ca_set_branch(JobID, Idx, _{state: "drafting"}),
    ca_check_alive(JobID),
    (   Config.features.clausewise == true
    ->  clausewise_draft(JobID, Config, Ctx, Idx, Sketch, Draft0)
    ;   stage_llm(JobID, Config, draft(Idx), 'stage2_draft',
                  [materials-Ctx.materials, vocabulary-Ctx.vocabulary, architecture-Sketch],
                  [temperature(0.2)], DraftReply),
        extract_le_code(DraftReply, Draft0)
    ),
    branch_artifact_name(Idx, draft, DraftName),
    save_text_artifact(JobID, DraftName, Draft0),
    repair_loop(JobID, Config, Idx, Draft0, 0, none, Repaired, Score0),
    holdout_extend(JobID, Config, Ctx, Idx, Repaired, Score0, Final, Score),
    branch_artifact_name(Idx, final, FinalName),
    save_text_artifact(JobID, FinalName, Final),
    ca_set_branch(JobID, Idx, _{state: "done", summary: Score.summary,
                                errors: Score.errors, warnings: Score.warnings,
                                tests_passed: Score.tests_passed, tests_failed: Score.tests_failed}).

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
    stage_llm(JobID, Config, finalize(Idx), 'stage2_finalize',
              [program-Program1, schedule-Ctx.schedule, cases-CasesBlock,
               vocabulary-Ctx.vocabulary],
              [temperature(0.2)], Reply),
    extract_le_code(Reply, Draft),
    reverse(LedgerLines, Ordered),
    atomic_list_concat(Ordered, "\n", LiveLedger),
    branch_ledger_name(Idx, LedgerName),
    save_text_artifact(JobID, LedgerName, LiveLedger).

clausewise_block(JobID, Config, Ctx, Idx, Sketch, NB, Block, Prog0-Led0-I, Prog-Led-I1) :-
    ca_check_alive(JobID),
    ca_emit(JobID, "Branch ~w: clause block ~w/~w"-[Idx, I, NB]),
    stage_llm(JobID, Config, clause(Idx, I), 'stage2_clause',
              [program-Prog0, clause-Block, vocabulary-Ctx.vocabulary,
               architecture-Sketch],
              [temperature(0.2)], Reply),
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

%!  repair_loop(+JobID, +Config, +Idx, +Text, +Iter, +Best0, -Final, -Score)
%
%   Iterates verify -> feedback -> LLM repair. Keeps the best-ranked version
%   seen so far (a repair can make things worse) and returns that one when
%   the loop ends without reaching a clean program.
repair_loop(JobID, Config, Idx, Text, Iter, Best0, Final, Score) :-
    verify_le_text(Text, V),
    score_summary(V, Summary),
    ca_set_branch(JobID, Idx, _{state: "repairing", iteration: Iter, summary: Summary,
                                errors: V.errors, warnings: V.warnings,
                                tests_passed: V.tests_passed, tests_failed: V.tests_failed}),
    ca_emit(JobID, "Branch ~w iteration ~w: ~w"-[Idx, Iter, Summary]),
    best_of(Best0, cand(Text, V, Summary), Best),
    (   ( V.errors =:= 0, V.tests_failed =:= 0, V.tests_passed > 0 )
    ->  Final = Text, branch_score(V, Summary, Score)
    ;   Iter >= Config.repairs
    ->  ca_emit(JobID, "Branch ~w: repair budget exhausted, keeping the best iteration"-[Idx]),
        best_result(Best, Final, Score)
    ;   deadline_exceeded(Config)
    ->  ca_emit(JobID, "Branch ~w: wall-clock budget exhausted, keeping the best iteration"-[Idx]),
        best_result(Best, Final, Score)
    ;   ca_check_alive(JobID),
        format_verify_feedback(V, Feedback),
        stage_llm(JobID, Config, repair(Idx, Iter), 'stage5_repair',
                  [program-Text, feedback-Feedback], [temperature(0)], Reply),
        apply_repair_reply(Config, Reply, Text, Text1, How),
        ca_emit(JobID, "Branch ~w repair ~w: ~w"-[Idx, Iter, How]),
        Iter1 is Iter + 1,
        repair_loop(JobID, Config, Idx, Text1, Iter1, Best, Final, Score)
    ).

%!  apply_repair_reply(+Config, +Reply, +OldText, -NewText, -How) is det.
%
%   Feature `diff_repairs` (default on): a repair reply may carry
%   SEARCH/REPLACE edit blocks; matching edits are applied to the old text.
%   A full fenced program (the old behaviour) is always accepted — it is the
%   automatic fallback when no edit matches or the feature is off.
apply_repair_reply(Config, Reply, OldText, NewText, How) :-
    (   Config.features.diff_repairs == true,
        extract_search_replace(Reply, Edits),
        Edits \== []
    ->  apply_edits(Edits, OldText, Text1, Applied, Failed),
        (   Applied > 0
        ->  NewText = Text1,
            format(string(How), "applied ~w edit(s), ~w did not match", [Applied, Failed])
        ;   first_fenced_block(Reply, Full)
        ->  NewText = Full, How = "edits did not match; used the full program from the reply"
        ;   NewText = OldText, How = "no edit matched and no full program given; text unchanged"
        )
    ;   extract_le_code(Reply, NewText),
        How = "replaced the full program"
    ).

%!  extract_search_replace(+Reply, -Edits:list(edit(Search, Replace))) is det.
%
%   Parses blocks of the form
%       <<<<<<< SEARCH\n <text> \n=======\n <text> \n>>>>>>> REPLACE
extract_search_replace(Reply, Edits) :-
    atom_string(RA, Reply),
    atomic_list_concat(Chunks, '<<<<<<< SEARCH\n', RA),
    Chunks = [_|Rest],
    findall(edit(Search, Replace),
            ( member(Chunk, Rest),
              sub_atom(Chunk, B, _, _, '\n=======\n'),
              sub_atom(Chunk, 0, B, _, Search0),
              Mid is B + 9,
              sub_atom(Chunk, Mid, _, 0, Tail),
              sub_atom(Tail, RB, _, _, '\n>>>>>>> REPLACE'),
              sub_atom(Tail, 0, RB, _, Replace0),
              atom_string(Search0, Search),
              atom_string(Replace0, Replace)
            ),
            Edits).

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

verify_rank(V, Text, rank(V.errors, NoTests, V.tests_failed, NegPassed, V.warnings, Len)) :-
    ( V.tests_passed + V.tests_failed =:= 0 -> NoTests = 1 ; NoTests = 0 ),
    NegPassed is -V.tests_passed,
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

% Rank tuple, lexicographic (the plan's fitness function): fewer errors, fewer
% held-out failures (blind evaluation ranks above development tests), fewer
% failed tests, MORE passed tests, fewer warnings, smaller program.
branch_rank(branch(_, Text, S), rank(S.errors, NoTests, HF, S.tests_failed, NegPassed, S.warnings, Len)) :-
    HF = S.get(holdout_failed, 0),
    ( S.tests_passed + S.tests_failed =:= 0 -> NoTests = 1 ; NoTests = 0 ),
    NegPassed is -S.tests_passed,
    string_length(Text, Len).

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
                  [temperature(0.4)], Reply),
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
            repair_loop(JobID, Config, probes, Merged, 0, none, FinalMerged, _),
            verify_le_text(FinalMerged, VF)
        ;   FinalMerged = Merged, VF = V1
        ),
        probe_delta(V0, VF, AgreedF, DisagreedF),
        (   ( DisagreedF =:= 0, VF.errors =< V0.errors )
        ->  Text = FinalMerged,
            open_disagreements(VF, V0, Open),
            ca_emit(JobID, "Interrogation: all probes agree; probes kept as regression scenarios"-[])
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
                  [wording-Ctx.wording], [temperature(0.7)], PText),
        stage_llm(JobID, Config, vocabulary_paraphrase, 'stage1_vocabulary',
                  [materials-PText], [temperature(0.2)], Sample),
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

ledger_for(JobID, Config, WordingSlice, WinnerText, Ledger) :-
    (   deadline_exceeded(Config)
    ->  Ledger = "(ledger skipped: budget exhausted)"
    ;   catch(
            stage_llm(JobID, Config, ledger, 'stage6_ledger',
                      [materials-WordingSlice, program-WinnerText],
                      [temperature(0)], Ledger),
            E,
            ( term_string(E, ES),
              format(atom(Ledger), "(ledger failed: ~w)", [ES]) ))
    ),
    save_text_artifact(JobID, 'ledger.md', Ledger).

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
    V = _{errors: NErrors, warnings: NWarnings,
          tests_passed: NPassed, tests_failed: NFailed,
          issues: Issues, test_details: Details}.

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
        append(Options, [api_key(Key), max_tokens(16000)], Opts),
        catch(
            llm_client:llm_request(Model, Messages, Reply, Opts),
            E,
            ( term_string(E, ES),
              ca_emit(JobID, "LLM call failed (~w): ~w"-[Purpose, ES]),
              throw(error(contract_assistant_error(llm_failed(Purpose, ES)), _)) ))
    ).

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
    (   exists_file('docs/le_summary.md') -> read_file_to_string('docs/le_summary.md', Text, [])
    ;   exists_file('../docs/le_summary.md') -> read_file_to_string('../docs/le_summary.md', Text, [])
    ;   Text = ""
    ).

%!  extract_le_code(+Reply, -Code) is det.
%
%   Pulls the first fenced code block out of an LLM reply; if there is no
%   fence, the whole reply is taken as code.
extract_le_code(Reply, Code) :-
    (   first_fenced_block(Reply, Code0)
    ->  Code = Code0
    ;   Code = Reply
    ).

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
target_slice(Text, _, none, _, Text) :- !.
target_slice(Text, Sections, Target, JobID, Slice) :-
    string_lower(Target, TL),
    findall(S, ( member(S, Sections), string_lower(S.title, STL),
                 sub_string(STL, _, _, _, TL) ), Matches),
    (   Matches == []
    ->  ca_emit(JobID, "Target section '~w' not found; using the full wording"-[Target]),
        Slice = Text
    ;   findall(G, ( member(G, Sections), string_lower(G.title, GTL),
                     sub_string(GTL, _, _, _, "general") ), Generals),
        append(Generals, Matches, Wanted0),
        sort(start_line, @<, Wanted0, Wanted),
        split_string(Text, "\n", "", Lines),
        findall(Part,
                ( member(Sec, Wanted),
                  section_lines(Lines, Sec, Part) ),
                Parts),
        atomic_list_concat(Parts, "\n\n[...]\n\n", Slice),
        length(Wanted, NW),
        ca_emit(JobID, "Sliced wording to ~w sections matching '~w' (+ general terms)"-[NW, Target])
    ).

section_lines(Lines, Sec, Part) :-
    findall(L, ( between(Sec.start_line, Sec.end_line, I), nth1(I, Lines, L) ), Ls),
    atomic_list_concat(Ls, "\n", Part).

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
    print_message(informational, format("[contract_assistant ~w] ~w", [JobID, Line])).

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

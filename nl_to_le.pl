/** <module> Natural-language → Logical English conversion (LLM-assisted, verified).

    Turns an English sentence into Logical English (LE) text — either fact statements
    (for a scenario) or a query body — that respects the templates already declared in
    a program, and then VERIFIES the result against that program before returning it.

    This is the "Write it in English…" path of the Scenario and Query editors: one
    interactive conversion, seconds not minutes, against a program the user owns and
    which is never modified. Its bigger sibling is the LE Contract Assistant, which
    generates whole programs (and, in its `scenario` / `query` modes, fragments) as a
    budgeted background job; the two share the verifier and the way verifier issues are
    ranked and presented to a model (le_issue_feedback.pl), and nothing else.

    The loop:

      1. Verify the baseline Program as given, to record its PRE-EXISTING issues (and
         which of its tests pass — a fragment must not break one).
      2. Ask the LLM for an initial fragment (facts / query body) from the sentence.
      3. Splice the fragment into a throw-away copy of the program (as a scenario or a
         query block) and verify that. Compare to the baseline: only issues that are
         NOT in the baseline count as NEW — they were introduced by the fragment. Their
         line numbers are re-based onto the fragment, since that is all the model sees.
      4. If there are new issues, feed back a RANKED, capped working set of them —
         errors first, then warnings that change what the program means, then cosmetic
         ones — and re-verify. This repeats while the rounds keep improving, bounded by
         a patience counter and a hard round cap (see refine/12).
      5. Keep the BEST round, not the last one: a correction can make things worse, and
         it used to be the worse version that was returned.
      6. Return the final fragment plus any new issues that still remain. The spliced
         program is discarded — only the fragment (the new scenario facts or query) is
         kept; the caller may warn about, yet still use, a fragment with new issues.

    The single entry point is english_to_le/8. The Model id and Options are passed
    straight to the LLM client (llm/le_llm.pl chooses which); if Options omits
    api_key(_), the provider env var (e.g. GROQ_API_KEY) is used. Options may also
    carry this module's own `max_rounds(N)` and `patience(N)`, which are consumed here
    rather than forwarded. Verification uses le_verifier:verify/2 in-process.
*/

:- module(nl_to_le, [ english_to_le/8 ]).

%   Through the broker, not straight at llm_client: an embedder (LPS2) can
%   substitute its own client, so English→LE uses the keys and the model
%   registry the surrounding application already has. See llm/le_llm.pl.
:- use_module(llm/le_llm).
:- use_module(le_i18n).
:- use_module(le_kbs, [load_text/2, text_language/2]).
:- use_module(le_verifier, [verify/2, unmatched_sentences/3]).
:- use_module(le_issue_feedback).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).

% A distinctive scenario/query name for the throw-away verification splice, unlikely
% to collide with a name already in the user's program.
nl_check_name('nl__editor_check__').

% How hard to try. `max_rounds` is a runaway guard — the loop normally ends because a
% round stopped improving (patience) or because the fragment verified clean, which is
% the common case and costs ONE call. It used to be a flat two corrections whatever
% happened, so a fragment that was still getting better on round two was returned
% broken; and since only the LAST round was kept, a fragment that got WORSE on round
% two was returned worse than the one before it.
default_max_rounds(4).
default_patience(2).

% A fragment is a handful of lines: a working set of eight issues already describes
% everything wrong with it several times over. (The Contract Assistant uses twelve for
% a whole program.)
feedback_caps(caps(8, 4, 2)).

%!  english_to_le(+Kind, +Sentence, +Templates, +Program, +Model, +Options, -LEText, -NewIssues) is det.
%
%   Convert the English Sentence into Logical English text with the LLM Model, then
%   verify it against Program and refine it up to a bounded number of times.
%
%   @arg Kind      `facts` (produce fact statements, each ending with a period) or
%                  `query` (produce one query body: conditions joined by and/or,
%                  optionally negated, ending in one period). Any other value throws.
%   @arg Sentence  the English text (atom or string) to translate.
%   @arg Templates a list of template label strings/atoms WITH their `*...*` markers;
%                  the model must produce only instances of these.
%   @arg Program   the baseline LE program source (atom/string): its templates and
%                  rules give the verification context, and its existing scenarios and
%                  queries are shown to the model as the house style to match. The
%                  fragment is spliced into a COPY of it for checking; Program itself
%                  is never modified.
%   @arg Model     an llm_client model id (atom/string), e.g. 'openai/gpt-oss-120b'.
%   @arg Options   forwarded to llm_request/4 (e.g. api_key(Key), max_tokens(N)),
%                  except this module's own, which are consumed here:
%                  `max_rounds(N)` and `patience(N)` bound the refinement loop,
%                  and `check_regressions(true)` additionally runs the program's
%                  own tests before and after the splice (off by default — see
%                  baseline/3).
%   @arg LEText    the cleaned LE fragment (a string): facts (kind facts) or a query
%                  body (kind query), fences/prose stripped.
%   @arg NewIssues the issues introduced by LEText that are NOT in the baseline and
%                  still remain after refinement, most important first (errors, then
%                  warnings about meaning, then cosmetic ones). Each is a dict with
%                  keys severity, type, message, fix, line, source. Empty when the
%                  fragment verified cleanly; non-empty means the caller should warn.
%
%   @throws error(type_error(nl_kind, Kind), _) if Kind is neither facts nor query.
%   Errors from the LLM call propagate from llm_client unchanged.
english_to_le(Kind, Sentence, Templates, Program, Model, Options0, LEText, NewIssues) :-
    % The fragment must be written in the PROGRAM's language: its keyword set
    % drives both the prompt's connective words and the verification parse.
    text_language(Program, ProgLang),
    le_i18n:set_le_language(ProgLang),
    must_be_kind(Kind),
    to_string(Program, ProgramS),
    to_string(Sentence, SentenceS),
    loop_options(Options0, Limits, CheckRegressions, Options1),
    ensure_max_tokens(Options1, Options2),
    ensure_temperature(Options2, Options),
    baseline(ProgramS, CheckRegressions, Baseline),
    system_prompt(Kind, Templates, ProgramS, System),
    Messages0 = [ _{role: system, content: System}, _{role: user, content: SentenceS} ],
    le_llm_request(Model, Messages0, Raw0, Options),
    clean_reply(Raw0, LE0),
    refine(Kind, ProgramS, Baseline, Model, Options, Messages0, Raw0, LE0,
           1, none, 0, Limits, LEText0, New0),
    % One last, more expensive question, asked once rather than every round: does the
    % fragment BREAK anything that used to work? A scenario whose facts leak out of
    % their block (a line the splice could not indent into it, a stray section header)
    % becomes global data and quietly changes every other scenario's answers.
    regression_issues(Kind, ProgramS, Baseline, LEText0, Regressions),
    append(Regressions, New0, NewIssues),
    LEText = LEText0.

%!  refine(+Kind, +Program, +Baseline, +Model, +Options, +Messages, +LastReply, +LE,
%!         +Round, +Best0, +Streak, +Limits, -FinalLE, -FinalNewIssues) is det.
%
%   Verify the current fragment LE against the (throw-away) spliced program; if it
%   introduces new issues, ask the model to correct it and recurse.
%
%   The loop is progress-aware rather than a fixed count, for the same reason the
%   Contract Assistant's is: the round that would have fixed the fragment is often the
%   one after the arbitrary limit. It ends when the fragment is clean, when
%   `Patience` consecutive rounds have failed to improve it, or at the `MaxRounds`
%   runaway guard — and it returns the BEST round seen, which is not always the last.
refine(Kind, Program, Baseline, Model, Options, Messages, LastReply, LE,
       Round, Best0, Streak0, Limits, FinalLE, FinalNew) :-
    Limits = limits(Patience, MaxRounds),
    check_fragment(Kind, Program, Baseline, LE, New),
    Cand = cand(LE, New),
    best_of(Best0, Cand, Best),
    ( ( Best0 == none ; Best == Cand ) -> Streak = 0 ; Streak is Streak0 + 1 ),
    (   New == []
    ->  FinalLE = LE, FinalNew = []
    ;   ( Round >= MaxRounds ; Streak >= Patience )
    ->  Best = cand(FinalLE, FinalNew)
    ;   kind_noun(Kind, Noun),
        % Correct the BEST fragment known, not whatever the last round left: a round
        % that made things worse must not become the base of every later round.
        Best = cand(WorkLE, WorkNew),
        rewind_note(WorkLE, LE, RewindNote),
        format_issue_feedback(WorkNew, IssuesText),
        format(string(Feedback),
            "Adding your output to the program produced these NEW problems (the line numbers are lines of YOUR output):~n~w~n~w~nReturn a corrected version of the ~w below. Output ONLY the corrected ~w, in the same plain-text format as before — no explanation, no code fences.~n~n~w",
            [IssuesText, RewindNote, Noun, Noun, WorkLE]),
        append(Messages, [ _{role: assistant, content: LastReply}, _{role: user, content: Feedback} ], Messages1),
        le_llm_request(Model, Messages1, Raw1, Options),
        clean_reply(Raw1, LE1),
        Round1 is Round + 1,
        refine(Kind, Program, Baseline, Model, Options, Messages1, Raw1, LE1,
               Round1, Best, Streak, Limits, FinalLE, FinalNew)
    ).

% What to say when the round being corrected is NOT the one the model just sent.
% Without it the model — asked the same question about the same fragment — simply
% sends the discarded version again.
rewind_note(Work, Last, Note) :-
    (   Work == Last
    ->  Note = ""
    ;   Note = "\nYOUR PREVIOUS ATTEMPT WAS DISCARDED: it verified worse than the version below. Do not send it again.\n"
    ).

%!  best_of(+Cand0, +Cand1, -Best) is det.
%
%   The better of two candidates. Fewer errors first (a fragment that does not parse
%   is worth nothing), then fewer warnings about MEANING — a fact that silently holds
%   of everyone, a datum no rule reads — then fewer cosmetic warnings. An EMPTY
%   fragment loses to everything: it has no issues precisely because it says nothing.
best_of(none, Cand, Cand) :- !.
best_of(cand(L0, N0), cand(L1, N1), Best) :-
    fragment_rank(L0, N0, R0),
    fragment_rank(L1, N1, R1),
    ( R1 @< R0 -> Best = cand(L1, N1) ; Best = cand(L0, N0) ).

fragment_rank(LE, New, rank(Empty, NErrors, NModelling, NOther)) :-
    ( blank_text(LE) -> Empty = 1 ; Empty = 0 ),
    include([I]>>(get_dict(severity, I, "error")), New, Errors),
    length(Errors, NErrors),
    count_modelling_warnings(New, NModelling),
    length(New, NAll),
    NOther is NAll - NErrors - NModelling.

% ============================ Verification of a fragment =====================

%!  baseline(+ProgramText, -Baseline:dict) is det.
%
%   What is already true of the user's program, so that only what the FRAGMENT
%   introduces is reported. Keys:
%
%     - sigs:   signatures of the program's own issues (it need not be clean; most
%               working programs carry a warning or two, and reporting those back as
%               "problems with your sentence" is what made the old warning list noise);
%     - lines:  how many lines the program has, so a spliced issue's line number can be
%               re-based onto the fragment the model actually wrote;
%     - loaded: whether the program parsed at all. When it did not, a fragment cannot be
%               blamed for the wreckage, so the load-failure issue is suppressed rather
%               than shown to a user who asked about one sentence;
%     - passing: the (query, scenario) pairs whose tests pass today — the ones a
%               fragment must not break. Empty unless the caller asked for the
%               regression check (see loop_options/4): running the program's
%               tests twice costs real seconds on a path a person is waiting on,
%               and the splice indents every generated line into its own block,
%               so a statement escaping into the program is already hard here.
%               The Contract Assistant's fragment modes, where the model writes
%               the whole block header itself and the job is budgeted, run it
%               always.
baseline(ProgramText, CheckRegressions, Baseline) :-
    program_issues(ProgramText, none, Issues, Loaded),
    maplist(issue_signature, Issues, Sigs),
    count_lines(ProgramText, NLines),
    (   CheckRegressions == true
    ->  passing_tests(ProgramText, Passing)
    ;   Passing = []
    ),
    Baseline = _{sigs: Sigs, lines: NLines, loaded: Loaded, passing: Passing}.

%!  check_fragment(+Kind, +Program, +Baseline, +LE, -New) is det.
%
%   The issues LE introduces into Program, ranked most important first.
check_fragment(_Kind, _Program, _Baseline, LE, New) :-
    blank_text(LE), !,
    New = [_{severity: "error", type: "empty_fragment", message:
             "Your reply was empty. Produce Logical English for the sentence using the templates listed, or — only if no template is even remotely applicable — say nothing at all.",
             fix: "", line: 0, source: ""}].
check_fragment(Kind, Program, Baseline, LE, New) :-
    candidate_program(Kind, Program, LE, Candidate),
    program_issues(Candidate, check(Kind), Issues, Loaded),
    asterisk_issues(LE, Asterisks),
    (   Loaded == false, Baseline.loaded == false
    ->  % The program was already unparseable; that is not this sentence's doing.
        New = []
    ;   exclude(in_baseline(Baseline.sigs), Issues, New0),
        maplist(rebase_line(Baseline.lines), New0, New1),
        append(Asterisks, New1, New2),
        rank_issues(New2, New)
    ).

%!  program_issues(+ProgramText, +Block, -Issues, -Loaded) is det.
%
%   Every issue an LE text carries: the grammar/load-time le_issue/6 facts (parse
%   errors, missing dots, ...), the semantic le_verifier:verify/2 checks (missing
%   templates, undefined predicates, ...) and — when Block is check(Kind) — the
%   sentences of the throw-away block that matched NO template (see
%   unmatched_issues/5). Each issue carries its severity, type, message, suggested
%   fix, line number and source line.
%
%   A text too broken to load at all used to come back as NO issues, which the
%   baseline diff then read as "the fragment introduced nothing" — the one case where
%   the fragment is most certainly wrong was the one case reported clean. It now comes
%   back as one load_failure error, and `Loaded` says which happened.
program_issues(ProgramText, Block, Issues, Loaded) :-
    % Recover with `true` (not `fail`) so a thrown error leaves Error bound and the
    % catch still succeeds; then distinguish success (Error unbound) from a throw.
    (   catch(collect_issues(ProgramText, Block, Issues0), Error, true)
    ->  (   var(Error)
        ->  Issues = Issues0, Loaded = true
        ;   load_failure_issue(Error, I), Issues = [I], Loaded = false
        )
    ;   load_failure_issue('the loader gave up', I), Issues = [I], Loaded = false
    ).

load_failure_issue(E, _{severity: "error", type: "load_failure", message: Msg,
                        fix: "", line: 0, source: ""}) :-
    truncated(E, 200, EStr),
    format(string(Msg),
           "The program no longer parses at all once your text is added (~w). Usual causes: *asterisks* around a phrase (they belong only in the templates section), a line that is not a sentence of any declared template, or a missing final period.",
           [EStr]).

collect_issues(ProgramText, Block, Issues) :-
    load_text(ProgramText, KB),
    split_string(ProgramText, "\n", "", SrcLines),
    line_start_offsets(SrcLines, Starts),
    unmatched_issues(Block, KB, Starts, SrcLines, Unmatched),
    findall(_{severity: SevS, type: TypeS, message: MsgS, fix: FixS,
              line: LineNo, source: SrcLine},
            ( KB:le_issue(Sev, Type, Msg, Fix, Start, _End),
              term_string(Sev, SevS), term_string(Type, TypeS),
              issue_text(Msg, MsgS), issue_text(Fix, FixS),
              issue_location(Starts, SrcLines, Start, LineNo, SrcLine) ),
            Grammar),
    ( verify(KB, VIssues) -> true ; VIssues = [] ),
    findall(_{severity: "warning", type: VTypeS, message: DescS, fix: VFixS,
              line: VLineNo, source: VSrcLine},
            ( member(issue(VType, Desc, VFix, VStart, _VEnd), VIssues),
              term_string(VType, VTypeS),
              issue_text(Desc, DescS), issue_text(VFix, VFixS),
              issue_location(Starts, SrcLines, VStart, VLineNo, VSrcLine) ),
            Semantic),
    append([Unmatched, Grammar, Semantic], All),
    % load_text also asserts the verify/2 results as le_issue, so the two sources
    % overlap — keep one of each (by signature), preserving order.
    dedupe_issues(All, [], Issues).

%!  unmatched_issues(+Block, +KB, +Starts, +Lines, -Issues) is det.
%
%   The sentences of the throw-away block that matched NO declared template
%   (le_verifier:unmatched_sentences/3).
%
%   This is the hole the baseline diff alone left wide open, and the one that
%   mattered most. A scenario fact or a query condition the parser cannot match is
%   not an error and not a warning: it is parked in the knowledge base as an
%   `unknown_template/3` term and NOTHING is reported. So a model that answered
%   "alice flies to mars" for a program that has no such template produced a fragment
%   the verifier called perfectly clean — and the editor inserted a line that decides
%   nothing, silently, which is the exact failure this whole verify-and-refine loop
%   exists to prevent.
unmatched_issues(none, _, _, _, []) :- !.
unmatched_issues(check(Kind), KB, Starts, Lines, Issues) :-
    nl_check_name(Name),
    check_block_scope(Kind, Name, Scope),
    unmatched_sentences(KB, Scope, Found),
    maplist(unmatched_issue(Kind, Starts, Lines), Found, Issues).

check_block_scope(facts, Name, scenario(Name)).
check_block_scope(query, Name, query(Name)).

unmatched_issue(Kind, Starts, Lines, unmatched(_, Start, Text0), Issue) :-
    truncated(Text0, 200, Text),
    issue_location(Starts, Lines, Start, LineNo, SrcLine),
    kind_unmatched_message(Kind, Text, Msg),
    Issue = _{severity: "error", type: "unknown_template", message: Msg,
              fix: "Rewrite it as an instance of one of the templates listed, or leave it out.",
              line: LineNo, source: SrcLine}.

kind_unmatched_message(facts, Text, Msg) :-
    format(string(Msg),
           "'~w' matches NO declared template, so it states nothing: the reasoner will never read it. Every fact must be a sentence of one of the templates.",
           [Text]).
kind_unmatched_message(query, Text, Msg) :-
    format(string(Msg),
           "'~w' matches NO declared template, so this condition can never be evaluated. Every condition must be a sentence of one of the templates.",
           [Text]).

%!  asterisk_issues(+LE, -Issues) is det.
%
%   `*asterisked phrases*` in the fragment itself. They belong only inside the
%   templates section; anywhere else they quietly turn a constant into a variable or
%   break the parse, and the verifier does not always say so. Adjacency distinguishes
%   a marker (`*a claim*`) from multiplication (`X * Y`).
asterisk_issues(LE, Issues) :-
    split_string(LE, "\n", "", Lines),
    findall(I,
            ( nth1(N, Lines, L), normalize_space(string(T), L), has_asterisk_variable(T),
              format(string(Msg),
                     "Asterisks around a phrase are not allowed here — they mark placeholders in the templates section only. Write 'a claim' (first mention) or 'the claim' (later mentions) instead.", []),
              I = _{severity: "error", type: "asterisks_outside_templates", message: Msg,
                    fix: "Remove the asterisks.", line: N, source: T} ),
            Issues).

% A '*' immediately followed by a non-space, with a later '*' immediately preceded by
% a non-space: an *asterisked phrase*, not arithmetic.
has_asterisk_variable(T) :-
    sub_string(T, B, 1, _, "*"),
    B1 is B + 1,
    sub_string(T, B1, 1, _, C1), C1 \== " ",
    sub_string(T, B2, 1, _, "*"), B2 > B1,
    B3 is B2 - 1,
    sub_string(T, B3, 1, _, C2), C2 \== " ",
    !.

dedupe_issues([], _, []).
dedupe_issues([I|T], Seen, Out) :-
    issue_signature(I, Sig),
    ( memberchk(Sig, Seen)
    ->  dedupe_issues(T, Seen, Out)
    ;   Out = [I|Out1], dedupe_issues(T, [Sig|Seen], Out1)
    ).

% The fragment is appended at the END of the program, so every baseline issue keeps
% its exact (type, message, line) signature in the candidate; anything with a
% signature not seen in the baseline was introduced by the fragment.
in_baseline(BaseSigs, Issue) :-
    issue_signature(Issue, Sig),
    memberchk(Sig, BaseSigs).

issue_signature(Issue, sig(Type, Msg, Line)) :-
    ( get_dict(type, Issue, Type) -> true ; Type = "" ),
    ( get_dict(message, Issue, Msg) -> true ; Msg = "" ),
    ( get_dict(line, Issue, Line) -> true ; Line = 0 ).

% Line numbers of the SPLICED program mean nothing to a model that only ever saw its
% own few lines. Re-base them: line 1 of the fragment is the first line after the
% program and the throw-away header the splice added.
rebase_line(ProgramLines, I0, I) :-
    (   get_dict(line, I0, N), integer(N), N > 0
    ->  Rebased is N - ProgramLines - 2,     % the blank line and the section header
        ( Rebased > 0 -> I = I0.put(line, Rebased) ; I = I0.put(line, 0) )
    ;   I = I0
    ).

%!  rank_issues(+Issues, -Ranked) is det.
%
%   Most important first: errors, then the warnings that change what the program MEANS
%   (le_issue_feedback:modelling_warning/1 — a fact that holds of everyone, a datum no
%   rule reads), then the cosmetic rest. The caller shows this list to the user in the
%   same order, so the first line of the warning box is the one worth reading.
rank_issues(Issues, Ranked) :-
    findall(R-I, ( member(I, Issues), issue_rank(I, R) ), Keyed),
    keysort(Keyed, Sorted),
    pairs_values(Sorted, Ranked).

issue_rank(I, R) :-
    (   get_dict(severity, I, "error") -> R = 1
    ;   get_dict(type, I, Ty), modelling_warning(Ty) -> R = 2
    ;   R = 3
    ).

%!  format_issue_feedback(+New, -Text) is det.
%
%   The working set one correction round is asked to fix: the ranked issues, capped
%   per type and overall, with a closing line naming what was left out. While the
%   fragment does not parse, a warning is not worth a line of the prompt.
format_issue_feedback(New, Text) :-
    findall(item(R, ItemType, Line),
            ( member(I, New), issue_rank(I, R), issue_line(I, Ty, Line),
              ( R =:= 1 -> ItemType = error(Ty) ; ItemType = Ty ) ),
            Items0),
    (   memberchk(item(1, _, _), Items0)
    ->  partition([item(R, _, _)]>>(R < 2), Items0, Items, Deferred)
    ;   Items = Items0, Deferred = []
    ),
    feedback_caps(Caps),
    select_feedback(Caps, Items, Shown, Omitted0),
    append(Omitted0, Deferred, Omitted),
    findall(L, member(item(_, _, L), Shown), Lines),
    omitted_note(Omitted, NoteLines),
    append(Lines, NoteLines, All),
    ( All == [] -> Text = "no issues" ; atomic_list_concat(All, "\n", Text) ).

% --------------------------- Regression against the program -------------------
% The one check the interactive path pays for twice (once on the program, once on the
% final fragment) rather than every round: a fragment must not break a test that
% passes today. It only ever produces ERRORS, and only for tests the user already had
% working, so it cannot become noise.

%!  passing_tests(+ProgramText, -Passing) is det.
%
%   The (query, scenario) pairs of the program's own expectations that pass today.
%   A program with an implausible number of them is skipped rather than run: this is
%   an interactive path, and the point is a fast sanity check, not a test suite.
passing_tests(ProgramText, Passing) :-
    (   catch(run_program_tests(ProgramText, Results), _, fail)
    ->  findall(Q-S, member(pass(Q, S), Results), Passing)
    ;   Passing = []
    ).

max_regression_tests(25).

run_program_tests(ProgramText, Results) :-
    load_text(ProgramText, KB),
    (   current_predicate(KB:le_expected/4)
    ->  findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Tests)
    ;   Tests = []
    ),
    length(Tests, N),
    max_regression_tests(Max),
    (   N =< Max
    ->  maplist([T, R]>>( catch(le_kbs:run_one_test(KB, T, R), _, R = skipped) ), Tests, Results)
    ;   Results = []
    ).

%!  regression_issues(+Kind, +Program, +Baseline, +LE, -Issues) is det.
%
%   The tests that passed before the fragment and do not pass with it.
regression_issues(_Kind, _Program, Baseline, _LE, []) :- Baseline.passing == [], !.
regression_issues(_Kind, _Program, _Baseline, LE, []) :- blank_text(LE), !.
regression_issues(Kind, Program, Baseline, LE, Issues) :-
    candidate_program(Kind, Program, LE, Candidate),
    (   catch(run_program_tests(Candidate, Results), _, fail)
    ->  findall(Q-S, member(pass(Q, S), Results), StillPassing),
        subtract(Baseline.passing, StillPassing, Broken),
        maplist(regression_issue, Broken, Issues)
    ;   Issues = []
    ).

regression_issue(Q-S, _{severity: "error", type: "regression", message: Msg,
                        fix: "", line: 0, source: ""}) :-
    format(string(Msg),
           "Adding this text BREAKS a test that passes in your program today: query '~w' in scenario '~w'. Almost always this means a statement escaped the new block and became a fact of the whole program — check that every line is a sentence of a declared template.",
           [Q, S]).

% ------------------------------- Splicing -------------------------------------

% candidate_program(+Kind, +Program, +LE, -Candidate): Program with the fragment LE
% spliced in at the end as a throw-away scenario (facts) or query (query body).
candidate_program(facts, Program, LE, Candidate) :-
    nl_check_name(Name),
    fact_lines(LE, Body),
    format(string(Candidate), "~w~n~nscenario ~w is:~n~w~n", [Program, Name, Body]).
candidate_program(query, Program, LE, Candidate) :-
    nl_check_name(Name),
    query_body(LE, Body),
    format(string(Candidate), "~w~n~nquery ~w is:~n~w~n", [Program, Name, Body]).

% fact_lines(+LE, -Body): the fragment's non-blank lines, each indented and ended
% with a period (a scenario fact per line).
fact_lines(LE, Body) :-
    nonblank_lines(LE, Lines),
    maplist([L, O]>>(ensure_period(L, P), format(string(O), "    ~w", [P])), Lines, Indented),
    atomic_list_concat(Indented, "\n", Body).

% query_body(+LE, -Body): the fragment's non-blank lines indented, terminated by a
% single period (a query body).
query_body(LE, Body) :-
    nonblank_lines(LE, Lines),
    maplist([L, O]>>(string_trim(L, T), format(string(O), "    ~w", [T])), Lines, Indented),
    atomic_list_concat(Indented, "\n", Body0),
    ensure_period(Body0, Body).

nonblank_lines(Text, Lines) :-
    split_string(Text, "\n", "", Lines0),
    exclude(blank_line, Lines0, Lines).

blank_line(L) :- split_string(L, "", " \t\r\n", [""]).

blank_text(T) :- to_string(T, S), split_string(S, "", " \t\r\n", [""]).

count_lines(Text, N) :-
    split_string(Text, "\n", "", Lines), length(Lines, N).

ensure_period(Text, Out) :-
    string_trim(Text, T),
    ( sub_string(T, _, 1, 0, ".") -> Out = T ; string_concat(T, ".", Out) ).

%!  issue_text(+Term, -String) is det.
%
%   An issue's message or fix as PLAIN text. term_string/2 quotes an atom that needs
%   quoting, so a message would reach the prompt (and the user's warning box) wrapped
%   in quotes with its apostrophes backslash-escaped.
issue_text(T, S) :- ( atomic(T) -> text_to_string(T, S) ; term_string(T, S) ).

must_be_kind(facts) :- !.
must_be_kind(query) :- !.
must_be_kind(Kind)  :- throw(error(type_error(nl_kind, Kind), _)).

kind_noun(facts, "facts").
kind_noun(query, "query").

%!  loop_options(+Options0, -Limits, -CheckRegressions, -Options) is det.
%
%   Split this module's own options out of the list: everything else goes to the LLM
%   client, which would not know what to do with them.
loop_options(Options0, limits(Patience, MaxRounds), CheckRegressions, Options) :-
    ( memberchk(max_rounds(M), Options0), integer(M), M > 0 -> MaxRounds = M
    ; default_max_rounds(MaxRounds) ),
    ( memberchk(patience(P), Options0), integer(P), P > 0 -> Patience = P
    ; default_patience(Patience) ),
    ( memberchk(check_regressions(C), Options0), ( C == true ; C == false ) -> CheckRegressions = C
    ; CheckRegressions = false ),
    exclude(own_option, Options0, Options).

own_option(max_rounds(_)).
own_option(patience(_)).
own_option(check_regressions(_)).

ensure_max_tokens(Options, Options) :- memberchk(max_tokens(_), Options), !.
ensure_max_tokens(Options, [max_tokens(1024)|Options]).

% Translating one sentence against a fixed vocabulary has a right answer; sampling
% around it only costs correction rounds. (A caller that wants variety still can:
% an explicit temperature is left alone.)
ensure_temperature(Options, Options) :- memberchk(temperature(_), Options), !.
ensure_temperature(Options, [temperature(0)|Options]).

to_string(X, S) :- ( atom(X) ; string(X) ), !, atom_string(X, S).
to_string(_, "").

% ================================= Prompting ==================================

% system_prompt(+Kind, +Templates, +Program, -Prompt): the instruction that constrains
% the model to emit ONLY LE of the requested kind, using ONLY the given templates —
% plus the handful of Logical English traps that make a plausible-looking fragment
% mean something else, and the program's own scenarios/queries as the style to match.
system_prompt(Kind, Templates, Program, Prompt) :-
    templates_block(Templates, TemplatesText),
    kind_rules(Kind, Rules),
    pitfalls(Kind, Pitfalls),
    program_context(Kind, Program, Context),
    language_note(LangNote),
    format(string(Prompt),
        "You translate a natural-language sentence into Logical English (LE).~w~n~n~w~n~nKeep each template's fixed words EXACTLY, adjusting the sentence's wording and tense to fit them (e.g. 'was born' becomes the template's 'is born'). Replace each *...* placeholder with the matching value from the sentence. If the sentence does NOT give a value for some placeholder, keep the placeholder's own words in its place (for example write 'a date' where no date is stated) — do NOT invent a specific value, and do NOT drop the placeholder. Do not use predicates or wording that is not in a template below. Output plain text only — no Markdown, no code fences, no commentary.~n~n~w~n~nTemplates (each *...* is a placeholder to fill):~n~w~w",
        [LangNote, Rules, Pitfalls, TemplatesText, Context]).

% language_note(-Note): output-language directive for non-English programs.
language_note(Note) :-
    le_i18n:le_active_language(Lang),
    (   Lang == en
    ->  Note = ""
    ;   ( le_i18n:language_param(Lang, english_name, Name) -> true ; Name = Lang ),
        format(string(Note), " The program and its templates are written in ~w: write the LE output in ~w, keeping each template's ~w words exactly.", [Name, Name, Name])
    ).

% The connective words quoted in the kind rules come from the program
% language's lexicon (and/or, negation, which), so the instructions match what
% the verifying parser will accept.
kind_rules(facts, Rules) :-
    format(string(Rules), "Produce Logical English FACTS. Output one fact per line, each ending with a period. Match the sentence to the CLOSEST applicable template(s), even if it does not spell out every placeholder or phrases things differently. If the sentence expresses several facts, output several lines. Only output nothing if no template below is relevant to the sentence at all.", []).
kind_rules(query, Rules) :-
    ( le_i18n:kw_main_words(and, [AndW]) -> true ; AndW = and ),
    ( le_i18n:kw_main_words(or, [OrW]) -> true ; OrW = or ),
    ( le_i18n:kw_main_words(not_the_case, NafWords), atomic_list_concat(NafWords, ' ', Naf) -> true ; Naf = 'it is not the case that' ),
    ( le_i18n:class_word_list(wh_var, [Wh|_]) -> true ; Wh = which ),
    format(string(Rules), "Produce a Logical English QUERY BODY: one or more conditions, each based on the CLOSEST applicable template below, joined by '~w' or '~w' (put the connective at the start of each line after the first). Negate a condition by prefixing '~w'. To ask for a value to be returned, put '~w' before a placeholder's noun. Put each condition on its own line, and indent a condition further than the previous one to nest it for tighter and/or scoping. End the whole body with a single period. Do NOT output a query header.", [AndW, OrW, Naf, Wh]).

%!  pitfalls(+Kind, -Text) is det.
%
%   The mistakes that make a fragment verify with a warning instead of failing
%   outright — the ones a user is least likely to notice. They are the short,
%   fragment-sized cousins of the Contract Assistant's house style
%   (llm/contract_prompts/house_style.md); each corresponds to a verifier warning the
%   refinement loop would otherwise spend a round (and an LLM call) discovering.
pitfalls(facts, Text) :-
    Text = "Traps that make a fact mean something other than the sentence did:\n\
- NEVER put *asterisks* around a phrase. Asterisks mark placeholders in the templates section only; in a fact they turn the phrase into a variable.\n\
- An indefinite article makes a fact UNIVERSAL: 'a payment is 500' says EVERY payment is 500. Name the individual instead ('claim one', 'Alice'), or refer back with 'the payment' / 'this payment' once it has been introduced.\n\
- Never begin a value with 'a', 'an' or 'the': write 'United Kingdom', not 'the United Kingdom'.\n\
- Write dates as YYYY-MM-DD, and numbers without thousands separators or currency symbols (18500, not £18,500).\n\
- Do not state anything the sentence does not: no outcomes, no conclusions the rules are supposed to derive, no invented identifiers beyond what is needed to name the individuals the sentence talks about."
    .
pitfalls(query, Text) :-
    Text = "Traps to avoid:\n\
- NEVER put *asterisks* around a phrase; in a query they are a syntax error, not a variable.\n\
- Ask only what the sentence asks. Do not add conditions that merely seem useful, and do not restate the rules of the program — the query asks a question, the program answers it.\n\
- Write dates as YYYY-MM-DD and numbers without separators or currency symbols.\n\
- Every condition must be a sentence of one of the templates below, with 'which' before the nouns whose values you want back."
    .

%!  program_context(+Kind, +Program, -Block) is det.
%
%   A digest of the program the fragment joins: which scenarios and queries it already
%   has, and one of them in full as the style to match. Constants, naming conventions
%   and the level of detail the user actually writes are all in there, and none of it
%   is in the template list.
program_context(Kind, Program, Block) :-
    split_string(Program, "\n", "\r", Lines),
    findall(N, ( member(L, Lines), block_header(L, scenario, N) ), Scenarios),
    findall(N, ( member(L, Lines), block_header(L, query, N) ), Queries),
    names_line("Scenarios already in the program", Scenarios, SLine),
    names_line("Queries already in the program", Queries, QLine),
    ( Kind == facts -> Want = scenario ; Want = query ),
    (   example_block(Lines, Want, Example)
    ->  format(string(ELine), "~n~nOne of them, as an example of the conventions to follow (do NOT copy its content — only its style):~n~w", [Example])
    ;   ELine = ""
    ),
    (   SLine == "", QLine == "", ELine == ""
    ->  Block = ""
    ;   format(string(Block), "~n~n--- The program this will be added to ---~w~w~w", [SLine, QLine, ELine])
    ).

names_line(_, [], "") :- !.
names_line(Label, Names, Line) :-
    length(Names, N),
    ( N =< 20 -> Shown = Names ; length(Shown, 20), append(Shown, _, Names) ),
    atomic_list_concat(Shown, ", ", Joined),
    format(string(Line), "~n~w: ~w", [Label, Joined]).

% "scenario <name> is:" / "query <name> is:", in whatever language the program is
% written in — the keyword comes from the active lexicon.
block_header(Line, Kind, Name) :-
    normalize_space(string(T), Line),
    block_keyword(Kind, KW),
    string_concat(KW, Rest0, T),
    string_concat(" ", Rest1, Rest0),
    sub_string(Rest1, Before, _, 0, ":"),
    sub_string(Rest1, 0, Before, _, Rest2),
    normalize_space(string(Rest), Rest2),
    Rest \== "",
    % strip the trailing copula (the keyword set spells the header "<kw> <name> is:")
    ( le_i18n:kw_main_words(marker_is, [Is0|_]) -> true ; Is0 = is ),
    format(string(IsW), " ~w", [Is0]),
    ( sub_string(Rest, B, _, 0, IsW) -> sub_string(Rest, 0, B, _, Name) ; Name = Rest ).

block_keyword(scenario, KW) :-
    ( le_i18n:kw_main_words(scenario, [W|_]) -> true ; W = scenario ),
    atom_string(W, KW).
block_keyword(query, KW) :-
    ( le_i18n:kw_main_words(query, [W|_]) -> true ; W = query ),
    atom_string(W, KW).

% The first block of the wanted kind, header included, capped so a 200-line scenario
% does not become the bulk of the prompt.
example_block(Lines, Kind, Example) :-
    nth1(I, Lines, L), block_header(L, Kind, _), !,
    length(Prefix, I), append(Prefix, Rest, Lines),
    last(Prefix, Header),
    take_block(Rest, 24, Body),
    atomic_list_concat([Header|Body], "\n", Example).

take_block([], _, []) :- !.
take_block(_, 0, []) :- !.
take_block([L|Ls], N, Out) :-
    (   blank_line(L)
    ->  Out = []                      % blocks are separated by a blank line
    ;   N1 is N - 1, Out = [L|Out1], take_block(Ls, N1, Out1)
    ).

templates_block(Templates, Text) :-
    ( Templates == [] ->
        Text = "(no templates declared)"
    ;   maplist(template_line, Templates, Lines),
        atomic_list_concat(Lines, "\n", Text)
    ).

template_line(T, Line) :- format(string(Line), "- ~w", [T]).

% clean_reply(+Raw, -Clean): strip Markdown code fences and trim surrounding
% whitespace, leaving just the LE lines the model produced.
clean_reply(Raw, Clean) :-
    to_string(Raw, S0),
    split_string(S0, "\n", "", Lines0),
    exclude(fence_line, Lines0, Lines1),
    atomic_list_concat(Lines1, "\n", Joined),
    string_trim(Joined, Clean).

fence_line(Line) :-
    string_trim(Line, T),
    sub_string(T, 0, 3, _, "```").

% string_trim(+S, -T): S without leading/trailing whitespace (incl. newlines).
string_trim(S0, T) :-
    to_string(S0, S),
    split_string(S, "", " \t\r\n", [T]).

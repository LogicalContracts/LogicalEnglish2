/** <module> Natural-language → Logical English conversion (LLM-assisted, verified).

    Turns an English sentence into Logical English (LE) text — either fact statements
    (for a scenario) or a query body — that respects the templates already declared in
    a program, and then VERIFIES the result against that program before returning it.

    The verification is a simplified variant of the LE Assistant's "Light" mode:

      1. Verify the baseline Program as given, to record its PRE-EXISTING issues.
      2. Ask the LLM for an initial fragment (facts / query body) from the sentence.
      3. Splice the fragment into a throw-away copy of the program (as a scenario or a
         query block) and verify that. Compare to the baseline: only issues that are
         NOT in the baseline count as NEW — they were introduced by the fragment.
      4. If there are new issues, feed them back to the LLM to correct the fragment and
         re-verify. This repeats at most `MaxLoops` times (the caller passes 2).
      5. Return the final fragment plus any new issues that still remain. The spliced
         program is discarded — only the fragment (the new scenario facts or query) is
         kept; the caller may warn about, yet still use, a fragment with new issues.

    The single entry point is english_to_le/8. The Model id and Options are passed
    straight to llm_client; if Options omits api_key(_), the provider env var (e.g.
    GROQ_API_KEY) is used. Verification uses le_tools:le_tool_verify/2 in-process.
*/

:- module(nl_to_le, [ english_to_le/8 ]).

:- use_module(llm/llm_client).
:- use_module(le_kbs, [load_text/2]).
:- use_module(le_verifier, [verify/2]).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).

% A distinctive scenario/query name for the throw-away verification splice, unlikely
% to collide with a name already in the user's program.
nl_check_name('nl__editor_check__').

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
%                  rules give the verification context. The fragment is spliced into a
%                  COPY of it for checking; Program itself is never modified.
%   @arg Model     an llm_client model id (atom/string), e.g. 'openai/gpt-oss-120b'.
%   @arg Options   forwarded to llm_request/4 (e.g. api_key(Key), max_tokens(N)).
%   @arg LEText    the cleaned LE fragment (a string): facts (kind facts) or a query
%                  body (kind query), fences/prose stripped.
%   @arg NewIssues the issues introduced by LEText that are NOT in the baseline and
%                  still remain after refinement (a list of issue dicts, each with
%                  keys severity, type, message, fix, start, end). Empty when the
%                  fragment verified cleanly; non-empty means the caller should warn.
%
%   @throws error(type_error(nl_kind, Kind), _) if Kind is neither facts nor query.
%   Errors from the LLM call propagate from llm_client unchanged.
english_to_le(Kind, Sentence, Templates, Program, Model, Options, LEText, NewIssues) :-
    must_be_kind(Kind),
    to_string(Program, ProgramS),
    to_string(Sentence, SentenceS),
    verify_issues(ProgramS, BaselineIssues),
    ensure_max_tokens(Options, Options1),
    system_prompt(Kind, Templates, System),
    Messages0 = [ _{role: system, content: System}, _{role: user, content: SentenceS} ],
    llm_request(Model, Messages0, Raw0, Options1),
    clean_reply(Raw0, LE0),
    MaxLoops = 2,
    refine(Kind, ProgramS, BaselineIssues, Model, Options1, Messages0, Raw0, LE0, MaxLoops, LEText, NewIssues).

% refine(+Kind, +Program, +Baseline, +Model, +Options, +Messages, +LastReply, +LE,
%        +LoopsLeft, -FinalLE, -FinalNewIssues): verify the current fragment LE against
% the (throw-away) spliced program; if it introduces new issues and loops remain, ask
% the model to correct it and recurse. Otherwise return LE and whatever new issues are
% left (possibly none).
refine(Kind, Program, Baseline, Model, Options, Messages, LastReply, LE, LoopsLeft, FinalLE, FinalNew) :-
    candidate_program(Kind, Program, LE, Candidate),
    verify_issues(Candidate, CandidateIssues),
    new_issues(Baseline, CandidateIssues, New),
    (   New == []
    ->  FinalLE = LE, FinalNew = []
    ;   LoopsLeft =< 0
    ->  FinalLE = LE, FinalNew = New
    ;   kind_noun(Kind, Noun),
        describe_issues(New, IssuesText),
        format(string(Feedback),
            "Adding your output to the program produced these NEW problems:~n~w~n~nReturn a corrected version. Output ONLY the ~w, in the same plain-text format as before — no explanation, no code fences.",
            [IssuesText, Noun]),
        append(Messages, [ _{role: assistant, content: LastReply}, _{role: user, content: Feedback} ], Messages1),
        llm_request(Model, Messages1, Raw1, Options),
        clean_reply(Raw1, LE1),
        L1 is LoopsLeft - 1,
        refine(Kind, Program, Baseline, Model, Options, Messages1, Raw1, LE1, L1, FinalLE, FinalNew)
    ).

% verify_issues(+ProgramText, -Issues): load ProgramText and collect all issues —
% both the grammar/load-time le_issue/6 facts (parse errors, missing dots, …) and the
% semantic le_verifier:verify/2 checks (missing templates, undefined predicates, …).
% A load/verify that throws (a program too broken to parse at all) yields []. Each
% issue is a dict with keys severity, type, message, fix, start, end.
verify_issues(ProgramText, Issues) :-
    ( catch(collect_issues(ProgramText, Issues0), _, fail) -> Issues = Issues0 ; Issues = [] ).

collect_issues(ProgramText, Issues) :-
    load_text(ProgramText, KB),
    findall(_{severity: Sev, type: Type, message: Msg, fix: Fix, start: Start, end: End},
            KB:le_issue(Sev, Type, Msg, Fix, Start, End),
            Grammar),
    ( verify(KB, VIssues) -> true ; VIssues = [] ),
    findall(_{severity: warning, type: VType, message: Desc, fix: VFix, start: VStart, end: VEnd},
            member(issue(VType, Desc, VFix, VStart, VEnd), VIssues),
            Semantic),
    append(Grammar, Semantic, All),
    % load_text also asserts the verify/2 results as le_issue, so the two sources
    % overlap — keep one of each (by signature), preserving order.
    dedupe_issues(All, [], Issues).

dedupe_issues([], _, []).
dedupe_issues([I|T], Seen, Out) :-
    issue_signature(I, Sig),
    ( memberchk(Sig, Seen)
    ->  dedupe_issues(T, Seen, Out)
    ;   Out = [I|Out1], dedupe_issues(T, [Sig|Seen], Out1)
    ).

% new_issues(+Baseline, +Candidate, -New): the Candidate issues that are not already
% in the Baseline. The fragment is appended at the END of the program, so every
% baseline issue keeps its exact (type,message,start,end) signature in the candidate;
% anything with a signature not seen in the baseline was introduced by the fragment.
new_issues(Baseline, Candidate, New) :-
    maplist(issue_signature, Baseline, BaseSigs),
    exclude(in_baseline(BaseSigs), Candidate, New).

in_baseline(BaseSigs, Issue) :-
    issue_signature(Issue, Sig),
    memberchk(Sig, BaseSigs).

issue_signature(Issue, sig(Type, Msg, Start, End)) :-
    ( get_dict(type, Issue, Type) -> true ; Type = "" ),
    ( get_dict(message, Issue, Msg) -> true ; Msg = "" ),
    ( get_dict(start, Issue, Start) -> true ; Start = 0 ),
    ( get_dict(end, Issue, End) -> true ; End = 0 ).

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

ensure_period(Text, Out) :-
    string_trim(Text, T),
    ( sub_string(T, _, 1, 0, ".") -> Out = T ; string_concat(T, ".", Out) ).

% describe_issues(+Issues, -Text): the issues as a "- [severity] message" bullet list
% (with any suggested fix) for the correction prompt.
describe_issues(Issues, Text) :-
    maplist(issue_line, Issues, Lines),
    atomic_list_concat(Lines, "\n", Text).

issue_line(I, Line) :-
    ( get_dict(severity, I, Sev) -> true ; Sev = "warning" ),
    ( get_dict(message, I, Msg) -> true ; Msg = "" ),
    (   get_dict(fix, I, Fix), Fix \== "", Fix \== null
    ->  format(string(Line), "- [~w] ~w (suggested fix: ~w)", [Sev, Msg, Fix])
    ;   format(string(Line), "- [~w] ~w", [Sev, Msg])
    ).

must_be_kind(facts) :- !.
must_be_kind(query) :- !.
must_be_kind(Kind)  :- throw(error(type_error(nl_kind, Kind), _)).

kind_noun(facts, "facts").
kind_noun(query, "query").

ensure_max_tokens(Options, Options) :- memberchk(max_tokens(_), Options), !.
ensure_max_tokens(Options, [max_tokens(1024)|Options]).

to_string(X, S) :- ( atom(X) ; string(X) ), !, atom_string(X, S).
to_string(_, "").

% system_prompt(+Kind, +Templates, -Prompt): the instruction that constrains the
% model to emit ONLY LE of the requested kind, using ONLY the given templates.
system_prompt(Kind, Templates, Prompt) :-
    templates_block(Templates, TemplatesText),
    kind_rules(Kind, Rules),
    format(string(Prompt),
        "You translate English into Logical English (LE).~n~n~w~n~nKeep each template's fixed words EXACTLY, adjusting the sentence's wording and tense to fit them (e.g. 'was born' becomes the template's 'is born'). Replace each *...* placeholder with the matching value from the sentence. If the sentence does NOT give a value for some placeholder, keep the placeholder's own words in its place (for example write 'a date' where no date is stated) — do NOT invent a specific value, and do NOT drop the placeholder. Do not use predicates or wording that is not in a template below. Output plain text only — no Markdown, no code fences, no commentary.~n~nTemplates (each *...* is a placeholder to fill):~n~w",
        [Rules, TemplatesText]).

kind_rules(facts,
    "Produce Logical English FACTS. Output one fact per line, each ending with a period. Match the sentence to the CLOSEST applicable template(s), even if it does not spell out every placeholder or phrases things differently. If the sentence expresses several facts, output several lines. Only output nothing if no template below is relevant to the sentence at all.").
kind_rules(query,
    "Produce a Logical English QUERY BODY: one or more conditions, each based on the CLOSEST applicable template below, joined by 'and' or 'or' (put the connective at the start of each line after the first). Negate a condition by prefixing 'it is not the case that'. To ask for a value to be returned, put 'which' before a placeholder's noun (e.g. 'which person is happy'). Put each condition on its own line, and indent a condition further than the previous one to nest it for tighter and/or scoping. End the whole body with a single period. Do NOT output a 'query ... is:' header.").

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

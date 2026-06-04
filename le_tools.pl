/** <module> Logical English Shared Tools
    
    This module provides shared, in-process implementations of the 'verify'
    and 'query' tools for Logical English. These are used by both the MCP server
    and the Light Assistant.
*/

:- module(le_tools, [
    le_tool_verify/2,
    le_tool_query/2,
    convert_test_result/2,
    convert_why/3,
    run_query/4,
    get_last_verified_program/3,
    set_verify_job/1,
    clear_verify_job/0
]).

:- use_module(le_kbs).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).

%!  le_tool_verify(+ProgramTextOrArgs, -Result) is det.
%
%   Parses and verifies a Logical English program, returning all issues found
%   and running any embedded tests.
le_tool_verify(Args, Result) :-
    is_dict(Args), !,
    get_dict(program_text, Args, ProgramText),
    le_tool_verify(ProgramText, Result).
le_tool_verify(ProgramText, Result) :-
    le_kbs:load_text(ProgramText, KB),
    findall(_{severity: Sev, type: Type, message: Msg, fix: Fix, start: Start, end: End},
            KB:le_issue(Sev, Type, Msg, Fix, Start, End),
            Issues),
    % Run embedded tests if any
    ( current_predicate(KB:le_expected/3) ->
        findall(test(Q, S, A), KB:le_expected(Q, S, A), Tests),
        maplist(le_kbs:run_one_test(KB), Tests, TestResults),
        maplist(convert_test_result, TestResults, JSONTestResults)
    ; JSONTestResults = []
    ),
    % Capture this program so the LE Assistant can recover the agent's work
    % even if its file edits failed or the job was interrupted (see le_assistant).
    record_verified_program(ProgramText),
    Result = _{issues: Issues, test_results: JSONTestResults}.

% --- Capture of the most recent program submitted to the verify tool ---
% The verify tool runs in-process (same server as the LE Assistant), so the
% full program_text the agent verifies is available here. We keep a small,
% time-stamped history so the assistant can deliver the agent's latest verified
% program to the editor even when its surgical file edits never landed.
%
% Captures are keyed by a per-job token so that concurrent assistant jobs (or
% other MCP clients) cannot recover each other's work. The token is supplied by
% the MCP HTTP handler (via set_verify_job/1) for the duration of a tool call;
% callers without a token (REST endpoints, light assistant) record under 'none'.

:- dynamic last_verified_program/3.   % Token, Timestamp, ProgramText
:- thread_local verify_context_job/1.

%!  set_verify_job(+Token) is det.
%   Establishes the job token attributed to verify captures on this thread.
set_verify_job(Token) :-
    retractall(verify_context_job(_)),
    ( Token == none -> true ; assertz(verify_context_job(Token)) ).

%!  clear_verify_job is det.
clear_verify_job :-
    retractall(verify_context_job(_)).

current_verify_job(Token) :-
    ( verify_context_job(T) -> Token = T ; Token = none ).

record_verified_program(ProgramText) :-
    ( (var(ProgramText) ; \+ (string(ProgramText) ; atom(ProgramText)) ; ProgramText == "") ->
        true
    ;   current_verify_job(Token),
        get_time(Now),
        assertz(last_verified_program(Token, Now, ProgramText)),
        % Bound the history to the 50 most recent entries (across all tokens).
        findall(T, last_verified_program(_, T, _), Times),
        sort(0, @>=, Times, Sorted),
        ( nth0(50, Sorted, Cutoff) ->
            forall((last_verified_program(Tk, T2, P2), T2 =< Cutoff),
                   retract(last_verified_program(Tk, T2, P2)))
        ; true
        )
    ).

%!  get_last_verified_program(+Token, +AfterTime, -ProgramText) is semidet.
%
%   Unifies ProgramText with the most recent program submitted to the verify
%   tool under the given job Token at or after AfterTime (an epoch timestamp).
%   Fails if none exists for that token.
get_last_verified_program(Token0, AfterTime, ProgramText) :-
    % Keys are stored as atoms; normalize so a string JobID also matches.
    ( atom(Token0) -> Token = Token0 ; atom_string(Token, Token0) ),
    findall(T-P, (last_verified_program(Token, T, P), T >= AfterTime), Pairs),
    Pairs \== [],
    keysort(Pairs, Sorted),
    last(Sorted, _-ProgramText).

%!  le_tool_query(+Args, -Result) is det.
%
%   Executes a query against a Logical English program or example.
le_tool_query(Args, Result) :-
    get_dict(query, Args, Query),
    ( get_dict(example_name, Args, ExampleName) -> true ; ExampleName = "" ),
    ( get_dict(program_text, Args, ProgramText) -> true ; ProgramText = "" ),
    ( get_dict(scenario_name, Args, ScenarioName) -> true ; ScenarioName = "" ),
    ( get_dict(facts, Args, Facts) -> true ; Facts = "" ),
    (   ExampleName \== "" ->
        examples_dir(Dir),
        atom_concat(Dir, ExampleName, Path0),
        (exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', Path), exists_file(Path)),
        le_kbs:load(Path, KB)
    ;   ProgramText \== "" ->
        le_kbs:load_text(ProgramText, KB)
    ;   KB = none
    ),
    le_kbs:createSession(KB, SM),
    % Single-use session: always free it when done.
    setup_call_cleanup(
        true,
        (   (   (ScenarioName \== "", ScenarioName \== null) ->
                ( atom_string(ScenarioAtom, ScenarioName), le_kbs:setScenarion(SM, ScenarioAtom) -> true ; true )
            ;   true
            ),
            (   (Facts \== "", Facts \== null) ->
                catch(le_kbs:parse_custom_facts(KB, Facts, FactTerms), error(le_parse_error(Msg), _), ErrorFacts = Msg),
                ( var(ErrorFacts) -> forall(member(F, FactTerms), le_kbs:addSessionFact(SM, F)) ; true )
            ;   true
            ),
            (   nonvar(ErrorFacts) -> Result = _{error: ErrorFacts}
            ;   catch(run_query(SM, Query, KB, Result), error(le_parse_error(Msg), _), Result = _{error: Msg})
            )
        ),
        le_kbs:destroySession(SM)
    ).

examples_dir(AbsDir) :-
    working_directory(CWD, CWD),
    % Remove trailing slash from CWD if present
    ( sub_atom(CWD, _, 1, 0, '/') -> sub_atom(CWD, 0, _, 1, CWD0) ; CWD0 = CWD ),
    le_kbs:le_examples_dir(ExDir),
    format(atom(AbsDir), "~w/~w/", [CWD0, ExDir]).

run_query(SM, QueryStr, KB, Result) :-
    findall(_{answer: AnswerStr, explanation: JSONWhy}, (
        le_kbs:query(SM, QueryStr, Instance, _, Why),
        le_kbs:canonical_string(Instance, AnswerStr),
        convert_why(Why, KB, JSONWhy)
    ), Results),
    (   Results \== [] ->
        Result = _{results: Results}
    ;   % Try to get negative explanation
        (   le_kbs:query_explain(SM, QueryStr, _, _, Why) ->
            convert_why(Why, KB, JSONWhy),
            Result = _{results: [], explanation: JSONWhy}
        ;   Result = _{results: [], error: "No answer and no explanation found"}
        )
    ).

% --- Helpers ---

convert_why(success(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, children: JSONChildren}.
convert_why(failure(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(failure(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, children: JSONChildren}.
convert_why(Whys, KB, JSON) :-
    is_list(Whys), !,
    maplist(convert_why_child(KB), Whys, JSON).
convert_why(Other, _, JSON) :-
    term_string(Other, JSON).

convert_why_child(KB, Child, JSON) :-
    convert_why(Child, KB, JSON).

convert_test_result(pass(Q, S), _{status: "pass", query: Q, scenario: S}).
convert_test_result(fail(Q, S, E, A), _{status: "fail", query: Q, scenario: S, expected: E, actual: A}).
convert_test_result(error(Q, S, Msg), _{status: "error", query: Q, scenario: S, message: Msg}).

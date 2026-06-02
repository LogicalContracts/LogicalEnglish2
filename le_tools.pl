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
    run_query/4
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
    Result = _{issues: Issues, test_results: JSONTestResults}.

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
    (   (ScenarioName \== "", ScenarioName \== null) ->
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

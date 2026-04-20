/** <module> Logical English Knowledge Base Management
    
    This module provides predicates for loading Logical English files,
    managing reasoning sessions, and running tests.

    Predicates asserted into the KB module (e.g., m<hash>):
    - le_kb(Name): The name of the knowledge base.
    - le_source(Ref, Start, End): Source location information for a clause or fact.
    - scenario(Name, Facts): A list of facts defining a scenario.
    - query_info(Name, Goal, Terms): Information about a named query.
    - ontology(Content): The content of the ontology section.
    - le_dict(Dict): Template dictionary definitions.
    - <user_predicate>(...): Predicates generated from Logical English rules and facts.

    Predicates asserted into the Session module (e.g., s<uuid>):
    - le_my_kb(KBmodule): The KB module associated with this session.
    - le_neg(Fact): Represents a negated fact in the session.
    - sessionClause(Ref): Tracks clauses/facts added specifically to this session.
    - le_source(Ref, Start, End): Source location for session-specific facts.
    - <user_predicate>(...): Facts added to the session (e.g., from a scenario).
*/

:- module(le_kbs, [load/2, createSession/2, 
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, 
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0, get_kb_metadata/2, is_system_predicate/1]).

:- discontiguous print_test_result/1.

:- use_module(le_grammar).
:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(library(uuid)).
:- use_module(library(pcre)).

% For friendlier messages
:- multifile prolog:message//1.
prolog:message(S-Args) --> {atomic(S),is_list(Args)},[S-Args].

%!  do_log is det.
%
%   Dynamic predicate that controls whether debug messages are printed.
%   Retract it to silence the system.
:- dynamic do_log/0. % assert(le_kbs:do_log).

%!  load(+FilePath:atom, -Module:atom) is det.
%
%   Loads a Logical English file from FilePath into a new generated Module.
%   The module name is derived from the file path and modification time.
load(FilePath, NewModule) :-
    time_file(FilePath, Time),
    variant_sha1([FilePath, Time], Hash),
    atom_concat(m, Hash, NewModule),
    (   current_module(NewModule)
    ->  true
    ;   parse_le_file(FilePath, doc(Sections)),
        forall(member(S, Sections), process_section(S, NewModule)),
        % Also store system templates in the KB module
        findall(D, le_system_template(D), SysDicts),
        forall(member(D, SysDicts), assertz(NewModule:le_dict(D)))
    ).

process_section(S, M) :-
    (do_log -> print_message(informational,'Processing section: ~w~n' - [S]) ; true),
    process_section_acc(S, M).

process_section_acc(kb(Name, Content, Start, End), M) :-
    assertz(M:le_kb(Name), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(scenario(Name, Content, Start, End), M) :-
    maplist(item_to_term, Content, Terms),
    assertz(M:scenario(Name, Terms), Ref),
    assertz(M:le_source(Ref, Start, End)).

process_section_acc(query(Name, Content, Start, End), M) :-
    maplist(item_to_term, Content, Terms),
    list_to_conj(Terms, Goal),
    assertz(M:query_info(Name, Goal, Terms), Ref),
    assertz(M:le_source(Ref, Start, End)).

process_section_acc(ontology(Content, Start, End), M) :-
    assertz(M:ontology(Content), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(predicates(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(templates(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(fluents(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(events(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(meta(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).

process_section_acc(_, _).

process_item(clause(Head, Body, Start, End), M) :-
    ( Body == true -> Clause = Head ; Clause = (Head :- Body) ),
    functor(Head, F, N),
    M:dynamic(F/N),
    (   clause(M:Head, Body)
    ->  true
    ;   assertz(M:Clause, Ref),
        assertz(M:le_source(Ref, Start, End))
    ).

%!  createSession(+KBmodule:atom, -SessionModule:atom) is det.
%
%   Creates a new reasoning session associated with KBmodule.
%   Generates a unique SessionModule name.
createSession(KBmodule, SessionModule) :-
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    assertz(SessionModule:le_my_kb(KBmodule)),
    % Declare dynamic relations
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source/3).

%!  addSessionFact(+SessionModule:atom, +Fact:term) is det.
%
%   Adds a fact to the current session.
addSessionFact(SessionModule, Fact) :-
    functor(Fact,F,N),
    SessionModule:dynamic(F/N),
    (   SessionModule:clause(Fact, true)
    ->  true
    ;   assertz(SessionModule:Fact, Ref),
        assertz(SessionModule:sessionClause(Ref))
    ).

%!  negateSessionFact(+SessionModule:atom, +Fact:term) is det.
%
%   Negates a fact in the current session by retracting it and
%   asserting its negation.
negateSessionFact(SessionModule, Fact) :-
    % Retract matching facts from the session and clean up sessionClause
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    % Assert negation
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

%!  setScenarion(+SessionModule:atom, +ScenarioName:atom) is semidet.
%
%   Sets the current scenario for the session by loading facts
%   defined in the KB's scenario ScenarioName.
setScenarion(SessionModule, ScenarioName) :-
    SessionModule:le_my_kb(KBmodule),
    (   current_predicate(KBmodule:scenario/2)
    ->  KBmodule:scenario(ScenarioName, Facts),
        forall(member(Fact, Facts), addSessionFact(SessionModule, Fact))
    ;   print_message(warning,'scenario/2 not found in module ~w~n' - [KBmodule]),
        fail
    ).

%!  clearSession(+SessionModule:atom) is det.
%
%   Clears all facts and definitions from the session module.
clearSession(SessionModule) :-
    % Abolish all predicates in the session module
    forall(current_predicate(SessionModule:F/N),
           abolish(SessionModule:F/N)).

%!  printSession(+SessionModule:atom) is det.
%
%   Prints the current state of the session, including the KB and facts.
printSession(SessionModule) :-
    SessionModule:le_my_kb(KBmodule),
    KBmodule:le_kb(KBName),
    print_message(informational,'Session: ~w~n' - [SessionModule]),
    print_message(informational,'KB: ~w (~w)~n' - [KBName, KBmodule]),
    print_message(informational,'Current Facts:~n'),
    forall((SessionModule:sessionClause(Ref), clause(H, B, Ref)),
           (H \= sessionClause(_), print_message(informational,'  ~w:' - [SessionModule]), writeq(H), print_message(informational,' :- ~w~n' - [B]))).

%!  query(+SessionModule:atom, +Template:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is semidet.
%
%   Executes a query against the session using a Logical English template.
%   Template can be a list of tokens or an atom/string.
query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    SessionModule:le_my_kb(KBmodule),
    KBmodule:le_dict(Dict),
    copy_term(Dict, dict([Functor|Args], _NTs, WordsAndVars)),
    % Use the grammar's matching logic to handle multi-word variables in queries
    findall(D, KBmodule:le_dict(D), Templates),
    (   le_grammar:match_instance_to_template(Tokens, WordsAndVars, [], _, Templates, true)
    ->  Goal =.. [Functor|Args],
        (do_log -> print_message(informational,'Query Goal: ~w~n' - [Goal]) ; true),
        i(Goal, SessionModule, Unknowns, Why),
        TemplateInstance = WordsAndVars
    ).

ensure_tokens(Template, Tokens) :-
    is_list(Template), !, Tokens = Template.
ensure_tokens(Template, Tokens) :-
    (atom(Template) ; string(Template)), !,
    tokenize(Template, RawTokens),
    exclude(is_noise_token, RawTokens, Tokens).

is_noise_token(indent(_, _)).
is_noise_token(line_comment(_, _)).
is_noise_token(multi_comment(_, _)).

%!  queryScenario(+SessionModule:atom, +ScenarioName:atom, +Template:term, -TemplateInstance:list) is semidet.
%
%   Clears the session, sets the scenario, and executes a query.
%   Template can be a list of tokens or an atom/string.
queryScenario(SessionModule, ScenarioName, Template, TemplateInstance) :-
    clearSession(SessionModule),
    setScenarion(SessionModule, ScenarioName),
    query(SessionModule, Template, TemplateInstance,_,_).

%!  runTestsInDir(+Dir:atom, -Results:list) is det.
%
%   Runs all Logical English tests found in the specified directory.
runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(R, (member(F, Files), sub_atom(F, _, _, 0, '.le.tests'), 
                directory_file_path(Dir, F, Path),
                runTestsFor(Path, R)), Results).

%!  runTestsFor(+TestsFile:atom, -Result:term) is det.
%
%   Runs tests defined in a .le.tests file.
runTestsFor(TestsFile, Result) :-
    print_message(informational,"Running tests for ~w"-[TestsFile]),
    % 1. Get LE file path
    (   file_name_extension(LEFile, tests, TestsFile)
    ->  true
    ;   LEFile = TestsFile % Fallback
    ),
    (   catch(call_with_time_limit(5, load(LEFile, KBmodule)), E, (format('Error loading ~w: ~w~n', [LEFile, E]), fail))
    ->  % 3. Read tests from file
        setup_call_cleanup(
            open(TestsFile, read, Stream),
            read_tests(Stream, Tests),
            close(Stream)
        ),
        % 4. Run each test
        maplist(run_one_test(KBmodule), Tests, TestResults),
        % 5. Summarize
        Result = test_file(TestsFile, TestResults)
    ;   Result = test_file(TestsFile, [error(load, LEFile, 'Failed to load or timeout loading LE file')])
    ).

%!  runTests is det.
%
%   Runs all tests in the default examples directory and prints a summary.
runTests :-
    runTestsInDir('examples/moreExamples', Results),
    print_test_summary(Results),
    setup_call_cleanup(
        open('testSuiteStatus.txt', write, Stream),
        with_output_to(Stream, print_test_summary(Results)),
        close(Stream)
    ),
    forall(member(R, Results), print_test_result(R)).

%!  print_test_summary(+Results:list) is det.
%
%   Prints a high-level summary of all test results, including
%   total counts and a per-file breakdown.
print_test_summary(Results) :-
    findall(P, (member(test_file(_, FileResults), Results), member(pass(_,_), FileResults), P = 1), Passes),
    findall(F, (member(test_file(_, FileResults), Results), member(fail(_,_,_,_), FileResults), F = 1), Fails),
    findall(E, (member(test_file(_, FileResults), Results), member(error(_,_,_), FileResults), E = 1), Errs),
    length(Results, FileCount),
    length(Passes, PassCount),
    length(Fails, FailCount),
    length(Errs, ErrCount),
    Total is PassCount + FailCount + ErrCount,
    format('~nTest Summary:~n'),
    format('-------------~n'),
    format('Files processed: ~w~n', [FileCount]),
    format('Total tests:     ~w~n', [Total]),
    format('Passed:          ~w~n', [PassCount]),
    format('Failed:          ~w~n', [FailCount]),
    format('Errors/Timeouts: ~w~n', [ErrCount]),
    format('-------------~n'),
    format('~nDetailed File Summary:~n'),
    forall(member(test_file(File, FileResults), Results),
           (   findall(1, member(pass(_,_), FileResults), PFile),
               findall(1, member(fail(_,_,_,_), FileResults), FFile),
               findall(1, member(error(_,_,_), FileResults), EFile),
               length(PFile, PC), length(FFile, FC), length(EFile, EC),
               (   (FC > 0 ; EC > 0) -> Status = '[FAIL]' ; Status = '[PASS]' ),
               format('  ~w ~w: ~w Pass, ~w Fail, ~w Error~n', [Status, File, PC, FC, EC])
           )),
    format('-------------~n~n').

%!  print_test_result(+Result:term) is det.
%
%   Prints the detailed results of a test file execution.
print_test_result(test_file(File, FileResults)) :-
    format('File: ~w~n', [File]),
    forall(member(R, FileResults),
           ( R = pass(Q, S) -> format('  PASS: ~w (~w)~n', [Q, S])
           ; R = fail(Q, S, E, A) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n', [Q, S, E, A])
           ; format('  ERROR: ~w~n', [R])
           )).

item_to_term(clause(Head, true, _, _), Head) :- !.
item_to_term(clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Item, Item).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

normalize_string(S, N) :-
    re_replace("_"/g, " ", S, N1),
    re_replace("-"/g, " ", N1, N2),
    % Also normalize multiple spaces to single space
    re_replace("  +"/g, " ", N2, N).

run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings), Result) :-
    createSession(KBmodule, SM),
    (   setScenarion(SM, ScenarioName)
    ->  (   (KBmodule:query_info(QueryName, FullGoal, Items) ; 
             normalize_string(QueryName, NormName),
             KBmodule:query_info(InfoName, FullGoal, Items),
             normalize_string(InfoName, NormName))
        ->  (   catch(call_with_time_limit(30, findall(S, (i(FullGoal, SM, [], _), 
                                                          maplist(item_to_instance(KBmodule), Items, Instances),
                                                          flatten(Instances, TemplateInstance),
                                                          canonical_string(TemplateInstance, Atom),
                                                          atom_string(Atom, S)), ActualStrings)),
                      time_limit_exceeded,
                      (ActualStrings = timeout))
            ->  (   ActualStrings == timeout
                ->  Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                ;   maplist(normalize_string, ExpectedStrings, NormExpected),
                    maplist(normalize_string, ActualStrings, NormActual),
                    sort(NormExpected, SortedExpected),
                    sort(NormActual, SortedActual),
                    (   SortedExpected == SortedActual
                    ->  Result = pass(QueryName, ScenarioName)
                    ;   Result = fail(QueryName, ScenarioName, SortedExpected, SortedActual)
                    )
                )
            ;   Result = error(QueryName, ScenarioName, 'Test execution failed')
            )
        ;   Result = error(QueryName, ScenarioName, 'Query not found')
        )
    ;   Result = error(QueryName, ScenarioName, 'Scenario not found')
    ),
    clearSession(SM).

read_tests(Stream, Tests) :-
    read(Stream, Term),
    (   Term == end_of_file
    ->  Tests = []
    ;   Term = expected(Q, S, E)
    ->  Tests = [test(Q, S, E)|Rest],
        read_tests(Stream, Rest)
    ;   read_tests(Stream, Tests) % Skip other terms
    ).

item_to_instance(KBmodule, Head, WordsAndVars) :-
    (   Head = is_a(Type, SuperType)
    ->  WordsAndVars = [Type, is, a, SuperType]
    ;   KBmodule:le_dict(dict([Functor|Args], _NTs, WordsAndVars)),
        Head =.. [Functor|Args]
    ).

canonical_string(Instance, String) :-
    maplist(token_to_atom, Instance, Atoms),
    atomic_list_concat(Atoms, ' ', String).

token_to_atom(S, Atom) :-
    string(S), !, atom_string(Atom, S).
token_to_atom(date(Y,M,D), Atom) :-
    number(Y), number(M), number(D),
    !, format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]).
token_to_atom(N, Atom) :-
    number(N), !, 
    atom_number(Atom, N).
token_to_atom(A, Atom) :- 
    atom(A), !, 
    (   (A \== '_', sub_atom(A, _, _, _, '_')) % If it has underscores, maybe replace them?
    ->  re_replace("_"/g, " ", A, Atom)
    ;   Atom = A
    ).
token_to_atom(X, Atom) :- 
    (   var(X) -> Atom = '_'
    ;   term_to_atom(X, Atom)
    ).

%!  get_kb_metadata(+KBModule:atom, -Metadata:dict) is det.
%
%   Extracts metadata from a knowledge base module.
get_kb_metadata(KB, Metadata) :-
    findall(PredStr, (
        current_predicate(KB:P/A), 
        functor(G, P, A),
        \+ is_system_predicate(P/A),
        \+ predicate_property(KB:G, imported_from(_)),
        format(atom(PredStr), '~w/~w', [P, A])
    ), Preds),
    (KB:le_kb(KBName) -> true ; KBName = null),
    findall(_{name: Name, scenarios: JSONScenarios}, (
        KB:scenario(Name, Scenarios),
        maplist(term_string, Scenarios, JSONScenarios)
    ), Examples),
    findall(JSONQ, (
        KB:query_info(_, _, Q),
        maplist(term_string, Q, JSONQ)
    ), Queries),
    Metadata = _{
        kb: KBName,
        predicates: Preds,
        examples: Examples,
        queries: Queries
    }.

%!  is_system_predicate(?PI) is semidet.
%
%   True if PI is a predicate indicator for a Logical English system predicate.
is_system_predicate(le_kb/1).
is_system_predicate(le_source/3).
is_system_predicate(scenario/2).
is_system_predicate(query_info/3).
is_system_predicate(ontology/1).
is_system_predicate(le_dict/1).
is_system_predicate(le_my_kb/1).
is_system_predicate(le_neg/1).
is_system_predicate(sessionClause/1).

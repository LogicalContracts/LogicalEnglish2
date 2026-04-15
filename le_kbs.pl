:- module(le_kbs, [load/2, createSession/2, 
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, 
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0]).

:- use_module(le_grammar).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(library(uuid)).
:- use_module(library(pcre)).

% For friendlier messages
:- multifile prolog:message//1.
prolog:message(S-Args) --> {atomic(S),is_list(Args)},[S-Args].

:- dynamic do_log/0.
% do_log. % Default to on, user can retract it.

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
    (do_log -> format('Processing section: ~w~n', [S]) ; true),
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

addSessionFact(SessionModule, Fact) :-
    functor(Fact,F,N),
    SessionModule:dynamic(F/N),
    (   SessionModule:clause(Fact, true)
    ->  true
    ;   assertz(SessionModule:Fact, Ref),
        assertz(SessionModule:sessionClause(Ref))
    ).

item_to_term(clause(Head, true, _, _), Head) :- !.
item_to_term(clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Item, Item).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

createSession(KBmodule, SessionModule) :-
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    assertz(SessionModule:le_my_kb(KBmodule)),
    % Declare dynamic relations
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source/3).

negateSessionFact(SessionModule, Fact) :-
    % Retract matching facts from the session and clean up sessionClause
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    % Assert negation
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

setScenarion(SessionModule, ScenarioName) :-
    SessionModule:le_my_kb(KBmodule),
    (   current_predicate(KBmodule:scenario/2)
    ->  KBmodule:scenario(ScenarioName, Facts),
        forall(member(Fact, Facts), addSessionFact(SessionModule, Fact))
    ;   format('Warning: scenario/2 not found in module ~w~n', [KBmodule]),
        fail
    ).

clearSession(SessionModule) :-
    % Abolish all predicates in the session module
    forall(current_predicate(SessionModule:F/N),
           abolish(SessionModule:F/N)).

printSession(SessionModule) :-
    SessionModule:le_my_kb(KBmodule),
    KBmodule:le_kb(KBName),
    format('Session: ~w~n', [SessionModule]),
    format('KB: ~w (~w)~n', [KBName, KBmodule]),
    format('Current Facts:~n'),
    forall((SessionModule:sessionClause(Ref), clause(H, B, Ref)),
           (H \= sessionClause(_), format('  ~w:', [SessionModule]), writeq(H), format(' :- ~w~n', [B]))).

query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    SessionModule:le_my_kb(KBmodule),
    KBmodule:le_dict(Dict),
    copy_term(Dict, dict([Functor|Args], _NTs, WordsAndVars)),
    % Use the grammar's matching logic to handle multi-word variables in queries
    findall(D, KBmodule:le_dict(D), Templates),
    (   le_grammar:match_instance_to_template(Template, WordsAndVars, [], _, Templates, true)
    ->  Goal =.. [Functor|Args],
        format('Query Goal: ~w~n', [Goal]),
        i(Goal, SessionModule, Unknowns, Why),
        TemplateInstance = WordsAndVars
    ).

queryScenario(SessionModule, ScenarioName, Template, TemplateInstance) :-
    clearSession(SessionModule),
    setScenarion(SessionModule, ScenarioName),
    query(SessionModule, Template, TemplateInstance,_,_).



runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(R, (member(F, Files), sub_atom(F, _, _, 0, '.le.tests'), 
                directory_file_path(Dir, F, Path),
                runTestsFor(Path, R)), Results).

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

runTests :-
    runTestsInDir('examples/moreExamples', Results),
    print_test_summary(Results),
    forall(member(R, Results), print_test_result(R)).

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
               format('  ~w: ~w Pass, ~w Fail, ~w Error~n', [File, PC, FC, EC])
           )),
    format('-------------~n~n').

print_test_result(test_file(File, FileResults)) :-
    format('File: ~w~n', [File]),
    forall(member(R, FileResults),
           ( R = pass(Q, S) -> format('  PASS: ~w (~w)~n', [Q, S])
           ; R = fail(Q, S, E, A) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n', [Q, S, E, A])
           ; format('  ERROR: ~w~n', [R])
           )).

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

token_to_atom(date(Y,M,D), Atom) :-
    number(Y), number(M), number(D),
    !, format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]).
token_to_atom(N, Atom) :-
    number(N), !, 
    (   float(N) -> format(atom(Atom), '~1f', [N])
    ;   atom_number(Atom, N)
    ).
token_to_atom(A, Atom) :- 
    atom(A), !, 
    (   sub_atom(A, _, _, _, '_') % If it has underscores, maybe replace them?
    ->  re_replace("_"/g, " ", A, Atom)
    ;   Atom = A
    ).
token_to_atom(X, Atom) :- 
    (   var(X) -> Atom = '_'
    ;   term_to_atom(X, Atom)
    ).

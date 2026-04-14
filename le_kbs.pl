:- module(le_kbs, [load/2, createSession/2, addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1]).
:- use_module(le_grammar).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(library(uuid)).

load(FilePath, NewModule) :-
    time_file(FilePath, Time),
    variant_sha1([FilePath, Time], Hash),
    atom_concat(m, Hash, NewModule),
    parse_le_file(FilePath, doc(Sections)),
    forall(member(S, Sections), process_section(S, NewModule)),
    % Also store system templates in the KB module
    findall(D, le_system_template(D), SysDicts),
    forall(member(D, SysDicts), assertz(NewModule:le_dict(D))).

process_section(kb(Name, Content, Start, End), M) :-
    assertz(M:le_kb(Name), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

process_section(scenario(Name, Content, Start, End), M) :-
    maplist(item_to_term, Content, Terms),
    assertz(M:scenario(Name, Terms), Ref),
    assertz(M:le_source(Ref, Start, End)).

process_section(query(Name, Content, Start, End), M) :-
    maplist(item_to_term, Content, Terms),
    list_to_conj(Terms, Goal),
    assertz(M:query_info(Name, Goal, Content), Ref),
    assertz(M:le_source(Ref, Start, End)).

process_section(ontology(Content, Start, End), M) :-
    assertz(M:ontology(Content), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

process_section(predicates(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section(templates(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section(fluents(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section(events(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section(meta(Dicts), M) :-
    forall(member(D, Dicts), assertz(M:le_dict(D))).

process_section(_, _).

process_item(clause(Head, Body, Start, End), M) :-
    ( Body == true -> Clause = Head ; Clause = (Head :- Body) ),
    assertz(M:Clause, Ref),
    assertz(M:le_source(Ref, Start, End)).
process_item(unknown_template(Tokens, Start, End), M) :-
    assertz(M:unknown_template(Tokens), Ref),
    assertz(M:le_source(Ref, Start, End)).
process_item(_, _).

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

%TODO: should handle conflicts with le_neg:
addSessionFact(SessionModule, Fact) :-
    functor(Fact,F,N),
    SessionModule:dynamic(F/N),
    assertz(SessionModule:Fact, Ref),
    assertz(SessionModule:sessionClause(Ref)).

negateSessionFact(SessionModule, Fact) :-
    % Retract matching facts from the session and clean up sessionClause
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    % Assert negation
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

setScenarion(SessionModule, ScenarioName) :-
    SessionModule:le_my_kb(KBmodule),
    KBmodule:scenario(ScenarioName, Facts),
    forall(member(Fact, Facts), addSessionFact(SessionModule, Fact)).

clearSession(SessionModule) :-
    forall(retract(SessionModule:sessionClause(Ref)), erase(Ref)).

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
    match_query_template(Template, WordsAndVars),
    Goal =.. [Functor|Args],
    i(Goal, SessionModule, Unknowns, Why),
    TemplateInstance = WordsAndVars.

match_query_template([], []).
match_query_template([W1|T1], [W2|T2]) :-
    (   W1 == W2 -> true
    ;   is_query_word(W1), var(W2) -> true
    ;   var(W1), var(W2) -> W1 = W2
    ;   var(W1) -> W1 = W2
    ;   var(W2) -> W2 = W1
    ;   fail
    ),
    match_query_template(T1, T2).

is_query_word(which).
is_query_word(a).
is_query_word(an).
is_query_word(the).
is_query_word(some).


queryScenario(SessionModule, ScenarioName, Template, TemplateInstance) :-
    clearSession(SessionModule),
    setScenarion(SessionModule, ScenarioName),
    query(SessionModule, Template, TemplateInstance,_,_).

runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(R, (member(F, Files), sub_atom(F, _, _, 0, '.le.tests'), 
                directory_file_path(Dir, F, Path),
                format('Running tests for ~w...~n', [F]),
                runTestsFor(Path, R)), Results).

runTestsFor(TestsFile, Result) :-
    % 1. Get LE file path
    (   file_name_extension(LEFile, tests, TestsFile)
    ->  true
    ;   LEFile = TestsFile % Fallback
    ),
    % 2. Load LE file
    load(LEFile, KBmodule),
    % 3. Read tests from file
    setup_call_cleanup(
        open(TestsFile, read, Stream),
        read_tests(Stream, Tests),
        close(Stream)
    ),
    % 4. Run each test
    maplist(run_one_test(KBmodule), Tests, TestResults),
    % 5. Summarize
    Result = test_file(TestsFile, TestResults).

runTests :-
    runTestsFor('examples/moreExamples/citizenship.le.tests', Result),
    print_test_result(Result).

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

run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings), Result) :-
    createSession(KBmodule, SM),
    (   setScenarion(SM, ScenarioName)
    ->  (   KBmodule:query_info(QueryName, FullGoal, Items)
        ->  findall(S, (i(FullGoal, SM, [], _), 
                        maplist(item_to_instance(KBmodule), Items, Instances),
                        flatten(Instances, TemplateInstance),
                        canonical_string(TemplateInstance, Atom),
                        atom_string(Atom, S)), ActualStrings),
            sort(ExpectedStrings, SortedExpected),
            sort(ActualStrings, SortedActual),
            (   SortedExpected == SortedActual
            ->  Result = pass(QueryName, ScenarioName)
            ;   Result = fail(QueryName, ScenarioName, SortedExpected, SortedActual)
            )
        ;   Result = error(QueryName, ScenarioName, 'Query not found')
        )
    ;   Result = error(QueryName, ScenarioName, 'Scenario not found')
    ),
    clearSession(SM).

item_to_instance(KBmodule, clause(Head, _, _, _), WordsAndVars) :-
    (   Head = is_a(Type, SuperType)
    ->  WordsAndVars = [Type, is, a, SuperType]
    ;   KBmodule:le_dict(dict([Functor|Args], _NTs, WordsAndVars)),
        Head =.. [Functor|Args]
    ).

canonical_string(Instance, String) :-
    maplist(token_to_atom, Instance, Atoms),
    atomic_list_concat(Atoms, ' ', String).

token_to_atom(date(Y,M,D), Atom) :-
    !, format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]).
token_to_atom(N, Atom) :-
    number(N), !, atom_number(Atom, N).
token_to_atom(A, A) :- atom(A), !.
token_to_atom(X, Atom) :- term_to_atom(X, Atom).

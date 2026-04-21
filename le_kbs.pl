/** <module> Logical English Knowledge Base Management
    
    This module provides predicates for loading Logical English files,
    managing reasoning sessions, and running tests.
*/

:- module(le_kbs, [load/2, createSession/2, 
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, 
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0, get_kb_metadata/2, is_system_predicate/1,
    verify/1, edit/1, canonical_string/2, token_to_atom/2, item_to_instance/3]).

:- discontiguous print_test_result/1.

:- use_module(le_grammar).
:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(le_verifier, [verify/2]).
:- use_module(library(uuid)).
:- use_module(library(pcre)).
:- use_module(library(www_browser)).

% For friendlier messages
:- multifile prolog:message//1.
prolog:message(S-Args) --> {atomic(S),is_list(Args)},[S-Args].

%!  edit(+LEfilePath:atom) is det.
%
%   Fetches the LE file and opens the user browser to display/edit it.
edit(LEfilePath) :-
    read_file_to_string(LEfilePath, Text, []),
    www_form_encode(Text, Encoded),
    file_base_name(LEfilePath, FileName),
    www_form_encode(FileName, EncodedFileName),
    format(atom(URL), 'http://localhost:3050/editor/index.html?text=~w&filename=~w', [Encoded, EncodedFileName]),
    www_open_url(URL).

%!  do_log is det.
%
%   Dynamic predicate that controls whether debug messages are printed.
:- dynamic do_log/0. % assert(le_kbs:do_log).

%!  load(+FilePath:atom, -Module:atom) is det.
%
%   Loads a Logical English file from FilePath into a new generated Module.
load(FilePath, NewModule) :-
    time_file(FilePath, Time),
    variant_sha1([FilePath, Time], Hash),
    atom_concat(m, Hash, NewModule),
    (   current_module(NewModule)
    ->  true
    ;   (   catch(parse_le_file(FilePath, doc(Sections)), EP, (print_message(error, EP), fail))
        ->  forall(member(S, Sections), process_section(S, NewModule)),
            findall(D, le_system_template(D), SysDicts),
            forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
            (   catch(le_verifier:verify(NewModule, _Issues), EV, (print_message(error, EV), true))
            ->  true
            ;   true
            )
        ;   print_message(error, "parse_le_file failed for ~w" - [FilePath]),
            fail
        )
    ).

process_section(S, M) :-
    (do_log -> print_message(informational,'Processing section: ~w' - [S]) ; true),
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

process_section_acc(predicates(Dicts), M) :- forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(templates(Dicts), M) :- forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(fluents(Dicts), M) :- forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(events(Dicts), M) :- forall(member(D, Dicts), assertz(M:le_dict(D))).
process_section_acc(meta(Dicts), M) :- forall(member(D, Dicts), assertz(M:le_dict(D))).
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
createSession(KBmodule, SessionModule) :-
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    assertz(SessionModule:le_my_kb(KBmodule)),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source/3).

%!  addSessionFact(+SessionModule:atom, +Fact:term) is det.
addSessionFact(SessionModule, Fact) :-
    functor(Fact,F,N),
    SessionModule:dynamic(F/N),
    (   SessionModule:clause(Fact, true)
    ->  true
    ;   assertz(SessionModule:Fact, Ref),
        assertz(SessionModule:sessionClause(Ref))
    ).

%!  negateSessionFact(+SessionModule:atom, +Fact:term) is det.
negateSessionFact(SessionModule, Fact) :-
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

%!  setScenarion(+SessionModule:atom, +ScenarioName:atom) is semidet.
setScenarion(SessionModule, ScenarioName) :-
    SessionModule:le_my_kb(KBmodule),
    (   current_predicate(KBmodule:scenario/2)
    ->  KBmodule:scenario(ScenarioName, Facts),
        forall(member(Fact, Facts), addSessionFact(SessionModule, Fact))
    ;   fail
    ).

%!  clearSession(+SessionModule:atom) is det.
clearSession(SessionModule) :-
    (   SessionModule:le_my_kb(KBmodule)
    ->  true
    ;   KBmodule = none
    ),
    forall(current_predicate(SessionModule:F/N), abolish(SessionModule:F/N)),
    (   KBmodule \== none
    ->  assertz(SessionModule:le_my_kb(KBmodule))
    ;   true
    ),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source/3).

%!  printSession(+SessionModule:atom) is det.
printSession(SessionModule) :-
    SessionModule:le_my_kb(KBmodule),
    KBmodule:le_kb(KBName),
    format('Session: ~w~nKB: ~w (~w)~nFacts:~n', [SessionModule, KBName, KBmodule]),
    forall((SessionModule:sessionClause(Ref), clause(H, B, Ref)),
           (H \= sessionClause(_), format('  ~w :- ~w~n', [H, B]))).

%!  query(+SessionModule:atom, +Template:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is semidet.
query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    SessionModule:le_my_kb(KBmodule),
    (   (atom(Template) ; string(Template)),
        atom_string(QueryName, Template),
        current_predicate(KBmodule:query_info/3),
        KBmodule:query_info(QueryName, Goal, Items)
    ->  (   reasoner:i(Goal, SessionModule, Unknowns, Why)
        ->  maplist(item_to_instance(KBmodule), Items, Instances),
            flatten(Instances, TemplateInstance)
        ;   fail
        )
    ;   findall(D, KBmodule:le_dict(D), Templates),
        (   member(Dict, Templates),
            copy_term(Dict, dict([Functor|Args], _NTs, WordsAndVars)),
            le_grammar:match_instance_to_template(Tokens, WordsAndVars, [], _, Templates, true)
        ->  Goal =.. [Functor|Args],
            (   reasoner:i(Goal, SessionModule, Unknowns, Why)
            ->  TemplateInstance = WordsAndVars
            ;   fail
            )
        ;   fail
        )
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

queryScenario(SessionModule, ScenarioName, Template, TemplateInstance) :-
    clearSession(SessionModule),
    setScenarion(SessionModule, ScenarioName),
    query(SessionModule, Template, TemplateInstance,_,_).

%!  canonical_string(+Instance:list, -String:string) is det.
canonical_string(Instance, String) :-
    (   is_list(Instance)
    ->  maplist(le_kbs:token_to_atom, Instance, Atoms),
        (   maplist(var, Atoms) -> String = "" % Should not happen with robust token_to_atom
        ;   catch(atomic_list_concat(Atoms, ' ', String), _, String = "error")
        )
    ;   le_kbs:token_to_atom(Instance, Atom),
        atom_string(Atom, String)
    ).

%!  token_to_atom(+Token:term, -Atom:atom) is det.
token_to_atom(X, Atom) :- var(X), !, Atom = '_'.
token_to_atom(word(W, _), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(word(W), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(var(Words), Atom) :- !, 
    (   var(Words) -> Atom = '_'
    ;   is_list(Words) -> (maplist(token_to_atom, Words, Atoms), atomic_list_concat(Atoms, ' ', Atom))
    ;   atom_string(Atom, Words)
    ).
token_to_atom(number(N, _), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
token_to_atom(number(N), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
token_to_atom(punctuation(P, _), P) :- !.
token_to_atom(punctuation(P), P) :- !.
token_to_atom(punct(P, _), P) :- !.
token_to_atom(punct(P), P) :- !.
token_to_atom(date(date(Y,M,D), _), Atom) :- !, 
    (   number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]) ; Atom = 'date'
    ).
token_to_atom(date(Y,M,D), Atom) :- !,
    (   number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]) ; Atom = 'date'
    ).
token_to_atom(S, Atom) :- string(S), !, atom_string(Atom, S).
token_to_atom(A, Atom) :- atom(A), !, 
    (   (A \== '_', sub_atom(A, _, _, _, '_')) -> re_replace("_"/g, " ", A, Atom) ; Atom = A
    ).
token_to_atom(X, Atom) :- term_to_atom(X, Atom).

%!  item_to_instance(+KBmodule:atom, +Head:term, -WordsAndVars:list) is det.
item_to_instance(KBmodule, Head, WordsAndVars) :-
    (   Head = is_a(Type, SuperType)
    ->  WordsAndVars = [Type, is, a, SuperType]
    ;   copy_term(Head, HeadCopy),
        (   KBmodule:le_dict(dict([Functor|Args], _NTs, WordsAndVars)),
            HeadCopy =.. [Functor|Args]
        ->  true
        ;   term_string(Head, Str), WordsAndVars = [Str]
        )
    ).

%!  get_kb_metadata(+KBModule:atom, -Metadata:dict) is det.
get_kb_metadata(KB, Metadata) :-
    (   current_predicate(KB:P/A)
    ->  findall(PredStr, (
            current_predicate(KB:P/A), functor(G, P, A),
            \+ is_system_predicate(P/A), \+ predicate_property(KB:G, imported_from(_)),
            format(atom(PredStr), '~w/~w', [P, A])
        ), Preds)
    ;   Preds = []
    ),
    (   current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true ; KBName = null),
    (   current_predicate(KB:scenario/2)
    ->  findall(_{name: Name, scenarios: JSONScenarios}, (
            KB:scenario(Name, Scenarios), maplist(term_string, Scenarios, JSONScenarios)
        ), Examples)
    ;   Examples = []
    ),
    (   current_predicate(KB:query_info/3)
    ->  findall(_{name: Name, template: QueryStr, le: LEStr}, (
            KB:query_info(Name, _, Q),
            copy_term(Q, QCopy),
            maplist(le_kbs:item_to_instance(KB), QCopy, Instances),
            maplist(le_kbs:canonical_string, Instances, QueryStrings),
            atomic_list_concat(QueryStrings, ' and ', LEStr),
            maplist(term_string, QCopy, TermStrings),
            atomic_list_concat(TermStrings, ' and ', QueryStr)
        ), Queries)
    ;   Queries = []
    ),
    Metadata = _{ kb: KBName, predicates: Preds, examples: Examples, queries: Queries }.

is_system_predicate(le_kb/1).
is_system_predicate(le_source/3).
is_system_predicate(scenario/2).
is_system_predicate(query_info/3).
is_system_predicate(ontology/1).
is_system_predicate(le_dict/1).
is_system_predicate(le_my_kb/1).
is_system_predicate(le_neg/1).
is_system_predicate(sessionClause/1).

verify(LEfilePath) :-
    uuid(UUID), atom_concat(v, UUID, KBmodule),
    parse_le_file(LEfilePath, doc(Sections)),
    forall(member(S, Sections), process_section(S, KBmodule)),
    findall(D, le_system_template(D), SysDicts),
    forall(member(D, SysDicts), assertz(KBmodule:le_dict(D))),
    le_verifier:verify(KBmodule, Issues),
    forall(member(Issue, Issues), le_verifier:print_issue(Issue)),
    atom_concat(LEfilePath, '.tests', TestsFile),
    (   exists_file(TestsFile)
    ->  setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, Tests), close(Stream)),
        maplist(run_one_test(KBmodule), Tests, TestResults),
        print_test_result(test_file(TestsFile, TestResults))
    ;   true
    ),
    forall(current_predicate(KBmodule:F/N), abolish(KBmodule:F/N)).

item_to_term(clause(Head, true, _, _), Head) :- !.
item_to_term(clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Item, Item).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

normalize_string(S, N) :-
    re_replace("_"/g, " ", S, N1), re_replace("-"/g, " ", N1, N2),
    re_replace("  +"/g, " ", N2, N).

run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings), Result) :-
    createSession(KBmodule, SM),
    (   setScenarion(SM, ScenarioName)
    ->  (   (KBmodule:query_info(QueryName, FullGoal, Items) ; 
             normalize_string(QueryName, NormName),
             KBmodule:query_info(InfoName, FullGoal, Items),
             normalize_string(InfoName, NormName))
        ->  (   catch(call_with_time_limit(30, findall(S, (reasoner:i(FullGoal, SM, [], _), 
                                                          maplist(item_to_instance(KBmodule), Items, Instances),
                                                          flatten(Instances, TemplateInstance),
                                                          canonical_string(TemplateInstance, Atom),
                                                          atom_string(Atom, S)), ActualStrings)),
                      time_limit_exceeded, (ActualStrings = timeout))
            ->  (   ActualStrings == timeout -> Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                ;   maplist(normalize_string, ExpectedStrings, NormExpected),
                    maplist(normalize_string, ActualStrings, NormActual),
                    sort(NormExpected, SortedExpected), sort(NormActual, SortedActual),
                    (SortedExpected == SortedActual -> Result = pass(QueryName, ScenarioName) ; Result = fail(QueryName, ScenarioName, SortedExpected, SortedActual))
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
    (   Term == end_of_file -> Tests = []
    ;   Term = expected(Q, S, E) -> Tests = [test(Q, S, E)|Rest], read_tests(Stream, Rest)
    ;   read_tests(Stream, Tests)
    ).

runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(R, (member(F, Files), sub_atom(F, _, _, 0, '.le.tests'), 
                directory_file_path(Dir, F, Path),
                runTestsFor(Path, R)), Results).

runTestsFor(TestsFile, Result) :-
    print_message(informational,"Running tests for ~w"-[TestsFile]),
    (file_name_extension(LEFile, tests, TestsFile) -> true ; LEFile = TestsFile),
    (   catch(call_with_time_limit(5, load(LEFile, KBmodule)), E, (format('Error loading ~w: ~w~n', [LEFile, E]), fail))
    ->  setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, Tests), close(Stream)),
        maplist(run_one_test(KBmodule), Tests, TestResults),
        Result = test_file(TestsFile, TestResults)
    ;   Result = test_file(TestsFile, [error(load, LEFile, 'Failed to load or timeout loading LE file')])
    ).

runTests :-
    runTestsInDir('examples/moreExamples', Results),
    print_test_summary(Results),
    setup_call_cleanup(open('testSuiteStatus.txt', write, Stream), with_output_to(Stream, print_test_summary(Results)), close(Stream)),
    forall(member(R, Results), print_test_result(R)).

print_test_summary(Results) :-
    findall(P, (member(test_file(_, FileResults), Results), member(pass(_,_), FileResults), P = 1), Passes),
    findall(F, (member(test_file(_, FileResults), Results), member(fail(_,_,_,_), FileResults), F = 1), Fails),
    findall(E, (member(test_file(_, FileResults), Results), member(error(_,_,_), FileResults), E = 1), Errs),
    length(Results, FileCount), length(Passes, PassCount), length(Fails, FailCount), length(Errs, ErrCount),
    Total is PassCount + FailCount + ErrCount,
    format('~nTest Summary:~n-------------~nFiles processed: ~w~nTotal tests:     ~w~nPassed:          ~w~nFailed:          ~w~nErrors/Timeouts: ~w~n-------------~n~nDetailed File Summary:~n', [FileCount, Total, PassCount, FailCount, ErrCount]),
    forall(member(test_file(File, FileResults), Results),
           (   findall(1, member(pass(_,_), FileResults), PFile),
               findall(1, member(fail(_,_,_,_), FileResults), FFile),
               findall(1, member(error(_,_,_), FileResults), EFile),
               length(PFile, PC), length(FFile, FC), length(EFile, EC),
               ( (FC > 0 ; EC > 0) -> Status = '[FAIL]' ; Status = '[PASS]' ),
               format('  ~w ~w: ~w Pass, ~w Fail, ~w Error~n', [Status, File, PC, FC, EC])
           )),
    format('-------------~n~n').

print_test_result(test_file(File, FileResults)) :-
    format('File: ~w~n', [File]),
    forall(member(R, FileResults),
           ( R = pass(Q, S) -> format('  PASS: ~w (~w)~n', [Q, S])
           ; R = fail(Q, S, E, A) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n', [Q, S, E, A])
           ; format('  ERROR: ~w~n', [R])
           )).

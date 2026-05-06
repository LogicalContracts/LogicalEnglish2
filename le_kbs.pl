/** <module> Logical English Knowledge Base Management
    
    This module provides predicates for loading Logical English files,
    managing reasoning sessions, running tests, and providing metadata
    about loaded KBs. It acts as the main interface for managing LE programs.
*/

:- module(le_kbs, [load/2, load_text/2, createSession/2, 
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, 
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0, get_kb_metadata/2, is_system_predicate/1,
    run_one_test/3, le_my_id/1, le_my_kb/1, set_id_from_ref/2, person_age/2,
    set_kb_module/1, clear_kb_module/0,
    current_compiling_module/1, rule_counter/1,
    verify/1, edit/1, canonical_string/2, token_to_atom/2, item_to_instance/3, query_explain/5,
    topPredicates/2, kbSummary/2, parse_custom_facts/3, parse_custom_query/3, is_a_hierarchy/2]).

:- discontiguous process_section_acc/2.
:- discontiguous print_test_result/1.

:- meta_predicate set_id_from_ref(+, +).

:- use_module(le_grammar).
:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(reasoner).
:- use_module(le_verifier, [verify/2]).
:- use_module(library(uuid)).
:- use_module(library(pcre)).
:- use_module(library(www_browser)).

:- (exists_file('le_extensions.pl') -> use_module('le_extensions') ; true).

% For friendlier messages
:- multifile prolog:message//1.
prolog:message(S-Args) --> {atomic(S),is_list(Args)}, !, [S-Args].
prolog:message(Msg) --> {string(Msg)}, !, [Msg].
prolog:message(Msg) --> {atom(Msg)}, !, [Msg].

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
:- dynamic do_log/0, current_compiling_module/1. % assert(le_kbs:do_log).
:- thread_local le_current_id/1, le_kb_module/1.

%!  load(+FilePath:atom, -Module:atom) is det.
%
%   Loads a Logical English file from FilePath into a new generated Module.
load(FilePath, NewModule) :-
    (   var(NewModule) ->  
        time_file(FilePath, Time),
        variant_sha1([FilePath, Time], Hash),
        atom_concat(m, Hash, NewModule)
    ;   true
    ),
    with_mutex(NewModule, load_sync(NewModule, FilePath)).

load_sync(NewModule, _) :-
    current_module(NewModule), 
    current_predicate(NewModule:le_source_info/4), 
    \+ current_predicate(NewModule:le_issue/6),
    !.
load_sync(NewModule, FilePath) :-
    % Ensure we start with a clean module
    forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
    NewModule:use_module(le_kbs),
    forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
    assertz(NewModule:le_kb_module_fact(NewModule)),
    retractall(rule_counter(_)),
    assertz(rule_counter(1)),
    (   setup_call_cleanup(
            asserta(le_grammar:current_compiling_module(NewModule)),
            catch(parse_le_file(FilePath, doc(Sections), NewModule), EP, (print_message(error, EP), fail)),
            retractall(le_grammar:current_compiling_module(_))
        ) ->  
        forall(member(S, Sections), process_section(S, NewModule)),
        findall(D, le_system_template(D), SysDicts),
        forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
        (   catch(le_verifier:verify(NewModule, Issues), EV, (print_message(error, EV), Issues = [])) -> 
            forall(member(issue(Type, Desc, Fix, Start, End), Issues), (
                (Type == missing_template -> Severity = error; Severity = warning),
                assertz(NewModule:le_issue(Severity, Type, Desc, Fix, Start, End))
            ))
        ;   true
        )
    ;   % Parsing failed
        forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
        forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
        assertz(NewModule:le_issue(error, parse_error, "parse_le_file failed for ~w" - [FilePath], "", 0, 0)),
        assertz(NewModule:le_source_info(none, 0, 0, none)),
        print_message(error, "parse_le_file failed for ~w" - [FilePath])
    ).

load_text(Text, NewModule) :-
    (   var(NewModule) ->  
        variant_sha1(Text, Hash),
        atom_concat(m, Hash, NewModule)
    ;   true
    ),
    with_mutex(NewModule, load_text_sync(NewModule, Text)).

load_text_sync(NewModule, _) :-
    current_module(NewModule), 
    current_predicate(NewModule:le_source_info/4), 
    \+ current_predicate(NewModule:le_issue/6),
    !.
load_text_sync(NewModule, Text) :-
    % Ensure we start with a clean module
    forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
    NewModule:use_module(le_kbs),
    forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
    assertz(NewModule:le_kb_module_fact(NewModule)),
    retractall(rule_counter(_)),
    assertz(rule_counter(1)),
    (   setup_call_cleanup(
            asserta(le_grammar:current_compiling_module(NewModule)),
            catch(parse_le_text(Text, doc(Sections), NewModule), EP, (print_message(error, EP), fail)),
            retractall(le_grammar:current_compiling_module(_))
        ) ->  
        forall(member(S, Sections), process_section(S, NewModule)),
        findall(D, le_system_template(D), SysDicts),
        forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
        (   catch(le_verifier:verify(NewModule, Issues), EV, (print_message(error, EV), Issues = [])) -> 
            forall(member(issue(Type, Desc, Fix, Start, End), Issues), (
                (Type == missing_template -> Severity = error; Severity = warning),
                assertz(NewModule:le_issue(Severity, Type, Desc, Fix, Start, End))
            ))
        ;   true)
    ;   % Parsing failed
        forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
        forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
        assertz(NewModule:le_issue(error, parse_error, "Parsing failed. Check for malformed sections or characters.", "", 0, 0)),
        assertz(NewModule:le_source_info(none, 0, 0, none)),
        print_message(error, "parse_le_text failed")
    ).

:- dynamic rule_counter/1.
:- thread_local rule_counter/1.

process_section(S, M) :-
    ( do_log -> print_message(informational,'Processing section: ~w' - [S]); true),
    retractall(rule_counter(_)),
    assertz(rule_counter(1)),
    (process_section_acc(S, M) -> true ; writeln(user_error, failed_section(S)), fail).

process_section_acc(kb(Name, Content, Start, End), M) :-
    assertz(M:le_kb(Name), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(scenario(Name, Content, Start, End), M) :-
    dynamic(M:le_expected/3),
    partition(is_expected_item, Content, ExpectedItems, FactItems),
    findall(D, M:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, AllTemplates),
    maplist(item_to_term_with_source(M, AllTemplates), FactItems, Terms),
    assertz(M:scenario(Name, Terms), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)),
    forall(member(expected(Q, A, S, E), ExpectedItems), (
        assertz(M:le_expected(Q, Name, A), ERef),
        assertz(M:le_source_info(ERef, S, E, Q))
    )).

process_section_acc(query(Name, Content, Start, End), M) :-
    findall(D, M:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, AllTemplates),
    maplist(item_to_term(AllTemplates, M), Content, Terms),
    list_to_conj(Terms, Goal),
    assertz(M:query_info(Name, Goal, Content), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)).



process_section_acc(ontology(Content, Start, End), M) :-
    assertz(M:ontology(Content), Ref),
    assertz(M:le_source_info(Ref, Start, End, ontology)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(predicates(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(templates(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(fluents(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(events(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(meta(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).

process_section_acc(unknown_section(Tokens, Start, End), M) :-
    le_grammar:reconstruct_name(Tokens, FullName),
    ( atom_length(FullName, L), L > 100 -> sub_atom(FullName, 0, 100, _, Sub), atom_concat(Sub, '...', Name); Name = FullName),
    format(atom(Desc), "Unknown or malformed section starting with: ~w", [Name]),
    assertz(M:le_issue(error, unknown_section, Desc, Start, End)).

assert_dict_with_source(dict(FA, NTs, WV, Start, End), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)).
assert_dict_with_source(dict(FA, NTs, WV), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV))).

process_item(clause(Head, Body, Start, End, ID), M) :-
    ( var(ID) -> 
        rule_counter(C), NextC is C + 1, retractall(rule_counter(_)), assertz(rule_counter(NextC)),
        format(atom(GeneratedID), 'rule_~w', [C]),
        ActualID = GeneratedID
    ; ActualID = ID
    ),
    ( Body == true -> Clause = Head; Clause = (Head :- Body)),
    functor(Head, F, N),
    dynamic(M:F/N),
    ( clause(M:Head, Body) -> true; assertz(M:Clause, Ref), assertz(M:le_source_info(Ref, Start, End, ActualID))).

le_my_id(ID) :-
    le_current_id(ID).

:- multifile le_my_kb/1.

le_my_kb(KB) :-
    ( le_kb_module(K), K \== none -> KB = K
    ; context_module(KB)
    ).

set_kb_module(KB) :-
    retractall(le_kb_module(_)),
    assertz(le_kb_module(KB)).

clear_kb_module :-
    retractall(le_kb_module(_)).

set_id_from_ref(Ref, M) :-
    ( M:le_source_info(Ref, _, _, ID) -> retractall(le_current_id(_)), assertz(le_current_id(ID)) ; true ).

person_age('Bob', 42).
person_age('Alice', 30).

createSession(KBmodule, SessionModule) :-
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    SessionModule:use_module(le_kbs),
    dynamic(SessionModule:le_kb_module_fact/1),
    assertz(SessionModule:le_kb_module_fact(KBmodule)),
    dynamic(SessionModule:debug_mode/0),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:debug_mode/0),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source_info/4).

addSessionFact(SessionModule, Fact) :-
    ( Fact = fact_with_source(ActualFact, Start, End) -> true; ActualFact = Fact, Start = 0, End = 0),
    ( do_log -> print_message(informational, 'Adding session fact: ~w' - [ActualFact]); true),
    functor(ActualFact,F,N),
    SessionModule:dynamic(F/N),
    (   (current_predicate(SessionModule:F/N), functor(Template, F, N), SessionModule:clause(Template, true), copy_term(Template, ECopy), copy_term(ActualFact, ACopy), numbervars(ECopy, 0, _), numbervars(ACopy, 0, _), ECopy == ACopy) ->  
            ( do_log -> print_message(informational, 'Fact already exists (variant): ~w' - [ActualFact]); true)
        ; assertz(SessionModule:ActualFact, Ref),
          assertz(SessionModule:sessionClause(Ref)),
          ( Start \== 0 -> assertz(SessionModule:le_source_info(Ref, Start, End, session_fact)); true)
    ).

negateSessionFact(SessionModule, Fact) :-
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

setScenarion(SessionModule, ScenarioName) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( current_predicate(KBmodule:scenario/2) -> 
        (   KBmodule:scenario(ScenarioName, Facts) -> true
        ;   atom(ScenarioName), atom_number(ScenarioName, Num), KBmodule:scenario(Num, Facts) -> true
        ;   fail
        ),
        forall(member(Fact, Facts), addSessionFact(SessionModule, Fact))
    ; fail).

clearSession(SessionModule) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true; KBmodule = none),
    forall(current_predicate(SessionModule:F/N), abolish(SessionModule:F/N)),
    ( KBmodule \== none -> 
        dynamic(SessionModule:le_kb_module_fact/1),
        assertz(SessionModule:le_kb_module_fact(KBmodule))
    ; true),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:debug_mode/0),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source_info/4).

printSession(SessionModule) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( KBmodule \== none -> KBmodule:le_kb(KBName) ; KBName = unknown ),
    format('Session: ~w~nKB: ~w (~w)~nFacts:~n', [SessionModule, KBName, KBmodule]),
    forall((SessionModule:sessionClause(Ref), clause(H, B, Ref)),
           (H \= sessionClause(_), format('  ~w :- ~w~n', [H, B]))).

query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( do_log -> print_message(informational, 'Querying KB ~w in session ~w with tokens ~w' - [KBmodule, SessionModule, Tokens]); true),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), (KBmodule:query_info(QueryName, Goal, Items) ; (atom(QueryName), atom_number(QueryName, Num), KBmodule:query_info(Num, Goal, Items)))) ->  
            ( do_log -> print_message(informational, 'Executing named query ~w: ~w' - [QueryName, Goal]); true),
            reasoner:i(Goal, SessionModule, Unknowns, Why0),
            ( do_log -> print_message(informational, 'Named query solution found for ~w' - [QueryName]); true),
            maplist(le_kbs:item_to_instance(KBmodule), Items, Instances),
            flatten(Instances, TemplateInstance),
            postprocess_why(Why0, SessionModule, Why)
        ; ( do_log -> print_message(informational, 'Searching for template matching tokens: ~w' - [Tokens]); true),
            findall(D, KBmodule:le_dict(D), Dicts),
            le_grammar:prepare_templates(Dicts, Templates),
            findall(match(G, WV, FA), (
                member(Dict, Templates),
                ( Dict = dict(FA, _, WV, _, _, _) -> true ; Dict = dict(FA, _, WV, _) -> true ; Dict = dict(FA, _, WV) ),
                \+ (FA = [le_is|_]),
                le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
                G =.. FA
            ), SpecificMatches),
            (   SpecificMatches \== [] -> Matches = SpecificMatches
                ; findall(match(G, WV, FA), (
                    member(Dict, Templates),
                    ( Dict = dict(FA, _, WV, _, _, _) -> true ; Dict = dict(FA, _, WV, _) -> true ; Dict = dict(FA, _, WV) ),
                    FA = [le_is|_],
                    le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
                    G =.. FA
                ), Matches)
            ),
            (   Matches \== [] ->
                member(match(Goal, TemplateInstance, _), Matches),
                ( do_log -> print_message(informational, 'Executing template goal: ~w' - [Goal]); true),
                reasoner:i(Goal, SessionModule, Unknowns, Why0),
                ( do_log -> print_message(informational, 'Template goal solution found: ~w' - [Goal]); true),
                postprocess_why(Why0, SessionModule, Why)
            ;   format(string(Error), "Query does not match any template: ~w", [Template]),
                throw(error(le_parse_error(Error), _))
            )
    ).

query_explain(SessionModule, Goal, TemplateInstance, Unknowns, Why) :-
    compound(Goal), \+ is_list(Goal), !,
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    reasoner:explain(Goal, SessionModule, Unknowns, Why0),
    ( (KBmodule \== none, item_to_instance(KBmodule, Goal, _Tokens)) -> true ; TemplateInstance = [Goal] ),
    postprocess_why(Why0, SessionModule, Why).
query_explain(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), (KBmodule:query_info(QueryName, Goal, Items) ; (atom(QueryName), atom_number(QueryName, Num), KBmodule:query_info(Num, Goal, Items)))) ->  
            ( do_log -> print_message(informational, 'Executing named query explain ~w: ~w' - [QueryName, Goal]); true),
            reasoner:explain(Goal, SessionModule, Unknowns, Why0),
            ( (maplist(le_kbs:item_to_instance(KBmodule), Items, Instances), flatten(Instances, TemplateInstance)) -> true; TemplateInstance = []),
            postprocess_why(Why0, SessionModule, Why)
        ; findall(D, KBmodule:le_dict(D), Dicts),
          le_grammar:prepare_templates(Dicts, Templates),
          findall(match(G, WV, FA), (
              member(Dict, Templates),
              ( Dict = dict(FA, _, WV, _, _, _) -> true ; Dict = dict(FA, _, WV, _) -> true ; Dict = dict(FA, _, WV) ),
              \+ (FA = [le_is|_]),
              le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
              G =.. FA
          ), SpecificMatches),
          (   SpecificMatches \== [] -> Matches = SpecificMatches
              ; findall(match(G, WV, FA), (
                    member(Dict, Templates),
                    ( Dict = dict(FA, _, WV, _, _, _) -> true ; Dict = dict(FA, _, WV, _) -> true ; Dict = dict(FA, _, WV) ),
                    FA = [le_is|_],
                    le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
                    G =.. FA
                ), Matches)
          ),
          (   Matches \== [] ->
                member(match(Goal, TemplateInstance, _), Matches),
                ( do_log -> print_message(informational, 'Executing template goal explain: ~w' - [Goal]); true),
                reasoner:explain(Goal, SessionModule, Unknowns, Why0),
                postprocess_why(Why0, SessionModule, Why)
            ;   format(string(Error), "Query does not match any template: ~w", [Template]),
                throw(error(le_parse_error(Error), _))
          )
    ).

postprocess_why(success(Goal0, Ref, Children), SM, success(Goal, Range, LE, ChildrenOut)) :- !,
    ( Goal0 = le_at(Goal, _, _) -> true; Goal = Goal0),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( (SM:le_source_info(Ref, Start, End, _); (KB \== none, KB:le_source_info(Ref, Start, End, _))) -> Range = range(Start, End); Range = Ref),
    ( (KB \== none, item_to_instance(KB, Goal, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    maplist(postprocess_why_child(SM), Children, ChildrenOut).
postprocess_why(failure(Goal0, Children), SM, failure(Goal, Range, LE, ChildrenOut)) :- !,
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( Goal0 = le_at(Goal, Start, End) -> Range = range(Start, End)
    ; Goal = Goal0, ( find_first_range(Goal, SM, KB, Range) -> true ; Range = none )
    ),
    ( (KB \== none, item_to_instance(KB, Goal, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    maplist(postprocess_why_child(SM), Children, ChildrenOut).
postprocess_why(Whys, SM, WhysOut) :-
    is_list(Whys), !,
    maplist(postprocess_why_child(SM), Whys, WhysOut).
postprocess_why(Other, _, Other).

find_first_range(Goal, SM, KB, range(Start, End)) :-
    functor(Goal, F, A),
    functor(Skeleton, F, A),
    findall(S-E, (
        (SM:clause(Skeleton, _, Ref) ; (KB \== none, KB:clause(Skeleton, _, Ref))),
        (SM:le_source_info(Ref, S, E, _) ; (KB \== none, KB:le_source_info(Ref, S, E, _)))
    ), Ranges),
    Ranges \== [],
    sort(Ranges, [Start-End|_]).

postprocess_why_child(SM, Child, ChildOut) :-
    postprocess_why(Child, SM, ChildOut).

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

canonical_string(Instance, String) :-
    (   is_list(Instance) ->  
        maplist(le_kbs:token_to_atom, Instance, Atoms),
        ( maplist(var, Atoms) -> String = ""; catch(atomic_list_concat(Atoms, ' ', String), _, String = "error"))
        ;   
        le_kbs:token_to_atom(Instance, Atom),
        atom_string(Atom, String)
    ).

token_to_atom(X, Atom) :- var(X), !, Atom = '_'.
token_to_atom(var(Words, loc(_, _)), Atom) :- !, token_to_atom(var(Words), Atom).
token_to_atom(var(Name, Value), Atom) :- !,
    ( nonvar(Value) -> token_to_atom(Value, Atom); token_to_atom(Name, Atom)).
token_to_atom(var(Words, _), Atom) :- !, token_to_atom(var(Words), Atom).
token_to_atom(word(W, _), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(word(W), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(var(Words), Atom) :- !, 
    ( var(Words) -> Atom = '_'; is_list(Words) -> (maplist(token_to_atom, Words, Atoms), atomic_list_concat(Atoms, ' ', Atom)); atom_string(Atom, Words)).
token_to_atom(number(N, _), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
token_to_atom(number(N), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
token_to_atom(string(S, _), Atom) :- !, (string(S) -> atom_string(Atom, S) ; atom(S) -> Atom = S ; term_to_atom(S, Atom)).
token_to_atom(punctuation(P, _), P) :- !.
token_to_atom(punctuation(P), P) :- !.
token_to_atom(punct(P, _), P) :- !.
token_to_atom(punct(P), P) :- !.
token_to_atom(date(date(Y,M,D), _), Atom) :- !, 
    ( number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]); Atom = 'date').
token_to_atom(date(Y,M,D), Atom) :- !,
    ( number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]); Atom = 'date').
token_to_atom(S, Atom) :- string(S), !, atom_string(Atom, S).
token_to_atom(A, Atom) :- atom(A), !, 
    ( (A \== '_', sub_atom(A, _, _, _, '_')) -> re_replace("_"/g, " ", A, Atom); Atom = A).
token_to_atom(X, Atom) :- term_to_atom(X, Atom).

item_to_instance(KBmodule, le_at(Goal, _, _), WordsAndVars) :- !,
    item_to_instance(KBmodule, Goal, WordsAndVars).
item_to_instance(_KBmodule, query_clause(_Goal, _, InstantiatedTokens, _, _), InstantiatedTokens) :- !.
item_to_instance(_KBmodule, query_clause(_Goal, _, _, InstantiatedTokens, _, _, _, _), InstantiatedTokens) :- !.
item_to_instance(KBmodule, Head, WordsAndVars) :-
    (   Head = is_a(Type, SuperType) -> WordsAndVars = [Type, is, a, SuperType]
    ;   Head = sum([each, Var], _Goal, [Result]) -> 
        extract_name(Var, VarName),
        WordsAndVars = [Result, is, the, sum, of, each, VarName, such, that]
    ;   Head = count([each, Var], _Goal, [Result]) -> 
        extract_name(Var, VarName),
        WordsAndVars = [Result, is, the, count, of, each, VarName, such, that]
    ;   Head = min([each, Var], _Goal, [Result]) -> 
        extract_name(Var, VarName),
        WordsAndVars = [Result, is, the, minimum, of, each, VarName, such, that]
    ;   Head = max([each, Var], _Goal, [Result]) -> 
        extract_name(Var, VarName),
        WordsAndVars = [Result, is, the, maximum, of, each, VarName, such, that]
    ;   Head = average([each, Var], _Goal, [Result]) -> 
        extract_name(Var, VarName),
        WordsAndVars = [Result, is, the, average, of, each, VarName, such, that]
    ;   Head = not(Goal) -> 
        ( item_to_instance(KBmodule, Goal, GoalLE) -> WordsAndVars = [it, is, not, the, case, that | GoalLE]; WordsAndVars = [it, is, not, the, case, that, Goal])
    ;   Head = forall(Cond, Cons) -> 
        ( item_to_instance(KBmodule, Cond, CondLE), item_to_instance(KBmodule, Cons, ConsLE) -> 
            append([for, all, cases, in, which | CondLE], [it, is, the, case, that | ConsLE], WordsAndVars)
        ; WordsAndVars = [for, all, cases, in, which, Cond, it, is, the, case, that, Cons])
    ;   Head = and(A, B) -> 
        ( item_to_instance(KBmodule, A, ALE), item_to_instance(KBmodule, B, BLE) -> 
            append(ALE, [and | BLE], WordsAndVars)
        ; WordsAndVars = [A, and, B])
    ;   Head = or(A, B) -> 
        ( item_to_instance(KBmodule, A, ALE), item_to_instance(KBmodule, B, BLE) -> 
            append(ALE, [or | BLE], WordsAndVars)
        ; WordsAndVars = [A, or, B])
    ;   copy_term(Head, HeadCopy),
        ( (KBmodule:le_dict(dict([Functor|Args], _NTs, WordsAndVars)), HeadCopy =.. [Functor|Args]) -> true; term_string(Head, Str), WordsAndVars = [Str])
    ).

extract_name(var(Name, _), Name) :- !.
extract_name(V, V).

get_kb_metadata(KB, Metadata) :-
    ( current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true; KBName = null),
    findall(TemplateStr, (
        KB:le_dict(dict(FA, NTs, WV)),
        \+ le_system_templates:le_system_template(dict(FA, NTs, WV)),
        copy_term(NTs-WV, NTsC-WVC),
        maplist(fill_type, NTsC),
        canonical_string(WVC, TemplateStr)
    ), Templates),
    (   current_predicate(KB:query_info/3) ->  
        findall(_{name: Name, template: QueryStr, le: LEStr}, (
            KB:query_info(Name, Goal, Items),
            copy_term(Goal, GoalCopy),
            term_string(GoalCopy, QueryStr),
            maplist(item_to_le_string, Items, LEStrings),
            atomic_list_concat(LEStrings, ' and ', LEStr)
        ), Queries)
        ;   
        Queries = []
    ),
    (   current_predicate(KB:scenario/2) ->  
        findall(_{name: Name}, KB:scenario(Name, _), Scenarios)
        ;   
        Queries = []
    ),
    Metadata = _{ kb: KBName, templates: Templates, queries: Queries, examples: Scenarios }.

topPredicates(KB, TopPreds) :-
    findall(F/A, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(G, F, A),
        \+ predicate_property(KB:G, imported_from(_)),
        le_verifier:is_intensional(KB, F, A),
        \+ is_used_by_other_rules(KB, F, A)
    ), Preds),
    sort(Preds, UniquePreds),
    maplist(pred_to_template(KB), UniquePreds, TopPreds).

is_used_by_other_rules(KB, F, A) :-
    current_predicate(KB:F2/A2),
    F2/A2 \== F/A,
    \+ is_system_predicate(F2/A2),
    functor(G2, F2, A2),
    KB:clause(G2, Body),
    le_verifier:find_in_body(Body, Literal),
    functor(Literal, F, A).

pred_to_template(KB, F/A, TemplateStr) :-
    (   KB:le_dict(dict([F|_], NTs, WordsAndVars))
    ->  copy_term(NTs-WordsAndVars, NTsCopy-WordsAndVarsCopy),
        maplist(fill_type, NTsCopy),
        canonical_string(WordsAndVarsCopy, TemplateStr)
    ;   functor(Head, F, A),
        item_to_instance(KB, Head, Tokens),
        canonical_string(Tokens, TemplateStr)
    ).

fill_type(V-Type) :-
    (   atom(Type) -> format(atom(V), "a ~w", [Type])
    ;   V = 'a variable'
    ).

kbSummary(KB, Summary) :-
    (current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true ; KBName = KB),
    topPredicates(KB, TopPreds),
    atomic_list_concat(TopPreds, '; ', PredsStr),
    format(string(Summary), "KB: ~w. Top predicates: ~w", [KBName, PredsStr]).

is_a_hierarchy(KBmodule, Hierarchy) :-
    findall(edge(Sub, Super, Start, End), (
        (   current_predicate(KBmodule:le_taxonomy_edge/3),
            KBmodule:le_taxonomy_edge(Sub, Super, Start), End = Start
        ;   current_predicate(KBmodule:is_a/2),
            KBmodule:clause(is_a(Sub, Super), _Body, Ref),
            KBmodule:le_source_info(Ref, Start, End, _)
        ),
        atom(Sub), atom(Super)
    ), Edges0),
    sort(Edges0, Edges),
    % Find all types
    findall(T, (
        (member(edge(Sub, Super, _, _), Edges), (T = Sub ; T = Super))
        ; (current_predicate(KBmodule:le_type/1), KBmodule:le_type(T))
    ), AllTypes0),
    sort(AllTypes0, _AllTypes),
    % Find roots (types that are a Super but not a Sub in any edge)
    findall(R, (member(edge(_, R, _, _), Edges), \+ member(edge(R, _, _, _), Edges)), Roots0),
    sort(Roots0, Roots1),
    % If no roots (cycles?), just take all types that are Super
    ( Roots1 == [] -> findall(R, member(edge(_, R, _, _), Edges), Roots2), sort(Roots2, Roots) ; Roots = Roots1),
    maplist(build_node(Edges, []), Roots, Hierarchy).

build_node(Edges, Visited, Type, node(Type, Start, End, Children)) :-
    \+ memberchk(Type, Visited),
    % Children are those that have this Type as Super (Sub is_a Type)
    findall(edge(Sub, Type, S, E), member(edge(Sub, Type, S, E), Edges), ChildEdges),
    % Sort children by name
    sort(ChildEdges, SortedChildEdges),
    maplist(build_child_node(Edges, [Type|Visited]), SortedChildEdges, Children),
    % A node's source is where it is defined as a Sub of something
    ( member(edge(Type, _, S, E), Edges) -> Start = S, End = E ; Start = 0, End = 0).

build_child_node(Edges, Visited, edge(Type, _Super, Start, End), node(Type, Start, End, Children)) :-
    \+ memberchk(Type, Visited),
    findall(edge(Sub, Type, S, E), member(edge(Sub, Type, S, E), Edges), ChildEdges),
    sort(ChildEdges, SortedChildEdges),
    maplist(build_child_node(Edges, [Type|Visited]), SortedChildEdges, Children).
build_child_node(_Edges, Visited, edge(Type, _Super, _S, _E), node(Type, 0, 0, [])) :-
    memberchk(Type, Visited).







parse_custom_facts(KB, Text, Terms) :-
    tokenize(Text, Tokens),
    le_grammar:set_token_pos(0),
    ( phrase(le_grammar:kb_items(Items), Tokens) -> true ; Items = [] ),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    maplist(item_to_term(Templates), Items, Terms).

parse_custom_query(KB, Text, Goal) :-
    tokenize(Text, Tokens),
    le_grammar:set_token_pos(0),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    (   le_grammar:parse_literal(Tokens, Templates, [], _VM, Goal, _, true) -> true
    ;   format(string(Error), "Query does not match any template: ~w", [Text]),
        throw(error(le_parse_error(Error), _))
    ).

is_system_predicate(le_source_element/3).
is_system_predicate(le_kb/1).
is_system_predicate(le_source_info/4).
is_system_predicate(scenario/2).
is_system_predicate(le_expected/3).
is_system_predicate(query_info/3).
is_system_predicate(ontology/1).
is_system_predicate(le_dict/1).
is_system_predicate(unknown_template/1).
is_system_predicate(le_issue/6).
is_system_predicate(le_kb_module_fact/1).
is_system_predicate(le_neg/1).
is_system_predicate(sessionClause/1).
is_system_predicate(le_type/1).
is_system_predicate(le_taxonomy_edge/3).

is_expected_item(expected(_, _, _, _)).

verify(LEfilePath) :-
    uuid(UUID), atom_concat(v, UUID, KBmodule),
    le_grammar:parse_le_file(LEfilePath, doc(Sections), KBmodule),
    forall(member(S, Sections), process_section(S, KBmodule)),
    findall(D, le_system_template(D), SysDicts),
    forall(member(D, SysDicts), assertz(KBmodule:le_dict(D))),
    le_verifier:verify(KBmodule, Issues),
    forall(member(Issue, Issues), le_verifier:print_issue(Issue)),
    atom_concat(LEfilePath, '.tests', TestsFile),
    (   exists_file(TestsFile) ->  
        setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, LegacyTests), close(Stream))
        ; LegacyTests = []
    ),
    ( current_predicate(KBmodule:le_expected/3) -> findall(test(Q, S, A), KBmodule:le_expected(Q, S, A), EmbeddedTests); EmbeddedTests = []),
    append(LegacyTests, EmbeddedTests, AllTests),
    (   AllTests \== [] ->  
        maplist(run_one_test(KBmodule), AllTests, TestResults),
        print_test_result(test_file(LEfilePath, TestResults))
        ;   
        true
    ),
    forall(current_predicate(KBmodule:F/N), abolish(KBmodule:F/N)).

item_to_le_string(query_clause(_, OriginalTokens, _, _, _), String) :- !,
    tokens_to_string(OriginalTokens, String).
item_to_le_string(query_clause(_, OriginalTokens, _, _, _, _, _, _), String) :- !,
    tokens_to_string(OriginalTokens, String).
item_to_le_string(Item, String) :-
    term_string(Item, String).

item_to_term(_Templates, _M, query_clause(Head, _, _, _, _), Head) :- !.
item_to_term(_Templates, _M, query_clause(Head, _, _, _, _, _, _, _), Head) :- !.
item_to_term(_Templates, _M, clause(Head, true, _, _, _), Head) :- !.
item_to_term(_Templates, _M, clause(Head, Body, _, _, _), (Head :- Body)) :- !.
item_to_term(_Templates, _M, clause(Head, true, _, _), Head) :- !.
item_to_term(_Templates, _M, clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Templates, M, Item, Term) :-
    ( le_grammar:second_pass_item_with_module(Templates, M, Item, NewItem) -> item_to_term(Templates, M, NewItem, Term)
    ; Item = Term
    ).

item_to_term_with_source(_M, _Templates, query_clause(Head, _, _, Start, End), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, query_clause(Head, _, _, _, _, Start, End, _ID), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, true, Start, End, _ID), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, true, Start, End), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, Body, _Start, _End, _ID), (Head :- Body)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, Body, _Start, _End), (Head :- Body)) :- 
    % Rules in scenarios are rare but possible; we don't track their source yet
    !.
item_to_term_with_source(M, Templates, Item, Term) :-
    ( le_grammar:second_pass_item_with_module(Templates, M, Item, NewItem) -> item_to_term_with_source(M, Templates, NewItem, Term)
    ; Item = Term
    ).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

normalize_string(string(S, _), N) :- !, normalize_string(S, N).
normalize_string(S, N) :-
    (   number(S) -> atom_string(S, N)
    ;   (atom(S) ; string(S)) ->  
        split_string(S, "_- ", "_- ", Words),
        atomic_list_concat(Words, ' ', Atom),
        atom_string(Atom, N)
    ;   N = S
    ).

run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings), Result) :-
    createSession(KBmodule, SM),
    (   setScenarion(SM, ScenarioName) ->  
        (   ((KBmodule:query_info(QueryName, FullGoal, Items) ; (normalize_string(QueryName, NormName), KBmodule:query_info(InfoName, FullGoal, Items), normalize_string(InfoName, NormName)))) ->  
            (   catch(call_with_time_limit(30, findall(S, (reasoner:i(FullGoal, SM, [], _Why), maplist(le_kbs:item_to_instance(KBmodule), Items, Instances), flatten(Instances, TemplateInstance), le_kbs:canonical_string(TemplateInstance, Atom), atom_string(Atom, S)), ActualStrings)), time_limit_exceeded, (ActualStrings = timeout)) ->  
                    (   ActualStrings == timeout -> 
                            Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                        ; 
                        maplist(normalize_string, ExpectedStrings, NormExpected),
                        maplist(normalize_string, ActualStrings, NormActual),
                        sort(NormExpected, SortedExpected),
                        sort(NormActual, SortedActual),
                        (   SortedExpected == SortedActual -> 
                                Result = pass(QueryName, ScenarioName)
                            ; 
                            maplist(strip_string_wrapper, ExpectedStrings, CleanExpected),
                            Result = fail(QueryName, ScenarioName, CleanExpected, ActualStrings)
                        )
                    )
                ; Result = error(QueryName, ScenarioName, 'Test execution failed')
            )
            ;   
            % Try to parse QueryName as a custom query if not found in query_info
            (   catch(parse_custom_query(KBmodule, QueryName, FullGoal), _, fail) ->
                (   catch(call_with_time_limit(30, findall(S, (reasoner:i(FullGoal, SM, [], _Why), item_to_instance(KBmodule, FullGoal, TemplateInstance), le_kbs:canonical_string(TemplateInstance, Atom), atom_string(Atom, S)), ActualStrings)), time_limit_exceeded, (ActualStrings = timeout)) ->
                    (   ActualStrings == timeout -> Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                    ;   maplist(normalize_string, ExpectedStrings, NormExpected),
                        maplist(normalize_string, ActualStrings, NormActual),
                        sort(NormExpected, SortedExpected),
                        sort(NormActual, SortedActual),
                        ( SortedExpected == SortedActual -> Result = pass(QueryName, ScenarioName) ; maplist(strip_string_wrapper, ExpectedStrings, CleanExpected), Result = fail(QueryName, ScenarioName, CleanExpected, ActualStrings) )
                    )
                ;   Result = error(QueryName, ScenarioName, 'Test execution failed')
                )
            ;   % Last resort: try to find query by name in query_info again with more logging
                ( le_kbs:do_log -> format('Query not found: ~w~n', [QueryName]) ; true ),
                Result = error(QueryName, ScenarioName, 'Query not found')
            )
        )
        ;   
        Result = error(QueryName, ScenarioName, 'Scenario not found')
    ),
    clearSession(SM).

strip_string_wrapper(string(S, _), S) :- !.
strip_string_wrapper(S, S).

read_tests(Stream, Tests) :-
    read(Stream, Term),
    ( Term == end_of_file -> Tests = []; Term = expected(Q, S, E) -> Tests = [test(Q, S, E)|Rest], read_tests(Stream, Rest); read_tests(Stream, Tests)).

runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(LEFile, (member(F, Files), sub_atom(F, _, _, 0, '.le'), \+ sub_atom(F, _, _, 0, '.le.tests'), directory_file_path(Dir, F, LEFile)), LEFiles0),
    sort(LEFiles0, LEFiles),
    maplist(runTestsFor, LEFiles, Results).

runTestsFor(LEFile, Result) :-
    print_message(informational,"Running tests for ~w"-[LEFile]),
    (   catch(call_with_time_limit(5, load(LEFile, KBmodule)), E, (format('Error loading ~w: ~w~n', [LEFile, E]), fail)) ->  
        atom_concat(LEFile, '.tests', TestsFile),
        (   exists_file(TestsFile) ->  
            setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, LegacyTests), close(Stream))
            ; LegacyTests = []
        ),
        ( current_predicate(KBmodule:le_expected/3) -> findall(test(Q, S, A), KBmodule:le_expected(Q, S, A), EmbeddedTests); EmbeddedTests = []),
        append(LegacyTests, EmbeddedTests, AllTests),
        maplist(run_one_test(KBmodule), AllTests, TestResults),
        Result = test_file(LEFile, TestResults)
        ;   
        Result = test_file(LEFile, [error(load, LEFile, 'Failed to load or timeout loading LE file')])
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
               ( (FC > 0 ; EC > 0) -> Status = '[FAIL]' ; (PC == 0, FC == 0, EC == 0) -> Status = '[NONE]' ; Status = '[PASS]' ),
               format('  ~w ~w: ~w Pass, ~w Fail, ~w Error~n', [Status, File, PC, FC, EC])
           )),
    format('-------------~n~n').

print_test_result(test_file(File, FileResults)) :-
    format('File: ~w~n', [File]),
    forall(member(R, FileResults),
           ( R = pass(Q, S) -> format('  PASS: ~w (~w)~n', [Q, S]); R = fail(Q, S, E, A) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n', [Q, S, E, A]); format('  ERROR: ~w~n', [R]))).

/** <module> Logical English Knowledge Base Management
    
    This module provides predicates for loading Logical English files,
    managing reasoning sessions, and running tests.
*/

:- module(le_kbs, [load/2, load_text/2, createSession/2, 
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, 
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0, get_kb_metadata/2, is_system_predicate/1,
    run_one_test/3,
    verify/1, edit/1, canonical_string/2, token_to_atom/2, item_to_instance/3, query_explain/5,
    topPredicates/2, kbSummary/2, parse_custom_facts/3, parse_custom_query/3]).

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
    (   var(NewModule) ->  
        time_file(FilePath, Time),
        variant_sha1([FilePath, Time], Hash),
        atom_concat(m, Hash, NewModule)
        ;   
        true
    ),
    (   (current_module(NewModule), current_predicate(NewModule:le_source/3), \+ current_predicate(NewModule:le_issue/5)) -> true
        ; (   catch(parse_le_file(FilePath, doc(Sections)), EP, (print_message(error, EP), fail)) ->  
                % Ensure we start with a clean module
                forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
                dynamic(NewModule:le_issue/5),
                forall(member(S, Sections), process_section(S, NewModule)),
                findall(D, le_system_template(D), SysDicts),
                forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
                ( catch(le_verifier:verify(NewModule, Issues), EV, (print_message(error, EV), Issues = [])) -> 
                    forall(member(issue(Type, Desc, _Fix, Start, End), Issues), (
                        (Type == missing_template -> Severity = error; Severity = warning),
                        assertz(NewModule:le_issue(Severity, Type, Desc, Start, End))
                    ))
                ; true)
            ; print_message(error, "parse_le_file failed for ~w" - [FilePath]),
              fail
        )
    ).

process_section(S, M) :-
    ( do_log -> print_message(informational,'Processing section: ~w' - [S]); true),
    process_section_acc(S, M).

process_section_acc(kb(Name, Content, Start, End), M) :-
    assertz(M:le_kb(Name), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(scenario(Name, Content, Start, End), M) :-
    M:dynamic(le_expected/3),
    partition(is_expected_item, Content, ExpectedItems, FactItems),
    maplist(item_to_term_with_source(M), FactItems, Terms),
    assertz(M:scenario(Name, Terms), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(expected(Q, A, S, E), ExpectedItems), (
        assertz(M:le_expected(Q, Name, A), ERef),
        assertz(M:le_source(ERef, S, E))
    )).

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
process_section_acc(unknown_section(Tokens, Start, End), M) :-
    le_grammar:reconstruct_name(Tokens, FullName),
    ( atom_length(FullName, L), L > 100 -> sub_atom(FullName, 0, 100, _, Sub), atom_concat(Sub, '...', Name); Name = FullName),
    format(atom(Desc), "Unknown or malformed section starting with: ~w", [Name]),
    assertz(M:le_issue(error, unknown_section, Desc, Start, End)).
process_section_acc(_, _).

process_item(clause(Head, Body, Start, End), M) :-
    ( Body == true -> Clause = Head; Clause = (Head :- Body)),
    functor(Head, F, N),
    M:dynamic(F/N),
    ( clause(M:Head, Body) -> true; assertz(M:Clause, Ref), assertz(M:le_source(Ref, Start, End))).

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
    ( Fact = fact_with_source(ActualFact, Start, End) -> true; ActualFact = Fact, Start = 0, End = 0),
    ( do_log -> print_message(informational, 'Adding session fact: ~w' - [ActualFact]); true),
    functor(ActualFact,F,N),
    SessionModule:dynamic(F/N),
    % Use variant check instead of unification to allow multiple facts with variables
    (   (current_predicate(SessionModule:F/N), functor(Template, F, N), SessionModule:clause(Template, true), copy_term(Template, ECopy), copy_term(ActualFact, ACopy), numbervars(ECopy, 0, _), numbervars(ACopy, 0, _), ECopy == ACopy) ->  
            ( do_log -> print_message(informational, 'Fact already exists (variant): ~w' - [ActualFact]); true)
        ; assertz(SessionModule:ActualFact, Ref),
          assertz(SessionModule:sessionClause(Ref)),
          ( Start \== 0 -> assertz(SessionModule:le_source(Ref, Start, End)); true)
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
    ( current_predicate(KBmodule:scenario/2) -> KBmodule:scenario(ScenarioName, Facts), forall(member(Fact, Facts), addSessionFact(SessionModule, Fact)); fail).

%!  clearSession(+SessionModule:atom) is det.
clearSession(SessionModule) :-
    ( SessionModule:le_my_kb(KBmodule) -> true; KBmodule = none),
    forall(current_predicate(SessionModule:F/N), abolish(SessionModule:F/N)),
    ( KBmodule \== none -> assertz(SessionModule:le_my_kb(KBmodule)); true),
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

%!  query(+SessionModule:atom, +Template:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is nondet.
%
%   Executes a query against the knowledge base associated with the given session.
%   The query can be specified either as a named query (defined in the LE file) 
%   or as a natural language string/list of tokens that matches a template.
%
%   @param SessionModule The module identifier for the current reasoning session.
%   @param Template Either an atom/string naming a query, or a natural language 
%          representation (string, atom, or list of tokens) of the goal.
%   @param TemplateInstance A list of tokens representing the matched template, 
%          with variables instantiated to their discovered values.
%   @param Unknowns A list of goals that could not be proven but are marked as 
%          unknown in the KB, leading to a conditional success.
%   @param Why An explanation tree providing the justification for the result.
query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    SessionModule:le_my_kb(KBmodule),
    ( do_log -> print_message(informational, 'Querying KB ~w in session ~w with tokens ~w' - [KBmodule, SessionModule, Tokens]); true),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), KBmodule:query_info(QueryName, Goal, Items)) ->  
            ( do_log -> print_message(informational, 'Executing named query ~w: ~w' - [QueryName, Goal]); true),
            reasoner:i(Goal, SessionModule, Unknowns, Why0),
            ( do_log -> print_message(informational, 'Named query solution found for ~w' - [QueryName]); true),
            maplist(le_kbs:item_to_instance(KBmodule), Items, Instances),
            flatten(Instances, TemplateInstance),
            postprocess_why(Why0, SessionModule, Why)
        ; ( do_log -> print_message(informational, 'Searching for template matching tokens: ~w' - [Tokens]); true),
            findall(D, KBmodule:le_dict(D), Dicts),
            le_grammar:prepare_templates(Dicts, Templates),
            % Find all matching templates, but separate le_is
            findall(match(G, WV, FA), (
                member(Dict, Templates),
                copy_term(Dict, dict(FA, _, WV, _)),
                \+ (FA = [le_is|_]),
                le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
                G =.. FA
            ), SpecificMatches),
            (   SpecificMatches \== [] -> Matches = SpecificMatches
                ; % Only try le_is if no specific template matched
                findall(match(G, WV, FA), (
                    member(Dict, Templates),
                    copy_term(Dict, dict(FA, _, WV, _)),
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

%!  query_explain(+SessionModule:atom, +Template:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is nondet.
query_explain(SessionModule, Goal, TemplateInstance, Unknowns, Why) :-
    compound(Goal), \+ is_list(Goal), !,
    SessionModule:le_my_kb(KBmodule),
    reasoner:explain(Goal, SessionModule, Unknowns, Why0),
    ( (KBmodule \== none, item_to_instance(KBmodule, Goal, TemplateInstance)) -> true ; TemplateInstance = [Goal] ),
    postprocess_why(Why0, SessionModule, Why).
query_explain(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    SessionModule:le_my_kb(KBmodule),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), KBmodule:query_info(QueryName, Goal, Items)) ->  
            ( do_log -> print_message(informational, 'Executing named query explain ~w: ~w' - [QueryName, Goal]); true),
            reasoner:explain(Goal, SessionModule, Unknowns, Why0),
            ( maplist(le_kbs:item_to_instance(KBmodule), Items, Instances), flatten(Instances, TemplateInstance) -> true; TemplateInstance = []),
            postprocess_why(Why0, SessionModule, Why)
        ; findall(D, KBmodule:le_dict(D), Dicts),
          le_grammar:prepare_templates(Dicts, Templates),
          % Find all matching templates, but separate le_is
          findall(match(G, WV, FA), (
              member(Dict, Templates),
              copy_term(Dict, dict(FA, _, WV, _)),
              \+ (FA = [le_is|_]),
              le_grammar:match_instance_to_template(Tokens, WV, [], _, Templates, true),
              G =.. FA
          ), SpecificMatches),
          (   SpecificMatches \== [] -> Matches = SpecificMatches
              ; findall(match(G, WV, FA), (
                    member(Dict, Templates),
                    copy_term(Dict, dict(FA, _, WV, _)),
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

%!  load_text(+Text:string, -Module:atom) is det.
%
%   Loads Logical English source text into a new generated Module.
load_text(Text, NewModule) :-
    (   var(NewModule) ->  
        variant_sha1(Text, Hash),
        atom_concat(m, Hash, NewModule)
        ;   
        true
    ),
    (   (current_module(NewModule), current_predicate(NewModule:le_source/3), \+ current_predicate(NewModule:le_issue/5)) -> true
        ; (   catch(parse_le_text(Text, doc(Sections)), EP, (print_message(error, EP), fail)) ->  
                % Ensure we start with a clean module
                forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
                dynamic(NewModule:le_issue/5),
                forall(member(S, Sections), process_section(S, NewModule)),
                findall(D, le_system_template(D), SysDicts),
                forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
                ( catch(le_verifier:verify(NewModule, Issues), EV, (print_message(error, EV), Issues = [])) -> 
                    forall(member(issue(Type, Desc, _Fix, Start, End), Issues), (
                        (Type == missing_template -> Severity = error; Severity = warning),
                        assertz(NewModule:le_issue(Severity, Type, Desc, Start, End))
                    ))
                ; true)
            ; print_message(error, "parse_le_text failed"),
              fail
        )
    ).


%!  postprocess_why(+WhyIn:term, +SM:atom, -WhyOut:term) is det.
postprocess_why(success(Goal0, Ref, Children), SM, success(Goal, Range, LE, ChildrenOut)) :- !,
    ( Goal0 = le_at(Goal, _, _) -> true; Goal = Goal0),
    ( SM:le_my_kb(KB) -> true; KB = none),
    ( (SM:le_source(Ref, Start, End); (KB \== none, KB:le_source(Ref, Start, End))) -> Range = range(Start, End); Range = Ref),
    ( (KB \== none, item_to_instance(KB, Goal, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    maplist(postprocess_why_child(SM), Children, ChildrenOut).
postprocess_why(failure(Goal0, Children), SM, failure(Goal, LE, ChildrenOut)) :- !,
    ( Goal0 = le_at(Goal, _, _) -> true; Goal = Goal0),
    ( SM:le_my_kb(KB) -> true; KB = none),
    ( (KB \== none, item_to_instance(KB, Goal, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    maplist(postprocess_why_child(SM), Children, ChildrenOut).
postprocess_why(Whys, SM, WhysOut) :-
    is_list(Whys), !,
    maplist(postprocess_why_child(SM), Whys, WhysOut).
postprocess_why(Other, _, Other).

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

%!  canonical_string(+Instance:list, -String:string) is det.
canonical_string(Instance, String) :-
    (   is_list(Instance) ->  
        maplist(le_kbs:token_to_atom, Instance, Atoms),
        ( maplist(var, Atoms) -> String = ""; catch(atomic_list_concat(Atoms, ' ', String), _, String = "error"))
        ;   
        le_kbs:token_to_atom(Instance, Atom),
        atom_string(Atom, String)
    ).

%!  token_to_atom(+Token:term, -Atom:atom) is det.
token_to_atom(X, Atom) :- var(X), !, Atom = '_'.
token_to_atom(var(Name, Value), Atom) :- !,
    ( nonvar(Value) -> token_to_atom(Value, Atom); token_to_atom(Name, Atom)).
token_to_atom(word(W, _), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(word(W), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(var(Words), Atom) :- !, 
    ( var(Words) -> Atom = '_'; is_list(Words) -> (maplist(token_to_atom, Words, Atoms), atomic_list_concat(Atoms, ' ', Atom)); atom_string(Atom, Words)).
token_to_atom(number(N, _), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
token_to_atom(number(N), Atom) :- !, (var(N) -> Atom = '0' ; atom_number(Atom, N)).
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

%!  item_to_instance(+KBmodule:atom, +Head:term, -WordsAndVars:list) is det.
item_to_instance(KBmodule, le_at(Goal, _, _), WordsAndVars) :- !,
    item_to_instance(KBmodule, Goal, WordsAndVars).
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


%!  get_kb_metadata(+KBModule:atom, -Metadata:dict) is det.
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
            KB:query_info(Name, _, Q),
            copy_term(Q, QCopy),
            maplist(le_kbs:item_to_instance(KB), QCopy, Instances),
            maplist(le_kbs:canonical_string, Instances, QueryStrings),
            atomic_list_concat(QueryStrings, ' and ', LEStr),
            maplist(term_string, QCopy, TermStrings),
            atomic_list_concat(TermStrings, ' and ', QueryStr)
        ), Queries)
        ;   
        Queries = []
    ),
    (   current_predicate(KB:scenario/2) ->  
        findall(_{name: Name}, KB:scenario(Name, _), Scenarios)
        ;   
        Scenarios = []
    ),
    Metadata = _{ kb: KBName, templates: Templates, queries: Queries, examples: Scenarios }.

%!  topPredicates(+KBmodule:atom, -TopPredicates:list) is det.
%
%   Returns a list of templates for the top-level predicates of the given KB module.
%   A top-level predicate is one defined by a rule but not used by other rules.
topPredicates(KB, TopPreds) :-
    findall(F/A, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
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

%!  kbSummary(+KBmodule:atom, -Summary:string) is det.
%
%   Returns a summary of the KB, including its name and top-level predicates.
kbSummary(KB, Summary) :-
    (current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true ; KBName = KB),
    topPredicates(KB, TopPreds),
    atomic_list_concat(TopPreds, '; ', PredsStr),
    format(string(Summary), "KB: ~w. Top predicates: ~w", [KBName, PredsStr]).

%!  parse_custom_facts(+KB:atom, +Text:string, -Terms:list) is semidet.
%
%   Parses a string of Logical English facts/rules using the templates of the given KB.
%   Fails if any fact or rule head does not match a template.
parse_custom_facts(KB, Text, Terms) :-
    tokenize(Text, Tokens),
    le_grammar:set_token_pos(0),
    ( phrase(le_grammar:kb_items(Items), Tokens) -> true ; Items = [] ),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    maplist(le_grammar:second_pass_item(Templates), Items, Clauses),
    (   member(clause(unknown_template(Head), _, _, _), Clauses) ->
        le_kbs:canonical_string(Head, HeadStr),
        format(string(Error), "Fact does not match any template: ~w", [HeadStr]),
        throw(error(le_parse_error(Error), _))
    ;   findall(Term, (member(clause(Head, Body, _, _), Clauses), (Body == true -> Term = Head; Term = (Head :- Body))), Terms)
    ).

%!  parse_custom_query(+KB:atom, +Text:string, -Goal:term) is semidet.
%
%   Parses a string of Logical English as a query goal using the templates of the given KB.
%   Throws an error if the query does not match any template.
parse_custom_query(KB, Text, Goal) :-
    tokenize(Text, Tokens),
    le_grammar:set_token_pos(0),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    (   le_grammar:parse_literal(Tokens, Templates, [], _VM, Goal, true) -> true
    ;   format(string(Error), "Query does not match any template: ~w", [Text]),
        throw(error(le_parse_error(Error), _))
    ).

is_system_predicate(le_kb/1).
is_system_predicate(le_source/3).
is_system_predicate(scenario/2).
is_system_predicate(le_expected/3).
is_system_predicate(query_info/3).
is_system_predicate(ontology/1).
is_system_predicate(le_dict/1).
is_system_predicate(unknown_template/1).
is_system_predicate(le_issue/5).
is_system_predicate(le_my_kb/1).
is_system_predicate(le_neg/1).
is_system_predicate(sessionClause/1).

is_expected_item(expected(_, _, _, _)).

verify(LEfilePath) :-
    uuid(UUID), atom_concat(v, UUID, KBmodule),
    parse_le_file(LEfilePath, doc(Sections)),
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

item_to_term(clause(Head, true, _, _), Head) :- !.
item_to_term(clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Item, Item).

item_to_term_with_source(_M, clause(Head, true, Start, End), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, clause(Head, Body, _Start, _End), (Head :- Body)) :- 
    % Rules in scenarios are rare but possible; we don't track their source yet
    !.
item_to_term_with_source(_, Item, Item).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

normalize_string(S, N) :-
    re_replace("_"/g, " ", S, N1), re_replace("-"/g, " ", N1, N2),
    re_replace("  +"/g, " ", N2, N).

run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings), Result) :-
    createSession(KBmodule, SM),
    (   setScenarion(SM, ScenarioName) ->  
        (   ((KBmodule:query_info(QueryName, FullGoal, Items) ; (normalize_string(QueryName, NormName), KBmodule:query_info(InfoName, FullGoal, Items), normalize_string(InfoName, NormName)))) ->  
            (   catch(call_with_time_limit(30, findall(S, (reasoner:i(FullGoal, SM, [], _), maplist(le_kbs:item_to_instance(KBmodule), Items, Instances), flatten(Instances, TemplateInstance), le_kbs:canonical_string(TemplateInstance, Atom), atom_string(Atom, S)), ActualStrings)), time_limit_exceeded, (ActualStrings = timeout)) ->  
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
                            Result = fail(QueryName, ScenarioName, SortedExpected, SortedActual)
                        )
                    )
                ; Result = error(QueryName, ScenarioName, 'Test execution failed')
            )
            ;   
            Result = error(QueryName, ScenarioName, 'Query not found')
        )
        ;   
        Result = error(QueryName, ScenarioName, 'Scenario not found')
    ),
    clearSession(SM).

read_tests(Stream, Tests) :-
    read(Stream, Term),
    ( Term == end_of_file -> Tests = []; Term = expected(Q, S, E) -> Tests = [test(Q, S, E)|Rest], read_tests(Stream, Rest); read_tests(Stream, Tests)).

runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(LEFile, (member(F, Files), sub_atom(F, _, _, 0, '.le'), \+ sub_atom(F, _, _, 0, '.le.tests'), directory_file_path(Dir, F, LEFile)), LEFiles),
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

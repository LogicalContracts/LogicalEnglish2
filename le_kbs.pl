:- module(le_kbs, [load/2, createSection/2, addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1]).
:- use_module(le_grammar).
:- use_module(library(uuid)).

load(FilePath, NewModule) :-
    time_file(FilePath, Time),
    variant_sha1([FilePath, Time], Hash),
    atom_concat(m, Hash, NewModule),
    parse_le_file(FilePath, doc(Sections)),
    forall(member(S, Sections), process_section(S, NewModule)).

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
    assertz(M:query(Name, Goal), Ref),
    assertz(M:le_source(Ref, Start, End)).

process_section(ontology(Content, Start, End), M) :-
    assertz(M:ontology(Content), Ref),
    assertz(M:le_source(Ref, Start, End)),
    forall(member(Item, Content), process_item(Item, M)).

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

createSection(KBmodule, SessionModule) :-
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    assertz(SessionModule:le_my_kb(KBmodule)).

addSessionFact(SessionModule, Fact) :-
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
           (H \= sessionClause(_), format('  ~w :- ~w~n', [H, B]))).

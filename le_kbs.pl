:- module(le_kbs, [load/2]).
:- use_module(le_grammar).

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

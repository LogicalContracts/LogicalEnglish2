% A plain Prolog program: the test bed of the Prolog -> LE path
% (InsurLE2/docs/migration/roadmap.md §5.7). Translated by
% le_writer:prolog_file_to_ir/3; its answers must equal Prolog's own.

parent(alice, bob).
parent(bob, carol).
parent(bob, dave).
parent(carol, eve).

ancestor(Ancestor, Descendant) :- parent(Ancestor, Descendant).
ancestor(Ancestor, Descendant) :- parent(Ancestor, Child), ancestor(Child, Descendant).

sibling(Person, Other) :- parent(Parent, Person), parent(Parent, Other), Person \= Other.

childless(Person) :- person(Person), \+ parent(Person, _).

person(alice). person(bob). person(carol). person(dave). person(eve).

age(alice, 80). age(bob, 55). age(carol, 30). age(dave, 28). age(eve, 3).

adult(Person) :- age(Person, Years), Years >= 18.

grandparent_age_gap(Grandparent, Grandchild, Gap) :-
    parent(Grandparent, Middle), parent(Middle, Grandchild),
    age(Grandparent, A1), age(Grandchild, A2),
    Gap is A1 - A2.

children_count(Person, Count) :-
    person(Person),
    aggregate_all(count, parent(Person, _), Count).

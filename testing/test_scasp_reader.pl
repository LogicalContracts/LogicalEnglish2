/** <module> The s(CASP) reader (le_writer:prolog_to_ir/3) and its round trip

    A sample of testing/scasp_roundtrip.pl (the whole corpus takes a
    minute): LE -> s(CASP) -> LE -> s(CASP) gives the same clauses for
    programs with opposites, universals, synonyms, ontology types and
    abducibles; and the reader's s(CASP) specifics one by one.

    Run with:  swipl -q -g run_tests -t halt testing/test_scasp_reader.pl
*/

:- module(test_scasp_reader, []).

:- use_module(library(plunit)).
:- use_module('../le_writer').

:- if(exists_source(library(scasp))).
:- use_module('scasp_roundtrip').

:- begin_tests(scasp_round_trip).

test(sample_round_trips, [forall(member(F, ['examples/moreExamples/citizenship.le',
                                             'examples/moreExamples/only_if.le',
                                             'examples/moreExamples/flying_dragon.le',
                                             'examples/moreExamples/synonyms.le',
                                             'examples/moreExamples/rkBook/amazing_animals.le',
                                             'examples/moreExamples/abduction/loan_approval.le',
                                             'examples/es/ciudadania.le']))]) :-
    scasp_roundtrip:roundtrip_file(F, O),
    assertion(O == same).

:- end_tests(scasp_round_trip).
:- endif.

:- begin_tests(scasp_reader).

scasp_ir(Text, IR) :-
    tmp_file_stream(text, F, S), write(S, Text), close(S),
    prolog_file_to_ir(F, [kb(t)], IR), delete_file(F).

test(classical_negation_is_an_opposite) :-
    scasp_ir("#pred flies(X) :: '@(X) can fly'.\n#pred -flies(X) :: '@(X) can not fly'.\nflies(tweety).\n-flies(X) :- penguin(X).\npenguin(sam).\n", program(H, Items)),
    assertion(memberchk(target(scasp), H)),
    assertion(( member(template(flies/1, _, Adds), Items), memberchk(opposite('*a thing* can not fly'), Adds) )),
    assertion(( member(rule(H1, _, _), Items), functor(H1, can_not_fly, 1) )).

test(abducibles_are_assumable) :-
    scasp_ir("#abducible rain.\nwet :- rain.\n", program(_, Items)),
    assertion(( member(template(rain/0, _, Adds), Items), memberchk(assumable, Adds) )).

test(denials_are_constraints) :-
    scasp_ir("p(a).\nq(a).\n:- p(X), q(X).\n", program(_, Items)),
    assertion(( member(constraint(B, _), Items), B = and(p(X), q(Y)), X == Y )).

test(clp_comparisons) :-
    scasp_ir("big(X) :- size(X, S), S #> 10.\nsize(a, 20).\n", program(_, Items)),
    assertion(( member(rule(big(_), B, _), Items), sub_term(le_gt(_, 10), B) )).

test(list_patterns_are_residue) :-
    scasp_ir("first([H|_], H).\n", program(_, Items)),
    assertion(( member(residue(_, O), Items), memberchk(title(_), O) )).

test(typed_placeholders_name_places) :-
    scasp_ir("#pred parent(A, B) :: '@(A:person) is a parent of @(B:person)'.\nparent(bob, alice).\n", program(_, Items)),
    assertion(memberchk(template(parent/2, '*a person* is a parent of *a person*', _), Items)).

:- end_tests(scasp_reader).

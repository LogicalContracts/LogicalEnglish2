/** <module> Old example names keep resolving (le_kbs:example_alias/2)

    When examples are regrouped (docs/NewExamplesStructure.md), the names
    they had — in links, QR codes, papers, videos — are kept in
    example_alias/2 and example_dir_alias/2. Every alias must lead to a
    file that exists, and resolution must go through them.

    Run with:  swipl -q -g run_tests -t halt testing/test_example_alias.pl
*/

:- module(test_example_alias, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

:- begin_tests(example_alias).

test(every_alias_leads_to_a_file, [forall(le_kbs:example_alias(Old, _))]) :-
    le_example_relpath(Old, Path0),
    atom_concat(Path0, '.le', Path),
    assertion(exists_file(Path)).

test(every_directory_alias_leads_to_a_directory, [forall(le_kbs:example_dir_alias(_, New))]) :-
    (   le_kbs:le_extra_examples_dir(New, Dir) -> true
    ;   le_example_relpath(New, Dir)
    ),
    assertion(exists_directory(Dir)).

test(old_directory_names_resolve) :-
    le_example_relpath('RulesRus/flip_housing', P1),
    assertion(P1 == 'examples/regulatory/flip_housing'),
    le_example_relpath('testing/nonterminating', P2),
    assertion(P2 == 'testing/fixtures/le/nonterminating'),
    le_example_relpath('tax/payg.le', P3),
    assertion(exists_file(P3)).

test(an_alias_is_not_an_existing_name, [forall(le_kbs:example_alias(Old, _))]) :-
    le_kbs:le_examples_dir(Main),
    atomic_list_concat([Main, '/', Old, '.le'], Stale),
    assertion(\+ exists_file(Stale)).

test(old_name_resolves_to_new_path) :-
    le_example_relpath(sum_onto, P1),
    assertion(P1 == 'examples/moreExamples/language/aggregates/sums'),
    le_example_relpath('sum_onto.le', P2),
    assertion(P2 == 'examples/moreExamples/language/aggregates/sums.le').

test(current_names_are_unchanged) :-
    le_example_relpath(citizenship, P1),
    assertion(P1 == 'examples/moreExamples/citizenship'),
    le_example_relpath('regulatory/precedent', P2),
    assertion(P2 == 'examples/regulatory/precedent'),
    le_example_relpath('pt/cidadania', P3),
    assertion(P3 == 'examples/pt/cidadania').

:- end_tests(example_alias).

/** <module> Scenario-element regression tests (es/conjuntos.le)

    Pins the two server-side fixes behind "scenarios broken for
    es/conjuntos.le" (2026-07-17):
    - a scenario fact STARTING with a list value ("[Alicia, Roberto] es un
      conjunto.") keeps its source range — the list template-instance part
      used to carry no location, so such facts got Start = 0 ("no source")
      and were dropped from the Proof Game board;
    - a scenario RULE ("una cosa pertenece a un conjunto si prolog
      member(...)") becomes a Proof Game rule card — extraction previously
      only scanned the KB module, never the session's scenario elements.

    Run with:  swipl -q -g run_tests -t halt testing/test_scenario_multilingual.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_scenario_multilingual, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_proof_game').

:- begin_tests(scenario_multilingual).

test(list_initial_facts_keep_source_ranges) :-
    le_kbs:load('examples/es/conjuntos.le', KB),
    KB:scenario(listas, Items),
    Items \== [],
    forall(member(fact_with_source(_, Start, End), Items),
           ( Start > 0, End > Start )).

test(scenario_facts_and_rules_become_game_cards) :-
    le_kbs:load('examples/es/conjuntos.le', KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, listas),
          le_proof_game:extract_rules_and_facts(KB, SM, es_un_subconjunto_de(_, _), Rules, Facts, _),
          % the scenario's two list facts appear as fact cards...
          length(Facts, 2),
          % ...and its own rule as a rule card, alongside the KB rule.
          length(Rules, 2)
        ),
        le_kbs:destroySession(SM)).

% The session scans above must only touch the session's OWN clauses:
% current_predicate(SM:F/N) also enumerates le_kbs predicates once SM's import
% table has resolved them (which depends on request history), and clause/3 on
% an imported static procedure throws permission_error — seen as "Could not
% open the Proof Game" for ordinary examples. Resolve an import first, then
% extract: it must neither throw nor lose the scenario's cards.
test(extraction_survives_resolved_imports) :-
    le_kbs:load('examples/moreExamples/citizenship.le', KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, alice),
          SM:le_examples_dir(_),
          le_proof_game:extract_rules_and_facts(KB, SM, is_a(_, _), Rules, Facts, _),
          Rules \== [],
          Facts \== []
        ),
        le_kbs:destroySession(SM)).

:- end_tests(scenario_multilingual).

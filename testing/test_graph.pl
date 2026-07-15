/** <module> Tests for the Source Graph generator (le_graph.pl).

    Pins down that bookkeeping clauses stay out of the graph — notably the
    expected-answer test records ("expects answers" scenario items compile to
    le_expected/4, which used to leak into the graph as bogus fact nodes
    because the exclusion guard only matched le_expected/3) — while all the
    substantive layers (templates, rules, facts, scenarios, queries) remain.

    Run with:  swipl -q -g run_tests -t halt testing/test_graph.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_graph, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_graph').

citizenship_graph(Nodes) :-
    le_kbs:load('examples/moreExamples/citizenship.le', KB),
    le_graph:kb_graph(KB, G),
    get_dict(nodes, G, Nodes).

node_label(N, L) :-
    get_dict(data, N, D),
    get_dict(label, D, L0),
    term_to_atom(L0, L).

:- begin_tests(source_graph).

% le_expected/N records are bookkeeping, not knowledge: no node shows them.
test(no_le_expected_nodes) :-
    citizenship_graph(Nodes),
    forall(( member(N, Nodes), node_label(N, L) ),
           \+ sub_atom(L, _, _, _, le_expected)).

% The substantive layers are all present.
test(graph_has_all_layers) :-
    citizenship_graph(Nodes),
    findall(T, ( member(N, Nodes), get_dict(data, N, D), get_dict(type, D, T) ), Ts0),
    sort(Ts0, Ts),
    forall(member(Expected, ["template", "rule", "fact", "scenario", "query"]),
           assertion(memberchk(Expected, Ts))).

:- end_tests(source_graph).

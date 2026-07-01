/** <module> Unit tests for the "strongest reason" explanation summary.

    strongest_reason/2 (classic_web_api.pl) picks the explanation node whose subtree
    weight — its descendant-node count (1 + sum of children) — is closest to half the
    whole tree's weight W, breaking ties toward the larger subtree. It returns that
    node's literal, or "" when there is no explanation.

    Run with:  swipl -g run_tests -t halt testing/test_strongest_reason.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_strongest_reason, []).

:- use_module(library(plunit)).
:- use_module('../classic_web_api').

leaf(Lit, _{literal:Lit, children:[]}).
node(Lit, Children, _{literal:Lit, children:Children}).
% A node carrying a source range, so it can be tied to a rule via le_source_info.
node_at(Lit, S, E, Children, _{literal:Lit, start:S, end:E, children:Children}).

% No KB (none) => no node is transparent (every node keeps its intrinsic weight).
:- begin_tests(strongest_reason).

test(empty_tree_no_reason) :-
    classic_web_api:strongest_reason([], none, R, _),
    assertion(R == "").

test(single_node_is_its_own_reason) :-
    leaf("solo", T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "solo").

test(node_closest_to_half_wins) :-
    % root(5) -> a(3){a1,a2}, b(1). W=5, half=2.5; a (weight 3) is closest. Its tree
    % path (root "1" -> first child "1.1") is returned for the client to reveal.
    leaf("a1", A1), leaf("a2", A2), leaf("b", B),
    node("a", [A1, A2], A),
    node("root", [A, B], T),
    classic_web_api:strongest_reason(T, none, R, P),
    assertion(R == "a"),
    assertion(P == "1.1").

test(forest_total_is_all_nodes) :-
    % roots r1(3){x,y} and r2(1): W=4, half=2. All nodes tie on distance, so the
    % larger subtree (r1) wins.
    leaf("x", X), leaf("y", Y), leaf("r2", R2),
    node("r1", [X, Y], R1),
    classic_web_api:strongest_reason([R1, R2], none, R, _),
    assertion(R == "r1").

test(tie_breaks_to_larger_subtree) :-
    % root(3){c1,c2}: leaves (weight 1) beat the root (weight 3) for half=1.5; the two
    % equal leaves tie and resolve deterministically (by literal order) to c1.
    leaf("c1", C1), leaf("c2", C2),
    node("root", [C1, C2], T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "c1").

test(failure_node_gets_negation_prefix) :-
    % A chosen failure node reads as "it is not the case that <literal>".
    T = _{literal:"bob smokes", type:"failure", children:[]},
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "it is not the case that bob smokes").

test(failed_naf_node_drops_its_prefix) :-
    % A failed NAF node already reads "it is not the case that X"; negating it strips
    % the phrase back to "X" rather than double-prefixing.
    T = _{literal:"it is not the case that bob smokes", type:"failure", children:[]},
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "bob smokes").

:- end_tests(strongest_reason).

% With a KB, a node whose source range names an AUTO-generated rule is transparent
% (no intrinsic weight, never the strongest reason); an explicitly named rule counts.
:- begin_tests(strongest_reason_transparency).

% A tree where the auto-named rule node "M" (range 10-20) sits at ~half the weight:
%   root "R" (named rule, 30-40) -> [ M(auto rule,10-20) -> [m1,m2], x1, x2 ]
% Weights (M transparent): m1=m2=x1=x2=1, M=2 (no +1), R=1+2+1+1=5. W=5.
tree(T) :-
    leaf("m1", M1), leaf("m2", M2), leaf("x1", X1), leaf("x2", X2),
    node_at("M-auto", 10, 20, [M1, M2], M),
    node_at("R-named", 30, 40, [M, X1, X2], T).

test(auto_named_rule_node_is_transparent, [setup(setup_kb), cleanup(cleanup_kb)]) :-
    tree(T),
    classic_web_api:strongest_reason(T, tkb, R, _),
    % M would be closest to W/2 but is transparent, so it is never chosen.
    assertion(R \== "M-auto"),
    assertion(memberchk(R, ["m1", "m2", "x1", "x2"])).

test(without_kb_the_same_node_would_win) :-
    % Contrast: treated as an ordinary node (no KB), M IS the strongest reason.
    tree(T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "M-auto").

setup_kb :-
    assertz(tkb:le_source_info(r_auto, 10, 20, 'rule_10')),   % auto-generated id
    assertz(tkb:le_source_info(r_named, 30, 40, myrule)).      % explicit name
cleanup_kb :-
    retractall(tkb:le_source_info(_, _, _, _)).

:- end_tests(strongest_reason_transparency).

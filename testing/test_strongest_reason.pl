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

test(weightier_internal_node_beats_leaves) :-
    % Like citizenship trust_harry: a root with four children, one of which is derived
    % (weight 2). That weightier internal node — not a leaf — is the important reason.
    leaf("l1", L1), leaf("l2", L2), leaf("l3", L3), leaf("says", Says),
    node("Harry is the father of John", [Says], Father),   % weight 2
    node("root", [L1, L2, Father, L3], T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "Harry is the father of John").

:- end_tests(strongest_reason).

% A "failed clause attempt" node (marked `ruleAttempt` — one per clause whose head
% matched a failed goal) is transparent: no intrinsic weight, never the strongest reason.
:- begin_tests(strongest_reason_transparency).

ra_node(Lit, Children, _{literal:Lit, type:"failure", ruleAttempt:true, children:Children}).

% root "R" -> [ M (a failed clause-attempt over [m1,m2]), x1, x2 ]. With M transparent
% its weight is 2 (no +1) and it is not a candidate.
tree(T) :-
    leaf("m1", M1), leaf("m2", M2), leaf("x1", X1), leaf("x2", X2),
    ra_node("rule-attempt", [M1, M2], M),
    node("R", [M, X1, X2], T).

test(rule_attempt_node_is_transparent) :-
    tree(T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R \== "rule-attempt"),
    assertion(memberchk(R, ["m1", "m2", "x1", "x2"])).

test(without_the_marker_the_node_would_win) :-
    % Same shape but M is an ordinary node (weight 3) — it IS the important reason.
    leaf("m1", M1), leaf("m2", M2), leaf("x1", X1), leaf("x2", X2),
    node("plain", [M1, M2], M),
    node("R", [M, X1, X2], T),
    classic_web_api:strongest_reason(T, none, R, _),
    assertion(R == "plain").

:- end_tests(strongest_reason_transparency).

% The Explanation Drill state machine: repeatedly ask about the strongest reason within
% TOP (ignoring UNDERSTOOD), "yes" removes it, "not yet" descends into it.
:- begin_tests(explanation_drill).

% root(7): a(3){a1,a2}, b(1), c(2){c1}.
dtree(_{literal:"root", children:[
    _{literal:"a", children:[_{literal:"a1",children:[]}, _{literal:"a2",children:[]}]},
    _{literal:"b", children:[]},
    _{literal:"c", children:[_{literal:"c1",children:[]}]}]}).

pending_path(Answers, Path) :-
    dtree(T),
    classic_web_api:drill_loop(none, T, Answers, "", [], [], _Qs, _Top, _Und, Pending),
    ( Pending == null -> Path = done ; get_dict(path, Pending, Path) ).

test(first_question_is_strongest) :- pending_path([], P), assertion(P == "1.1").
test(yes_moves_to_next_region) :- pending_path(["yes"], P), assertion(P == "1.3").
test(not_yet_descends_into_node) :- pending_path(["not_yet"], P), assertion(P == "1.1.1").
test(all_understood_terminates) :- pending_path(["yes","yes","yes"], P), assertion(P == done).

test(understood_and_questions_tracked) :-
    dtree(T),
    classic_web_api:drill_loop(none, T, ["not_yet","yes"], "", [], [], Qs, Top, Und, _P),
    % Descended into "a" (1.1), then understood "a1" (1.1.1).
    assertion(Top == "1.1"),
    assertion(Und == ["1.1.1"]),
    maplist([Q,P]>>get_dict(path, Q, P), Qs, Paths),
    assertion(Paths == ["1.1", "1.1.1"]).

:- end_tests(explanation_drill).

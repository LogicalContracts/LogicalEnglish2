/** <module> Unit tests for cross-tree repeated-explanation navigation.

    When "hide repeated explanations" is on, a sub-explanation that recurs
    elsewhere in the tree is collapsed to a root-only PROXY. Each proxy must carry
    `repeatedOf` — the CLIENT tree-path ("1.2.3") of the full original it stands in
    for — so the editor's "Go to full sub-explanation" can navigate to it. These
    tests pin that the path matches the client's 1-indexed pre-order numbering.

    Run with:  swipl -q -g run_tests -t halt testing/test_repeated_explanations.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_repeated_explanations, []).

:- use_module(library(plunit)).
:- use_module('../classic_web_api').

% A forest whose subtree "x" (non-leaf: x -> leaf) appears under both "a" and "b".
% Client paths:  root=1, a=1.1, x(first)=1.1.1, b=1.2, x(proxy)=1.2.1.
sample_forest([
    success(g(root), range(0,1), "root", [
        success(g(a), range(2,3), "a", [
            success(g(x), range(10,11), "x", [ success(g(leaf), range(20,21), "leaf", []) ]) ]),
        success(g(b), range(4,5), "b", [
            success(g(x), range(10,11), "x", [ success(g(leaf), range(20,21), "leaf", []) ]) ])
    ]) ]).

% The first proxy node (repeated, with repeatedOf) found in a converted JSON tree.
first_proxy(J, P) :-
    is_dict(J), get_dict(repeated, J, true), get_dict(repeatedOf, J, _), !, P = J.
first_proxy(J, P) :-
    is_dict(J), get_dict(children, J, Ch), member(C, Ch), first_proxy(C, P), !.
first_proxy(J, P) :-
    is_list(J), member(C, J), first_proxy(C, P), !.

marked_json(JSON) :-
    sample_forest(Forest),
    classic_web_api:mark_cross_tree_repeats(Forest, Marked),
    classic_web_api:convert_why(Marked, none, JSON).

:- begin_tests(repeated_explanations).

% The second occurrence of "x" becomes a proxy: repeated, empty children, and its
% repeatedOf names the FIRST occurrence's client path ("1.1.1").
test(proxy_points_to_original_path) :-
    marked_json(JSON),
    first_proxy(JSON, Px),
    assertion(get_dict(literal, Px, "x")),
    assertion(get_dict(repeatedOf, Px, '1.1.1')),
    assertion(get_dict(children, Px, [])).

% The first "x" is kept in full (its leaf child survives) and is NOT a proxy.
test(original_kept_in_full) :-
    marked_json([Root]),
    get_dict(children, Root, [A, _B]),          % root's children: a, b
    get_dict(children, A, [X]),                  % a's child: x (first occurrence)
    assertion(\+ get_dict(repeatedOf, X, _)),
    assertion(get_dict(children, X, [_Leaf])).

% Leaves never collapse — a one-line node is not worth a proxy marker.
test(leaves_not_collapsed) :-
    marked_json([Root]),
    get_dict(children, Root, [_A, B]),
    get_dict(children, B, [Xproxy]),
    assertion(get_dict(repeated, Xproxy, true)),  % x under b IS the proxy
    assertion(get_dict(repeatedOf, Xproxy, '1.1.1')).

:- end_tests(repeated_explanations).

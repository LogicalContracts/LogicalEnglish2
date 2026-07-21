/** <module> "Important reason" special case for FAILED queries

    For a query with zero answers, the important reason (strongestReason) is drawn
    from the LEAF failure nodes — the terminal failed conditions reached by
    descending only through FAILED (zero-answer) nodes; success / choice-point
    subtrees are not entered. With the "larger important reasons" preference the
    reason lists all such leaves ("it is not the case that X, nor that Y, nor that Z",
    truncated after the third); otherwise it is the single deepest leaf (ties
    broken by pre-order). Only when the tree has no failure node does it fall back
    to the weight-based heuristic. See important_reason_failed/4 in classic_web_api.pl.

    Run with:  swipl -q -g run_tests -t halt testing/test_important_reason.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_important_reason, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../classic_web_api').

% failed_query_reason(+Program, +Scenario, +Query, -Reason, -Path)
failed_query_reason(Program, Scenario, Query, Reason, Path) :-
    le_kbs:load_text(Program, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, Scenario),
          classic_web_api:run_answering_query(SM, Query, KB, Response),
          get_dict(results, Response, []),                 % zero answers (failed)
          get_dict(strongestReason, Response, Reason),
          get_dict(strongestReasonPath, Response, Path)
        ),
        le_kbs:destroySession(SM)).

:- begin_tests(important_reason).

% A straight chain good <- ok <- fine <- great: the deepest failure ("great") is
% the important reason, at the deepest path.
chain_prog("the target language is: prolog.
the templates are:
    *a thing* is good,
    *a thing* is ok,
    *a thing* is fine,
    *a thing* is great.
the knowledge base k includes:
    a thing is good if the thing is ok.
    a thing is ok if the thing is fine.
    a thing is fine if the thing is great.
scenario s is:
    widget is a thing.
query q is:
    widget is good.").

test(deepest_failure_is_the_reason) :-
    chain_prog(P),
    failed_query_reason(P, s, q, Reason, Path),
    assertion(sub_atom_icasechk(Reason, _, "great")),
    assertion(Path == "1.1.1.1").

% Two rules for good, each with its own one-step failure: two failures share the
% deepest level; the FIRST one in rendered order (alpha, from the first rule) wins.
tie_prog("the target language is: prolog.
the templates are:
    *a thing* is good,
    *a thing* is ok,
    *a thing* is nice,
    *a thing* is alpha,
    *a thing* is beta.
the knowledge base k includes:
    a thing is good if the thing is ok.
    a thing is ok if the thing is alpha.
    a thing is good if the thing is nice.
    a thing is nice if the thing is beta.
scenario s is:
    widget is a thing.
query q is:
    widget is good.").

test(tie_breaks_to_first_in_render_order) :-
    tie_prog(P),
    failed_query_reason(P, s, q, Reason, _Path),
    assertion(sub_atom_icasechk(Reason, _, "alpha")),
    assertion(\+ sub_atom_icasechk(Reason, _, "beta")).

% Type-restriction guard nodes (typeCheck, rendered "X is a Type") are excluded
% from the candidate set: a DEEPER guard failure must not beat a shallower
% substantive failure. Here the deepest node overall is a typeCheck guard (depth
% 2); the important reason is instead the first substantive failure at depth 1.
test(type_guard_nodes_are_excluded) :-
    Tree = _{type: "failure", literal: "the query fails", children: [
        _{type: "failure", literal: "a shallow reason", children: []},
        _{type: "failure", literal: "a wrapper", children: [
            _{type: "failure", literal: "x is a payment", typeCheck: true, children: []}
        ]}
    ]},
    classic_web_api:important_reason_failed(Tree, false, Reason, Path),
    assertion(sub_atom_icasechk(Reason, _, "shallow reason")),
    assertion(\+ sub_atom_icasechk(Reason, _, "payment")),
    assertion(Path == "1.1").

% The per-rule "rule: <head>" wrapper nodes (present only when the user enabled
% "Detailed failure explanations") must not change the chosen reason. They are
% depth-transparent: the same substantive failure wins whether or not the tree is
% wrapped, even when the wrappers nest the shallow branch more deeply.
test(rule_attempt_wrappers_are_depth_transparent) :-
    Plain = _{type: "failure", literal: "query fails", children: [
        _{type: "failure", literal: "chain", children: [
            _{type: "failure", literal: "the real reason", children: []}
        ]},
        _{type: "failure", literal: "a shallow one", children: []}
    ]},
    Detailed = _{type: "failure", literal: "query fails", children: [
        _{type: "failure", ruleAttempt: true, literal: "rule A", children: [
            _{type: "failure", literal: "chain", children: [
                _{type: "failure", literal: "the real reason", children: []}
            ]}
        ]},
        _{type: "failure", ruleAttempt: true, literal: "rule B", children: [
            _{type: "failure", ruleAttempt: true, literal: "rule C", children: [
                _{type: "failure", ruleAttempt: true, literal: "rule D", children: [
                    _{type: "failure", literal: "a shallow one", children: []}
                ]}
            ]}
        ]}
    ]},
    classic_web_api:important_reason_failed(Plain, false, RP, _),
    classic_web_api:important_reason_failed(Detailed, false, RD, _),
    assertion(sub_atom_icasechk(RP, _, "the real reason")),
    assertion(RP == RD).

% "Larger important reasons": all deepest failures are listed, joined with
% ", nor that ", truncated after the third (with a trailing "…"). Without the flag,
% only the first is returned.
four_deepest_tree(_{type: "failure", literal: "the query fails", children: [
    _{type: "failure", literal: "a is missing", children: []},
    _{type: "failure", literal: "b is missing", children: []},
    _{type: "failure", literal: "c is missing", children: []},
    _{type: "failure", literal: "d is missing", children: []}
]}).

test(larger_reasons_lists_up_to_three_deepest) :-
    four_deepest_tree(Tree),
    classic_web_api:important_reason_failed(Tree, true, Reason, Path),
    assertion(sub_atom_icasechk(Reason, _, "it is not the case that a is missing")),
    assertion(sub_atom_icasechk(Reason, _, "nor that b is missing")),
    assertion(sub_atom_icasechk(Reason, _, "nor that c is missing")),
    assertion(\+ sub_atom_icasechk(Reason, _, "d is missing")),   % truncated after the third
    assertion(sub_atom(Reason, _, _, _, "…")),                    % truncation marker
    assertion(Path == "1.1").                                     % first deepest node's path

test(single_reason_uses_only_the_first) :-
    four_deepest_tree(Tree),
    classic_web_api:important_reason_failed(Tree, false, Reason, _),
    assertion(sub_atom_icasechk(Reason, _, "a is missing")),
    assertion(\+ sub_atom_icasechk(Reason, _, "b is missing")).

% With three or fewer deepest failures, no truncation marker is added.
test(larger_reasons_no_truncation_when_three) :-
    Tree = _{type: "failure", literal: "the query fails", children: [
        _{type: "failure", literal: "a is missing", children: []},
        _{type: "failure", literal: "b is missing", children: []},
        _{type: "failure", literal: "c is missing", children: []}
    ]},
    classic_web_api:important_reason_failed(Tree, true, Reason, _),
    assertion(sub_atom_icasechk(Reason, _, "nor that c is missing")),
    assertion(\+ sub_atom(Reason, _, _, _, "…")).

% Candidates are the LEAF failures reached through FAILED nodes only. A failure
% under a SUCCESS (choice-point) node is an exhausted alternative of a goal that
% DID succeed, so it is not a reason. Leaves at different depths are both kept;
% an ancestor of a kept leaf is not itself listed.
success_subtree_tree(_{type: "failure", literal: "top fails", children: [
    _{type: "success", literal: "a choice point", children: [
        _{type: "failure", literal: "an exhausted alternative", children: []}
    ]},
    _{type: "failure", literal: "a failing rule", children: [
        _{type: "failure", literal: "the shallow condition", children: []},
        _{type: "failure", literal: "the mid condition", children: [
            _{type: "failure", literal: "the deep condition", children: []}
        ]}
    ]}
]}).

test(larger_reasons_span_depths_and_skip_success_subtrees) :-
    success_subtree_tree(Tree),
    classic_web_api:important_reason_failed(Tree, true, Reason, _),
    assertion(sub_atom_icasechk(Reason, _, "the shallow condition")),   % depth-2 leaf
    assertion(sub_atom_icasechk(Reason, _, "nor that the deep condition")),  % depth-3 leaf
    assertion(\+ sub_atom_icasechk(Reason, _, "exhausted")),            % under SUCCESS — skipped
    assertion(\+ sub_atom_icasechk(Reason, _, "mid condition")).        % ancestor of a leaf — not listed

test(single_reason_is_the_deepest_leaf_skipping_success) :-
    success_subtree_tree(Tree),
    classic_web_api:important_reason_failed(Tree, false, Reason, _),
    assertion(sub_atom_icasechk(Reason, _, "the deep condition")),
    assertion(\+ sub_atom_icasechk(Reason, _, "shallow condition")),
    assertion(\+ sub_atom_icasechk(Reason, _, "exhausted")).

:- end_tests(important_reason).

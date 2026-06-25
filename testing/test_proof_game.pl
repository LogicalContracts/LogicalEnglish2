/** <module> Unit tests for the Proof Game's rule rendering (le_proof_game.pl).

    Pins down that a rule's explicit source variable identifiers (e.g. X) are
    shown in the game's rule nodes, and that coreferent occurrences of the same
    variable share a single id (so the game can link them). Uses the bundled
    examples/moreExamples/alice.le, whose rule

        Alice is happy if
            Alice likes a thing X
            and X likes Alice.

    must render the body condition as "Alice likes a thing X" (not "a thing").

    Run with:  swipl -g run_tests -t halt testing/test_proof_game.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_proof_game, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_proof_game').

% The "Alice is happy" rule node extracted for the `happy` query.
happy_rule(Rule) :-
    le_kbs:load('examples/moreExamples/alice.le', KB),
    le_kbs:createSession(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = happy(_) ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, _Facts, _QT),
    member(Rule, Rules),
    get_dict(head, Rule, "Alice is happy"),
    !.

% The variable tokens of a rendered condition (only var tokens carry an id).
var_tokens(Tokens, Vars) :-
    findall(Tok, (member(Tok, Tokens), get_dict(id, Tok, _)), Vars).

:- begin_tests(proof_game_var_names).

% The named variable X is shown in the rule's body rendering.
test(named_variable_is_shown) :-
    happy_rule(Rule),
    get_dict(bodyTokens, Rule, [Cond0 | _]),   % "Alice likes a thing X"
    var_tokens(Cond0, [V | _]),
    assertion(get_dict(name, V, 'X')),
    assertion(get_dict(text, V, 'a thing X')).

% Both body conditions mention the same variable X, so its two tokens share an id.
test(coreferent_variables_share_id) :-
    happy_rule(Rule),
    get_dict(bodyTokens, Rule, [Cond0, Cond1]),
    var_tokens(Cond0, [V0 | _]),
    var_tokens(Cond1, [V1 | _]),
    get_dict(id, V0, Id0),
    get_dict(id, V1, Id1),
    assertion(Id0 == Id1).

:- end_tests(proof_game_var_names).

% --- Negation links and "for all cases" sub-condition links --------------------
% Uses examples/moreExamples/happy_dragon.le, whose "alice is happy" proof needs
% both a negation link (the smokes rule satisfying "it is not the case that ...
% smokes") and the two sub-conditions of a "for all cases in which ..." rule.

happy_dragon_session(KB, SM) :-
    le_kbs:load('examples/moreExamples/happy_dragon.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, smoky).

% The rule id whose head renders as HeadText (e.g. "a creature is happy").
rule_id_for_head(Rules, HeadText, Id) :-
    member(R, Rules), get_dict(head, R, HeadText), get_dict(id, R, Id), !.

% The fact id whose rendered text is FactText (e.g. "bob is a dragon"). Resolving
% by text keeps the tests independent of fact enumeration order.
fact_id_for_text(Facts, FactText, Id) :-
    member(F, Facts), get_dict(fact, F, FactText), get_dict(id, F, Id), !.

:- begin_tests(proof_game_naf_forall).

% A "for all cases in which <Cond> it is the case that <Cons>" body condition
% exposes its two sub-conditions so the UI can offer a link target for each.
test(forall_exposes_subconditions) :-
    happy_dragon_session(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = _ ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, _Facts, _QT),
    once(( member(Happy, Rules), get_dict(head, Happy, "a creature is happy") )),
    get_dict(bodyForall, Happy, [Meta|_]),
    assertion(get_dict(index, Meta, 1)),
    % The sub-conditions show the author's variable names ("other creature"),
    % not the template slot types ("a dragon" / "a creature").
    assertion(get_dict(condLE, Meta, "a creature is a parent of an other creature")),
    assertion(get_dict(consLE, Meta, "an other creature is healthy")).

% The full "alice is happy" proof — with the two forall sub-condition links and a
% negation link (the smokes rule into the NAF condition) — unifies successfully.
test(full_proof_with_negation_link_unifies) :-
    happy_dragon_session(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = _ ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, Facts, _QT),
    rule_id_for_head(Rules, "a creature is happy", HappyId),
    rule_id_for_head(Rules, "a creature is healthy", HealthyId),
    rule_id_for_head(Rules, "a creature smokes", SmokesId),
    fact_id_for_text(Facts, "bob is a dragon", BobDragon),
    fact_id_for_text(Facts, "alice is a dragon", AliceDragon),
    fact_id_for_text(Facts, "alice is a parent of bob", Parent),
    Nodes = [ _{instanceId:"q1", templateId:"query"},
              _{instanceId:"happy", templateId:HappyId},
              _{instanceId:"smokes", templateId:SmokesId},
              _{instanceId:"healthy", templateId:HealthyId},
              _{instanceId:"f_bobdragon", templateId:BobDragon},
              _{instanceId:"f_alicedragon", templateId:AliceDragon},
              _{instanceId:"f_parent", templateId:Parent} ],
    Edges = [ _{child:"happy", parent:"q1", bodyIndex:0},
              _{child:"f_alicedragon", parent:"happy", bodyIndex:0},
              _{child:"f_parent", parent:"happy", bodyIndex:1, subIndex:0},
              _{child:"healthy", parent:"happy", bodyIndex:1, subIndex:1},
              _{child:"f_bobdragon", parent:"healthy", bodyIndex:0},
              _{child:"smokes", parent:"healthy", bodyIndex:1} ],
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "ok")).

% A generic FAIL node still satisfies the NAF condition (the negation link is an
% addition, not a replacement).
test(fail_node_still_satisfies_naf) :-
    happy_dragon_session(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = _ ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, Facts, _QT),
    rule_id_for_head(Rules, "a creature is healthy", HealthyId),
    fact_id_for_text(Facts, "bob is a dragon", BobDragon),
    Nodes = [ _{instanceId:"healthy", templateId:HealthyId},
              _{instanceId:"f_bobdragon", templateId:BobDragon},
              _{instanceId:"failn", templateId:"fail"} ],
    Edges = [ _{child:"f_bobdragon", parent:"healthy", bodyIndex:0},
              _{child:"failn", parent:"healthy", bodyIndex:1} ],
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "ok")).

% A FAIL node connected to a positive (non-NAF) condition is rejected.
test(fail_node_rejected_on_positive_condition) :-
    happy_dragon_session(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = _ ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, _Facts, _QT),
    rule_id_for_head(Rules, "a creature is healthy", HealthyId),
    Nodes = [ _{instanceId:"healthy", templateId:HealthyId},
              _{instanceId:"failn", templateId:"fail"} ],
    Edges = [ _{child:"failn", parent:"healthy", bodyIndex:0} ],  % "is a dragon" is positive
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "clash")).

:- end_tests(proof_game_naf_forall).

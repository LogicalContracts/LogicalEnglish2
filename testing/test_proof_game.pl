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
:- use_module('../le_verifier').
:- use_module('../reasoner').

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

% --- A negation satisfied by SEVERAL failing rules ----------------------------
% In examples/moreExamples/testing/p_with_negation.le the goal `r` is the head of
% two rules (`r if u`, `r if w`), so "it is not the case that r" fails only when
% BOTH of them fail. The proof game must accept a link from the NAF condition to
% each such rule (a "not the case" link unifies the rule head with the negated
% inner goal `r`), all into the same condition socket, without clashing.

p_with_negation_session(KB, SM) :-
    le_kbs:load('examples/moreExamples/testing/p_with_negation.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, negation).

% The rule id whose head renders as HeadText and whose (single-condition) body is
% BodyText — distinguishes the two `r` rules (body "u" vs body "w").
rule_id_for_head_body(Rules, HeadText, BodyText, Id) :-
    member(R, Rules),
    get_dict(head, R, HeadText), get_dict(body, R, [BodyText]),
    get_dict(id, R, Id), !.

:- begin_tests(proof_game_naf_multi_rule).

% Both `r if u` and `r if w` link into the single NAF condition of the `p` rule
% ("p if q and it is not the case that r") and the fragment still unifies — the
% backend admits multiple "not the case" links on one negation socket.
test(two_rules_into_one_negation_unifies) :-
    p_with_negation_session(KB, SM),
    le_proof_game:extract_rules_and_facts(KB, SM, p, Rules, Facts, _QT),
    once(( member(P, Rules), get_dict(head, P, "p"), get_dict(body, P, ["q"|_]),
           get_dict(id, P, PId) )),
    rule_id_for_head_body(Rules, "r", "u", RUId),
    rule_id_for_head_body(Rules, "r", "w", RWId),
    rule_id_for_head(Rules, "q", QId),
    fact_id_for_text(Facts, "t", TId),
    Nodes = [ _{instanceId:"q1", templateId:"query"},
              _{instanceId:"prule", templateId:PId},
              _{instanceId:"qrule", templateId:QId},
              _{instanceId:"ru", templateId:RUId},
              _{instanceId:"rw", templateId:RWId},
              _{instanceId:"ft", templateId:TId} ],
    % bodyIndex 1 of the p rule is the negation; both r-rules connect there.
    Edges = [ _{child:"prule", parent:"q1", bodyIndex:0},
              _{child:"qrule", parent:"prule", bodyIndex:0},
              _{child:"ft", parent:"qrule", bodyIndex:0},
              _{child:"ru", parent:"prule", bodyIndex:1},
              _{child:"rw", parent:"prule", bodyIndex:1} ],
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "ok")).

:- end_tests(proof_game_naf_multi_rule).

% --- Abduction: assumable predicates become ASSUMPTION cards -------------------
% In examples/moreExamples/abduction/grass_is_wet.le the two candidate causes are
% "; assumable" templates with no facts at all: the game must offer each as an
% assumption card (assumed: true) that satisfies the rule condition it matches,
% so the abductive proof (query -> rule -> assumption) can be completed.

grass_session(KB, SM, Goal) :-
    le_kbs:load('examples/moreExamples/abduction/grass_is_wet.le', KB),
    le_kbs:createSession(KB, SM),
    KB:query_info(explain, Goal, _).

:- begin_tests(proof_game_abduction).

% Each "; assumable" template yields an assumption card, marked assumed.
test(assumables_become_assumption_cards) :-
    grass_session(KB, SM, Goal),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, _Rules, Facts, _QT),
    findall(T, ( member(F, Facts), get_dict(assumed, F, true), get_dict(fact, F, T) ), Ts),
    msort(Ts, Sorted),
    assertion(Sorted == ["it rained", "the sprinkler was on"]).

% Ordinary facts stay unmarked (assumed: false).
test(plain_facts_are_not_marked_assumed) :-
    happy_dragon_session(KB, SM),
    ( KB:query_info(happy, Goal, _) -> true ; Goal = _ ),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, _Rules, Facts, _QT),
    forall(member(F, Facts), get_dict(assumed, F, false)).

% The abductive proof fragment — the query, the rule "the grass is wet if it
% rained", and the ASSUMPTION card "it rained" on its condition — unifies ok.
test(assumption_satisfies_rule_condition) :-
    grass_session(KB, SM, Goal),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, Facts, _QT),
    once(( member(R, Rules), get_dict(body, R, ["it rained"]), get_dict(id, R, RainRule) )),
    once(( member(F, Facts), get_dict(fact, F, "it rained"), get_dict(id, F, RainCard) )),
    Nodes = [ _{instanceId:"q1", templateId:"query"},
              _{instanceId:"wet", templateId:RainRule},
              _{instanceId:"rained", templateId:RainCard} ],
    Edges = [ _{child:"wet", parent:"q1", bodyIndex:0},
              _{child:"rained", parent:"wet", bodyIndex:0} ],
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "ok")).

% An assumption card on a condition of a DIFFERENT predicate clashes like any
% mismatched fact ("the sprinkler was on" cannot satisfy "it rained").
test(mismatched_assumption_clashes) :-
    grass_session(KB, SM, Goal),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, Facts, _QT),
    once(( member(R, Rules), get_dict(body, R, ["it rained"]), get_dict(id, R, RainRule) )),
    once(( member(F, Facts), get_dict(fact, F, "the sprinkler was on"), get_dict(id, F, SprinklerCard) )),
    Nodes = [ _{instanceId:"wet", templateId:RainRule},
              _{instanceId:"sprinkler", templateId:SprinklerCard} ],
    Edges = [ _{child:"sprinkler", parent:"wet", bodyIndex:0} ],
    le_proof_game:unify_game_nodes(KB, SM, Nodes, Edges, Response),
    assertion(get_dict(status, Response, "clash")).

:- end_tests(proof_game_abduction).

% --- Building the game after a query has already run -------------------------
% Answering a query ends in postprocess_why -> find_first_range/4, which calls
% `SM:clause(Skeleton, _, Ref)` for a goal whose predicate the module does not
% define. Resolving that unknown procedure pulls the BUILT-IN clause/3 into the
% module's import table, and from then on current_predicate(M:F/N) enumerates
% clause/3 itself — so every "enumerate the predicates, then inspect their
% clauses" walk hits clause(M:clause(_,_,_), B, R) and throws
% permission_error(access, private_procedure, clause/3).
%
% That is why the Proof Game worked on a freshly loaded session and died as soon
% as the user had run their query, which is the normal order in the editor.

% Reproduces the resolution exactly as query/5 does, without depending on which
% example happens to take that path.
resolve_clause_into_modules(KB, SM) :-
    ignore(catch(le_kbs:find_first_range(no_such_predicate_xyz(_), SM, KB, _), _, true)),
    assertion(( current_predicate(SM:F/N), F/N == clause/3 )).

:- begin_tests(proof_game_after_query).

test(extract_survives_resolved_clause_3) :-
    grass_session(KB, SM, Goal),
    resolve_clause_into_modules(KB, SM),
    catch(le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules, Facts, _QT),
          E, ( print_message(error, E), fail )),
    assertion(Rules \== []),
    assertion(Facts \== []),
    le_kbs:destroySession(SM).

% The guard must not throw cards away: same game before and after.
test(extract_is_unchanged_by_resolved_clause_3) :-
    grass_session(KB, SM, Goal),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules0, Facts0, _),
    length(Rules0, NR0), length(Facts0, NF0),
    resolve_clause_into_modules(KB, SM),
    le_proof_game:extract_rules_and_facts(KB, SM, Goal, Rules1, Facts1, _),
    length(Rules1, NR1), length(Facts1, NF1),
    assertion(NR0 == NR1),
    assertion(NF0 == NF1),
    le_kbs:destroySession(SM).

% The same trap bit every KB walk that enumerates predicates and then inspects
% their clauses, not just the game's.
test(kb_walks_survive_resolved_clause_3) :-
    grass_session(KB, SM, Goal),
    resolve_clause_into_modules(KB, SM),
    catch(le_verifier:verify(KB, [skip_tests], _), E1, (print_message(error, E1), fail)),
    catch(le_kbs:topPredicates(KB, _), E2, (print_message(error, E2), fail)),
    catch(le_kbs:kbSummary(KB, _), E3, (print_message(error, E3), fail)),
    Goal = Goal,
    le_kbs:destroySession(SM).

% count_rules/count_facts used to count le_kbs's OWN clauses, imported into the
% KB module, as the program's rules — 75-odd phantom rules, which silently
% disabled the missing_rules and too_many_facts checks.
test(rule_and_fact_counts_are_the_programs_own) :-
    le_kbs:load('examples/moreExamples/testing/citizenship_premier.le', KB, [skip_tests]),
    le_verifier:count_rules(KB, Rules),
    le_verifier:count_facts(KB, Facts),
    assertion(Rules == 1),
    assertion(Facts < 20).

:- end_tests(proof_game_after_query).

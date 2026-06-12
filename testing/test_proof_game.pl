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

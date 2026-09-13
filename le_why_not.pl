/** <module> Why not: the unmet conditions of a failed query

    A failed query's explanation (reasoner.pl, build_failure_tree/2, with
    detailed failures: one node per rule attempted) says everything that was
    tried. What a reader wants of it is shorter: the conditions the case did not
    meet, each with the rule that asked for it and the facts that rule compared
    — "not met: 223 is less than or equal to 183 (rule pmd_pa_delivery, LCD
    L33789: "the delivery must be within 6 months following the
    determination"), given that prior authorization was affirmed on 2026-03-01
    and the item was delivered on 2026-10-10".

    unmet_conditions/4 walks the (post-processed) failure tree:

    - where a goal was attempted by several rules, only the attempts that came
      CLOSEST are followed — those in which the most conditions held before the
      one that failed (le_kbs:rule_progress/4 counts them). An alternative that
      failed at its first test (another policy's code list, another group's
      criteria) is not a reason; the alternatives that got equally far are all
      reasons, since meeting any of them would do;
    - a failed condition proved by rules is followed into them; one that is not
      is a LEAF, and each leaf is one unmet condition:
        * `not_stated` — a fact the case could state (a scenario-element or
          judged template, le_flip:changeable/2) that it does not state: the
          record is silent;
        * `not_met` — a comparison or other test that is false on the case's
          values, a negation whose subject holds, a fact the case states
          otherwise (same template, same subject, another value), a judgment
          recorded with another outcome, or a goal no rule concludes.

    Each unmet condition carries the rule whose body holds it (the innermost
    rule of the program at its source position), that rule's provenance, and
    the conditions of that rule that held on the way (the facts compared).
    Nothing here knows any domain.
*/

:- module(le_why_not, [
    unmet_conditions/4,     % +SM, +KB, +Why, -Items:list(dict)
    unmet_json/4            % +SM, +KB, +Why, -JSON:list(dict)
]).

:- use_module(library(apply)).
:- use_module(library(lists)).

%!  unmet_conditions(+SM, +KB, +Why, -Items) is det.
%
%   Items: unmet(Kind, Goal, LE, Range, Facts) in the order of the
%   explanation, without duplicates. Facts are the LE strings of the
%   conditions that held beside it.
unmet_conditions(SM, KB, Why, Items) :-
    ( is_list(Why) -> Roots = Why ; Roots = [Why] ),
    findall(I, ( member(R, Roots), unmet_node(SM, KB, R, [], I) ), Items0),
    dedup_items(Items0, Items).

unmet_node(SM, KB, repeated_group(_, W), Ctx, I) :- !,
    unmet_node(SM, KB, W, Ctx, I).
unmet_node(_, _, failure(le_section_checklist(_), _, _, _), _, _) :- !, fail.
unmet_node(_, _, failure(le_type_check(_, _), _, _, _), _, _) :- !, fail.
unmet_node(SM, KB, failure(rule_attempt(_, _, _), _, _, Cs), _, I) :- !,
    held(Cs, Facts),
    failed_children(Cs, Fs),
    member(F, Fs),
    unmet_node(SM, KB, F, Facts, I).
unmet_node(SM, KB, failure(G, R, LE, Cs), Ctx, I) :-
    rule_attempts(Cs, Attempts),
    (   Attempts \== []
    ->  closest(Attempts, Kept),
        member(A, Kept),
        unmet_node(SM, KB, A, Ctx, I)
    ;   failed_children(Cs, Fs),
        (   Fs \== []
        ->  held(Cs, Facts),                % the facts of the rule that asks
            member(F, Fs),
            unmet_node(SM, KB, F, Facts, I)
        ;   leaf_kind(SM, KB, G, Cs, Kind, Extra),
            append(Ctx, Extra, Facts),
            I = unmet(Kind, G, LE, R, Facts)
        )
    ).

rule_attempts(Cs, As) :-
    findall(A, ( member(C0, Cs), unwrap(C0, A), A = failure(rule_attempt(_, _, _), _, _, _) ), As).

% the attempts in which the most conditions held — and of those, the ones in
% which they were the largest part of the rule (a route that only begins to
% apply later, "the rental month is at least 4", ties by count with the route
% that applies now and failed on a criterion, but met less of itself)
closest(Attempts, Kept) :-
    findall(M-T, member(failure(rule_attempt(_, M, T), _, _, _), Attempts), MTs),
    pairs_keys(MTs, Ms), max_list(Ms, Max),
    findall(R, ( member(M-T, MTs), M =:= Max, share(M, T, R) ), Rs),
    max_list(Rs, MaxR),
    findall(A, ( member(A, Attempts), A = failure(rule_attempt(_, M, T), _, _, _),
                 M =:= Max, share(M, T, R), R =:= MaxR ), Kept).

share(_, 0, 0) :- !.
share(M, T, R) :- R is M / T.

failed_children(Cs, Fs) :-
    findall(F, ( member(C0, Cs), unwrap(C0, F), F = failure(_, _, _, _),
                 F \= failure(le_type_check(_, _), _, _, _) ), Fs).

% the conditions shown as having held (a choice point, with its binding)
held(Cs, Facts) :-
    findall(LE, ( member(C0, Cs), unwrap(C0, success(_, _, LE0, _)), text(LE0, LE) ), Facts).

unwrap(repeated_group(_, W), X) :- !, unwrap(W, X).
unwrap(X, X).

text(S, S) :- string(S), !.
text(A, S) :- atom(A), !, atom_string(A, S).
text(T, S) :- term_string(T, S).

%!  leaf_kind(+SM, +KB, +Goal, +Children, -Kind, -Extra) is det.
leaf_kind(SM, KB, G, Cs, Kind, Extra) :-
    (   % "it is not the case that X": X holds
        member(C0, Cs), unwrap(C0, success(_, _, LE0, _))
    ->  Kind = not_met, text(LE0, LE), Extra = [LE]
    ;   callable(G), catch(le_flip:changeable(KB, G), _, fail)
    ->  (   stated_otherwise(SM, KB, G, Other)
        ->  Kind = not_met, Extra = [Other]
        ;   Kind = not_stated, Extra = []
        )
    ;   Kind = not_met, Extra = []
    ).

% The case states the same template for the same question with another value
% (the last argument): "the type of the sleep test of Ben is home sleep test"
% where "... is facility polysomnogram" was asked for. For a judged template
% that is a recorded outcome ("unsupported" where "established" was needed).
stated_otherwise(SM, KB, G, LE) :-
    G =.. [F|Args],
    append(Question, [Last], Args), Question \== [],
    ground(Question), nonvar(Last),
    append(Question, [Other], Args1),
    G1 =.. [F|Args1],
    ( catch(clause(SM:G1, true), _, fail) ; catch(clause(KB:G1, true), _, fail) ),
    Other \== Last, !,
    (   catch(le_kbs:item_to_instance(KB, G1, Toks), _, fail)
    ->  le_kbs:canonical_string(Toks, LE)
    ;   term_string(G1, LE)
    ).

% one item per condition, as it reads (the first rule that asks for it)
dedup_items([], []).
dedup_items([I|Is], [I|Out]) :-
    I = unmet(_, _, LE, _, _),
    exclude(same_literal(LE), Is, Is1),
    dedup_items(Is1, Out).

same_literal(LE, unmet(_, _, LE2, _, _)) :- LE2 == LE.

% ---------------------------------------------------------------------------
% As the client reads them
% ---------------------------------------------------------------------------

%!  unmet_json(+SM, +KB, +Why, -JSON) is det.
%
%   Each unmet condition as {literal, kind, facts, rule?, provenance?, plain?,
%   label?, goal?, values?}: the rule of the program that asks for it (its
%   name when the author named it) and its provenance; for a fact the case
%   could state, the template's label, the goal as a fact to state, and the
%   values the rules read at each placeholder (as openQuestions gives them).
unmet_json(SM, KB, Why, JSON) :-
    unmet_conditions(SM, KB, Why, Items),
    maplist(item_json(KB), Items, JSON).

item_json(KB, unmet(Kind, G, LE0, R, Facts), J) :-
    text(LE0, LE1),
    rejoin_hyphens(LE1, LE),
    maplist(rejoin_hyphens, Facts, Facts1),
    J0 = _{literal: LE, kind: Kind, facts: Facts1},
    (   rule_at(KB, R, ID, S, E)
    ->  % the rule's name only when its author named it (not "rule_944")
        (   le_kbs:user_rule_name(ID)
        ->  J1 = J0.put(_{rule: ID, ruleStart: S, ruleEnd: E})
        ;   J1 = J0.put(_{ruleStart: S, ruleEnd: E})
        ),
        (   catch(le_provenance:rule_provenance(KB, ID, Prov), _, fail)
        ->  le_provenance:provenance_dict(none, KB, Prov, P),
            J2 = J1.put(provenance, P)
        ;   J2 = J1
        )
    ;   J2 = J0
    ),
    (   Kind == not_stated, callable(G),
        functor(G, F, A),
        catch(le_kbs:template_def(KB, F, A, Label, _, Values), _, fail)
    ->  (   catch(le_kbs:item_to_instance(KB, G, Tokens), _, fail)
        ->  copy_term(Tokens, T1), numbervars(T1, 0, _), le_kbs:goal_string(T1, GoalStr0),
            rejoin_hyphens(GoalStr0, GoalStr)
        ;   GoalStr = LE
        ),
        J = J2.put(_{label: Label, goal: GoalStr, values: Values})
    ;   J = J2
    ).

% The innermost rule of the program whose text holds the condition at range R
% (a named rule's name, or the rule's generated id).
rule_at(KB, range(P, _), ID, S, E) :-
    integer(P),
    findall(Len-(ID0-S0-E0),
            ( catch(KB:le_source_info(Ref, S0, E0, ID0), _, fail),
              integer(S0), integer(E0), S0 =< P, P =< E0,
              \+ catch(clause(_, true, Ref), _, fail),     % a rule, not a fact
              Len is E0 - S0 ),
            Hits),
    Hits \== [],
    keysort(Hits, [_-(ID-S-E)|_]).

% a hyphenated word renders tokenised ("full - time"): as written ("full-time")
rejoin_hyphens(S0, S) :-
    atomic_list_concat(Parts, ' - ', S0), atomic_list_concat(Parts, '-', A), atom_string(A, S).

/** <module> Flip queries: which minimal change to the scenario flips an outcome

        query flip is:
            which minimal change to the scenario makes it the case that
                rich gets help to pay rent.

    A change adds or removes ONE fact of a scenario-element template (a
    template marked `; undefined` or `; judged`; when a program marks none,
    any template no rule concludes). The answers are the minimal change sets —
    smallest first; every set of that size that works — each with the proof
    the changed scenario gives. "Makes it the case that G" means G then holds
    outright, with no assumption; for `it is not the case that G`, that G no
    longer has any proof.

    The search is explanation-guided and verified. Candidates are never drawn
    from the whole fact space, only from what an attempt at the goal actually
    touched: an ADDITION is a ground goal of a scenario-element template that
    the attempt called and that is not a fact (it failed, or held only by
    assumption — so a judged template's open instance becomes a "judgment"
    change); a REMOVAL is a scenario fact the attempt used. Change sets grow
    one change at a time (iterative deepening on their size), each candidate
    set applied to a copy of the session and the goal re-solved there; the
    candidates of a set are recomputed from ITS attempt, so a change that
    opens a new path brings that path's conditions into play.
*/

:- module(le_flip, [
    minimal_changes/5,          % +Goal, +SM, +KM, -ChangeSets, -Proofs
    change_words/3              % +KM, +Change, -Words
]).

:- use_module(le_i18n).

max_changes(Max) :-
    ( current_prolog_flag(le_flip_max_changes, M), integer(M) -> Max = M ; Max = 3 ).
max_evaluations(Max) :-
    ( current_prolog_flag(le_flip_max_evaluations, M), integer(M) -> Max = M ; Max = 400 ).

:- thread_local evaluations/1.

%!  minimal_changes(+Goal, +SM, +KM, -ChangeSets, -Proofs) is det.
%
%   ChangeSets: the minimal sets (lists of add(Fact) / remove(Fact)) that make
%   Goal hold in the scenario loaded in session SM; [[]] when it already
%   holds, [] when no set of at most le_flip_max_changes changes (default 3)
%   does. Proofs pairs each set with the (post-processed) explanation of Goal
%   in the changed scenario.
minimal_changes(Goal, SM, KM, ChangeSets, Proofs) :-
    session_snapshot(SM, Base),
    retractall(evaluations(_)), assertz(evaluations(0)),
    evaluate(Goal, SM, KM, Base, [], Holds, Pool),
    (   Holds == true
    ->  ChangeSets = [[]]
    ;   max_changes(Max),
        deepen(1, Max, Goal, SM, KM, Base, [[]-Pool], ChangeSets)
    ),
    findall(Set-Why,
            ( member(Set, ChangeSets), proof_in(Goal, SM, KM, Base, Set, Why) ),
            Proofs).

deepen(K, Max, _, _, _, _, _, []) :- K > Max, !.
deepen(_, _, _, _, _, _, [], []) :- !.
deepen(K, Max, Goal, SM, KM, Base, Frontier, ChangeSets) :-
    findall(Set,
            ( member(Parent-Pool, Frontier),
              member(C, Pool),
              \+ memberchk(C, Parent), compatible(C, Parent),
              msort([C|Parent], Set) ),
            Sets0),
    sort(Sets0, Sets),
    evaluate_all(Sets, Goal, SM, KM, Base, Results),
    findall(S, member(S-true-_, Results), Solutions),
    (   Solutions \== []
    ->  ChangeSets = Solutions
    ;   budget_left
    ->  findall(S-P, member(S-false-P, Results), Next),
        K1 is K + 1,
        deepen(K1, Max, Goal, SM, KM, Base, Next, ChangeSets)
    ;   ChangeSets = []
    ).

evaluate_all([], _, _, _, _, []).
evaluate_all([S|Ss], Goal, SM, KM, Base, [S-H-P|Rs]) :-
    (   budget_left
    ->  evaluate(Goal, SM, KM, Base, S, H, P)
    ;   H = false, P = []
    ),
    evaluate_all(Ss, Goal, SM, KM, Base, Rs).

budget_left :-
    evaluations(N), max_evaluations(Max), N < Max.

compatible(add(F), Set) :- \+ ( member(remove(G), Set), G =@= F ).
compatible(remove(F), Set) :- \+ ( member(add(G), Set), G =@= F ).

% ---------------------------------------------------------------------------
% One evaluation: apply a change set to a copy of the session, attempt the goal
% ---------------------------------------------------------------------------

%!  evaluate(+Goal, +SM, +KM, +Base, +Set, -Holds, -Pool) is det.
evaluate(Goal, _SM, KM, Base, Set, Holds, Pool) :-
    retract(evaluations(N)), N1 is N + 1, assertz(evaluations(N1)),
    with_changed_session(KM, Base, Set, T,
        reasoner:with_saved_reasoner_state(le_flip:attempt(Goal, T, KM, Base, Set, Holds, Pool))).

attempt(Goal, T, KM, Base, Set, Holds, Pool) :-
    copy_term(Goal, G),
    le_kbs:set_kb_module(KM),
    (   catch(( reasoner:solve(G, T, KM, [], 0, 0, Us, _), Us == [] ), _, fail)
    ->  Holds = true, Pool = []
    ;   Holds = false,
        candidate_pool(T, KM, Base, Set, Pool)
    ).

%   Every ground goal the attempt called: additions for the scenario-element
%   ones that are not facts; removals for the scenario facts they matched.
candidate_pool(T, KM, Base, Set, Pool) :-
    findall(G, ( reasoner:called(_, _, G0), strip_le_at(G0, G), callable(G) ), Called0),
    sort(Called0, Called),
    findall(add(G),
            ( member(G, Called), ground(G),
              changeable(KM, G),
              \+ current_fact(T, G) ),
            Adds),
    Base = base(Facts, _),
    findall(remove(F),
            ( member(fact(F, _, _), Facts),
              \+ ( member(remove(R), Set), R =@= F ),
              changeable(KM, F),
              member(G, Called), \+ \+ G = F ),
            Removes),
    append(Adds, Removes, Pool0),
    sort(Pool0, Pool).

strip_le_at(le_at(G0, _, _), G) :- !, strip_le_at(G0, G).
strip_le_at(G, G).

current_fact(T, G) :-
    catch(clause(T:G, true), _, fail), !.

%!  changeable(+KM, +Goal) is semidet.
%
%   Goal's template is a scenario element: marked `; undefined` or `; judged`
%   — or, in a program that marks no template at all, any template no rule
%   concludes.
changeable(KM, Goal) :-
    functor(Goal, F, A),
    \+ sub_atom(F, 0, 3, _, le_),
    F \== is_a,
    (   marked_templates(KM)
    ->  marked_template(KM, F, A)
    ;   catch(le_kbs:template_of(KM, F, A, _, _), _, fail),
        \+ ( functor(H, F, A), current_predicate(KM:F/A),
             le_kbs:kb_own_predicate(KM, H),
             clause(KM:H, B), B \== true )
    ).

marked_templates(KM) :-
    marked_template(KM, _, _), !.

marked_template(KM, F, A) :-
    current_predicate(KM:le_dict/1),
    KM:le_dict(dict([F|Args], _, _, _, _, _, U)),
    ( U == scenario_element ; U == judged ),
    length(Args, A).

% ---------------------------------------------------------------------------
% Sessions
% ---------------------------------------------------------------------------

%   The scenario loaded in SM: its facts (with their source ranges), and the
%   provenance records scoped proofs read.
session_snapshot(SM, base(Facts, Provs)) :-
    findall(fact(T, S, E),
            ( catch(SM:sessionClause(Ref), _, fail),
              clause(SM:H, B, Ref),
              H \= le_provenance(_, _, _, _, _),
              ( B == true -> T = H ; T = (H :- B) ),
              ( SM:le_source_info(Ref, S, E, _) -> true ; S = 0, E = 0 ) ),
            Facts),
    findall(le_provenance(H, Src, D, L, R),
            catch(SM:le_provenance(H, Src, D, L, R), _, fail),
            Provs).

with_changed_session(KM, base(Facts, Provs), Set, T, Goal) :-
    le_kbs:createSession(KM, T),
    setup_call_cleanup(
        ( forall(( member(fact(F, S, E), Facts),
                   \+ ( member(remove(R), Set), R =@= F ) ),
                 le_kbs:addSessionFact(T, fact_with_source(F, S, E))),
          forall(member(P, Provs), assertz(T:P)),
          forall(member(add(A), Set), le_kbs:addSessionFact(T, A)) ),
        once(Goal),
        le_kbs:destroySession(T)).

% The explanation of Goal once the change set is applied, post-processed while
% the changed session still exists (its clause references die with it).
proof_in(Goal, _SM, KM, Base, Set, Why) :-
    with_changed_session(KM, Base, Set, T,
        reasoner:with_saved_reasoner_state(le_flip:
            (   copy_term(Goal, G),
                catch(reasoner:i(G, T, [], Why0), _, fail)
            ->  le_kbs:postprocess_why(Why0, T, Why1),
                mark_added(Why1, Why)
            ;   Why = []
            ))).

% A fact the change set added has no source: its node says so, instead of
% carrying a reference to a clause of the discarded session.
mark_added(L, Out) :- is_list(L), !, maplist(mark_added, L, Out).
mark_added(success(G, R, LE, Cs), success(G, R1, LE, Cs1)) :- !,
    ( blob(R, clause) -> R1 = scenario_change ; R1 = R ),
    mark_added(Cs, Cs1).
mark_added(failure(G, R, LE, Cs), failure(G, R, LE, Cs1)) :- !,
    mark_added(Cs, Cs1).
mark_added(repeated_group(N, W), repeated_group(N, W1)) :- !, mark_added(W, W1).
mark_added(X, X).

% ---------------------------------------------------------------------------
% Rendering
% ---------------------------------------------------------------------------

%!  change_words(+KM, +Change, -Words) is det.
%
%   "add: rich is on a low income", "remove: bob is on other benefits".
change_words(KM, Change, Words) :-
    Change =.. [Kind, Fact],
    (   catch(le_kbs:item_to_instance(KM, Fact, Toks), _, fail)
    ->  le_kbs:canonical_string(Toks, FS)
    ;   term_string(Fact, FS)
    ),
    atom_concat(flip_, Kind, MsgId),
    le_msg(MsgId, [fact-FS], Atom),
    atomic_list_concat(Words0, ' ', Atom),
    exclude(==(''), Words0, Words).

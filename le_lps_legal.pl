/** <module> The legal-readable view of an LE-for-LPS program

    An LE-for-LPS program (`the target language is: lps.`) is executable but
    reads as mechanism: laws that fire when an action happens, constraints
    that refuse it. Its *legal view* says WHO MAY DO WHAT, WHEN, AND WITH
    WHICH EFFECT, and is derived from the program by a fixed transformation,
    so the two cannot drift apart:

      - each action's integrity constraints (`it must not be true that …`)
        become ONE permission rule: the action is permitted when none of the
        constraints applies
            *a sender* may transfer *an amount* to *a recipient* if
                it is not the case that the token is paused
                and ...
      - each causal law (`when … then …`) becomes an effect rule
            *a sender* transferring *an amount* to *a recipient* results in
            the balance of *an account* being *an amount* if ...
        (a law that only materialises a zero default — `… is 0` when the
        entry is absent — is implementation, and is left out);
      - the fluents become scenario elements: the state is the scenario;
      - the program's own scenario gives the questions: for each call it
        observes, "may <the call>?", its effects, and (a flip query) what
        would have to change for it to be permitted.

    The view is an ordinary (Prolog-target) LE program, so it runs in the LE
    editor like any other: queries, explanations, flip queries.

    The wording is the program's own. An action template that starts with
    its actor and a verb in the third person (`*a sender* transfers …`)
    gives `*a sender* may transfer …` and `*a sender* transferring …` by
    English morphology; any other template (and every template of a program
    in another language) takes the fixed forms of i18n/writer_words.csv
    (`it is allowed that <action>`, `<action> has as a result that <fluent>`),
    which need no morphology.

    Nothing here knows any source system: the Solidity twins of the InsurLE
    migrations use it, and so does any hand-written LPS program.

    Entry points:
      legal_view_text(+LEText, +Options, -Text, -Issues)   a document -> the view's text
      legal_view_kb(+KB, +Options, -IR)                    a loaded knowledge base -> IR
      legal_view_ir(+Items, +Options, -IR)                 program items -> IR
      lps_program_items(+KB, -Items)                       the items of a loaded program

    Items: fluent(F, Text, Adds), action(F, Text, Adds), event(F, Text, Adds),
    template(F, Text, Adds) (timeless), lps(Term) — Migration IR items
    (docs/dev/migration.md), F being the functor the LPS terms use.

    Options: kb(Name), comment(Text), scenarios(Scenarios),
    queries(Queries) (replace the generated ones), language(Lang),
    run(States, Happened): a run of the program — T-Fluents, the state at
    each time T, and T-Events, the events that happened from T-1 to T (the
    `fluents` and `events` records of LPS2's trace). With a run, the view's
    scenarios and questions are the run's own calls: for the N-th call the
    program observes, scenario before_call_N holds the state just before it,
    may_call_N is expected to hold exactly when the run accepted the call,
    and the effect queries of an accepted call to name the entries it
    changed — so running the view's expectations checks it against the
    program. The view is then computed afresh whenever it is asked for:
    nothing about it needs to be stored. more_scenarios(Ss), more_queries(Qs):
    hand-written ones to add to the run's.
*/

:- module(le_lps_legal, [
    legal_view_text/3,          % +LEText, +Options, -Text
    legal_view_text/4,          % +LEText, +Options, -Text, -Issues
    legal_view_kb/3,            % +KB, +Options, -IR
    legal_view_ir/3,            % +Items, +Options, -IR
    legal_view_write/3,         % +IR, -Text, -Issues
    lps_program_items/2,        % +KB, -Items
    permission_functor/2,       % +ActionFunctor, -PermissionFunctor
    effect_functor/4,           % +Kind, +ActionFunctor, +FluentFunctor, -EffectFunctor
    call_queries/4              % +Items, +Calls, +Options, -Queries
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(le_kbs).
:- use_module(le_lps).
:- use_module(le_writer).
:- use_module(le_i18n).

		 /*******************************
		 *         ENTRY POINTS         *
		 *******************************/

%!  legal_view_text(+LEText, +Options, -Text) is semidet.
%!  legal_view_text(+LEText, +Options, -Text, -Issues) is semidet.
%
%   Fails when the document does not load or is not an LPS program.
legal_view_text(LEText, Options, Text) :-
    legal_view_text(LEText, Options, Text, _).

legal_view_text(LEText, Options, Text, Issues) :-
    catch(le_kbs:load_text(LEText, KB), _, fail),
    legal_view_kb(KB, Options, IR),
    legal_view_write(IR, Text, Issues).

%!  legal_view_write(+IR, -Text, -Issues) is det.
%
%   The view's text. The expectations a run gave its effect queries are
%   run once: an accepted call whose laws touch one entry more than once
%   (a transfer to oneself, say) is composed by the program, while the view
%   states each law's effect on its own, so such an expectation is turned
%   into a comment saying so. A permission expectation is never softened:
%   one that fails is a real disagreement between the view and the program.
legal_view_write(IR, Text, Issues) :-
    le_write(IR, Text0, Issues0),
    IR = program(Header, Items),
    (   once(( member(scenario(_, Lines, _), Items), member(expects(Q, _), Lines),
               sub_atom(Q, 0, _, _, effect_) )),
        failing_effect_expectations(Text0, Fails), Fails \== []
    ->  ir_dicts(IR, Dicts),
        maplist(soften_scenario(Dicts, Fails), Items, Items1),
        le_write(program(Header, Items1), Text, Issues)
    ;   Text = Text0, Issues = Issues0
    ).

failing_effect_expectations(Text, Fails) :-
    (   catch(le_kbs:load_text(Text, KB), _, fail),
        current_predicate(KB:le_expected/4)
    ->  findall(S-Q-Got,
                ( KB:le_expected(Q, S, A, U), sub_atom(Q, 0, _, _, effect_),
                  catch(le_kbs:run_one_test(KB, test(Q, S, A, U), R), _, fail),
                  R = fail(Q, S, _, Got, _, _) ),
                Fails)
    ;   Fails = []
    ).

soften_scenario(Dicts, Fails, scenario(S, Lines0, O), scenario(S, Lines, O)) :- !,
    maplist(soften_line(Dicts, S, Fails), Lines0, Lines).
soften_scenario(_, _, Item, Item).

soften_line(Dicts, S, Fails, expects(Q, Exp), comment(C)) :-
    memberchk(S-Q-Got, Fails), !,
    (   Exp == []
    ->  legal_word(legal_no_entry_changed, ExpT)
    ;   maplist(render_ground_literal(Dicts), Exp, ExpTs),
        quoted_list(ExpTs, ExpT)
    ),
    quoted_list(Got, GotT),
    legal_word(legal_composed_comment, CW),
    format(string(C), CW, [Q, GotT, ExpT]).
soften_line(_, _, _, L, L).

quoted_list(Ts, Text) :-
    findall(Q, ( member(T, Ts), format(string(Q), "\"~w\"", [T]) ), Qs),
    atomic_list_concat(Qs, ', ', Text).

%!  legal_view_kb(+KB, +Options, -IR) is semidet.
legal_view_kb(KB, Options0, IR) :-
    catch(KB:le_target_language(lps), _, fail),
    lps_program_items(KB, Items),
    (   catch(KB:le_kb(Name0), _, fail) -> true ; Name0 = program ),
    (   option(kb(_), Options0) -> Options1 = Options0
    ;   legal_word(legal_kb_suffix, Suffix), format(atom(KBN), '~w ~w', [Name0, Suffix]),
        Options1 = [kb(KBN)|Options0]
    ),
    (   option(language(_), Options1) -> Options2 = Options1
    ;   catch(KB:le_lang(L), _, fail) -> Options2 = [language(L)|Options1]
    ;   Options2 = Options1
    ),
    run_options(Items, Options2, Options3),
    %  a program that extends others is viewed flattened, and says so
    (   catch(KB:le_kb_extends(_, Bases, _), _, fail)
    ->  atomic_list_concat(Bases, ', ', BT),
        legal_word(legal_extends_comment, EW), format(string(EC), EW, [BT]),
        (   select(comment(C0), Options3, Rest)
        ->  format(string(C1), "~w~n~w", [C0, EC]), Options = [comment(C1)|Rest]
        ;   Options = [comment(EC)|Options3]
        )
    ;   Options = Options3
    ),
    legal_view_ir(Items, Options, IR).

%   A run gives the scenarios and questions, unless the caller gave its own.
run_options(Items, Options0, Options) :-
    (   option(run(States, Happened), Options0),
        \+ option(scenarios(_), Options0), \+ option(queries(_), Options0)
    ->  ( option(language(Lang), Options0) -> true ; le_i18n:le_active_language(Lang) ),
        b_setval(le_lps_legal_lang, Lang),
        run_calls(Items, States, Happened, Scenarios0, Queries0),
        option(more_scenarios(MS), Options0, []), append(Scenarios0, MS, Scenarios),
        option(more_queries(MQ), Options0, []), append(Queries0, MQ, Queries),
        (   option(comment(_), Options0) -> Options1 = Options0
        ;   Scenarios0 == [] -> Options1 = Options0          % no call to speak of
        ;   legal_word(legal_run_comment, Cm0),               % lines split by |
            split_string(Cm0, "|", "", CmLines), atomic_list_concat(CmLines, '\n', CmA),
            atom_string(CmA, Cm), Options1 = [comment(Cm)|Options0]
        ),
        Options = [scenarios(Scenarios), queries(Queries)|Options1]
    ;   Options = Options0
    ).

%!  lps_program_items(+KB, -Items) is det.
%
%   The declarations of a loaded LE-for-LPS program as IR templates (under the
%   functors its LPS terms use), and its LPS internal terms as lps(Term).
lps_program_items(KB, Items) :-
    le_kbs:ensure_kb_language(KB),
    findall(Start-Item,
            ( current_predicate(KB:le_dict/1),
              clause(KB:le_dict(D), true, Ref),
              D = dict([F|Args], NTs, WV, _, _, _, _),
              \+ le_system_templates:le_system_template(dict([F|Args], _, _)),
              le_writer:wv_derives(WV, F),
              catch(KB:le_source_info(Ref, Start, _, template), _, fail),
              length(Args, N),
              (   catch(KB:le_lps_functor(F/N, KA), _, fail) -> TF = KA ; TF = F ),
              (   catch(KB:le_lps_role(F/N, Role), _, fail) -> true ; Role = timeless ),
              le_writer:wv_template_text(WV, NTs, Text),
              role_item(Role, TF, Text, Item) ),
            Pairs0),
    keysort(Pairs0, Pairs1), pairs_values(Pairs1, Templates0),
    list_to_set(Templates0, Templates),
    le_lps_module(KB, "", Internal, _, _),
    setup_call_cleanup(open_string(Internal, In), read_terms(In, Terms0), close(In)),
    %  the view's state is a scenario of stated facts: a keyed fluent's
    %  default (`; 0 by default`) is made explicit — the entry stored, or
    %  absent and holding it; a fluent with no key has one value, and the
    %  view's scenarios state its default when the program stores none
    %  (scalar_default/2 items)
    (   select(defaults(Ds), Terms0, Terms1)
    ->  partition(scalar_default_term, Ds, Scalars, Keyed),
        ( Keyed == [] -> Terms2 = Terms1 ; Terms2 = [defaults(Keyed)|Terms1] ),
        findall(scalar_default(F, D), ( member(D, Scalars), functor(D, F, _) ), SDs)
    ;   Terms2 = Terms0, SDs = []
    ),
    lps_expand_defaults(Terms2, Terms),
    findall(lps(T), member(T, Terms), Lps),
    append([Templates, SDs, Lps], Items).

scalar_default_term(D) :- functor(D, _, 1).

role_item(fluent, F, T, fluent(F, T, [])).
role_item(action, F, T, action(F, T, [])).
role_item(event, F, T, event(F, T, [])).
role_item(prolog_event, F, T, event(F, T, [])).
role_item(timeless, F, T, template(F, T, [])).

read_terms(In, Terms) :-
    read_term(In, T, []),
    ( T == end_of_file -> Terms = [] ; Terms = [T|Rest], read_terms(In, Rest) ).

		 /*******************************
		 *           THE VIEW           *
		 *******************************/

%!  legal_view_ir(+Items, +Options, -IR) is det.
legal_view_ir(Items, Options, program(Header, ViewItems)) :-
    option(kb(KB), Options, 'legal view'),
    ( option(language(Lang), Options) -> true ; le_i18n:le_active_language(Lang) ),
    b_setval(le_lps_legal_lang, Lang),
    Header0 = [kb(KB), target(prolog)],
    ( Lang \== en -> Header1 = [language(Lang)|Header0] ; Header1 = Header0 ),
    ( option(comment(Cm), Options) -> Header = [comment(Cm)|Header1] ; Header = Header1 ),
    %  the state: each fluent a scenario element
    findall(template(F, Text, [undefined]), member(fluent(F, Text, _), Items), StateTemplates0),
    %  the program's timeless vocabulary and rules, unchanged
    findall(template(F, Text, Adds), member(template(F, Text, Adds), Items), TimelessTemplates),
    findall(I, ( member(lps(T), Items), timeless_item(T, I) ), TimelessRules),
    %  one permission template per action
    findall(a(AF, N, Text), ( member(action(AF, Text, _), Items), text_places(Text, N) ), Actions),
    %  an action nothing in the program governs (no constraint refuses it, no
    %  law gives it an effect: a residue, say) gets no permission rule — "may"
    %  with no condition would be a claim the program does not make
    partition(governed(Items), Actions, Governed, Ungoverned),
    findall(template(MayF, MayT, []),
            ( member(a(AF, _, Text), Governed),
              permission_functor(AF, MayF), permission_text(Text, MayT) ),
            MayTemplates),
    findall(R, ( member(a(AF, N, _), Governed), permission_rule(Items, AF, N, R) ), MayRules0),
    findall(comment(C), ( member(a(AF, _, _), Ungoverned),
                          legal_word(legal_ungoverned_comment, CW), format(string(C), CW, [AF]) ), UngovComments),
    append(MayRules0, UngovComments, MayRules),
    findall(R, ( member(a(AF, N, _), Actions), effect_rule(Items, AF, N, R) ), EffectRules),
    findall(template(EF, ET, []),
            ( member(rule(Head, _, _), EffectRules), functor(Head, EF, _),
              effect_template_text(Items, Actions, EF, ET) ),
            EffTs0),
    list_to_set(EffTs0, EffTemplates),
    (   option(scenarios(Scenarios0), Options) -> true
    ;   default_scenarios(Items, Scenarios0)
    ),
    %  a state entry no rule of the view reads is left out of its scenarios
    append([MayRules0, EffectRules, TimelessRules], Rules),
    findall(F/N, ( member(fluent(F, FT, _), Items), text_places(FT, N), functor(G, F, N),
                   \+ ( member(rule(_, B, _), Rules), body_reads(B, G) ) ), Unread),
    maplist(drop_unread(Unread), Scenarios0, Scenarios1),
    exclude(empty_scenario, Scenarios1, Scenarios),
    exclude(unread_template(Unread), StateTemplates0, StateTemplates),
    (   option(queries(Queries), Options) -> true
    ;   default_queries(Items, Queries)
    ),
    %  a section only when it has something in it; a program with no action
    %  (only events, which nobody performs) says so
    legal_word(legal_permissions_section, PermS),
    legal_word(legal_effects_section, EffS),
    (   Actions == []
    ->  legal_word(legal_no_actions_comment, NA), PermItems = [comment(NA)]
    ;   MayRules == [] -> PermItems = []
    ;   PermItems = [section(PermS)|MayRules]
    ),
    ( EffectRules == [] -> EffItems = [] ; EffItems = [section(EffS)|EffectRules] ),
    append([StateTemplates, TimelessTemplates, MayTemplates, EffTemplates,
            TimelessRules, PermItems, EffItems,
            Scenarios, Queries], ViewItems).

drop_unread(Unread, scenario(N, Lines0, O), scenario(N, Lines, O)) :-
    exclude(unread_fact(Unread), Lines0, Lines).

empty_scenario(scenario(_, [], _)).

unread_template(Unread, template(F, Text, _)) :- text_places(Text, N), memberchk(F/N, Unread).

unread_fact(Unread, fact(F)) :- ( compound(F) ; atom(F) ), functor(F, N, A), memberchk(N/A, Unread).

body_reads(B, G) :- sub_term(S, B), compound(S), S \= and(_, _), S \= not(_), subsumes_term(G, S), !.
body_reads(B, G) :- atom(G), sub_term(S, B), S == G, !.

%   Whether any constraint or law of the program is about the action.
governed(Items, a(AF, N, _)) :-
    functor(A, AF, N),
    (   member(lps(d_pre(Cs)), Items), memberchk(happens(A, _, _), Cs)
    ;   member(lps(L), Items), law_effect_event(L, A)
    ), !.

law_effect_event(initiated(happens(A, _, _), _, _), A).
law_effect_event(terminated(happens(A, _, _), _, _), A).
law_effect_event(updated(happens(A, _, _), _, _, _), A).

%   An LPS timeless clause, as an IR rule or fact.
timeless_item(l_timeless(H, Cs), rule(H, B, [])) :- !, conj_list(Cs, B).
timeless_item(T, _) :- lps_vocabulary(T), !, fail.
timeless_item((H :- B), rule(H, B, [])) :- !.
timeless_item(H, fact(H, [])) :- compound(H) ; atom(H).

lps_vocabulary(T) :-
    functor(T, N, A),
    memberchk(N/A, [maxTime/1, maxRealTime/1, minCycleTime/1, simulatedRealTimePerCycle/1,
                    simulatedRealTimeBeginning/1, events/1, actions/1, fluents/1,
                    prolog_events/1, unserializable/1, initial_state/1, observe/2,
                    reactive_rule/2, reactive_rule/3, l_int/2, l_events/2, l_timeless/2,
                    initiated/3, terminated/3, updated/4, d_pre/1, achieve/1, display/2,
                    (:-)/1, planning/1, lps_planning/1]).

text_places(Text, N) :-
    split_string(Text, "*", "", Parts), length(Parts, L), N is (L - 1) // 2.

permission_functor(AF, F) :- atom_concat(may_, AF, F).
effect_functor(Kind, AF, FF, EF) :- format(atom(EF), '~w_~w_~w', [Kind, AF, FF]).

%   The permission rule of an action: none of its constraints applies.
permission_rule(Items, AF, N, rule(Head, Body, [comment(Cm)])) :-
    functor(Act, AF, N),
    Act =.. [_|Args],
    permission_functor(AF, MayF),
    Head =.. [MayF|Args],
    %  (findall copies what it collects: the action comes back with each
    %  constraint and is unified with the head's afterwards)
    findall(A1-not(C),
            ( member(lps(d_pre(Cs0)), Items),
              single_event_constraint(Cs0, happens(A, T1, _), Gs),
              copy_term(A-T1-Gs, A1-T11-Gs1), functor(A1, AF, N),
              timeless_conds(Gs1, T11, Cs), Cs \== [],
              conj_list(Cs, C) ),
            Pairs),
    pairs_keys_values(Pairs, Acts, Nots0),
    maplist(=(Act), Acts),
    maplist(simplify_not, Nots0, Nots1),
    role_checks(Items, Nots1, Args, Nots2),
    maplist(readable_condition(Args), Nots2, Nots),
    (   Nots == [] -> Body = true
    ;   conj_list(Nots, Body)
    ),
    legal_word(legal_permission_comment, CW),
    permission_phrase(Items, AF, Phrase),
    format(string(Cm0), CW, [Phrase]),
    (   member(lps(d_pre(Cs1)), Items), memberchk(happens(A2, _, _), Cs1), functor(A2, AF, N),
        \+ single_event_constraint(Cs1, _, _)
    ->  legal_word(legal_concurrency_comment, CC), format(string(Cm), "~w~n~w", [Cm0, CC])
    ;   Cm = Cm0
    ).

%   What the comment above a permission rule names: the action's own words
%   in the base form (`transfer an amount to a recipient`) when its template
%   starts with the actor and a verb, else the action's name.
permission_phrase(Items, AF, Phrase) :-
    (   member(action(AF, Text, _), Items),
        actor_verb(Text, _, Verb, Rest), base_form(Verb, Base)
    ->  split_string(Rest, "*", "", Parts), atomic_list_concat(Parts, '', Rest1),
        join_words([Base, Rest1], Phrase)
    ;   Phrase = AF
    ).

%   A constraint about one action (or event) happening: it restricts who may
%   do it. One about two happening together restricts concurrency, which a
%   permission of one action cannot state; it is left out, and said so.
single_event_constraint(Cs, happens(A, T1, T2), Gs) :-
    select(happens(A, T1, T2), Cs, Gs),
    \+ memberchk(happens(_, _, _), Gs).

%   The effect rules of an action: one per law (and for an update of an entry
%   that may be absent, one more with its zero default), the materialisation
%   of a zero default aside. The head is a first-order template: the action's
%   places, then the fluent's.
effect_rule(Items, AF, N, rule(Head, Body, [])) :-
    member(lps(Law), Items),
    law_effect(Law, A, T1, Kind, F, Gs0),
    functor(A, AF, N),
    copy_term(A-T1-F-Gs0, A1-T11-F1-Gs1),
    A1 =.. [_|Args],
    F1 =.. [FF|FArgs],
    effect_functor(Kind, AF, FF, HF),
    append(Args, FArgs, HArgs),
    Head =.. [HF|HArgs],
    timeless_conds(Gs1, T11, Cs),
    ( Cs == [] -> Body = true ; conj_list(Cs, Body) ).

law_effect(initiated(happens(A, T1, _), F, Gs), A, T1, results, F, Gs) :-
    \+ materialisation(F, Gs, T1).
law_effect(terminated(happens(A, T1, _), F, Gs), A, T1, ends, F, Gs).
law_effect(updated(happens(A, T1, _), F, Old-New, Gs), A, T1, results, F1, Conds) :-
    F =.. L, append(Front, [Old], L), append(Front, [New], L1), F1 =.. L1,
    append(Front, [_], L0), F0 =.. L0,
    (   Conds = [holds(F, T1)|Gs]                     % the entry is there
    ;   \+ ( member(holds(G, T), Gs), T == T1, G =@= F0 ),
        Old = 0, Conds = [holds(not(F0), T1)|Gs]      % or not: its zero default
    ).

%   `the balance of R is 0` when it does not hold yet: a default, not an effect.
materialisation(F, Gs, T1) :-
    F =.. [N|As], last(As, 0),
    member(holds(not(G), T), Gs), T == T1,
    G =.. [N|_].

%   LPS conditions at the call's start time as timeless conditions. An LPS
%   aggregate (a findall inside holds/2, then its reduction) is LE's own
%   (`agg(Op, Element, Goal, Result)`: `N is the count of each E such that …`).
timeless_conds([], _, []).
timeless_conds([holds(findall(E, Gs, L), T), Red|Rest], T1, [agg(Op, E, G, R)|Cs]) :-
    T == T1, nonvar(Red), Red =.. [Pred, L2, R], L2 == L,
    memberchk(Pred-Op, [length-count, sum_list-sum, max_list-max, min_list-min, mean_list-average]),
    is_list(Gs), !,
    timeless_conds(Gs, T1, GCs),
    ( GCs == [] -> G = true ; conj_list(GCs, G) ),
    timeless_conds(Rest, T1, Cs).
timeless_conds([G|Gs], T1, Cs) :-
    (   G = holds(not(F), T), T == T1 -> C = not(F)
    ;   G = holds(F, T), T == T1 -> C = F
    ;   G = (X is E) -> C = le_assign(X, E)
    ;   C = G
    ),
    timeless_conds(Gs, T1, Cs0),
    Cs = [C|Cs0].

%   Left-associated, as LE reads sibling lines: and(and(A, B), C).
conj_list([], true).
conj_list([C|Cs], R) :- foldl(and_acc, Cs, C, R).
and_acc(X, Acc, and(Acc, X)).

%   `it is not the case that (the owner is an account and the account is not
%   the caller)` together with `it is not the case that it is not the case
%   that the owner is something` is `the owner is the caller`: the caller is
%   then named by the rule rather than left to a negation (which would leave
%   it unbound — "who may pause?" would have no one for an answer).
%   A fluent with no key and a default (`the owner of the token is *an
%   account*; the zero address by default`) always has exactly one value, so
%   the first negation alone says the same.
role_checks(Prog, Items0, Args, Items) :-
    select(not(and(F, Neq)), Items0, Items1),
    neq_parts(Neq, X, C),
    var(X), var(C), memberchk_eq(C, Args),
    compound(F), F =.. [FN|FA], append(Keys, [V], FA), V == X,
    (   select(E, Items1, Items2),
        compound(E), E =.. [FN|EA], append(EKeys, [_], EA), EKeys =@= Keys, EKeys = Keys
    ->  true
    ;   Keys == [], memberchk(scalar_default(FN, _), Prog)
    ->  Items2 = Items1
    ),
    !,
    append(Keys, [C], FA2), F2 =.. [FN|FA2],
    role_checks(Prog, [F2|Items2], Args, Items).
role_checks(_, Items, _, Items).

neq_parts(X \= C, X, C).
neq_parts(C \= X, X, C).

memberchk_eq(X, [Y|Ys]) :- ( X == Y -> true ; memberchk_eq(X, Ys) ).

simplify_not(not(not(F)), F) :- !.
simplify_not(N, N).

%   A permission condition said positively, the same condition. A constraint
%   is "it is not the case that <its conditions>", and read literally that
%   stacks negations ("it is not the case that it is not the case that the
%   balance of the sender is …"). So:
%     - a negated comparison is the opposite comparison (not N > M: N =< M);
%     - not (C1 and ... and Cn) with no value read in it is "either not C1
%       or ... or not Cn", each said positively;
%     - not (R and T) where R reads values the head does not name (the
%       balance of the sender is an amount M) is "for all cases in which R
%       it is the case that <not T>", said positively: the value, whatever it
%       is, passes the tests.
readable_condition(Args, not(C), R) :- !,
    (   negated(C, R0) -> R = R0
    ;   conj_items(C, Cs),
        partition(reads_new_value(Args, Cs), Cs, Readers, Tests),
        (   Readers == []
        ->  maplist(negated_or_not, Tests, Ns), disj_list(Ns, R)
        ;   Tests \== [],
            maplist(negated_or_not, Tests, Ns), disj_list(Ns, G),
            conj_list(Readers, Cond),
            R = forall(Cond, G)
        ->  true
        ;   R = not(C)
        )
    ).
readable_condition(_, C, C).

%   the opposite of a comparison, or of a negation
negated(not(F), F) :- !.
negated(A < B, A >= B).
negated(A > B, A =< B).
negated(A =< B, A > B).
negated(A >= B, A < B).
negated(A = B, A \= B).
negated(A \= B, A = B).
negated(le_lt(A, B), A >= B).
negated(le_gt(A, B), A =< B).

negated_or_not(C, N) :- ( negated(C, N0) -> N = N0 ; N = not(C) ).

%   a condition that reads a value into a variable the rule's head does not
%   name, and that the conditions before it have not read either
reads_new_value(Args, Cs, C) :-
    \+ negated(C, _),
    C \= not(_),
    term_variables(C, Vs),
    member(V, Vs), \+ memberchk_eq(V, Args),
    \+ ( member(Before, Cs), Before \== C, before(Before, C, Cs),
          term_variables(Before, BVs), memberchk_eq(V, BVs) ), !.

before(X, Y, [Z|Zs]) :- ( Z == X -> true ; Z \== Y, before(X, Y, Zs) ).

conj_items(and(A, B), Cs) :- !, conj_items(A, CA), conj_items(B, CB), append(CA, CB, Cs).
conj_items(C, [C]).

disj_list([C], C) :- !.
disj_list([C|Cs], or(C, R)) :- disj_list(Cs, R).

		 /*******************************
		 *    SCENARIOS AND QUESTIONS   *
		 *******************************/

%   The program's initial state, as a scenario.
default_scenarios(Items, Scenarios) :-
    (   member(lps(initial_state(Fs0)), Items), Fs0 \== []
    ->  with_scalar_defaults(Items, Fs0, Fs),
        findall(fact(F), member(F, Fs), Lines),
        legal_word(legal_initial_scenario, SN),
        Scenarios = [scenario(SN, Lines, [])]
    ;   Scenarios = []
    ).

%!  run_calls(+Items, +States, +Happened, -Scenarios, -Queries) is det.
%
%   One scenario per call the program observes, in time order, and its
%   questions (see run(States, Happened) in the module header).
run_calls(Items, States, Happened, Scenarios, Queries) :-
    findall(T2-E, ( member(lps(observe(Es, T2)), Items), member(E, Es),
                    compound(E), functor(E, AF, _), memberchk(action(AF, _, _), Items) ), Calls0),
    msort_stable(Calls0, Calls),
    findall(S-Qs, ( nth1(I, Calls, T2-E), T1 is T2 - 1,
                    run_call(Items, I, E, T1, T2, States, Happened, S, Qs) ), Pairs),
    pairs_keys_values(Pairs, Scenarios, QLs),
    append(QLs, Queries).

%   By time, keeping the program's order within one time.
msort_stable(Pairs, Sorted) :-
    findall(T-(I-E), nth1(I, Pairs, T-E), Keyed),
    msort(Keyed, S0),
    findall(T-E, member(T-(_-E), S0), Sorted).

run_call(Items, I, E, T1, T2, States, Happened, scenario(SN, Lines, []), Qs) :-
    call_stem(I, Stem),
    format(atom(SN), 'before_~w', [Stem]),
    state_at(States, T1, Before0),
    with_scalar_defaults(Items, Before0, Before),
    (   memberchk(T2-Es, Happened), memberchk(E, Es) -> Accepted = true ; Accepted = false ),
    state_at(States, T2, After),
    call_queries(Items, [E], [names([Stem])], Qs0),
    format(atom(MayQ), 'may_~w', [Stem]),
    format(atom(FlipQ), 'flip_~w', [Stem]),
    E =.. [AF|Args], permission_functor(AF, MayF), May =.. [MayF|Args],
    (   Accepted == true
    ->  exclude(query_named(FlipQ), Qs0, Qs),
        MayExp = expects(MayQ, [May]),
        findall(expects(QN, Answers),
                ( member(query(QN, G), Qs), G \= flip(_), G \= May,
                  effect_answers(G, AF, Before, After, Answers) ),
                EffExps)
    ;   include(query_named_in([MayQ, FlipQ]), Qs0, Qs),
        MayExp = expects(MayQ, []), EffExps = []
    ),
    findall(fact(F), member(F, Before), Facts),
    ( Accepted == true -> legal_word(legal_call_accepted, AW) ; legal_word(legal_call_refused, AW) ),
    legal_word(legal_call_comment, CW),
    format(atom(Cmt), CW, [I, E, AW]),
    append([[comment(Cmt)], Facts, [MayExp], EffExps], Lines).

query_named(N, query(N, _)).
query_named_in(Ns, query(N, _)) :- memberchk(N, Ns).

%   The effect answers an accepted call should give: its effect literal for
%   each entry of the fluent the call created (results) or removed (ends).
effect_answers(G, AF, Before, After, Answers) :-
    G =.. [EF|HArgs],
    member(Kind, [results, ends]),
    format(atom(Pre), '~w_~w_', [Kind, AF]),
    atom_concat(Pre, FF, EF), !,
    findall(G1,
            ( ( Kind == results -> member(F, After), \+ memberchk(F, Before)
              ; member(F, Before), \+ memberchk(F, After) ),
              F =.. [FF|FArgs],
              length(FArgs, NF), length(FVars, NF),
              append(CallArgs, FVars, HArgs),
              append(CallArgs, FArgs, HArgs1), G1 =.. [EF|HArgs1] ),
            Answers).

%   The state at time T: the last one recorded at or before it.
%   A state with the default of each fluent with no key and no stored value
%   (`the owner of the token is the zero address`, when there is no owner).
with_scalar_defaults(Items, State0, State) :-
    findall(D, ( member(scalar_default(F, D), Items), \+ ( member(S, State0), functor(S, F, 1) ) ), Ds),
    append(State0, Ds, State).

state_at(States, T, State) :-
    findall(T0-S, ( member(T0-S, States), T0 =< T ), Earlier),
    ( last(Earlier, _-State) -> true ; State = [] ).

%   The calls the program observes, first occurrence of each action.
default_queries(Items, Queries) :-
    findall(T-E, ( member(lps(observe(Es, T)), Items), member(E, Es),
                   compound(E), functor(E, AF, _), memberchk(action(AF, _, _), Items) ), Calls0),
    keysort(Calls0, Calls1), pairs_values(Calls1, Calls2),
    first_per_action(Calls2, Calls),
    call_queries(Items, Calls, [], Queries).

first_per_action([], []).
first_per_action([E|Es], [E|Rest]) :-
    functor(E, F, N),
    exclude(same_functor(F/N), Es, Es1),
    first_per_action(Es1, Rest).

same_functor(F/N, X) :- functor(X, F, N).

call_stem(I, S) :- format(atom(S), 'call_~w', [I]).

%!  call_queries(+Items, +Calls, +Options, -Queries) is det.
%
%   For each (ground) call: may_<n> "may <the call>?", flip_<n> "what would
%   make it permitted", and one effect query per fluent its laws touch
%   (effect_<n>_<fluent>, effect_<n>_<fluent>_ends). Options: names(Names)
%   (one name stem per call; default call_1, call_2, ...).
call_queries(_, [], _, []) :- !.
call_queries(Items, Calls, Options, Queries) :-
    length(Calls, NC),
    (   option(names(Names), Options) -> true
    ;   numlist(1, NC, Ns), maplist(call_stem, Ns, Names)
    ),
    findall(Q, ( nth1(I, Calls, E), nth1(I, Names, Stem), call_query(Items, Stem, E, Q) ), Queries).

call_query(Items, Stem, E, query(QN, Goal)) :-
    E =.. [AF|Args],
    permission_functor(AF, MayF),
    May =.. [MayF|Args],
    (   format(atom(QN), 'may_~w', [Stem]), Goal = May
    ;   format(atom(QN), 'flip_~w', [Stem]), Goal = flip(May)
    ;   effect_kind_fluent(Items, AF, Kind, FF, FN),
        effect_functor(Kind, AF, FF, EF),
        length(FArgs, FN), append(Args, FArgs, HArgs), Goal =.. [EF|HArgs],
        ( Kind == results -> format(atom(QN), 'effect_~w_~w', [Stem, FF])
        ; format(atom(QN), 'effect_~w_~w_ends', [Stem, FF]) )
    ).

effect_kind_fluent(Items, AF, Kind, FF, FN) :-
    findall(Kind0-FF0/FN0,
            ( member(lps(Law), Items),
              law_effect(Law, A, _, Kind0, F, _),
              functor(A, AF, _), functor(F, FF0, FN0) ),
            KFs0),
    list_to_set(KFs0, KFs),
    member(Kind-FF/FN, KFs).

		 /*******************************
		 *           WORDING            *
		 *******************************/

legal_lang(Lang) :- ( nb_current(le_lps_legal_lang, L), L \== [] -> Lang = L ; Lang = en ).

legal_word(Key, Word) :-
    legal_lang(Lang),
    (   le_writer:writer_word(Key, Lang, W) -> true
    ;   le_writer:writer_word(Key, en, W)
    ),
    atom_string(W, Word).

%   `*a sender* transfers *an amount* to *a recipient*`
%       -> `*a sender* may transfer *an amount* to *a recipient*`
%   or `it is allowed that *a sender* transfers ...`.
permission_text(Text, MayT) :-
    (   actor_verb(Text, Actor, Verb, Rest), base_form(Verb, Base)
    ->  legal_word(legal_may, May),
        join_words([Actor, May, Base, Rest], MayT)
    ;   legal_word(legal_allowed, Allowed),
        join_words([Allowed, Text], MayT)
    ).

%   `*a sender* transferring *an amount* to *a recipient*`, or fail.
gerund_text(Text, G) :-
    actor_verb(Text, Actor, Verb, Rest), base_form(Verb, Base), gerund(Base, Ger),
    join_words([Actor, Ger, Rest], G).

%   An English template that starts with its actor (a place) and a verb.
actor_verb(Text, Actor, Verb, Rest) :-
    legal_lang(en),
    string_concat("*", R0, Text),
    sub_string(R0, B, _, A0, "*"), !,
    sub_string(R0, 0, B, _, ActorIn), format(string(Actor), "*~w*", [ActorIn]),
    sub_string(R0, _, A0, 0, After0),
    split_string(After0, " ", " ", Ws0), exclude(==(""), Ws0, [Verb|RestWs]),
    Verb \= "",
    atomic_list_concat(RestWs, ' ', RestA), atom_string(RestA, Rest).

join_words(Ws0, Text) :-
    exclude(==(""), Ws0, Ws), atomic_list_concat(Ws, ' ', A), atom_string(A, Text).

%   English third person singular -> base form; fails for a word that is not
%   one (so the template takes the fixed wording).
base_form(V, B) :- irregular_base(V, B), !.
base_form(V, B) :-
    string_length(V, L), L > 3,
    (   string_concat(S, "ies", V), string_length(S, SL), SL > 1 -> string_concat(S, "y", B)
    ;   member(E, ["sses", "shes", "ches", "xes", "zes", "oes"]), string_concat(S0, E, V)
    ->  sub_string(E, 0, _, 2, Keep), string_concat(S0, Keep, B)
    ;   string_concat(S, "s", V), \+ string_concat(_, "ss", V),
        \+ string_concat(_, "us", V), \+ string_concat(_, "is", V)
    ->  B = S
    ).

irregular_base("is", "be").
irregular_base("has", "have").
irregular_base("does", "do").
irregular_base("goes", "go").

gerund("be", "being") :- !.
gerund(B, G) :-
    (   string_concat(S, "ie", B) -> string_concat(S, "ying", G)
    ;   ( string_concat(_, "ee", B) ; string_concat(_, "oe", B) ; string_concat(_, "ye", B) )
    ->  string_concat(B, "ing", G)
    ;   string_concat(S, "e", B), string_length(S, SL), SL > 1 -> string_concat(S, "ing", G)
    ;   doubles_final(B) -> sub_string(B, _, 1, 0, C), string_concat(B, C, B1), string_concat(B1, "ing", G)
    ;   string_concat(B, "ing", G)
    ).

%   The final consonant doubles before -ing: a one-syllable consonant-vowel-
%   consonant word (stop, set), or a verb stressed on its last syllable
%   (i18n/writer_words.csv, legal_doubling_verbs).
doubles_final(B) :-
    legal_word(legal_doubling_verbs, Ws), split_string(Ws, "|", " ", L), memberchk(B, L), !.
doubles_final(B) :-
    string_chars(B, Cs), append(_, [V0, V, C], Cs),
    \+ vowel(V0), vowel(V), \+ vowel(C), \+ memberchk(C, [w, x, y]),
    include(vowel, Cs, Vs), length(Vs, 1).

vowel(C) :- memberchk(C, [a, e, i, o, u]).

%   The words of an effect template: the action's gerund, then the fluent's
%   sentence with its first `is` as `being` (`no longer being` for an end).
effect_template_text(Items, Actions, EF, Text) :-
    member(a(AF, _, AText), Actions),
    member(fluent(FF, FText, _), Items),
    member(Kind, [results, ends]),
    effect_functor(Kind, AF, FF, EF), !,
    (   gerund_text(AText, GT),
        fluent_being(Kind, FText, FB)
    ->  legal_word(legal_results_in, RI),
        join_words([GT, RI, FB], Text)
    ;   Kind == results
    ->  legal_word(legal_has_result, HR), join_words([AText, HR, FText], Text)
    ;   legal_word(legal_ends_that, ET), join_words([AText, ET, FText], Text)
    ).

fluent_being(Kind, FText, FB) :-
    ( Kind == results -> legal_word(legal_being, Being) ; legal_word(legal_no_longer_being, Being) ),
    (   sub_string(FText, B, 4, A, " is ")
    ->  sub_string(FText, 0, B, _, L), sub_string(FText, _, A, 0, R),
        join_words([L, Being, R], FB)
    ;   sub_string(FText, B, 3, 0, " is")
    ->  sub_string(FText, 0, B, _, L), join_words([L, Being], FB)
    ;   actor_verb(FText, Actor, Verb, Rest), base_form(Verb, Base), gerund(Base, G)
    ->  (   Kind == results -> join_words([Actor, G, Rest], FB)
        ;   legal_word(legal_no_longer, NL), join_words([Actor, NL, G, Rest], FB)
        )
    ).

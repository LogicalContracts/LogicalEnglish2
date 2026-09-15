/** <module> LPS internal syntax back to Logical English

    `dump_le`: the direction docs/LPSplusLLM.md §I.9.5 asks for, and the reason
    it lives here rather than in LPS(2) — LE2 owns the template dictionary, so
    LE2 owns the only mapping that can be inverted. A template is what tells
    `played(miguel, rock)` from `beats(rock, scissors)`; without one there is
    nothing to write back *to*.

    ## What it is for

    §I.9.5 makes the round trip a TEST, not a feature. The claim it checks is:

	LE  ->  internal  ->  LE  ->  internal      the two internal forms are
						   variant/2-equal

    That is a real claim about the language — it says the internal form carries
    everything the English did, up to the choices this writer makes about
    wording and variable names — and it is checked by testing/lps_roundtrip.pl
    over the same fifteen programs M8c uses.

    It deliberately does NOT claim the two ENGLISH texts are equal. They are
    not, and could not be: `a first player` and `a player` are the same
    variable, `the reward is 0` and `the reward is 0 at time 1` are the same
    initial state, and a document's comments, section order and choice of
    synonym are not recoverable from the terms. Comparing the internal forms is
    the strongest claim that is actually true.

    ## How variables are named

    Every variable in a term gets an English name from the TYPE of the argument
    position it first appears in, taken from the template dictionary: the first
    variable of type `player` is `a player`, the second `a second player`, and
    every later occurrence is `the player` / `the second player`. Times are
    typed `time` by construction. A variable in no typed position is `a thing`.

    This is what makes the round trip meaningful rather than circular: the
    names are derived from the templates, not carried over from the source, so
    a program that survives has survived losing them.
*/

:- module(le_lps_write, [
    le_lps_document/3,           % +KBModule, +InternalTerms, -LEText
    le_lps_dump/2,               % +KBModule, -LEText
    le_lps_sentence/3            % +KBModule, +InternalTerm, -Sentence
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(le_grammar).
:- use_module(le_i18n).
:- use_module(le_kbs).
:- use_module(le_lps).
:- use_module(le_system_templates).
:- use_module(library(pairs)).

		 /*******************************
		 *	  the whole document	*
		 *******************************/

%!  le_lps_dump(+KB, -Text) is det.
%
%   The knowledge base as Logical English, by way of its own internal form.
le_lps_dump(KB, Text) :-
	le_lps:le_lps_module(KB, "", Internal, _, _),
	internal_terms(Internal, Terms),
	le_lps_document(KB, Terms, Text).

internal_terms(Internal, Terms) :-
	setup_call_cleanup(open_string(Internal, In), read_all(In, Terms), close(In)).

read_all(In, Terms) :-
	read_term(In, T, [module(le_lps_write)]),
	( T == end_of_file -> Terms = [] ; Terms = [T|Rest], read_all(In, Rest) ).

%!  le_lps_document(+KB, +Terms, -Text) is det.
le_lps_document(KB, Terms, Text) :-
	%  the fluents' defaults (`defaults/1`), for their declaration lines
	( memberchk(defaults(Ds), Terms) -> true ; Ds = [] ),
	b_setval(le_lps_write_defaults, Ds),
	partition_terms(Terms, P),
	with_output_to(string(Text), write_document(KB, P)).

%   p(Settings, Fluents, Events, Actions, PrologEvents, Body, Observations)
partition_terms(Terms, p(S, F, E, A, PE, Body, Obs)) :-
	findall(T, ( member(T, Terms), setting_term(T) ), S),
	decls(Terms, fluents, F),
	decls(Terms, events, E),
	decls(Terms, actions, A),
	decls(Terms, prolog_events, PE),
	findall(observe(Es, T2), member(observe(Es, T2), Terms), Obs),
	findall(T, ( member(T, Terms), body_term(T) ), Body).

decls(Terms, Which, L) :-
	D =.. [Which, L0],
	( memberchk(D, Terms) -> L = L0 ; L = [] ).

setting_term(maxTime(_)).
setting_term(maxRealTime(_)).
setting_term(minCycleTime(_)).

body_term(T) :-
	\+ setting_term(T),
	functor(T, F, N),
	\+ memberchk(F/N, [fluents/1, events/1, actions/1, prolog_events/1,
			   observe/2, (:-)/1, defaults/1]).

write_document(KB, p(Settings, F, E, A, PE, Body, Obs)) :-
	format('the target language is: lps.~n~n'),
	forall(member(S, Settings), write_setting(S)),
	( Settings == [] -> true ; nl ),
	write_section(KB, 'the events are', E),
	write_section(KB, 'the actions are', A),
	write_section(KB, 'the prolog events are', PE),
	write_section(KB, 'the fluents are', F),
	timeless_templates(KB, [F, E, A, PE], Timeless0),
	partition(constant_template(KB), Timeless0, Constants, Timeless),
	write_section(KB, 'the templates are', Timeless),
	partition(constant_fact(KB, Constants), Body, ConstFacts, Body1),
	write_constants(KB, ConstFacts),
	format('the knowledge base lps includes:~n~n'),
	forall(member(T, Body1), write_sentence(KB, T)),
	( Obs == [] -> true ; write_scenario(KB, Obs) ).

%   A named constant (`the constants are:`): a one-place timeless template
%   that defines a global, and its fact.
constant_template(KB, T) :-
	functor(T, F, 1), rename_in(KB, T, T1), functor(T1, F1, 1),
	current_predicate(KB:le_dict/1),
	KB:le_dict(D), D =.. [dict, [F1, _], _, _, [_|_]|_], !,
	F = F.

constant_fact(KB, Constants, Fact) :-
	compound(Fact), functor(Fact, F, 1), arg(1, Fact, V), atomic(V),
	member(C, Constants), functor(C, F, 1), !,
	KB = KB.

write_constants(_, []) :- !.
write_constants(KB, Facts) :-
	format('the constants are:~n'),
	forall(( member(Fact, Facts), functor(Fact, F, 1), arg(1, Fact, V),
		 functor(G, F, 1), global_goal(KB, G, _, Name) ),
	       ( ( string(V) -> format(atom(VT), '"~w"', [V]) ; format(atom(VT), '~w', [V]) ),
		 format('    ~w is ~w.~n', [Name, VT]) )),
	nl.

write_setting(maxTime(N))       :- format('the maximum time is ~w.~n', [N]).
write_setting(maxRealTime(N))   :- format('the maximum real time is ~w.~n', [N]).
write_setting(minCycleTime(N))  :- format('the minimum cycle time is ~w.~n', [N]).

write_section(_, _, []) :- !.
write_section(KB, Header, Terms) :-
	format('~w:~n', [Header]),
	forall(member(T, Terms), write_template(KB, T)),
	nl.

%   A declaration line is the template as the author wrote it, with `*slots*`
%   restored from the dictionary, the `; known as f` binding restored when
%   the functor is not the one LE2 would have derived, and a fluent's
%   default (`; 0 by default`).
write_template(KB, Term) :-
	functor(Term, F, N),
	(   template_words(KB, F/N, Derived/N, Words)
	->  atomic_list_concat(Words, ' ', Line),
	    ( Derived == F -> Known = '' ; format(atom(Known), '; known as ~w', [F]) ),
	    (   nb_current(le_lps_write_defaults, Ds), is_list(Ds),
		member(D, Ds), functor(D, F, N)
	    ->  arg(N, D, V),
		( string(V) -> format(atom(VT), '"~w"', [V]) ; format(atom(VT), '~w', [V]) ),
		format(atom(Def), '; ~w by default', [VT])
	    ;   Def = ''
	    ),
	    format('    ~w~w~w.~n', [Line, Known, Def])
	;   format('    % no template for ~w/~w~n', [F, N])
	).

%   The dictionary is keyed by the DERIVED functor; `; known as f` renamed it,
%   so the search goes through le_lps_functor/2 in reverse.
template_words(KB, F/N, Derived/N, Words) :-
	(   current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(Derived/N, F)
	->  true
	;   Derived = F
	),
	dict_of(KB, Derived/N, dict_wv(WV, NTs)),
	slot_words(WV, NTs, Words).

dict_of(KB, F/N, dict_wv(WV, NTs)) :-
	current_predicate(KB:le_dict/1),
	KB:le_dict(D),
	D =.. [dict, [F|Args], NTs, WV|_],
	length(Args, N), !.

slot_words([], _, []).
slot_words([W|Ws], NTs, [Out|Rest]) :-
	(   var(W)
	->  ( slot_type(W, NTs, Type) -> true ; Type = thing ),
	    article_for(Type, Article),
	    format(atom(Out), '*~w ~w*', [Article, Type])
	;   Out = W
	),
	slot_words(Ws, NTs, Rest).

slot_type(V, NTs, Type) :- member(V0-Type, NTs), V0 == V, atom(Type), !.

article_for(Type, Article) :-
	( sub_atom(Type, 0, 1, _, C), memberchk(C, [a,e,i,o,u]) -> Article = an ; Article = a ).

%   Everything the program defines that is not a fluent, an event or an action.
timeless_templates(KB, Declared, Timeless) :-
	append(Declared, Roles),
	findall(T,
		( current_predicate(KB:le_dict/1), KB:le_dict(D),
		  D =.. [dict, [F|Args]|_],
		  \+ le_kbs:is_system_predicate(F/_),
		  \+ system_functor(F),
		  length(Args, N), functor(T0, F, N),
		  \+ ( member(R, Roles), functor(R, RF, N), lps_same(KB, RF/N, F/N) ),
		  rename_out(KB, T0, T) ),
		Ts),
	sort(Ts, Timeless).

%   The built-in comparison and assignment templates are LE2's, not the
%   program's; writing them back out would declare them twice.
system_functor(F) :-
	le_system_templates:le_system_template(D),
	D =.. [dict, [F|_]|_], !.

lps_same(KB, RF/N, F/N) :-
	(   current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(F/N, RF)
	->  true
	;   RF == F
	).

rename_out(KB, T0, T) :-
	T0 =.. [F0|Args],
	length(Args, N),
	(   current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(F0/N, F)
	->  T =.. [F|Args]
	;   T = T0
	).

write_scenario(KB, Obs) :-
	format('~nscenario one is:~n'),
	forall(member(observe(Events, T2), Obs),
	       forall(member(Ev, Events),
		      ( T1 is T2 - 1,
			naming(KB, Ev, Names),
			render(KB, Names, Ev, S),
			format('    ~w from ~w to ~w.~n', [S, T1, T2]) ))).


		 /*******************************
		 *	   one sentence		*
		 *******************************/

%!  le_lps_sentence(+KB, +Term, -Sentence) is semidet.
le_lps_sentence(KB, Term, Sentence) :-
	with_output_to(string(Sentence), write_sentence(KB, Term)).

write_sentence(KB, Term0) :-
	copy_term(Term0, Term),
	shorten_times(Term),
	naming(KB, Term, Names0),
	global_names(KB, Term, Names0, Names),
	(   sentence(KB, Names, Term, Text)
	->  format('~w~n~n', [Text])
	;   format('% not expressible in Logical English: ~q~n~n', [Term0])
	).

%!  global_goal(+KB, +Goal, -Var, -Name) is semidet.
%
%   Goal reads a named constant (`the constants are:`, or any template with
%   `; defines global Name`): LE inserts it where the name is used, and the
%   writer writes the name instead of the goal.
global_goal(KB, G, V, Name) :-
	compound(G), rename_in(KB, G, G1),
	G1 =.. [F, V], var(V),
	current_predicate(KB:le_dict/1),
	KB:le_dict(D), D =.. [dict, [F, _], _, _, [Name|_]|_], !.

%   Each variable a constant's goal binds is named by the constant.
global_names(KB, Term, Names0, Names) :-
	maplist(global_name_of(KB, Term), Names0, Names).

global_name_of(KB, Term, V-M0, V-M) :-
	(   sub_term(G, Term), global_goal(KB, G, V1, Name), V1 == V
	->  M = m(Name, seen)
	;   M = M0
	).

%!  shorten_times(!Term) is det.
%
%   The times a sentence need not name, bound to markers the renderer leaves
%   out (docs/le_lps_surface.md §3.1):
%
%     - a causal law or a constraint whose conditions all read the state at
%       the start of its one event, and which uses the event's end nowhere,
%       is written with no times at all — `when a sender transfers …`,
%       `it must not be true that a sender transfers … and the balance of the
%       sender is …` — which LE-for-LPS reads back as exactly the same term.
%       So is an invariant whose conditions all read one state;
%     - elsewhere, an event whose end is named nowhere else is written
%       `… from T`, and one whose start is named nowhere else `… to T`.
%
%   Times stay wherever a sentence relates two moments.
shorten_times(Term) :-
	(   elided_times(Term) -> true ; true ),
	open_event_times(Term).

elided_times(Term) :-
	causal_trigger(Term, happens(E, T1, T2), Rest),
	var(T1), var(T2), T1 \== T2,
	\+ occurs_var(T1, E), \+ occurs_var(T2, E),
	\+ occurs_var(T2, Rest),
	only_state_time(Rest, T1), !,
	T1 = lps_now, T2 = lps_now.
elided_times(d_pre(Cs)) :-
	select(happens(E, T1, T2), Cs, Gs),
	\+ memberchk(happens(_, _, _), Gs),
	var(T1), var(T2), T1 \== T2,
	\+ occurs_var(T1, E), \+ occurs_var(T2, E),
	\+ occurs_var(T2, Gs),
	only_state_time(Gs, T1), !,
	T1 = lps_now, T2 = lps_now.
elided_times(d_pre(Cs)) :-
	\+ memberchk(happens(_, _, _), Cs),
	once(member(holds(_, T), Cs)), var(T),
	only_state_time(Cs, T), !,
	T = lps_now.

causal_trigger(initiated(Tr, F, Cs), Tr, F-Cs).
causal_trigger(terminated(Tr, F, Cs), Tr, F-Cs).
causal_trigger(updated(Tr, F, Ch, Cs), Tr, F-Ch-Cs).
causal_trigger(effects(Tr, Cs, Es), Tr, Es-Cs).

%   T occurs in Goals only as the time of a holds/2 (also inside an
%   aggregate's findall), and at least nowhere else.
only_state_time(Goals, T) :-
	untime(T, Goals, G),
	\+ occurs_var(T, G).

untime(T, G0, G) :-
	(   var(G0) -> G = G0
	;   G0 = holds(F0, T0), T0 == T -> untime(T, F0, F), G = holds(F, lps_now)
	;   compound(G0) -> G0 =.. [N|As0], maplist(untime(T), As0, As), G =.. [N|As]
	;   G = G0
	).

occurs_var(V, T) :- sub_term(S, T), S == V, !.

%   `happens(E, T1, T2)` with T2 mentioned nowhere else: `… from T1`; with
%   T1 mentioned nowhere else: `… to T2`.
%   (Bound in place, not with forall/2, which would undo the bindings.)
open_event_times(Term) :-
	happens_terms(Term, [], Hs),
	maplist(open_end(Term), Hs),
	maplist(open_start(Term), Hs).

open_end(Term, happens(_, A, B)) :-
	(   var(A), var(B), A \== B, once_in(B, Term) -> B = lps_open ; true ).
open_start(Term, happens(_, A, B)) :-
	(   var(A), B \== lps_open, once_in(A, Term) -> A = lps_open ; true ).

happens_terms(T, Acc, Out) :-
	(   var(T) -> Out = Acc
	;   T = happens(_, _, _) -> Out = [T|Acc]
	;   compound(T) -> T =.. [_|As], foldl(happens_terms_, As, Acc, Out)
	;   Out = Acc
	).
happens_terms_(A, Acc, Out) :- happens_terms(A, Acc, Out).

once_in(V, Term) :-
	aggregate_all(count, ( sub_term(S, Term), S == V ), 1).

%   The time suffix of an event (`from T1 to T2`, `from T1`, `to T2`, or none)
%   and of a state (`at T`, or none).
event_times(_, T1, _, '') :- T1 == lps_now, !.
event_times(Ns, T1, T2, S) :- T2 == lps_open, !, name_of(Ns, T1, S1), format(atom(S), ' from ~w', [S1]).
event_times(Ns, T1, T2, S) :- T1 == lps_open, !, name_of(Ns, T2, S2), format(atom(S), ' to ~w', [S2]).
event_times(Ns, T1, T2, S) :- name_of(Ns, T1, S1), name_of(Ns, T2, S2), format(atom(S), ' from ~w to ~w', [S1, S2]).

state_time(_, T, '') :- T == lps_now, !.
state_time(Ns, T, S) :- name_of(Ns, T, TS), format(atom(S), ' at ~w', [TS]).

sentence(KB, Ns, initial_state(Fs), Text) :- !,
	maplist(render(KB, Ns), Fs, Ss),
	join(Ss, '\n    and ', Body),
	format(atom(Text), 'initially ~w.', [Body]).

sentence(KB, Ns, achieve(Fs), Text) :- !,
	maplist(render(KB, Ns), Fs, Ss),
	join(Ss, '\n    and ', Body),
	format(atom(Text), 'the goal is that ~w.', [Body]).

sentence(KB, Ns, d_pre(Cs0), Text) :- !,
	fold_aggregates(Cs0, Cs),
	conditions(KB, Ns, Cs, Ss),
	join(Ss, '\n    and ', Body),
	format(atom(Text), 'it must not be true that\n    ~w.', [Body]).

sentence(KB, Ns, initiated(Trigger, F, Conds), Text) :- !,
	causal(KB, Ns, Trigger, Conds, Head),
	render(KB, Ns, F, S),
	format(atom(Text), '~w\nthen ~w.', [Head, S]).

sentence(KB, Ns, terminated(Trigger, F, Conds), Text) :- !,
	causal(KB, Ns, Trigger, Conds, Head),
	render(KB, Ns, F, S),
	format(atom(Text), '~w\nthen it is not the case that ~w.', [Head, S]).

%   Several effects of one event under the same conditions, one sentence
%   (docs/le_lps_surface.md §3.4: "several may be joined with `and`"; read
%   back, one law per effect): `effects(Trigger, Conds, [initiated(F),
%   terminated(G), ...])`, a writer's form, not an LPS term. The additions
%   come first.
sentence(KB, Ns, effects(Trigger, Conds, Effects), Text) :- !,
	causal(KB, Ns, Trigger, Conds, Head),
	partition([E]>>(E = initiated(_)), Effects, Adds, Dels),
	append(Adds, Dels, Es),
	maplist(effect_text(KB, Ns), Es, Ss),
	join(Ss, '\n    and ', Body),
	format(atom(Text), '~w\nthen ~w.', [Head, Body]).

sentence(KB, Ns, updated(Trigger, Fluent, Old-New, Conds), Text) :- !,
	%  The `New is Expr` goal the compiler added is the update's right-hand
	%  side; it is not a condition, and writing it as one would produce a
	%  program that does not round-trip.
	select_update_goal(Conds, New, Expr, Rest),
	causal(KB, Ns, Trigger, Rest, Head),
	render_update(KB, Ns, Fluent, Old, Expr, S),
	format(atom(Text), '~w\nthen ~w.', [Head, S]).

sentence(KB, Ns, reactive_rule(Ante0, Cons), Text) :- !,
	fold_aggregates(Ante0, Ante),
	conditions(KB, Ns, Ante, As),
	maplist(conclusion(KB, Ns), Cons, Cs),
	join(As, '\n    and ', A),
	join(Cs, '\n    and ', C),
	format(atom(Text), 'if ~w\nthen ~w.', [A, C]).

sentence(KB, Ns, l_int(holds(F, T), Body0), Text) :- !,
	fold_aggregates(Body0, Body),
	render(KB, Ns, F, S), name_of(Ns, T, TS),
	conditions(KB, Ns, Body, Bs),
	join(Bs, '\n    and ', B),
	( B == '' -> format(atom(Text), '~w at ~w.', [S, TS])
	; format(atom(Text), '~w at ~w if\n    ~w.', [S, TS, B]) ).

sentence(KB, Ns, l_events(happens(E, T1, T2), Body0), Text) :- !,
	fold_aggregates(Body0, Body),
	render(KB, Ns, E, S), event_times(Ns, T1, T2, TS),
	conditions(KB, Ns, Body, Bs),
	join(Bs, '\n    and ', B),
	format(atom(Text), '~w~w if\n    ~w.', [S, TS, B]).

sentence(KB, Ns, l_timeless(H, Body), Text) :- !,
	render(KB, Ns, H, S),
	conditions(KB, Ns, Body, Bs),
	join(Bs, '\n    and ', B),
	format(atom(Text), '~w if\n    ~w.', [S, B]).

sentence(KB, Ns, Fact, Text) :-
	callable(Fact), Fact \= (_ :- _),
	render(KB, Ns, Fact, S),
	format(atom(Text), '~w.', [S]).

effect_text(KB, Ns, initiated(F), S) :- render(KB, Ns, F, S).
effect_text(KB, Ns, terminated(F), S) :-
	render(KB, Ns, F, S0),
	format(atom(S), 'it is not the case that ~w', [S0]).

%   The trigger's times are written out unless shorten_times/1 found the law
%   needs none: a condition may share one -- upstream evaluates a causal law's
%   conditions at the event's start time -- and an unnamed variable comes back
%   as a different one.
causal(KB, Ns, happens(E, T1, T2), Conds0, Head) :-
	fold_aggregates(Conds0, Conds),
	render(KB, Ns, E, S),
	event_times(Ns, T1, T2, TS),
	conditions(KB, Ns, Conds, Cs),
	format(atom(Trigger), '~w~w', [S, TS]),
	( Cs == [] -> format(atom(Head), 'when ~w', [Trigger])
	; join(Cs, '\n    and ', C), format(atom(Head), 'when ~w\n    and ~w', [Trigger, C]) ).

select_update_goal(Conds, New, Expr, Rest) :-
	(   select(Goal, Conds, Rest0), nonvar(Goal), Goal = is(V, E), V == New
	->  Expr = E, Rest = Rest0
	;   Expr = New, Rest = Conds
	).

render_update(KB, Ns, Fluent, Old, Expr, S) :-
	%  Old is mentioned inside the literal, so its name is taken before.
	next_name_of(Ns, Old, OldName),
	render(KB, Ns, Fluent, FS),
	expr_text(Ns, Expr, ES),
	%  The literal is written with its Old slot in place; the relative
	%  clause re-states it, which is what the parser splits on.
	replace_last(FS, OldName, Prefix),
	format(atom(S), '~w that is ~w becomes ~w', [Prefix, OldName, ES]).

%   "the reward is a number" -> "the reward" (the parser puts the copula back)
replace_last(FS, OldName, Prefix) :-
	atomic_list_concat(Words, ' ', FS),
	atomic_list_concat(NameWords, ' ', OldName),
	append(Head0, Tail, Words),
	append(Copula, NameWords, Tail),
	Copula = [C], le_i18n:class_member(copula, C), !,
	atomic_list_concat(Head0, ' ', Prefix).
replace_last(FS, _, FS).


		 /*******************************
		 *   conditions and conclusions *
		 *******************************/

%   The emitter turns `R is the count of each E such that G` into two goals,
%   a findall inside holds/2 and a reduction; fold them back into one.
fold_aggregates([], []).
fold_aggregates([holds(findall(E, G, L1), T), Reduce|Rest], [agg(Op, E, G, T, R)|Out]) :-
	nonvar(Reduce), Reduce =.. [Pred, L2, R], L1 == L2,
	reduction(Pred, Op), !,
	fold_aggregates(Rest, Out).
fold_aggregates([C|Cs], [C|Out]) :- fold_aggregates(Cs, Out).

reduction(length, count).
reduction(sum_list, sum).
reduction(mean_list, average).
reduction(min_list, min).
reduction(max_list, max).

%   The conditions of a sentence, as text; a named constant's goal says
%   nothing of its own (the constant's name stands where its value is used).
conditions(KB, Ns, Goals, Texts) :-
	maplist(condition(KB, Ns), Goals, Texts0),
	exclude(==(''), Texts0, Texts).

condition(KB, _, G, '') :- global_goal(KB, G, _, _), !.
condition(KB, Ns, agg(Op, E, G, T, R), S) :- !,
	name_of(Ns, R, RS), name_of(Ns, E, ES),
	le_i18n:kw_main_words(is_the, IsThe), atomic_list_concat(IsThe, ' ', IsTheA),
	le_i18n:kw_main_words(Op, OpW), atomic_list_concat(OpW, ' ', OpA),
	le_i18n:kw_main_words(of_each, OfEach), atomic_list_concat(OfEach, ' ', OfEachA),
	le_i18n:kw_main_words(such_that, SuchThat), atomic_list_concat(SuchThat, ' ', SuchThatA),
	conditions(KB, Ns, G, Gs),
	join(Gs, '\n        and ', GS),
	format(atom(S), '~w ~w ~w ~w ~w ~w\n        ~w',
	       [RS, IsTheA, OpA, OfEachA, ES, SuchThatA, GS]),
	T = T.

condition(KB, Ns, holds(not(F), T), S) :- !,
	render(KB, Ns, F, FS), state_time(Ns, T, TS),
	format(atom(S), 'it is not the case that ~w~w', [FS, TS]).
condition(KB, Ns, holds(F, T), S) :- !,
	( F = findall(_, _, _) -> fail ; true ),
	render(KB, Ns, F, FS), state_time(Ns, T, TS),
	format(atom(S), '~w~w', [FS, TS]).
condition(KB, Ns, happens(not(E), T1, T2), S) :- !,
	render(KB, Ns, E, ES), event_times(Ns, T1, T2, TS),
	format(atom(S), 'it is not the case that ~w~w', [ES, TS]).
condition(KB, Ns, happens(E, T1, T2), S) :- !,
	render(KB, Ns, E, ES),
	event_times(Ns, T1, T2, TS),
	format(atom(S), '~w~w', [ES, TS]).
%   `member(X, L)`: LE's `X is in L`.
condition(_, Ns, member(X, L), S) :- !,
	expr_text(Ns, X, XS), expr_text(Ns, L, LS),
	format(atom(S), '~w is in ~w', [XS, LS]).
condition(_, Ns, Comparison, S) :-
	comparison(Comparison, X, Op, Y), !,
	expr_text(Ns, X, XS), expr_text(Ns, Y, YS),
	format(atom(S), '~w ~w ~w', [XS, Op, YS]).
%   A timeless negated condition (LE's `it is not the case that` with no time).
condition(KB, Ns, not(G), S) :-
	render(KB, Ns, G, GS), GS \== '', !,
	format(atom(S), 'it is not the case that ~w', [GS]).
condition(KB, Ns, G, S) :-
	render(KB, Ns, G, S0), S0 \== '', !, S = S0.
condition(_, _, G, S) :- format(atom(S), '% ~q', [G]).

comparison(X >= Y, X, '>=', Y).
comparison(X =< Y, X, '<=', Y).
comparison(X > Y,  X, '>',  Y).
comparison(X < Y,  X, '<',  Y).
%   `=` in LE is an assignment (le_assign, `is/2`); unification is
%   `is equal to` (le_equal_to).
comparison(X = Y,  X, 'is equal to',  Y).
comparison(X \= Y, X, 'is different from', Y).
comparison(is(X, Y), X, '=', Y).

conclusion(KB, Ns, happens(initiate(F), T1, T2), S) :- !,
	render(KB, Ns, F, FS), event_times(Ns, T1, T2, TS),
	format(atom(S), 'initiate ~w~w', [FS, TS]).
conclusion(KB, Ns, happens(terminate(F), T1, T2), S) :- !,
	render(KB, Ns, F, FS), event_times(Ns, T1, T2, TS),
	format(atom(S), 'terminate ~w~w', [FS, TS]).
conclusion(KB, Ns, G, S) :- condition(KB, Ns, G, S).

%   A whole term keeps its article -- `the amount >= 10` -- but the operands
%   INSIDE an arithmetic expression must be bare: LE2's expression parser
%   takes `price + tax`, not `the price + the tax` (see
%   examples/moreExamples/numbers.le). Dropping the article at the top level
%   too would turn every variable into a constant.
expr_text(Ns, T, S) :- var(T), !, name_of(Ns, T, S).
expr_text(_, T, S) :- number(T), !, format(atom(S), '~w', [T]).
expr_text(Ns, T, S) :- arith(T), !, expr_operand(Ns, T, S).
expr_text(_, T, S) :- format(atom(S), '~w', [T]).

arith(T) :- compound(T), T =.. [Op, _, _], memberchk(Op, [+, -, *, /, //, mod]).

expr_operand(Ns, T, S) :- var(T), !, name_of(Ns, T, S0), drop_article(S0, S).
expr_operand(_, T, S) :- number(T), !, format(atom(S), '~w', [T]).
expr_operand(Ns, T, S) :-
	arith(T), !, T =.. [Op, A, B],
	sub_operand(Ns, Op, left, A, AS), sub_operand(Ns, Op, right, B, BS),
	format(atom(S), '~w ~w ~w', [AS, Op, BS]).


expr_operand(_, T, S) :- format(atom(S), '~w', [T]).

%   An operand in parentheses where precedence or the non-associativity of
%   `-` and `/` needs them: `amount - (0 + total)`, not `amount - 0 + total`.
sub_operand(Ns, Op, Side, X, S) :-
	expr_operand(Ns, X, S0),
	(   arith(X), X =.. [SubOp, _, _],
	    prec(SubOp, PS), prec(Op, PO),
	    ( PS > PO
	    ; Side == right, PS =:= PO, memberchk(Op, [-, /, //, mod])
	    )
	->  format(atom(S), '(~w)', [S0])
	;   S = S0
	).

prec(Op, P) :- ( memberchk(Op, [+, -]) -> P = 500 ; P = 400 ).

drop_article(Name, Bare) :-
	atomic_list_concat([W|Ws], ' ', Name),
	Ws \== [],
	le_i18n:class_member(article, W), !,
	atomic_list_concat(Ws, ' ', Bare).
drop_article(Name, Name).


		 /*******************************
		 *	 rendering a literal	*
		 *******************************/

%   The literal as a sentence, built from its template's word/variable list.
%
%   NOT through le_kbs:item_to_instance/3, which is the renderer explanations
%   use: that one names an unbound argument from le_var_names/2 -- the variable
%   names recorded at parse time -- so two different variables of the same type
%   come back with the same name, and the round trip silently identifies them.
%   Here the names come from naming/3, which is the whole point (see the module
%   header).
render(KB, Names, Goal0, S) :-
	rename_in(KB, Goal0, Goal1),
	( compound(Goal1) -> Goal1 =.. [F|Args] ; F = Goal1, Args = [] ),
	length(Args, N),
	(   dict_of(KB, F/N, dict_wv(WV, _)),
	    dict_args(KB, F/N, DArgs, WV1),
	    maplist(arg_text(Names), Args, Texts),
	    DArgs = Texts
	->  maplist(token_text, WV1, Words),
	    exclude(==(''), Words, Words1),
	    atomic_list_concat(Words1, ' ', S0),
	    ( S0 == '' -> format(atom(S), '~q', [Goal1]) ; S = S0 ),
	    WV = WV                                   % keep the first lookup honest
	;   format(atom(S), '~q', [Goal1])
	).

%   A FRESH copy of the template: its argument variables and the same
%   variables as they appear in its word list.
dict_args(KB, F/N, DArgs, WV) :-
	current_predicate(KB:le_dict/1),
	KB:le_dict(D),
	D =.. [dict, [F|DArgs], _, WV|_],
	length(DArgs, N), !.

arg_text(Ns, A, T) :- var(A), !, name_of(Ns, A, T).
arg_text(_, A, T) :- string(A), !, format(atom(T), '"~w"', [A]).   % a string stays one
arg_text(_, A, T) :-                   % a constant LE would read as a word of its own (`a`)
	atom(A), lone_keyword(A), !, format(atom(T), '"~w"', [A]).

lone_keyword(A) :-
	(   le_i18n:class_member(article_narrow, A) ; le_i18n:class_member(definite_article, A)
	;   le_i18n:class_member(reserved, A)
	), !.
arg_text(_, A, T) :- format(atom(T), '~w', [A]).

token_text(W, W) :- atomic(W), !.
token_text(_, '').

rename_in(KB, G0, G) :-
	(   compound(G0), G0 =.. [F|Args], length(Args, N),
	    current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(D/N, F)
	->  G =.. [D|Args]
	;   atom(G0),
	    current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(D/0, G0)
	->  G = D
	;   G = G0
	).


%   The first mention of a variable, in the order the sentence is written, is
%   its indefinite name (`a player`); every later one is definite (`the
%   player`). The mark is a binding, so a rendering that fails and is
%   retried another way (condition/4) takes its mentions back with it.
name_of(Ns, V, Name) :-
	(   var(V), member(V0-m(N, Seen), Ns), V0 == V
	->  ( var(Seen) -> Seen = seen, Name = N ; definite(N, Name) )
	;   var(V)
	->  Name = 'a thing'
	;   format(atom(Name), '~w', [V])
	).

%   The name the next mention of V will get, without mentioning it.
next_name_of(Ns, V, Name) :-
	(   var(V), member(V0-m(N, Seen), Ns), V0 == V
	->  ( var(Seen) -> Name = N ; definite(N, Name) )
	;   name_of(Ns, V, Name)
	).

definite(Name, Definite) :-
	atomic_list_concat([W|Ws], ' ', Name),
	Ws \== [],
	le_i18n:class_member(article, W), !,
	atomic_list_concat([the|Ws], ' ', Definite).
definite(Name, Name).


		 /*******************************
		 *	  naming variables	*
		 *******************************/

%!  naming(+KB, +Term, -Names) is det.
%
%   Names is a list of Var-m(Name, Seen) for every variable in Term, ordered by first
%   appearance, with the name taken from the type of the argument position the
%   variable first appears in.
naming(KB, Term, Names) :-
	%  term_variables/2 rather than findall/3: findall COPIES its solutions,
	%  so a variable collected that way is no longer the variable in the
	%  term, and every name would be attached to a stranger.
	term_variables(Term, Vars),
	maplist(var_type(KB, Term), Vars, Types),
	pairs_keys_values(Pairs, Vars, Types),
	number_types(Pairs, [], Names).

var_type(KB, Term, V, Type) :-
	( type_of_var(KB, Term, V, T) -> Type = T ; Type = thing ).

%   The first typed position the variable appears in, reading left to right.
type_of_var(KB, Term, V, Type) :-
	sub_literal(Term, Lit),
	lit_type(KB, Lit, V, Type), !.

lit_type(_, Lit, V, time) :- nonvar(Lit), Lit = time_slot(V0), V0 == V.
%   An aggregate's result, and a list's element, have no template place of
%   their own: `a number is the count of each an element such that …`.
lit_type(_, Lit, V, number) :- nonvar(Lit), Lit = length(_, N), N == V.
lit_type(_, Lit, V, total) :- nonvar(Lit), Lit = sum_list(_, N), N == V.
lit_type(_, Lit, V, element) :- nonvar(Lit), Lit = member(E, _), E == V.
lit_type(KB, Lit, V, Type) :-
	compound(Lit), Lit \= time_slot(_),
	rename_in(KB, Lit, Lit1),
	Lit1 =.. [F|Args],
	length(Args, N),
	( dict_of(KB, F/N, dict_wv(_, NTs)) -> true ; NTs = [] ),
	nth1(I, Args, A), A == V,
	arg_type(NTs, I, Type).

arg_type(NTs, I, Type) :-
	nth1(I, NTs, _-Type0),
	atom(Type0),
	le_grammar:head_noun_type(Type0, Type).

%   Every literal anywhere in the term, plus the times, which are typed by
%   position rather than by a template.
%   Descending INTO a fluent matters for one construct: an aggregate is a
%   findall inside holds/2, and the element and the goals it quantifies are
%   where the types of its variables live.
sub_literal(holds(F, T), Out) :- !, ( Out = F ; Out = time_slot(T) ; aggregate_inside(F, Out) ).
sub_literal(holds(not(F), T), Out) :- !, ( Out = F ; Out = time_slot(T) ).
sub_literal(happens(E, T1, T2), Out) :- !,
	( Out = E ; Out = time_slot(T1) ; Out = time_slot(T2) ).
sub_literal(T, Out) :-
	compound(T), T =.. [F|Args],
	\+ memberchk(F, [holds, happens]),
	( Out = T ; member(A, Args), sub_literal(A, Out) ).

%   ONLY into a findall: an aggregate is a findall inside holds/2, and the
%   types of its element and of the variables it quantifies live in the goals
%   underneath. Descending into any other fluent would let a nested term
%   re-type a variable that the fluent itself already types.
aggregate_inside(F, Out) :-
	nonvar(F), F = findall(_, Goals, _), is_list(Goals),
	member(G, Goals), sub_literal(G, Out).

%   `a player`, then `a second player`, then `a third player`.
number_types([], _, []).
number_types([V-Type|Rest], Counts, [V-m(Name, _Seen)|More]) :-
	(   select(Type-N0, Counts, Counts0)
	->  N is N0 + 1, Counts1 = [Type-N|Counts0]
	;   N = 1, Counts1 = [Type-1|Counts]
	),
	type_name(Type, N, Name),
	number_types(Rest, Counts1, More).

type_name(Type, 1, Name) :- !,
	article_for(Type, Article),
	format(atom(Name), '~w ~w', [Article, Type]).
type_name(Type, N, Name) :-
	ordinal(N, Ord),
	format(atom(Name), 'a ~w ~w', [Ord, Type]).

ordinal(2, second). ordinal(3, third).  ordinal(4, fourth). ordinal(5, fifth).
ordinal(6, sixth).  ordinal(7, seventh). ordinal(8, eighth). ordinal(9, ninth).
ordinal(N, Ord) :- N > 9, format(atom(Ord), 'n~w', [N]).

join([], _, '') :- !.
join(L, Sep, Out) :- atomic_list_concat(L, Sep, Out).

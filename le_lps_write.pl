/** <module> LPS internal syntax back to Logical English

    `dump_le`: the direction lps2's docs/project/plan-of-record.md §I.9.5 asks for, and the reason
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
    over LPS2's examples/le (seventeen; testing/lps_roundtrip.pl).

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

    ## A program that never had a dictionary

    Everything above needs a dictionary, because a template is what tells
    `played(miguel, rock)` from `beats(rock, scissors)`. An LPS program
    written in the older Prolog-like syntax — a `.lps` file — has no
    dictionary and no Logical English original to take one from.
    `le_lps_from_internal/4` is the answer for that case: it reads the
    predicates out of the internal terms themselves, words a template for each
    one from the predicate's own name, binds the wording back to the name with
    `; known as`, and then writes the document the ordinary way. The wording is
    a guess about English and nothing else depends on it being a good guess:
    the binding, not the words, is what carries the meaning, which is why a
    converted program runs exactly as the original did.
*/

:- module(le_lps_write, [
    le_lps_document/3,           % +KBModule, +InternalTerms, -LEText
    le_lps_document/4,           % +KBModule, +InternalTerms, -LEText, +Options
    le_lps_check/3,              % +KBModule, +InternalTerms, -Problems
    le_lps_dump/2,               % +KBModule, -LEText
    le_lps_sentence/3,           % +KBModule, +InternalTerm, -Sentence
    le_lps_from_internal/4       % +InternalTerms, +Options, -LEText, -Issues
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(le_grammar).
:- use_module(le_i18n).
:- use_module(le_kbs).
:- use_module(le_lps).
:- use_module(le_system_templates).
%  Loaded, not imported: le_lps_from_internal/4 words its invented templates
%  with le_writer's lexicon (functor_words/2, unary_words/2, ...), and the two
%  modules have predicates of the same name.
:- use_module(le_writer, []).
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
%!  le_lps_document(+KB, +Terms, -Text, +Options) is det.
%
%   The whole program as Logical English. A term with no Logical English
%   form (le_lps_check/3) refuses the translation: it throws
%   le_lps_not_expressible(Problems), rather than write a document that
%   means something else than its program. With residue(true) in Options —
%   a translator INTO Logical English, whose contract is to keep what it
%   cannot translate as a comment (le_import.pl) — such a term is written as
%   a `% not expressible in Logical English:` comment instead.
le_lps_document(KB, Terms, Text) :-
	le_lps_document(KB, Terms, Text, []).

le_lps_document(KB, Terms, Text, Options) :-
	(   memberchk(residue(true), Options)
	->  true
	;   le_lps_check(KB, Terms, Problems), Problems \== []
	->  throw(le_lps_not_expressible(Problems))
	;   true
	),
	%  the fluents' defaults (`defaults/1`), for their declaration lines
	( memberchk(defaults(Ds), Terms) -> true ; Ds = [] ),
	b_setval(le_lps_write_defaults, Ds),
	%  the knowledge base's name: `lps` unless the caller says otherwise,
	%  which is what a converted `.lps` program does (it names it after the
	%  file, as a document written by hand would).
	option(kb_name(KBName), Options, lps),
	b_setval(le_lps_write_kb_name, KBName),
	partition_terms(Terms, P),
	setup_call_cleanup(nb_setval(le_lps_write_whole, true),
			   with_output_to(string(Text), write_document(KB, P)),
			   nb_setval(le_lps_write_whole, false)).

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
	partition(constant_template(KB), Timeless0, Constants, Timeless1),
	%  A template declared in `the functions are:` is written back there:
	%  the section is what says its value may be written without its last
	%  place (LE2's docs/user/reference/language.md §2.3).
	partition(function_template(KB), Timeless1, Functions, Timeless),
	write_section(KB, 'the functions are', Functions),
	write_section(KB, 'the templates are', Timeless),
	partition(constant_fact(KB, Constants), Body, ConstFacts, Body1),
	write_constants(KB, ConstFacts),
	le_writer:kw(kb_open, KBO), le_writer:kw(kb_include, KBI),
	( nb_current(le_lps_write_kb_name, KBName) -> true ; KBName = lps ),
	format('~w ~w ~w:~n~n', [KBO, KBName, KBI]),
	forall(member(T, Body1), write_sentence(KB, T)),
	( Obs == [] -> true ; write_scenario(KB, Obs) ).

%   A named constant (`the constants are:`): a one-place timeless template
%   that names its value, and its fact. The name is an ATOM in the dict's
%   globals field — a `the functions are:` template carries function(Arity)
%   in the same field and is written back as a function, below.
constant_template(KB, T) :-
	functor(T, F, 1), rename_in(KB, T, T1), functor(T1, F1, 1),
	current_predicate(KB:le_dict/1),
	KB:le_dict(D), D =.. [dict, [F1, _], _, _, Globals|_],
	is_list(Globals), member(G, Globals), atom(G), !,
	F = F.

%   A template declared in `the functions are:` (le_kbs records which).
function_template(KB, T) :-
	functor(T, F, N), rename_in(KB, T, T1), functor(T1, F1, N),
	current_predicate(KB:le_function/1),
	KB:le_function(F1/N), !,
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
	->  words_text(Words, Line),
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

%!  le_lps_check(+KB, +Terms, -Problems) is det.
%
%   The check before an LPS program is written as Logical English: every
%   term of its body must have a sentence. Problems: problem(none, Message)
%   for each that has none (le_import:export_refusal/4's shape).
le_lps_check(KB, Terms, Problems) :-
	( memberchk(defaults(Ds), Terms) -> true ; Ds = [] ),
	b_setval(le_lps_write_defaults, Ds),
	partition_terms(Terms, p(_, _, _, _, _, Body, _)),
	findall(problem(none, Msg),
		( member(T, Body), \+ has_sentence(KB, T),
		  format(string(TS), "~q", [T]),
		  le_i18n:le_msg(lps_not_expressible_in_le, [term-TS], Msg) ),
		Problems).

has_sentence(KB, Term0) :-
	nb_setval(le_lps_write_raw, []),
	(   \+ \+ ( copy_term(Term0, Term),
		    shorten_times(Term),
		    naming(KB, Term, Names0),
		    global_names(KB, Term, Names0, Names),
		    sentence(KB, Names, Term, _) )
	->  nb_getval(le_lps_write_raw, Raw)
	;   Raw = [none]
	),
	nb_setval(le_lps_write_raw, none),
	Raw == [].

write_sentence(KB, Term0) :-
	nb_current(le_lps_write_whole, true),         % a whole document: a term
	\+ has_sentence(KB, Term0), !,                % with no sentence is residue
	format('% not expressible in Logical English: ~q~n~n', [Term0]).
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
%   out (lps2's docs/user/reference/le-for-lps.md §3.1):
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
%   A reactive rule whose conditions all read one state and whose
%   consequents all start at that time, their ends named nowhere: `if there
%   is a fire in a room and it is not the case that an alarm is on then an
%   alarm goes on.` — LE-for-LPS reads the conditions at one time and starts
%   the consequents at it, which is this very term.
elided_times(reactive_rule(Ante, Cons)) :-
	Cons = [_|_],
	\+ ( member(G, Ante), nonvar(G), G = happens(_, _, _) ),
	reactive_start(Ante, Cons, T), var(T),
	only_state_time(Ante, T),
	maplist(untimed_consequent(T), Cons, Ends),
	\+ ( member(E, Ends), occurs_var(E, Ante) ),
	forall(member(E, Ends), once_in(E, reactive_rule(Ante, Cons))), !,
	T = lps_now,
	maplist(=(lps_now), Ends).

reactive_start(Ante, _, T) :- member(G, Ante), nonvar(G), G = holds(_, T), !.
reactive_start(_, [C|_], T) :- nonvar(C), C = happens(_, T, _).

untimed_consequent(T, C, End) :-
	nonvar(C), C = happens(E, S, End),
	S == T, var(End), End \== T,
	\+ occurs_var(T, E), \+ occurs_var(End, E).

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
%   (lps2's docs/user/reference/le-for-lps.md §3.4: "several may be joined with `and`"; read
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
expr_text(_, T, S) :- string(T), !, format(atom(S), '"~w"', [T]).    % a string stays one
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
	    words_text(Words1, S0),
	    ( S0 == '' -> format(atom(S), '~q', [Goal1]) ; S = S0 ),
	    WV = WV                                   % keep the first lookup honest
	;   format(atom(S), '~q', [Goal1]),
	    raw_goal(Goal1)
	).

%   A goal written as Prolog because no template says it in English: fine
%   for Prolog's own built-ins (LE reads them), but anything else is not
%   Logical English — le_lps_check/3 counts those (while it runs, the list
%   `le_lps_write_raw` collects them).
raw_goal(G) :-
	(   nb_current(le_lps_write_raw, L), is_list(L),
	    \+ catch(predicate_property(system:G, built_in), _, fail)
	->  nb_setval(le_lps_write_raw, [G|L])
	;   true
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
arg_text(_, A, T) :- format(atom(T), '~w', [A]).

lone_keyword(A) :-
	(   le_i18n:class_member(article_narrow, A) ; le_i18n:class_member(definite_article, A)
	;   le_i18n:class_member(reserved, A)
	), !.

%   A template's words, a punctuation mark after the word before it
%   (`a thing, a second thing`, not `a thing , a second thing`).
words_text(Ws, S) :- foldl(word_join, Ws, '', S).

word_join(W, '', W) :- !.
word_join(W, Acc, S) :-
	(   memberchk(W, [',', ';', ':']) -> atom_concat(Acc, W, S)
	;   atomic_list_concat([Acc, ' ', W], S)
	).

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
%   (the negation first: a variable seen only under `not` is typed by the
%   negated fluent's place too — `it is not the case that there is a fire in
%   a room`, not `… in a thing`)
sub_literal(holds(not(F), T), Out) :- !, ( Out = F ; Out = time_slot(T) ).
sub_literal(holds(F, T), Out) :- !, ( Out = F ; Out = time_slot(T) ; aggregate_inside(F, Out) ).
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


		 /*******************************
		 *  A PROGRAM WITH NO DICTIONARY *
		 *******************************/

%!  le_lps_from_internal(+Terms, +Options, -LEText, -Issues) is det.
%
%   The Logical English document an LPS program would have had, if it had
%   been written in Logical English. Terms are the LPS internal terms of
%   lps2's plan-of-record §I.3, as its readers give them for a `.lps`
%   program in the older Prolog-like syntax. Such a program has no template
%   dictionary and no Logical English original to take one from, so this
%   predicate makes one: a template for every predicate the program
%   mentions, worded from the predicate's own name (`pick_up(Who, What)` ->
%   `*a thing* picks up *a second thing*`) and bound back to that name with
%   `; known as`, which is what keeps the two programs the same program.
%
%   Options:
%
%     * kb(Name)        the knowledge base's name. Default `lps`.
%     * language(Lang)  the language to word the templates in. Default `en`.
%     * comment(Text)   a comment block written above the document.
%
%   Issues come back as issue(Severity, Code, Message) terms, never as
%   silence: a term with no Logical English form is written into the
%   document as a residue comment and reported here as well.
le_lps_from_internal(Terms0, Options, LEText, Issues) :-
	option(language(Lang), Options, en),
	le_i18n:with_le_language(Lang,
	    le_lps_write:le_lps_from_internal_(Terms0, Options, LEText, Issues)).

le_lps_from_internal_(Terms0, Options, LEText, Issues) :-
	set_aside_drawings(Terms0, TermsA, DrawIssues),
	maplist(clause_to_timeless, TermsA, TermsB),
	normalise_declarations(TermsB, Terms1),
	infer_declarations(Terms1, Terms),
	option(kb(Name), Options, lps),
	lps_predicates(Terms, Preds),
	invented_templates(Preds, Lines, ClashIssues),
	declarations_document(Lines, Name, Decls),
	setup_call_cleanup(
	    ( le_kbs:le_issue_reporting -> Was = true ; Was = false ),
	    ( le_kbs:set_le_issue_reporting(false),
	      le_kbs:load_text(Decls, KB) ),
	    le_kbs:set_le_issue_reporting(Was)),
	setup_call_cleanup(
	    true,
	    ( le_lps_check(KB, Terms, Problems),
	      maplist(not_expressible_issue, Problems, CheckIssues),
	      dropped_issues(Terms, DropIssues),
	      register_issues(Terms, RegIssues),
	      multi_kind_issues(Terms, KindIssues),
	      nested_term_issues(Terms, NestIssues),
	      le_lps_document(KB, Terms, Body, [residue(true), kb_name(Name)]),
	      comment_block(Options, Comment),
	      atomics_to_string([Comment, Body], LEText),
	      append([ClashIssues, DrawIssues, DropIssues, RegIssues, KindIssues,
		      NestIssues, CheckIssues], Issues) ),
	    catch(le_kbs:le_kb_dispose(KB), _, true)).

atomics_to_string(Parts, S) :-
	atomic_list_concat(Parts, A), atom_string(A, S).

comment_block(Options, Comment) :-
	(   option(comment(Text), Options)
	->  split_string(Text, "\n", "", Ls),
	    findall(L1, ( member(L0, Ls), format(atom(L1), '% ~w~n', [L0]) ), L1s),
	    atomic_list_concat(L1s, C0), atom_concat(C0, '\n', Comment)
	;   Comment = ''
	).

not_expressible_issue(problem(_, Msg), issue(warning, lps_not_expressible, Msg)).

%!	set_aside_drawings(+Terms0, -Terms, -Issues) is det.
%
%	`display/2` and `display3d/2` say how to draw a program's state: a
%	list of shapes, colours and coordinates, which reads no better in
%	English than in Prolog and has no Logical English form at all
%	(docs/user/reference/le-for-lps.md §7). They belong in a companion
%	`.lps` file, where the engine still reads them, and they are taken
%	out here rather than written as sentences that mean nothing.
set_aside_drawings(Terms0, Terms, Issues) :-
	partition(drawing_term, Terms0, Drawings, Terms),
	(   Drawings == []
	->  Issues = []
	;   length(Drawings, N),
	    format(string(M),
		   "~w drawing rule(s) (display/2, display3d/2) are not in this \c
		    document: a list of shapes and coordinates has no Logical \c
		    English form. Keep them in a companion .lps file beside it, \c
		    which the engine reads together with this document",
		   [N]),
	    Issues = [issue(warning, lps_drawing_rules, M)]
	).

drawing_term(T) :- nonvar(T), T = (H :- _), !, drawing_term(H).
drawing_term(T) :- nonvar(T), functor(T, F, N), memberchk(F/N, [display/2, display3d/2]).

%	A plain Prolog clause is what LPS calls a timeless rule; the older
%	syntax leaves it as a clause, and the internal vocabulary has a name
%	for it.
clause_to_timeless(T, l_timeless(H, B)) :- nonvar(T), T = (H :- B), nonvar(H), !.
clause_to_timeless(T, T).

%   A directive (`:- lps_engine(planning, ...)`) has no Logical English form
%   at all -- not even a residue comment, because le_lps_document drops it
%   with the declarations. Saying so is the whole of §I.9.6's discipline: a
%   converted program that silently stopped planning would be a lie.
dropped_issues(Terms, Issues) :-
	findall(issue(error, lps_directive_dropped, Msg),
		( member(T, Terms), T = (:- D), directive_message(D, Msg) ),
		Issues).

%	A document with a goal asks for the planning engine by itself (the
%	goal IS that declaration, docs/user/reference/le-for-lps.md §3.8), so
%	what is lost there is only the engine's settings -- and they are lost,
%	which is worth a different sentence from a directive nothing carries.
directive_message(lps_engine(planning, Opts), Msg) :-
	Opts \== [], !,
	format(string(Msg),
	       "the planning engine's settings ~q have no Logical English form. \c
		A document with a goal asks for the planning engine by itself, \c
		but with the engine's own settings, which are not these. Keep \c
		':- lps_engine(planning, ~q).' in a companion .lps file beside \c
		the document", [Opts, Opts]).
directive_message(D, Msg) :-
	format(string(Msg),
	       "the directive ':- ~q' has no Logical English form; keep it in a \c
		companion .lps file beside the document", [D]).

%   `fluent(F)` and `fluents([F, ...])` are the same declaration; the writer
%   reads only the second, so the first is folded into it. A program whose
%   declarations arrived one at a time would otherwise have them written out
%   as facts.
normalise_declarations(Terms0, Terms) :-
	foldl(fold_declaration, Terms0, t([], [], [], [], []), t(F, E, A, P, RevRest)),
	reverse(RevRest, Rest),
	findall(D, ( declaration_section(W, Which),
		     memberchk(Which-L0, [fluents-F, events-E, actions-A, prolog_events-P]),
		     L0 \== [], variant_set(L0, L), D =.. [W, L] ),
		Decls),
	append(Decls, Rest, Terms).

%	The declarations in the order the program gave them, each once. Their
%	order is nothing to the engine, but a converted program that reordered
%	them would look different from its original for no reason.
variant_set([], []).
variant_set([X|Xs], [X|Ys]) :- exclude(=@=(X), Xs, Rest), variant_set(Rest, Ys).

%!	infer_declarations(+Terms0, -Terms) is det.
%
%	The older syntax lets a program use a predicate it never declared, or
%	declare it at one arity and use it at another: `fluents carrying(_).`
%	beside `take(Who, What) initiates carrying(Who, What).` The reader
%	works out what such a literal is from where it stands, and Logical
%	English has no such rule -- a sentence is timeless unless its template
%	is declared a fluent, an event or an action. So what the older program
%	left implicit is written down here, or the converted program would
%	quietly lose the time from half its sentences.
infer_declarations(Terms0, Terms) :-
	declared_pairs(Terms0, Declared),
	findall(fluent-L, ( member(T, Terms0), fluent_position(T, L0), proto(L0, L) ), Fs),
	findall(K-L, ( member(T, Terms0), happening_position(T, K, L0), proto(L0, L) ), Hs),
	append(Fs, Hs, Wanted0),
	exclude(already_declared(Declared), Wanted0, Wanted1),
	exclude(also_an_event(Wanted1), Wanted1, Wanted2),
	variant_set(Wanted2, Wanted),
	foldl(add_declaration, Wanted, Terms0, Terms).

declared_pairs(Terms, Pairs) :-
	findall(Kind-F/N,
		( member(T, Terms), declared_literal(T, Kind, L),
		  callable(L), functor(L, F, N) ),
		Pairs0),
	sort(Pairs0, Pairs).

already_declared(Declared, _-L) :-
	functor(L, F, N), memberchk(_-F/N, Declared).

%	A composite event that a rule also brings about (`save_the_five`, the
%	head of an `l_events` clause and the consequent of a maintenance
%	goal) is an event: it is DEFINED, and what defines it is what says
%	what it is.
also_an_event(Wanted, action-L) :-
	functor(L, F, N),
	member(event-L2, Wanted), functor(L2, F, N), !.

%	The prototype a declaration carries: the functor with fresh places.
proto(L, P) :- callable(L), compound(L), !, functor(L, F, N), functor(P, F, N).
proto(L, L) :- atom(L).

%	Where a literal can only be a fluent.
fluent_position(initial_state(Fs), F) :- is_list(Fs), member(F, Fs).
fluent_position(achieve(Fs), F) :- ( is_list(Fs) -> member(F, Fs) ; F = Fs ).
fluent_position(initiated(_, F, _), F).
fluent_position(terminated(_, F, _), F).
fluent_position(updated(_, F, _, _), F).
fluent_position(T, F) :- lps_term_literal(T, holds(F0, _)), lps_strip(holds(F0, _), F).
fluent_position(l_int(holds(F0, _), _), F) :- lps_strip(F0, F).

%	Where a literal can only be something that happens. A consequent of a
%	reactive rule is something the program DOES, which is an action;
%	anything else that happens is an event.
happening_position(reactive_rule(_, Cs), action, E) :- member(happens(E, _, _), Cs).
happening_position(reactive_rule(_, Cs, _), action, E) :- member(happens(E, _, _), Cs).
happening_position(initiated(happens(E, _, _), _, _), event, E).
happening_position(terminated(happens(E, _, _), _, _), event, E).
happening_position(updated(happens(E, _, _), _, _, _), event, E).
happening_position(effects(happens(E, _, _), _, _), event, E).
happening_position(observe(Es, _), event, E) :- ( is_list(Es) -> member(E, Es) ; E = Es ).
happening_position(d_pre(Cs), event, E) :- is_list(Cs), member(happens(E, _, _), Cs).
happening_position(l_events(happens(E, _, _), _), event, E).
happening_position(reactive_rule(As, _), event, E) :- member(happens(E, _, _), As).

add_declaration(Kind-L, Terms0, Terms) :-
	declaration_section(W, Which),
	memberchk(Kind-Which, [fluent-fluents, event-events, action-actions]),
	(   select(D0, Terms0, Rest), D0 =.. [W, Ls], is_list(Ls)
	->  append(Ls, [L], Ls1), D =.. [W, Ls1],
	    Terms = [D|Rest0], Rest0 = Rest
	;   D =.. [W, [L]], Terms = [D|Terms0]
	).

declaration_section(fluents, fluents).
declaration_section(events, events).
declaration_section(actions, actions).
declaration_section(prolog_events, prolog_events).

fold_declaration(T, t(F, E, A, P, Rest), Out) :-
	(   declaration_of(T, Which, Ls)
	->  (   Which == fluents -> append(F, Ls, F1), Out = t(F1, E, A, P, Rest)
	    ;   Which == events  -> append(E, Ls, E1), Out = t(F, E1, A, P, Rest)
	    ;   Which == actions -> append(A, Ls, A1), Out = t(F, E, A1, P, Rest)
	    ;   append(P, Ls, P1), Out = t(F, E, A, P1, Rest)
	    )
	;   Out = t(F, E, A, P, [T|Rest])
	).

declaration_of(T, Which, Ls) :-
	compound(T), T =.. [W, Arg],
	(   memberchk(W, [fluents, events, actions, prolog_events]), is_list(Arg)
	->  Which = W, Ls = Arg
	;   memberchk(W-Which, [fluent-fluents, event-events, action-actions]),
	    \+ is_list(Arg)
	->  Ls = [Arg]
	).

		 /*******************************
		 *   THE PROGRAM'S PREDICATES   *
		 *******************************/

%!  lps_predicates(+Terms, -Preds) is det.
%
%   Preds is p(Kind, Functor/Arity) for every predicate the program
%   mentions, Kind one of `fluent`, `event`, `action`, `prolog_event` (from
%   the declarations) or `timeless` (everything else: the ordinary
%   relations a program calls, which need a template as much as a fluent
%   does). Sorted, so the document does not change between two runs.
lps_predicates(Terms, Preds) :-
	findall(Kind-F/N,
		( member(T, Terms), declared_literal(T, Kind, L),
		  callable(L), functor(L, F, N) ),
		Declared0),
	sort(Declared0, Declared),
	findall(F/N,
		( member(T, Terms), lps_literal(T, L), functor(L, F, N) ),
		Used0),
	sort(Used0, Used),
	findall(F/N, member(_-F/N, Declared), Names00), sort(Names00, Names0),
	updated_fluents(Terms, Registers),
	%  A name declared in two sections keeps ONE template, the first of
	%  them: Logical English decides what a sentence is from the name, so
	%  it cannot tell the two apart at all. multi_kind_issues/2 says so.
	findall(p(Kind, F/N, Register),
		( member(F/N, Names0), once(member(Kind-F/N, Declared)),
		  register_of(Registers, Kind, F/N, Register) ),
		Declared1),
	subtract(Used, Names0, Undeclared),
	findall(p(timeless, F/N, plain), member(F/N, Undeclared), Timeless),
	append(Declared1, Timeless, Preds0),
	sort(Preds0, Preds).

register_of(Registers, fluent, F/N, register(I)) :- memberchk(F/N-I, Registers), !.
register_of(_, _, _, plain).

%!	updated_fluents(+Terms, -Registers) is det.
%
%	`F/N-Place` for every fluent an `updates` law changes, Place the
%	argument the law replaces. Such a fluent is a register, and its
%	template must END with `is *that place*`: the update sentence is `the
%	battery that is a number becomes 100`, and the reader puts the literal
%	back together as everything before `that`, then `is`, then the old
%	value. A register whose changing place is not its last one cannot be
%	said this way at all, and `register_issues/2` says so.
updated_fluents(Terms, Registers) :-
	findall(F/N-I,
		( member(updated(_, Fluent, Old-_, _), Terms),
		  callable(Fluent), compound(Fluent), functor(Fluent, F, N),
		  arg(I, Fluent, A), A == Old ),
		Rs0),
	sort(Rs0, Registers).

%!	nested_term_issues(+Terms, -Issues) is det.
%
%	A place of a Logical English sentence holds a name, a number, a date
%	or a list -- never a term with a term inside it. An LPS program that
%	observes `command(open(case))` is saying something Logical English
%	cannot say, and what comes out the other end is the quoted text
%	`'open(case)'`, which is a different value. Better to say so.
nested_term_issues(Terms, Issues) :-
	findall(F/N-A,
		( member(T, Terms), lps_literal(T, L), compound(L),
		  arg(_, L, A), compound(A), \+ is_list(A),
		  functor(L, F, N) ),
		Bad0),
	sort(Bad0, Bad),
	findall(issue(error, lps_nested_term, M),
		( member(F/N-A, Bad),
		  format(string(M),
			 "~w/~w holds the term ~q in one of its places. A place of \c
			  a Logical English sentence holds a name, a number, a \c
			  date or a list, never a term with a term inside it: \c
			  this one is written as the text '~q' instead, which is \c
			  a different value", [F, N, A, A]) ),
		Issues).

%!	multi_kind_issues(+Terms, -Issues) is det.
%
%	A name the older syntax declares twice -- `temperature` both an event
%	(what the world reports) and a fluent (what we believe) -- has no
%	Logical English form. There, a sentence is an event or a fluent
%	because of the section its template is declared in, and one name
%	cannot be in two sections.
multi_kind_issues(Terms, Issues) :-
	declared_pairs(Terms, Pairs),
	findall(F/N, member(_-F/N, Pairs), Names0), sort(Names0, Names),
	findall(issue(error, lps_name_in_two_sections, M),
		( member(F/N, Names),
		  findall(K, member(K-F/N, Pairs), Ks0), sort(Ks0, Ks),
		  Ks = [_, _|_],
		  format(string(M),
			 "~w/~w is declared as ~w. In Logical English a sentence \c
			  is an event, an action or a fluent because of the \c
			  section its template stands in, and one name cannot \c
			  stand in two sections, so only the first is kept here. \c
			  Rename one of them in the program, or keep the program \c
			  in the older syntax", [F, N, Ks]) ),
		Issues).

%!	register_issues(+Terms, -Issues) is det.
%
%	The `updates` laws Logical English cannot say: the one construct of
%	the older syntax with no surface here. Saying so is the whole point --
%	a converted program that had quietly stopped updating a fluent would
%	be worse than one that refused.
register_issues(Terms, Issues) :-
	updated_fluents(Terms, Registers),
	findall(issue(error, lps_update_not_last_place, M),
		( member(F/N-I, Registers), I < N,
		  format(string(M),
			 "~w/~w is updated in its place ~w, and an update is said \c
			  in Logical English as `... that is <the old value> \c
			  becomes <the new one>`, which can only change a \c
			  relation's LAST place. Rewrite the program so that the \c
			  changing value of ~w comes last, or keep this law in a \c
			  companion .lps file", [F, N, I, F]) ),
		Issues).

declared_literal(D, Kind, L) :-
	compound(D), D =.. [W, Ls], is_list(Ls),
	memberchk(W-Kind, [fluents-fluent, events-event, actions-action,
			   prolog_events-prolog_event]),
	member(L, Ls).

%   Every literal the program mentions, with the time wrappers taken off.
lps_literal(T, L) :-
	lps_term_literal(T, L0), lps_strip(L0, L1),
	callable(L1), \+ lps_builtin(L1), L = L1.

lps_term_literal(initial_state(Fs), F) :- is_list(Fs), member(F, Fs).
lps_term_literal(achieve(Fs), F) :- ( is_list(Fs) -> member(F, Fs) ; F = Fs ).
lps_term_literal(observe(Es, _), E) :- ( is_list(Es) -> member(E, Es) ; E = Es ).
lps_term_literal(d_pre(Cs), C) :- is_list(Cs), member(C, Cs).
lps_term_literal(initiated(Tr, F, Cs), L) :- ( L = Tr ; L = F ; member(L, Cs) ).
lps_term_literal(terminated(Tr, F, Cs), L) :- ( L = Tr ; L = F ; member(L, Cs) ).
lps_term_literal(updated(Tr, F, _, Cs), L) :- ( L = Tr ; L = F ; member(L, Cs) ).
lps_term_literal(effects(Tr, Cs, Es), L) :- ( L = Tr ; member(L, Cs) ; member(L, Es) ).
lps_term_literal(reactive_rule(As, Cs), L) :- ( member(L, As) ; member(L, Cs) ).
lps_term_literal(reactive_rule(As, Cs, _), L) :- ( member(L, As) ; member(L, Cs) ).
lps_term_literal(l_int(H, B), L) :- ( L = H ; body_literal(B, L) ).
lps_term_literal(l_events(H, B), L) :- ( L = H ; body_literal(B, L) ).
lps_term_literal(l_timeless(H, B), L) :- ( L = H ; body_literal(B, L) ).
lps_term_literal(T, T) :- \+ lps_structural(T).

body_literal(B, L) :- is_list(B), !, member(L, B).
body_literal(B, L) :- nonvar(B), B = (X, Y), !, ( body_literal(X, L) ; body_literal(Y, L) ).
body_literal(B, B).

lps_structural(T) :-
	nonvar(T), functor(T, F, N),
	memberchk(F/N, [initial_state/1, achieve/1, observe/2, d_pre/1,
			initiated/3, terminated/3, updated/4, effects/3,
			reactive_rule/2, reactive_rule/3, l_int/2, l_events/2,
			l_timeless/2, fluents/1, events/1, actions/1,
			prolog_events/1, fluent/1, event/1, action/1,
			unserializable/1, defaults/1, maxTime/1, maxRealTime/1,
			minCycleTime/1, simulatedRealTimePerCycle/1,
			simulatedRealTimeBeginning/1, display/2, display3d/2,
			(:-)/1]).

lps_strip(V, V) :- var(V), !.
lps_strip(holds(F, _), L) :- !, lps_strip(F, L).
lps_strip(happens(E, _, _), L) :- !, lps_strip(E, L).
lps_strip(not(G), L) :- !, lps_strip(G, L).
lps_strip(L, L).

lps_builtin(L) :- var(L), !.
lps_builtin(L) :- number(L), !.
lps_builtin(L) :-
	functor(L, F, N),
	memberchk(F/N, [(=)/2, (\=)/2, (==)/2, (\==)/2, (<)/2, (>)/2, (=<)/2,
			(>=)/2, (is)/2, (=:=)/2, (=\=)/2, (@<)/2, (@>)/2,
			(@=<)/2, (@>=)/2, true/0, fail/0, false/0, (',')/2,
			(;)/2, (->)/2, findall/3, forall/2, between/3,
			member/2, memberchk/2, length/2, nth0/3, nth1/3,
			append/3, state/1, next_state/1]).

		 /*******************************
		 *     WORDING A TEMPLATE       *
		 *******************************/

%!  invented_templates(+Preds, -Lines, -Issues) is det.
%
%   One template line per predicate, each worded from the predicate's own
%   name. Two predicates that would be worded the same way are a real
%   hazard -- the second would be read as the first -- so the clash is
%   broken and reported rather than left to the grammar.
invented_templates(Preds, Lines, Issues) :-
	maplist(first_wording, Preds, Lines0),
	findall(T, member(line(_, _, T), Lines0), Texts),
	msort(Texts, Sorted),
	findall(T, ( member(T, Sorted), aggregate_all(count, member(T, Texts), C), C > 1 ), Clashing0),
	sort(Clashing0, Clashing),
	break_clashes(Lines0, Clashing, [], Lines, Issues).

first_wording(p(Kind, F/N, Register), line(Kind, F/N, Text)) :-
	lps_template_text(Kind, Register, F, N, Text).

%   A wording two predicates would share is broken on whichever of them has
%   a second wording of its own: an event or an action can be said with
%   `does` (`*a thing* does sing`, beside the fluent `*a thing* sings`),
%   which is ordinary English. A predicate with no second wording keeps its
%   name beside the words, which is ugly but never wrong, and either way the
%   caller is told.
%   Pass one: every event or action in a clashing group steps aside, since
%   English gives it a second wording. Pass two: whatever still collides
%   after that keeps its name beside the words, which is ugly but never
%   wrong. Either way the caller is told.
break_clashes(Lines0, Clashing, _, Lines, Issues) :-
	foldl(step_aside(Clashing), Lines0, Lines1-[], []-RevA),
	reverse(Lines1, Lines2),
	findall(T, member(line(_, _, T), Lines2), Texts),
	relabel(Lines2, Texts, [], Lines),
	findall(issue(warning, lps_template_clash, M),
		( member(line(_, F/N, T), Lines), sub_atom(T, _, _, _, ' ( '),
		  format(string(M),
			 "~w/~w and another predicate of this program would be \c
			  worded the same way, and there is no second wording for \c
			  it, so its name is written beside the words: '~w'",
			 [F, N, T]) ),
		Issues1),
	reverse(RevA, Issues0),
	append(Issues0, Issues1, Issues).

step_aside(Clashing, line(Kind, F/N, T0), [line(Kind, F/N, T)|Ls]-Is0, Ls-Is) :-
	(   memberchk(T0, Clashing), second_wording(Kind, F, N, T1),
	    \+ memberchk(T1, Clashing)
	->  T = T1,
	    format(string(M),
		   "~w/~w and another predicate of this program would be worded \c
		    the same way, so ~w/~w is worded '~w'", [F, N, F, N, T]),
	    Is = [issue(info, lps_template_clash, M)|Is0]
	;   T = T0, Is = Is0
	).

%   Whatever still collides: the first keeps the words, the rest take their
%   name beside them.
relabel([], _, _, []).
relabel([line(Kind, F/N, T0)|Ls], Texts, Taken, [line(Kind, F/N, T)|Rest]) :-
	(   \+ memberchk(T0, Taken)
	->  T = T0
	;   format(atom(T), '~w ( ~w )', [T0, F])
	),
	relabel(Ls, Texts, [T0|Taken], Rest).

%   `*a thing* does sing`: do-support, which English has for exactly this.
second_wording(Kind, F, N, Text) :-
	happening(Kind), N > 0,
	le_writer:functor_words(F, Words),
	length(Types, N), maplist(=(thing), Types),
	le_writer:distinct_place_names(Types, Places),
	maplist(le_writer:slot_text, Places, Slots),
	subject_shape(Slots, [does|Words], All),
	atomic_list_concat(All, ' ', Text0),
	le_writer:unclash(Text0, Text).

%!  lps_template_text(+Kind, +Functor, +Arity, -Text) is det.
%
%   An event or an action is something that happens, so its name is read as
%   a verb and put in the third person: `praise(fox, crow)` becomes `*a
%   thing* praises *a second thing*`. A fluent or an ordinary relation is
%   something that holds, so its name is read as a state, the way
%   le_writer.pl reads a Prolog predicate's name: `fooled(crow)` becomes `*a
%   thing* is fooled`, `light(Room, Setting)` becomes `the light of *a
%   thing* is *a second thing*`.
%
%   Every place is typed `thing`, because the older syntax declares no
%   types. Places are told apart by their ordinal, as everywhere else in
%   Logical English: `*a thing*`, `*a second thing*`.
lps_template_text(Kind, Register, F, N, Text) :-
	le_writer:functor_words(F, Words),
	length(Types, N), maplist(=(thing), Types),
	le_writer:distinct_place_names(Types, Places),
	maplist(le_writer:slot_text, Places, Slots),
	template_shape(Kind, Register, Words, Slots, All),
	atomic_list_concat(All, ' ', Text0),
	le_writer:unclash(Text0, Text).

%   No places: the name is the whole sentence (`move forward`).
template_shape(_, _, Words, [], Words) :- !.
template_shape(Kind, _, Words, Slots, All) :-
	happening(Kind), !,
	third_person(Words, Verb),
	subject_shape(Slots, Verb, All).
%   A register: the changing value last, after the copula, whatever the name
%   sounds like -- that is the only shape an update sentence can be put back
%   together from.
template_shape(_, register(I), Words, Slots, All) :-
	length(Slots, N), I =:= N, !,
	register_shape(Words, Slots, All).
template_shape(_, _, Words, [S1], All) :- !,
	one_place_shape(Words, S1, All).
template_shape(_, _, Words, [S1, S2], All) :- !,
	state_shape(Words, S1, S2, All).
template_shape(_, _, Words, Slots, All) :-
	subject_shape(Slots, Words, All).

happening(event).
happening(action).
happening(prolog_event).

%   `*a thing* picks up *a second thing* with *a third thing*`.
subject_shape([S1], Words, [S1|Words]) :- !.
subject_shape([S1, S2], Words, All) :- !,
	append([[S1], Words, [S2]], All).
subject_shape([S1, S2|More], Words, All) :-
	findall(P, ( member(S, More), member(P, [with, S]) ), Tail),
	append([[S1], Words, [S2], Tail], All).

%   A one-place state. A verb takes its subject (`*a thing* sings`), and so
%   does an adjective or a participle, with the copula (`*a thing* is
%   fooled`). A noun must NOT: `*a thing* is a room` is how Logical English
%   writes its own `*a thing* is a *a kind*` sentence, and a template of that
%   shape is read as that sentence instead, which silently changes what the
%   program says. A noun therefore reads as what it usually is in an LPS
%   program -- a register holding a value: `the battery is *a thing*`.
one_place_shape(Words, S1, All) :-
	le_writer:unary_words(Words, Ws),
	\+ article_word(Ws),
	last(Words, W), \+ noun_like(W), !,
	All = [S1|Ws].
one_place_shape(Words, S1, All) :-
	le_writer:writer_word(definite_m, The),
	opening_words(The, Words, Opening),
	append([Opening, [is, S1]], All).

article_word(Ws) :- member(W, Ws), memberchk(W, [a, an]).

%   `the battery is *a thing*`, `the at of *a thing* is *a second thing*`.
register_shape(Words, [S1], All) :- !,
	le_writer:writer_word(definite_m, The),
	opening_words(The, Words, Opening),
	append([Opening, [is, S1]], All).
register_shape(Words, Slots, All) :-
	append(Front, [Last], Slots),
	front_phrase(Front, Parts),
	le_writer:writer_word(definite_m, The),
	opening_words(The, Words, Opening),
	append([Opening, Parts, [is, Last]], All).

%!	opening_words(+The, +Words, -Opening) is det.
%
%	`the battery`, and `the current target` where the plain form would
%	open like a section of the document. `the target is *a thing*` begins
%	with the words that open `the target language is: lps.`, and the
%	reader stops reading the section there -- taking the rest of it with
%	it. A qualifier is the cheapest way out, and it reads.
opening_words(The, Words, Opening) :-
	append([The], Words, Plain),
	(   starts_like_section(Plain)
	->  le_writer:writer_word(lps_register_qualifier, Q),
	    append([The, Q], Words, Opening)
	;   Opening = Plain
	).

%!	starts_like_section(+Words) is semidet.
%
%	Words open the way a section of a Logical English document opens.
%	Two words are enough to fool the reader, so two words are what is
%	compared.
starts_like_section(Words) :-
	le_i18n:kw_category_key(section, Key),
	le_i18n:kw_synonym_words(Key, Kw),
	Kw \== [],
	( Kw = [K1, K2|_] -> Prefix = [K1, K2] ; Prefix = Kw ),
	append(Prefix, _, Words), !.

front_phrase([S1], [of, S1]) :- !.
front_phrase([S1|More], All) :-
	findall(P, ( member(S, More), member(P, [for, S]) ), Tail),
	append([of, S1], Tail, All).

%   `battery` ends in y and so looks like an adjective to le_writer's
%   lexicon (`dusty`, `heavy`); a name that ends in y, er or ion is read here
%   as the noun it almost always is in a program.
noun_like(W) :-
	member(Suffix, [y, er, or, ion, ity, ness, ment, ance, ence]),
	sub_atom(W, _, _, 0, Suffix),
	\+ memberchk(W, [ready, empty, dirty, busy, angry, happy, other]), !.

%   A two-place state. A name that is already a verb (`has`, `owns`) or ends
%   in a preposition (`is the father of`) takes its places around it; a name
%   that is a preposition or an adjective takes the copula (`*a thing* is
%   near *a second thing*`); a name that is a noun reads as a value (`the
%   light of *a thing* is *a second thing*`), which is how the same word
%   would be read in the older syntax.
state_shape(Words, S1, S2, All) :-
	Words = [W|_], state_verb(W), !,
	append([[S1], Words, [S2]], All).
state_shape([W], S1, S2, [S1, is, W, S2]) :-
	( preposition(W) ; le_writer:adjective_like(W) ), !.
state_shape(Words, S1, S2, All) :-
	last(Words, WL), preposition(WL), !,
	le_writer:writer_word(definite_m, The),
	append([[S1, is, The], Words, [S2]], All).
state_shape(Words, S1, S2, All) :-
	le_writer:writer_word(definite_m, The),
	opening_words(The, Words, Opening),
	append([Opening, [of, S1, is, S2]], All).

state_verb(W) :- already_third(W), !.
state_verb(W) :- memberchk(W, [is, are, was, were, can, may, must, will, should, have]).

preposition(W) :-
	memberchk(W, [of, to, in, on, at, for, with, from, by, than, as, near,
		      under, over, above, below, beside, inside, outside,
		      between, before, after, during, within, against, into,
		      onto, upon, toward, towards, about, around, behind]).

%   The third person singular of the first word: `praise` -> `praises`,
%   `pick up` -> `picks up`, `carry` -> `carries`, `push` -> `pushes`.
third_person([W|Ws], [W3|Ws]) :- third_person_word(W, W3).

third_person_word(W, W3) :- irregular_third(W, W3), !.
third_person_word(W, W) :- already_third(W), !.
third_person_word(W, W3) :-
	(   sub_atom(W, _, 2, 0, S2), memberchk(S2, [ch, sh])
	->  atom_concat(W, es, W3)
	;   sub_atom(W, _, 1, 0, S1), memberchk(S1, [x, z])
	->  atom_concat(W, es, W3)
	;   atom_length(W, L), L > 1, sub_atom(W, _, 1, 0, y),
	    L1 is L - 1, L2 is L1 - 1, sub_atom(W, L2, 1, _, C), \+ vowel(C)
	->  sub_atom(W, 0, L2, _, Stem), atom_concat(Stem, ies, W3)
	;   atom_concat(W, s, W3)
	).

irregular_third(go, goes).
irregular_third(do, does).
irregular_third(be, is).
irregular_third(have, has).

%   A word already in the third person (`sees`, `sings`, `has`): it ends in
%   s, and not in the ss, us or is of a noun or an adjective.
already_third(has).
already_third(does).
already_third(is).
already_third(was).
already_third(W) :-
	sub_atom(W, _, 1, 0, s),
	\+ ( member(E, [ss, us, is, os, as]), sub_atom(W, _, 2, 0, E) ).

vowel(C) :- memberchk(C, [a, e, i, o, u]).

		 /*******************************
		 *   THE INVENTED DICTIONARY    *
		 *******************************/

%   A Logical English document holding nothing but the invented templates.
%   Loading it is what turns them into a dictionary, and a dictionary is
%   all le_lps_document/4 needs; the sections it writes for the finished
%   document are its own.
declarations_document(Lines, Name, Text) :-
	le_writer:kw(meta_target, MT),
	le_writer:kw(known_as, KA),
	le_writer:kw(kb_open, KBO),
	le_writer:kw(kb_include, KBI),
	with_output_to(string(Text),
	    (	format("~w: lps.~n~n", [MT]),
		forall(( template_section(Kind, Key),
			 include_lines(Lines, Kind, Ls), Ls \== [] ),
		       (   le_writer:kw(Key, Header),
			   format("~w:~n", [Header]),
			   forall(member(line(_, F/_, T), Ls),
				  format("    ~w; ~w ~w.~n", [T, KA, F])),
			   nl
		       )),
		format("~w ~w ~w:~n~n", [KBO, Name, KBI])
	    )).

template_section(event, events).
template_section(action, actions).
template_section(prolog_event, prolog_events).
template_section(fluent, fluents).
template_section(timeless, templates).

include_lines(Lines, Kind, Ls) :-
	findall(line(Kind, X, T), member(line(Kind, X, T), Lines), Ls).

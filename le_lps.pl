/** <module> LPS backend for Logical English 2

    A third execution target, sibling to the Prolog and s(CASP) backends. It
    turns a Logical English document that declares

        the target language is: lps.

    into an LPS *internal-syntax* program — the frozen 2016 vocabulary of
    reactive_rule/2, l_int/2, l_events/2, initiated/3, terminated/3, updated/4,
    d_pre/1, initial_state/1 and observe/2 — together with a provenance list
    that points each generated term back at the `.le` sentence it came from.

    The contract with LPS(2) is docs/le_lps_interface.md, duplicated verbatim
    in that repository. The surface language is docs/le_lps_surface.md. Neither
    is restated here; what follows is how this module is built.

    ## Three stages, and why they are separate

    **Parsing** is le_grammar's, unchanged. The LPS sentence forms (`when …
    then …`, `it must not be true that …`, `initially …`) are extra kb_item
    clauses gated on the declared target, and each captures its antecedent and
    consequent as raw token lists. Nothing is interpreted there.

    **The second pass** is this module's, through le_grammar's multifile hooks:

      parse_node_extension/6      the temporal suffixes — `… at T`,
                                  `… from T1 to T2`, `… to T` — and the two
                                  consequent forms that are not literals,
                                  `initiate …` and `… becomes …`
      second_pass_item_extension/4 the LPS sentence forms

    It still interprets nothing about LPS. A condition comes out as
    `lps_at(Goal, T)`, which says only "this goal, at that time". Whether the
    goal is a fluent (so `holds/2`) or an event (so `happens/3`) is not decided
    here, because at second-pass time the declaration sections have not been
    processed yet.

    **The emitter** runs after load, over the KB module, exactly as
    le_scasp.pl does. By then `le_lps_role/2` records which declaration section
    each predicate came from, and that is what settles holds/2 versus
    happens/3. Doing it in one earlier pass would mean either ordering
    constraints on the document (declarations strictly before rules) or a
    second traversal; this way there are neither.

    ## What decides what

      - A literal's ROLE (fluent | event | action | prolog_event | timeless)
        comes from the section its template was declared in, never from how it
        is used. That is the distinction LPS cannot infer and the author must
        state.
      - `when` versus `if` decides causal law versus reactive rule. A `when`
        needs exactly one event or action in its antecedent — the trigger.
      - A temporal suffix is recognised by the HEAD NOUN of its variable being
        `time`. That is what tells `from a first place to a second place`
        (part of a template) from `from a first time to a second time` (a
        temporal annotation), and it is why the two can appear in the same
        sentence, as they do all through goat.le.
*/

:- module(le_lps, [
    le_lps_text/4,               % +LEText, -InternalText, -Provenance, -Issues
    le_lps_file/4,               % +Path, -InternalText, -Provenance, -Issues
    le_lps_module/5,             % +KBModule, +LEText, -Text, -Provenance, -Issues
    le_lps_json/1,               % +Path            (writes the §2 JSON object)
    le_lps_json_text/1,          % +LEText
    le_lps_dict/4,               % +Text, +Provenance, +Issues, -Dict
    offset_line_col/4,           % +Text, +Offset, -Line, -Col  (for le_service.pl)
    lps_split_time/5             % for le_lps_write.pl and the tests
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(http/json)).
:- use_module(le_grammar).
:- use_module(le_i18n).
:- use_module(le_kbs).

:- multifile le_grammar:parse_node_extension/6.
:- multifile le_grammar:second_pass_item_extension/4.


		 /*******************************
		 *     stage 2: the hooks       *
		 *******************************/

%!  le_grammar:parse_node_extension(+Tokens, +Children, +Templates, +VMIn, -VMOut, -Logic) is semidet.
%
%   The three body forms plain LE has no use for. Tried before everything else
%   in parse_node/6, and only under the LPS target, so a plain-LE document is
%   parsed exactly as it is today.

%   "<literal> becomes <expression>", the update form. Written as a relative
%   clause -- "the reward THAT IS a number becomes ..." -- so the literal is
%   recovered by deleting the `that`: "the reward is a number".
le_grammar:parse_node_extension(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
	le_grammar:lps_target,
	split_becomes(Tokens, LitTokens, VarTokens, ExprTokens),
	le_grammar:parse_literal(LitTokens, Templates, VMIn, VM1, Literal, _, true),
	time_or_var(VarTokens, VM1, VM2, Old),
	lps_expression(ExprTokens, Templates, VM2, VM3, Expr),
	Wrapped = lps_becomes(Literal, Old, Expr),
	(   Children == []
	->  VMOut = VM3, Logic = Wrapped
	;   le_grammar:hierarchy_to_logic(Children, Templates, VM3, VMOut, Kids),
	    ( Kids == true -> Logic = Wrapped ; Logic = and(Wrapped, Kids) )
	).

%   "initiate <fluent>" / "terminate <fluent>" in a consequent.
le_grammar:parse_node_extension(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
	le_grammar:lps_target,
	strip_kw(Tokens, Key, Rest),
	memberchk(Key-Wrapper, [lps_initiate-lps_initiate, lps_terminate-lps_terminate]),
	Rest \== [],
	le_grammar:parse_node(Rest, [], Templates, VMIn, VM1, Inner),
	Wrapped =.. [Wrapper, Inner],
	(   Children == []
	->  VMOut = VM1, Logic = Wrapped
	;   le_grammar:hierarchy_to_logic(Children, Templates, VM1, VMOut, Kids),
	    ( Kids == true -> Logic = Wrapped ; Logic = and(Wrapped, Kids) )
	).

%   A temporal suffix. Stripped here, so the core of the line is parsed by the
%   ordinary machinery -- templates, negation, aggregates and all.
%
%   Children are folded in AFTER the wrap, not passed down into it. A nested
%   line is a further conjunct of the rule, not part of the literal the suffix
%   times: in
%
%       if bob is in a room at a first time
%           and the light in the room is off at the first time
%
%   LE2's indentation makes the second line a child of the first, and passing
%   both into parse_node/6 would put `at a first time` around the conjunction
%   -- lps_at(and(...), T) -- which says something the author did not.
le_grammar:parse_node_extension(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
	le_grammar:lps_target,
	lps_split_time(Tokens, Core, Suffix, VMIn, VM1),
	Core \== [],
	le_grammar:parse_node(Core, [], Templates, VM1, VM2, Inner),
	wrap_time(Suffix, Inner, Wrapped),
	(   Children == []
	->  VMOut = VM2, Logic = Wrapped
	;   le_grammar:hierarchy_to_logic(Children, Templates, VM2, VMOut, Kids),
	    ( Kids == true -> Logic = Wrapped ; Logic = and(Wrapped, Kids) )
	).

inner_ctx(lps_from_to(_, A, B), _, from_to(A, B)) :- !.
inner_ctx(lps_at(_, T), _, at(T)) :- !.
inner_ctx(lps_to(_, T), _, from_to(_, T)) :- !.
inner_ctx(_, Ctx, Ctx).

wrap_time(at(T),         G, lps_at(G, T)).
wrap_time(from_to(A, B), G, lps_from_to(G, A, B)).
wrap_time(to(T),         G, lps_to(G, T)).

%!  le_grammar:second_pass_item_extension(+Templates, +Item, -NewItem, +M) is semidet.

le_grammar:second_pass_item_extension(Templates, lps_rule(Kind, AnteToks, ConsToks, Indent, Start, End),
				      lps(Kind, r(Ante, Cons), Start, End, ID), _M) :-
	item_id(Start, ID),
	le_grammar:parse_body(AnteToks, Indent, Templates, [], VM1, Ante),
	le_grammar:parse_body(ConsToks, Indent, Templates, VM1, _, Cons).

le_grammar:second_pass_item_extension(Templates, lps_denial(BodyToks, Indent, Start, End),
				      lps(denial, Body, Start, End, ID), _M) :-
	item_id(Start, ID),
	le_grammar:parse_body(BodyToks, Indent, Templates, [], _, Body).

le_grammar:second_pass_item_extension(Templates, lps_initially(BodyToks, Indent, Start, End),
				      lps(initially, Body, Start, End, ID), _M) :-
	item_id(Start, ID),
	le_grammar:parse_body(BodyToks, Indent, Templates, [], _, Body).

le_grammar:second_pass_item_extension(Templates, lps_goal(BodyToks, Indent, Start, End),
				      lps(goal, Body, Start, End, ID), _M) :-
	item_id(Start, ID),
	le_grammar:parse_body(BodyToks, Indent, Templates, [], _, Body).

le_grammar:second_pass_item_extension(_Templates, lps_setting(Key, Value, Start, End),
				      lps(setting, Key-Value, Start, End, ID), _M) :-
	item_id(Start, ID).

%   A rule whose HEAD carries a temporal suffix: an intensional fluent
%   (`… at T if …`) or a composite event (`… from T1 to T2 if …`). Which one it
%   is depends on the head's declared role, so it is left to the emitter.
le_grammar:second_pass_item_extension(Templates, rule(Head, BodyToks, Indent, Start, End, ID0),
				      lps(head_rule, h(WHead, Body), Start, End, ID), _M) :-
	le_grammar:lps_target,
	is_list(BodyToks),
	lps_split_time(Head, Core, Suffix, [], VM0),
	Core \== [],
	( var(ID0) -> item_id(Start, ID) ; ID = ID0 ),
	le_grammar:parse_literal(Core, Templates, VM0, VM1, Literal, _, true),
	wrap_time(Suffix, Literal, WHead),
	(   le_grammar:parse_body(BodyToks, Indent, Templates, VM1, _, Body)
	->  true
	;   Body = true
	).

%   A fact with `from T1 to T2` is an observation, wherever it is written: in a
%   scenario (the usual place) or in the knowledge base. It becomes an ordinary
%   clause so that the scenario machinery carries it unchanged.
le_grammar:second_pass_item_extension(Templates, fact(Head, Start, End),
				      clause(lps_observe(Event, T1, T2), true, Start, End, ID), _M) :-
	le_grammar:lps_target,
	lps_split_time(Head, Core, from_to(T1, T2), [], VM0),
	Core \== [],
	item_id(Start, ID),
	le_grammar:parse_literal(Core, Templates, VM0, _, Event, _, true).

%   A fact with `at T` is a timed fact: an intensional fluent with no body.
le_grammar:second_pass_item_extension(Templates, fact(Head, Start, End),
				      lps(head_rule, h(WHead, true), Start, End, ID), _M) :-
	le_grammar:lps_target,
	lps_split_time(Head, Core, at(T), [], VM0),
	Core \== [],
	item_id(Start, ID),
	le_grammar:parse_literal(Core, Templates, VM0, _, Literal, _, true),
	wrap_time(at(T), Literal, WHead).

item_id(Start, ID) :- format(atom(ID), 'lps_~w', [Start]).


		 /*******************************
		 *     the temporal suffix      *
		 *******************************/

%!  lps_split_time(+Tokens, -Core, -Suffix, +VMIn, -VMOut) is semidet.
%
%   Splits the temporal annotation off the end of a sentence. Suffix is
%   `from_to(T1,T2)`, `at(T)` or `to(T)`; Core is what is left, which is what
%   the ordinary parser sees.
%
%   The RIGHTMOST match wins, and both times must be time-like — a number, or a
%   variable phrase whose head noun is `time`. Without that test
%
%       the farmer rows from the second place to the first place
%                        from the second time to the third time
%
%   would split at the first `from` and lose half the template. With it, the
%   two are told apart by what they are about, which is also how a reader tells
%   them apart.
lps_split_time(Tokens, Core, from_to(T1, T2), VMIn, VMOut) :-
	last_split(Tokens, lps_from, Before, After),
	last_split(After, lps_to, T1Toks, T2Toks),
	time_term(T1Toks, VMIn, VM1, T1),
	time_term(T2Toks, VM1, VMOut, T2),
	Core = Before.
lps_split_time(Tokens, Core, at(T), VMIn, VMOut) :-
	last_split(Tokens, lps_at, Core, TToks),
	time_term(TToks, VMIn, VMOut, T).
lps_split_time(Tokens, Core, to(T), VMIn, VMOut) :-
	last_split(Tokens, lps_to, Core, TToks),
	time_term(TToks, VMIn, VMOut, T).

%   Before/After around the LAST occurrence of a keyword, at word level.
last_split(Tokens, Key, Before, After) :-
	findall(B-A, kw_split(Tokens, Key, B, A), Splits),
	Splits \== [],
	last(Splits, Before-After).

kw_split(Tokens, Key, Before, After) :-
	le_i18n:kw_synonym_words(Key, Words),
	append(Before, Rest, Tokens),
	match_words(Words, Rest, After).

match_words([], Rest, Rest).
match_words([W|Ws], [word(W0, _)|Ts], Rest) :- W0 == W, match_words(Ws, Ts, Rest).

%!  time_term(+Tokens, +VMIn, -VMOut, -Term) is semidet.
%
%   A time: an integer, or a variable phrase whose head noun is `time`.
time_term([number(N, _)], VM, VM, N) :- !.
time_term(Tokens, VMIn, VMOut, Var) :-
	Tokens \== [],
	maplist(word_of, Tokens, Words),
	atomic_list_concat(Words, ' ', Phrase),
	le_grammar:head_noun_type(Phrase, time),
	le_grammar:extract_var_name(Words, Name),
	le_grammar:unify_with_vmap(Name, Var, VMIn, VMOut, true).

word_of(word(W, _), W).

%   Like time_term/4 but for any variable phrase (the Old of an update).
time_or_var([number(N, _)], VM, VM, N) :- !.
time_or_var(Tokens, VMIn, VMOut, Var) :-
	maplist(word_of, Tokens, Words),
	le_grammar:extract_var_name(Words, Name),
	le_grammar:unify_with_vmap(Name, Var, VMIn, VMOut, true).


		 /*******************************
		 *      the update form         *
		 *******************************/

%   "<phrase> that is <var> becomes <expression>"
split_becomes(Tokens, LitTokens, VarTokens, ExprTokens) :-
	last_split(Tokens, lps_becomes, Left, ExprTokens),
	ExprTokens \== [],
	last_split(Left, lps_that_is, Head, VarTokens),
	VarTokens \== [],
	le_i18n:kw_synonym_words(lps_that_is, [_That|Copula]),
	append(Copula, VarTokens, Tail0),
	maplist(as_word_token, Tail0, Tail),
	append(Head, Tail, LitTokens).

as_word_token(word(W, L), word(W, L)) :- !.
as_word_token(W, word(W, loc(0, 0))).

%   The right-hand side: an arithmetic expression, or a bare variable.
lps_expression(Tokens, Templates, VMIn, VMOut, Expr) :-
	(   le_grammar:parse_expression(Tokens, VMIn, VMOut, Templates, Expr, true)
	->  true
	;   time_or_var(Tokens, VMIn, VMOut, Expr)
	).

strip_kw(Tokens, Key, Rest) :-
	member(Key, [lps_initiate, lps_terminate]),
	le_i18n:kw_synonym_words(Key, Words),
	match_words(Words, Tokens, Rest).


		 /*******************************
		 *      stage 3: the emitter    *
		 *******************************/

%!  le_lps_text(+LEText, -InternalText, -Provenance, -Issues) is det.
le_lps_text(LEText, Text, Provenance, Issues) :-
	(   catch(le_kbs:load_text(LEText, KB), E, (print_message(error, E), fail))
	->  le_lps_module(KB, LEText, Text, Provenance, Issues)
	;   Text = "", Provenance = [],
	    Issues = [le_lps_issue(error, parse_error, 'the document did not parse', 0, 0)]
	).

%!  le_lps_file(+Path, -InternalText, -Provenance, -Issues) is det.
le_lps_file(Path, Text, Provenance, Issues) :-
	read_file_to_string(Path, LEText, [encoding(utf8)]),
	le_lps_text(LEText, Text, Provenance, Issues).

%!  le_lps_module(+KB, +LEText, -Text, -Provenance, -Issues) is det.
%
%   The emitter proper: KB is a loaded knowledge base module, LEText its source
%   (used only to turn character offsets into line and column, and may be the
%   empty string, in which case the provenance list comes back empty — which
%   the contract allows).
le_lps_module(KB, LEText, Text, Provenance, Issues) :-
	le_kbs:ensure_kb_language(KB),
	with_kb(KB, emit_terms(KB, Entries0, Issues0)),
	kb_issues(KB, KBIssues),
	append(KBIssues, Issues0, Issues1),
	sort(0, @<, Issues1, Issues2),
	number_entries(Entries0, 0, Entries),
	terms_text(Entries, Text),
	provenance_of(Entries, LEText, Provenance),
	maplist(locate_issue(LEText), Issues2, Issues).

%   An entry is e(Term, Start) — Start being the character offset of the
%   sentence it came from, or `none` for a term the emitter generated on its
%   own (the declarations, the planning-mode directive).
number_entries([], _, []).
number_entries([e(T, S)|Es], N, [e(N, T, S)|Rest]) :-
	N1 is N + 1, number_entries(Es, N1, Rest).

terms_text(Entries, Text) :-
	with_output_to(string(Text),
		       forall(member(e(_, Term, _), Entries), write_term_line(Term))).

write_term_line(Term) :-
	\+ \+ ( numbervars(Term, 0, _), format('~q.~n', [Term]) ).

provenance_of(_, "", []) :- !.
provenance_of(Entries, LEText, Provenance) :-
	findall(prov(N, Line, Col),
		( member(e(N, _, Start), Entries), integer(Start),
		  offset_line_col(LEText, Start, Line, Col) ),
		Provenance).

locate_issue(LEText, le_lps_issue(S, T, M, Start, _),
	     le_lps_issue(S, T, M, Line, Col)) :-
	(   integer(Start), LEText \== ""
	->  offset_line_col(LEText, Start, Line, Col)
	;   Line = 0, Col = 0
	).

%!  offset_line_col(+Text, +Offset, -Line, -Col) is det.
%
%   1-based line, 0-based column, as docs/le_lps_interface.md §2 requires.
offset_line_col(Text, Offset, Line, Col) :-
	sub_string(Text, 0, Offset, _, Before),
	split_string(Before, "\n", "", Parts),
	length(Parts, Line),
	last(Parts, LastLine),
	string_length(LastLine, Col).

%   LE-side issues the loader already recorded, carried across unchanged.
kb_issues(KB, Issues) :-
	(   current_predicate(KB:le_issue/6)
	->  findall(le_lps_issue(Sev, Type, Msg, Start, 0),
		    KB:le_issue(Sev, Type, Msg, _Fix, Start, _End), Issues)
	;   Issues = []
	).


		 /*******************************
		 *      the term families       *
		 *******************************/

emit_terms(KB, Entries, Issues) :-
	findall(E-I, emit_family(KB, E, I), Pairs),
	pairs_keys_values(Pairs, EntryLists, IssueLists),
	append(EntryLists, Entries),
	append(IssueLists, Issues).

%   Source order within a family, families in the order LPS(2) prefers to read
%   them: settings, declarations, initial state, then everything else.
emit_family(KB, Es, []) :- settings(KB, Es).
emit_family(KB, Es, []) :- declarations(KB, Es).
emit_family(KB, Es, []) :- planning_directive(KB, Es).
emit_family(KB, Es, Is) :- initial_states(KB, Es, Is).
emit_family(KB, Es, Is) :- observations(KB, Es, Is).
emit_family(KB, Es, Is) :- timeless(KB, Es, Is).
emit_family(KB, Es, Is) :- head_rules(KB, Es, Is).
emit_family(KB, Es, Is) :- causal_laws(KB, Es, Is).
emit_family(KB, Es, Is) :- reactive_rules(KB, Es, Is).
emit_family(KB, Es, Is) :- denials(KB, Es, Is).
emit_family(KB, Es, Is) :- goals(KB, Es, Is).

item(KB, Kind, Payload, Start) :-
	current_predicate(KB:le_lps_item/3),
	KB:le_lps_item(Kind, Payload, ID),
	( item_start(KB, ID, S) -> Start = S ; Start = none ).

item_start(KB, ID, Start) :-
	current_predicate(KB:le_source_info/4),
	KB:le_source_info(_, Start, _, ID), !.

settings(KB, Es) :-
	findall(e(Term, Start),
		( item(KB, setting, Key-Value, Start), Term =.. [Key, Value] ),
		Es).

%!  declarations(+KB, -Entries) is det.
%
%   One list per role, each the most general term of every predicate declared
%   with that role. Emitted even when a program declares nothing of a kind, in
%   which case the list is empty and the term is dropped.
declarations(KB, Es) :-
	findall(e(Term, none),
		( member(Role-Functor, [fluent-fluents, event-events,
					action-actions, prolog_event-prolog_events]),
		  role_terms(KB, Role, Terms), Terms \== [],
		  Term =.. [Functor, Terms] ),
		Es).

role_terms(KB, Role, Terms) :-
	findall(T,
		( current_predicate(KB:le_lps_role/2),
		  KB:le_lps_role(F0/N, Role),
		  lps_functor(KB, F0/N, F),
		  functor(T, F, N) ),
		Terms0),
	sort(Terms0, Terms).

%   `; known as f`, or LE2's derived functor when the author did not say.
lps_functor(KB, F0/N, F) :-
	(   current_predicate(KB:le_lps_functor/2),
	    KB:le_lps_functor(F0/N, F1)
	->  F = F1
	;   F = F0
	).

%   A goal is the declaration that this is a planning problem (§3.8).
planning_directive(KB, [e((:- lps_engine(planning, [search(bfs)])), none)]) :-
	item(KB, goal, _, _), !.
planning_directive(_, []).

initial_states(KB, Es, Is) :-
	findall(E-I,
		( item(KB, initially, Body, Start),
		  initial_state_entry(KB, Body, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

initial_state_entry(KB, Body, Start, [e(initial_state(Fluents), Start)], Issues) :-
	conjuncts(Body, Goals),
	lower_all(KB, Goals, none, Fluents0, Issues),
	maplist(bare_fluent, Fluents0, Fluents).

bare_fluent(holds(F, _), F) :- !.
bare_fluent(F, F).

observations(KB, Es, []) :-
	findall(e(observe([Event], T2), none),
		( observed(KB, Event0, T2), rename(Event0, Event) ),
		Es).

observed(KB, Event0, T2) :-
	(   current_predicate(KB:scenario/2),
	    KB:scenario(_, Terms), member(Term, Terms),
	    scenario_observation(Term, Event0, _T1, T2)
	;   current_predicate(KB:lps_observe/3),
	    KB:lps_observe(Event0, _T1, T2)
	).

scenario_observation(fact_with_source(lps_observe(E, T1, T2), _, _), E, T1, T2).
scenario_observation(lps_observe(E, T1, T2), E, T1, T2).

%!  timeless(+KB, -Entries, -Issues) is det.
%
%   Everything the author wrote as an ordinary LE fact or rule over templates
%   with no LPS role: the domain vocabulary (`scissors beats paper`), which LPS
%   calls timeless. Facts stay facts; a rule becomes `l_timeless/2`.
timeless(KB, Es, []) :-
	findall(E, timeless_entry(KB, E), Es).

timeless_entry(KB, e(Term, Start)) :-
	current_predicate(KB:le_source_info/4),
	KB:le_source_info(Ref, Start, _, _),
	catch(clause(KB:Head, Body, Ref), _, fail),
	timeless_head(KB, Head),
	rename(Head, Head1),
	(   Body == true
	->  Term = Head1
	;   strip_body(Body, Goals),
	    Term = l_timeless(Head1, Goals)
	).

timeless_head(KB, Head) :-
	callable(Head),
	functor(Head, F, N),
	\+ le_kbs:is_system_predicate(F/N),
	\+ lps_role(KB, Head, _),
	F \== lps_observe.

%   The body of a timeless rule: LE's and/or tree, flattened, with its le_at
%   wrappers and its built-ins lowered. No times are involved by definition.
strip_body(Body, Goals) :-
	conjuncts(Body, Gs),
	maplist(plain_goal, Gs, Goals).

plain_goal(G0, G) :- strip_le_at(G0, G1), builtin(G1, G2), !, G = G2.
plain_goal(G0, G) :- strip_le_at(G0, G1), rename(G1, G).

head_rules(KB, Es, Is) :-
	findall(E-I,
		( item(KB, head_rule, h(WHead, Body), Start),
		  head_rule_entry(KB, WHead, Body, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

%   `… at T if …` is an intensional fluent; `… from T1 to T2 if …` is a
%   composite event. Which is which is checked against the declaration rather
%   than assumed from the suffix, so a mismatch is reported instead of
%   silently producing a program that cannot fire.
head_rule_entry(KB, lps_at(F0, T), Body, Start, [e(l_int(holds(F, T), Goals), Start)], Is) :- !,
	rename(F0, F),
	body_goals(KB, Body, at(T), Goals, Is).
head_rule_entry(KB, lps_from_to(E0, T1, T2), Body, Start,
		[e(l_events(happens(E, T1, T2), Goals), Start)], Is) :- !,
	rename(E0, E),
	body_goals(KB, Body, from_to(T1, T2), Goals, Is).
head_rule_entry(KB, lps_to(E0, T), Body, Start,
		[e(l_events(happens(E, _, T), Goals), Start)], Is) :-
	rename(E0, E),
	body_goals(KB, Body, at(T), Goals, Is).

body_goals(_, true, _, [], []) :- !.
body_goals(KB, Body, Ctx, Goals, Issues) :-
	conjuncts(Body, Gs),
	lower_all(KB, Gs, Ctx, Goals, Issues).

%!  causal_laws(+KB, -Entries, -Issues) is det.
%
%   `when <trigger and conditions> then <effects>`. One law per effect.
causal_laws(KB, Es, Is) :-
	findall(E-I,
		( item(KB, when, r(Ante, Cons), Start),
		  causal_entry(KB, Ante, Cons, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

causal_entry(KB, Ante, Cons, Start, Entries, Issues) :-
	conjuncts(Ante, AnteGoals),
	lower_all(KB, AnteGoals, when(T1, T2), Lowered, Is1),
	partition(is_happens, Lowered, Triggers, Conditions),
	(   Triggers = [happens(Ev, T1, T2)]
	->  conjuncts(Cons, ConsGoals),
	    findall(e(Law, Start),
		    ( member(C, ConsGoals),
		      causal_law(KB, happens(Ev, T1, T2), Conditions, C, Law) ),
		    Entries),
	    Issues = Is1
	;   length(Triggers, NT),
	    le_i18n:le_msg(lps_when_no_trigger_desc, [count-NT], Desc),
	    Entries = [],
	    Issues = [le_lps_issue(error, lps_when_no_trigger, Desc, Start, 0)|Is1]
	).

is_happens(happens(_, _, _)).

causal_law(KB, Trigger, Conds, C, Law) :-
	(   C = lps_becomes(Fluent0, Old, Expr)
	->  rename(Fluent0, Fluent),
	    append(Conds, [New is Expr], Cs),
	    Law = updated(Trigger, Fluent, Old-New, Cs)
	;   lower(KB, C, none, Lowered, _),
	    (   Lowered = holds(not(F), _)
	    ->  Law = terminated(Trigger, F, Conds)
	    ;   Lowered = holds(F, _)
	    ->  Law = initiated(Trigger, F, Conds)
	    ;   Lowered = happens(initiate(F), _, _)
	    ->  Law = initiated(Trigger, F, Conds)
	    ;   Lowered = happens(terminate(F), _, _)
	    ->  Law = terminated(Trigger, F, Conds)
	    ;   fail
	    )
	).

reactive_rules(KB, Es, Is) :-
	findall(E-I,
		( item(KB, if, r(Ante, Cons), Start),
		  reactive_entry(KB, Ante, Cons, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

reactive_entry(KB, Ante, Cons, Start, [e(reactive_rule(A, C), Start)], Issues) :-
	conjuncts(Ante, AnteGoals),
	lower_all(KB, AnteGoals, at(T1), A, Is1),
	conjuncts(Cons, ConsGoals),
	lower_all(KB, ConsGoals, after(T1), C, Is2),
	append(Is1, Is2, Issues).

denials(KB, Es, Is) :-
	findall(E-I,
		( item(KB, denial, Body, Start),
		  denial_entry(KB, Body, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

denial_entry(KB, Body, Start, [e(d_pre(Goals), Start)], Issues) :-
	conjuncts(Body, Gs),
	lower_all(KB, Gs, at(_), Goals, Issues).

goals(KB, Es, Is) :-
	findall(E-I,
		( item(KB, goal, Body, Start),
		  goal_entry(KB, Body, Start, E, I) ),
		Pairs),
	unzip(Pairs, Es, Is).

goal_entry(KB, Body, Start, [e(achieve(Fluents), Start)], Issues) :-
	conjuncts(Body, Gs),
	lower_all(KB, Gs, none, Lowered, Issues),
	maplist(bare_fluent, Lowered, Fluents).

unzip(Pairs, Es, Is) :-
	pairs_keys_values(Pairs, EL, IL),
	append(EL, Es), append(IL, Is).


		 /*******************************
		 *	      lowering		*
		 *******************************/

%!  lower(+KB, +LEGoal, +Context, -LPSGoal, -Issues) is det.
%
%   One LE body goal to one LPS internal goal. Context supplies the times of an
%   untimed literal: `at(T)` for a condition, `from_to(T1,T2)` for a
%   consequent or a trigger, `none` where there is no time at all (the initial
%   state, a goal).

lower(KB, G0, Ctx, G, Is) :- strip_le_at(G0, G1), G1 \== G0, !, lower(KB, G1, Ctx, G, Is).

lower(_, true, _, true, []) :- !.

lower(KB, lps_at(G, T), _, Out, Is) :- !, lower(KB, G, at(T), Out, Is).
lower(KB, lps_from_to(G, A, B), _, Out, Is) :- !, lower(KB, G, from_to(A, B), Out, Is).
lower(KB, lps_to(G, T), _, Out, Is) :- !, lower(KB, G, from_to(_, T), Out, Is).

%   `initiate <fluent> from T1 to T2`: the suffix is parsed INSIDE the
%   initiate (it is written after the fluent), so its times are the effect's,
%   not the enclosing rule's.
lower(KB, lps_initiate(G), Ctx, happens(initiate(F), T1, T2), Is) :- !,
	inner_ctx(G, Ctx, Ctx1),
	lower(KB, G, Ctx1, Inner, Is),
	bare_fluent(Inner, F),
	times(Ctx1, T1, T2).
lower(KB, lps_terminate(G), Ctx, happens(terminate(F), T1, T2), Is) :- !,
	inner_ctx(G, Ctx, Ctx1),
	lower(KB, G, Ctx1, Inner, Is),
	bare_fluent(Inner, F),
	times(Ctx1, T1, T2).

%   Negation. A negated fluent is `holds(not F, T)` — LPS's own form, not a
%   Prolog `\+`; a negated event is `happens(not E, T1, T2)`. Anything else is
%   ordinary negation as failure.
lower(KB, not(G0), Ctx, Out, Is) :- !,
	lower(KB, G0, Ctx, Inner, Is),
	(   Inner = holds(F, T)       -> Out = holds(not(F), T)
	;   Inner = happens(E, T1, T2) -> Out = happens(not(E), T1, T2)
	;   Out = not(Inner)
	).

%   Aggregates. LE gives `count([each|Elems], Goal, [Result])`; LPS evaluates a
%   findall inside `holds/2` so that its inner goals are resolved at the right
%   time (this is the shape the LE1 specimen produced, and what the engine
%   expects).
lower(KB, Agg, Ctx, goals(Out), Is) :-
	Agg =.. [Op, [each|Elems], Goal, Results],
	memberchk(Op, [count, sum, average, min, max]), !,
	conjuncts(Goal, Gs),
	lower_all(KB, Gs, Ctx, Inner, Is),
	agg_var(Elems, Elem),
	agg_var(Results, Result),
	ctx_time(Ctx, T),
	aggregate_goal(Op, Elem, Inner, Result, T, Out).

%   A conjunction or disjunction that survived flattening -- which happens when
%   a nested `or` branch sits under a conjunct. Kept as a term rather than
%   flattened into the surrounding list, because the two are not the same.
lower(KB, and(A, B), Ctx, ','(A1, B1), Is) :- !,
	lower(KB, A, Ctx, A1, Is1), lower(KB, B, Ctx, B1, Is2), append(Is1, Is2, Is).
lower(KB, or(A, B), Ctx, ';'(A1, B1), Is) :- !,
	lower(KB, A, Ctx, A1, Is1), lower(KB, B, Ctx, B1, Is2), append(Is1, Is2, Is).

lower(_, G, _, Out, []) :- builtin(G, Out), !.

%   A plain literal. Its role decides the form; with no role it is a timeless
%   goal, called as Prolog at no particular time. Either way `; known as f`
%   applies, so a timeless template renamed in its declaration is renamed at
%   every use as well.
lower(KB, G, Ctx, Out, []) :-
	callable(G),
	(   lps_role(KB, G, Role)
	->  lps_literal(Role, G, Ctx, Out)
	;   rename(G, Out)
	).

%   LE wraps an aggregate's element and result as var(Name, Var); the name is
%   for explanations and has no place in a program.
agg_var([var(_, V)], V) :- !.
agg_var([X], X) :- !.
agg_var(Xs, Xs).

lower_all(_, [], _, [], []).
lower_all(KB, [G|Gs], Ctx, Out, Issues) :-
	lower(KB, G, Ctx, G1, Is1),
	lower_all(KB, Gs, Ctx, Rest, Is2),
	(   G1 == true      -> Out = Rest
	;   G1 = goals(Many) -> append(Many, Rest, Out)
	;   Out = [G1|Rest]
	),
	append(Is1, Is2, Issues).

lps_literal(fluent, G, Ctx, holds(G1, T)) :- rename(G, G1), ctx_time(Ctx, T).
lps_literal(event, G, Ctx, happens(G1, T1, T2)) :- rename(G, G1), times(Ctx, T1, T2).
lps_literal(action, G, Ctx, happens(G1, T1, T2)) :- rename(G, G1), times(Ctx, T1, T2).
lps_literal(prolog_event, G, Ctx, happens(G1, T1, T2)) :- rename(G, G1), times(Ctx, T1, T2).

%   Which time an untimed literal takes from its context. A fluent condition
%   inside a `when` holds at T1 -- the state the event happens IN -- which is
%   where upstream evaluates the conditions of a causal law; a consequent of a
%   reactive rule starts at the antecedent's time and ends whenever it ends.
ctx_time(at(T), T) :- !.
ctx_time(when(T1, _), T1) :- !.
ctx_time(after(T1), T1) :- !.
ctx_time(from_to(_, T2), T2) :- !.
ctx_time(none, _).

times(from_to(T1, T2), T1, T2) :- !.
times(when(T1, T2), T1, T2) :- !.
times(after(T1), T1, _) :- !.
times(at(T), T, _) :- !.
times(none, _, _).

%   `; known as f` applied to a literal.
rename(G0, G) :-
	(   compound(G0), current_kb(KB)
	->  G0 =.. [F0|Args],
	    length(Args, N),
	    lps_functor(KB, F0/N, F1),
	    G =.. [F1|Args]
	;   atom(G0), current_kb(KB)
	->  ( lps_functor(KB, G0/0, F1) -> G = F1 ; G = G0 )
	;   G = G0
	).

lps_role(KB, G, Role) :-
	callable(G),
	functor(G, F, N),
	current_predicate(KB:le_lps_role/2),
	KB:le_lps_role(F/N, Role), !.

%   An aggregate is TWO LPS goals: the findall, which the engine evaluates at
%   the aggregate's time (hence the holds/2 wrapper -- its inner goals are a
%   list, which is LPS's own findall convention), and the reduction, which is
%   ordinary Prolog. Returned as goals/1 so lower_all/5 splices them into the
%   condition list rather than nesting a ','/2 inside one element.
aggregate_goal(count, Elem, Inner, Result, T,
	       [holds(findall(Elem, Inner, L), T), length(L, Result)]) :- !.
aggregate_goal(sum, Elem, Inner, Result, T,
	       [holds(findall(Elem, Inner, L), T), sum_list(L, Result)]) :- !.
aggregate_goal(Op, Elem, Inner, Result, T,
	       [holds(findall(Elem, Inner, L), T), Goal]) :-
	memberchk(Op-Pred, [average-mean_list, min-min_list, max-max_list]),
	Goal =.. [Pred, L, Result].

%   LE's built-ins, lowered to the Prolog LPS already runs.
builtin(le_ge(X, Y),          X >= Y).
builtin(le_le(X, Y),          X =< Y).
builtin(le_gt(X, Y),          X > Y).
builtin(le_lt(X, Y),          X < Y).
builtin(le_equal_to(X, Y),    X = Y).
builtin(le_not_equal_to(X, Y), X \= Y).
builtin(le_assign(X, Y),      X is Y).
builtin(le_is(X, Y),          X is Y).
builtin(le_is_in(X, L),       member(X, L)).
builtin(le_known(X),          ground(X)).
builtin(prolog_call(G),       G).

strip_le_at(le_at(G, _, _), G) :- !.
strip_le_at(G, G).

conjuncts(true, []) :- !.
conjuncts(and(A, B), Gs) :- !, conjuncts(A, As), conjuncts(B, Bs), append(As, Bs, Gs).
conjuncts(','(A, B), Gs) :- !, conjuncts(A, As), conjuncts(B, Bs), append(As, Bs, Gs).
conjuncts(le_at(G, _, _), Gs) :- !, conjuncts(G, Gs).
conjuncts(G, [G]).


		 /*******************************
		 *   the current KB, for rename *
		 *******************************/

:- thread_local current_kb_/1.

current_kb(KB) :- current_kb_(KB).

with_kb(KB, Goal) :-
	setup_call_cleanup(( retractall(current_kb_(_)), assertz(current_kb_(KB)) ),
			   Goal,
			   retractall(current_kb_(_))).


		 /*******************************
		 *	     the JSON		*
		 *******************************/

%!  le_lps_json(+Path) is det.
%
%   Writes the docs/le_lps_interface.md §2 object to the current output, as one
%   line, so that a caller reading the child's stdout can find it. This is
%   transport 3.3.
le_lps_json(Path) :-
	read_file_to_string(Path, LEText, [encoding(utf8)]),
	le_lps_json_text(LEText).

le_lps_json_text(LEText) :-
	le_lps_text(LEText, Text, Provenance, Issues),
	le_lps_dict(Text, Provenance, Issues, Dict),
	json_write_dict(current_output, Dict, [width(0)]),
	nl.

%!  le_lps_dict(+Text, +Provenance, +Issues, -Dict) is det.
le_lps_dict(Text, Provenance, Issues, _{lps: Text, provenance: P, issues: I}) :-
	findall(_{index: N, line: Line, col: Col, kind: "le"},
		member(prov(N, Line, Col), Provenance), P),
	findall(_{severity: S, type: T, message: M, line: L, col: C},
		( member(le_lps_issue(S0, T0, M0, L, C), Issues),
		  atom_string(S0, S), atom_string(T0, T),
		  ( atom(M0) -> atom_string(M0, M) ; M = M0 ) ),
		I).

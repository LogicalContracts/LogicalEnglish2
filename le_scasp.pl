/** <module> s(CASP) backend for Logical English 2

    A second execution target, sibling to the Prolog backend. It emits an
    s(CASP) program from a loaded LE knowledge base (the same clauses the Prolog
    reasoner uses, but lowered to s(CASP) constructs), runs it in-process via
    `library(scasp)`, and normalises the resulting justification tree into the
    same explanation-tree JSON the existing UI consumes.

    Design notes (see docs/project/plans/sCASP_plan.md):
      - The LE clause bodies are trees of and/2, or/2, not/1 and le_at/3 wrappers
        over leaf goals; we strip le_at, translate the connectives, and lower
        each leaf.
      - Arithmetic and comparisons are lowered *relationally* to CLP(Q)
        constraints (#=, #>, #>=, ...) rather than functional is/2, so an answer
        may come back as a constraint (the headline feature).
      - Every user template becomes a `#pred` directive carrying its LE sentence,
        so s(CASP)'s own --human output reads in the program's domain language
        and cross-checks our normaliser.
      - Constructs s(CASP) cannot run (aggregates, `prolog` goals, list
        membership, date arithmetic) are reported as le_scasp_issue/3 terms;
        such a program is Prolog-only: le_scasp_check/3 turns them into the
        problems for which See s(CASP) and the s(CASP) engine refuse it,
        rather than show or run a program that means something else.
*/
:- module(le_scasp, [
    le_scasp_available/0,
    le_scasp_program_text/3,     % +KBModule, -Text, -Issues
    le_scasp_check/3,            % +KBModule, +Issues, -Problems
    le_scasp_blocking_issue/1,   % +Issue
    le_scasp_query/6,            % +KBModule, +ScenarioName, +Goal, +Options, -Answers, -Issues
    le_scasp_tree_json/4,        % +KBModule, +Tree, +Options, -JSON
    le_scasp_stratification/2,   % +KBModule, -NegativeCycles
    le_scasp_symbolic_goal/4,    % +KBModule, +GoalInstance, -DisplayGoal, -Constraints
    le_scasp_assumptions/3       % +KBModule, +Tree, -Assumptions
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(pairs)).
:- use_module(library(error)).
:- use_module(library(ugraphs)).
:- use_module(library(ordsets)).
:- use_module(le_i18n).

%!  scasp_msg(+Key, +Pairs, -Text) is det.
%
%   The natural-language text of an s(CASP) issue, looked up in the active
%   language from i18n/messages.csv (English fallback). All user-facing issue
%   strings go through here rather than being hardcoded — see i18n/README.md.
scasp_msg(Key, Pairs, Text) :- le_i18n:le_msg(Key, Pairs, Text).

%!  scasp_issue(+Kind, +RuleID, +Key, +Pairs, -Issue) is det.
%
%   Build an le_scasp_issue/3 whose message is the i18n text for Key.
scasp_issue(Kind, RuleID, Key, Pairs, le_scasp_issue(Kind, RuleID, Msg)) :-
    scasp_msg(Key, Pairs, Msg).

% library(scasp) is an optional pack; guard its presence so LE keeps working
% (Prolog-only) when it is not installed.
:- if(exists_source(library(scasp))).
:- use_module(library(scasp)).
:- use_module(library(scasp/human), []).
have_scasp.
:- else.
% Without the pack, library(scasp)'s operators do not exist — and this file is
% written in them: `X #>= Y`, `not X`. Eleven clauses of the emitter and the
% normaliser then fail to READ, which is why a server with no s(CASP) installed
% printed eleven syntax errors at load and four discontiguous warnings (the
% unparsed clauses split their predicates in two).
%
% Declaring the operators here makes the file parse either way. The clauses
% still never run — le_scasp_available/0 is false without have_scasp/0, and
% every entry point checks it — so this changes what the reader accepts, not
% what the module does. SWI operators declared inside a module are local to it,
% so nothing outside le_scasp sees them.
:- op(700, xfx, #=).
:- op(700, xfx, #<>).
:- op(700, xfx, #<).
:- op(700, xfx, #>).
:- op(700, xfx, #=<).
:- op(700, xfx, #>=).
:- op(900, fy, not).
:- endif.

%!  le_scasp_available is semidet.
%
%   True when the s(CASP) pack is installed and usable.
le_scasp_available :- current_predicate(have_scasp/0).


		 /*******************************
		 *         EMITTER (WP2)        *
		 *******************************/

%!  le_scasp_program_text(+KBModule, -Text:string, -Issues:list) is det.
%
%   Render the loaded KB as an s(CASP) source program (string), suitable both
%   for display ("See s(CASP)") and for consulting into a unit module to solve.
%   Issues is a list of le_scasp_issue(Kind, RuleID, Message) for constructs the
%   s(CASP) backend cannot handle.
le_scasp_program_text(KBModule, Text, Issues) :-
    nb_setval(le_scasp_forall_n, 0),
    opposite_map(KBModule, OppMap), b_setval(le_scasp_opposites, OppMap),
    kb_rule_clauses(KBModule, Rules),
    kb_fact_clauses(KBModule, Facts),
    findall(P, pred_directive(KBModule, P), Preds0),
    sort(Preds0, Preds),
    findall(A, abducible_directive(KBModule, A), Abds0),
    sort(Abds0, Abds),
    emit_rules(KBModule, Rules, RuleLines, RuleIssues),
    emit_facts(KBModule, Facts, FactLines, FactIssues),
    kb_constraint_clauses(KBModule, Constraints),
    emit_rules(KBModule, Constraints, ConstraintLines, ConstraintIssues),
    opposite_constraints(KBModule, OppLines0),
    append(ConstraintLines, OppLines0, OppLines),
    append([RuleIssues, FactIssues, ConstraintIssues], Issues),
    with_output_to(string(Text),
        ( format("% s(CASP) program generated from Logical English KB ~w~n~n", [KBModule]),
          forall(member(L, Preds),  format("~w~n", [L])),
          ( Preds == [] -> true ; nl ),
          forall(member(L, Abds),   format("~w~n", [L])),
          ( Abds == [] -> true ; nl ),
          forall(member(L, FactLines), format("~w~n", [L])),
          ( FactLines == [] -> true ; nl ),
          forall(member(L, RuleLines), format("~w~n", [L])),
          ( OppLines == [] -> true ; nl ),
          forall(member(L, OppLines), format("~w~n", [L]))
        )).

% kb_rule_clauses(+KB, -Rules): Rules is a list of rule(ID, Start, End, Head, Body)
% for user (non-metadata, non-builtin) rules with a non-true body.
kb_rule_clauses(KB, Rules) :-
    findall(rule(ID, S, E, Head, Body),
            ( KB:le_source_info(Ref, S, E, ID),
              clause(KB:Head, Body, Ref),
              Body \== true,
              user_predicate(KB, Head)
            ),
            Rules).

% kb_constraint_clauses(+KB, -Rules): the program's integrity constraints (`it
% must not be true that …`, le_constraint/1) as rules with the head `false` —
% s(CASP)'s global constraints, which every model, and so every set of
% abducibles it assumes, must satisfy.
kb_constraint_clauses(KB, Rules) :-
    findall(rule(ID, S, E, false, Body),
            ( KB:le_source_info(Ref, S, E, ID),
              clause(KB:le_constraint(_), Body, Ref)
            ),
            Rules).

% kb_fact_clauses(+KB, -Facts): unit clauses for user predicates (Body==true).
kb_fact_clauses(KB, Facts) :-
    findall(fact(ID, S, E, Head),
            ( KB:le_source_info(Ref, S, E, ID),
              clause(KB:Head, true, Ref),
              user_predicate(KB, Head)
            ),
            Facts).

% user_predicate(+KB, +Head): Head is a user domain predicate, not LE metadata,
% not a system/comparison builtin, and known to a template.
user_predicate(KB, Head) :-
    callable(Head),
    functor(Head, F, A),
    %  is_a/2 is LE's own (types, the ontology), but its clauses in the
    %  program are the program's
    ( F/A == is_a/2 -> true ; \+ reasoner:le_metadata_predicate(F/A) ),
    \+ le_builtin_functor(F),
    ( known_template(KB, F, A) -> true ; true ).

% Functors that are LE plumbing / builtins, never emitted as domain predicates.
le_builtin_functor(le_at).
le_builtin_functor(le_constraint).
le_builtin_functor(le_is).
le_builtin_functor(le_assign).
le_builtin_functor(le_ge).
le_builtin_functor(le_le).
le_builtin_functor(le_gt).
le_builtin_functor(le_lt).
le_builtin_functor(le_equal_to).
le_builtin_functor(le_not_equal_to).
le_builtin_functor(le_is_in).
le_builtin_functor(le_is_days_after).
le_builtin_functor(le_is_months_after).
le_builtin_functor(le_minimum).
le_builtin_functor(le_maximum).
le_builtin_functor(le_known).
le_builtin_functor(prolog_call).
le_builtin_functor(and).
le_builtin_functor(or).
le_builtin_functor(not).
le_builtin_functor(for_all_cases).
le_builtin_functor(le_holds).
%   LE's own records, which are not the program's clauses: the ontology
%   section's record (its clauses are is_a/2 clauses of their own), flip
%   expectations, services.
le_builtin_functor(ontology).
le_builtin_functor(le_expected_changes).
le_builtin_functor(le_service).
le_builtin_functor(le_service_template).
%   Where a document is published and where its text is (`... is published
%   at ...`, `the text of ... is at ...`): records the explanation's citations
%   read, not conditions of the program.
le_builtin_functor(le_published_at).
le_builtin_functor(le_text_at).

known_template(KB, F, A) :-
    KB:le_dict(dict([F|Args], _, _, _, _, _, _)),
    length(Args, A), !.

		 /*******************************
		 *      #pred DIRECTIVES        *
		 *******************************/

%!  pred_directive(+KB, -Line:string) is nondet.
%
%   A `#pred` directive for each user template, mapping the predicate to its LE
%   sentence with typed @-placeholders (the almost one-to-one LE→#pred mapping).
%   The head and the format string share variables (via a single copy_term +
%   numbervars) so their names line up, as s(CASP) requires.
pred_directive(KB, Line) :-
    KB:le_dict(dict([F|Args], NTs, WV, _, _, _, _)),
    \+ le_builtin_functor(F),
    is_list(WV),
    copy_term(t(Args, NTs, WV), t(Args1, NTs1, WV1)),
    Head0 =.. [F|Args1],
    to_classical(Head0, Head),
    numbervars(t(Head, NTs1, WV1), 0, _),
    format_from_wv(WV1, NTs1, Parts),
    atomic_list_concat(Parts, ' ', Fmt0),
    atomic_list_concat(Qs, '\'', Fmt0), atomic_list_concat(Qs, '\'\'', Fmt),   % an apostrophe in the wording
    format(string(HeadS), "~W", [Head, [numbervars(true), quoted(true)]]),
    format(string(Line), "#pred ~w :: '~w'.", [HeadS, Fmt]).

%!  opposite_map(+KB, -Map) is det.
%
%   `; opposite:` (§4): the opposite form is the classical negation of its
%   template, `-p(...)`. Map pairs each opposite's functor with its main
%   template's: OF/N-F. Both forms have a dictionary entry, each naming the
%   other; the main one (the declaration) is asserted first.
opposite_map(KB, Map) :-
    findall(F/N-OF, ( KB:le_dict(dict([F|Args], _, _, _, Opp, _, _)), nonvar(Opp),
                      length(Args, N), functor(Opp, OF, N) ), Pairs),
    opposite_pairs(Pairs, [], Map).

opposite_pairs([], _, []).
opposite_pairs([F/N-OF|Ps], Seen, Map) :-
    (   memberchk(F/N, Seen)                    % F is itself the opposite of an earlier one
    ->  opposite_pairs(Ps, Seen, Map)
    ;   Map = [OF/N-F|Map1], opposite_pairs(Ps, [OF/N|Seen], Map1)
    ).

classical_deep(G, G) :- var(G), !.
classical_deep(G, C) :- to_classical(G, C), C \== G, !.
classical_deep(G, C) :- compound(G), functor(G, F, _), memberchk(F, [',', ';', not, '\\+']), !,
    G =.. [F|As], maplist(classical_deep, As, Bs), C =.. [F|Bs].
classical_deep(G, G).

%   An opposite form's literal as the classical negation of its template's.
to_classical(G, G) :- var(G), !.
to_classical(G, -(M)) :-
    callable(G), functor(G, OF, N),
    nb_current(le_scasp_opposites, Map), memberchk(OF/N-F, Map), !,
    G =.. [_|Args], M =.. [F|Args].
to_classical(G, G).

% format_from_wv(+WordsAndVars, +NameTypes, -Parts): render each template token,
% turning numbervar'd slots into '@(Name:type)' placeholders.
format_from_wv([], _, []).
format_from_wv([Tok|T], NTs, [Part|PT]) :-
    ( Tok = '$VAR'(_) ->
        varname(Tok, VN),
        ( member(V-Type, NTs), V == Tok -> true ; Type = term ),
        format(atom(Part), '@(~w:~w)', [VN, Type])
    ; format(atom(Part), '~w', [Tok])
    ),
    format_from_wv(T, NTs, PT).

varname('$VAR'(N), Name) :-
    ( integer(N) ->
        L is 0'A + (N mod 26), char_code(C, L),
        ( N < 26 -> Name = C ; D is N // 26, format(atom(Name), '~w~w', [C, D]) )
    ; Name = N
    ).

		 /*******************************
		 *     #abducible DIRECTIVES    *
		 *******************************/

%!  abducible_directive(+KB, -Line:string) is nondet.
%
%   Templates flagged assumable / `; unknown` become `#abducible` heads, so
%   s(CASP) may assume them and report the assumption set per model.
abducible_directive(KB, Line) :-
    KB:le_dict(dict([F|Args], _, _, _, _, _, Unknown)),
    Unknown == unknown,                 % `; unknown` / `; assumable` (§4), not a scenario element
    \+ le_builtin_functor(F),
    length(Args, A),
    functor(Head, F, A),
    format(string(Line), "#abducible ~q.", [Head]).

		 /*******************************
		 *      OPPOSITE / CLASSICAL    *
		 *******************************/

%!  opposite_constraints(+KB, -Lines:list) is det.
%
%   For a template declared with `; opposite: T`, add the global constraint
%   `false :- p(X), -p(X).` linking p and its opposite under classical negation.
opposite_constraints(KB, Lines) :-
    ( nb_current(le_scasp_opposites, Map) -> true ; opposite_map(KB, Map) ),
    findall(L,
        ( KB:le_dict(dict([F|Args], _, _, _, Opposite, _, _)),
          nonvar(Opposite),
          length(Args, N0), \+ memberchk(F/N0-_, Map),     % the main form only
          \+ le_builtin_functor(F),
          length(Args, A),
          functor(Head, F, A),
          Opp =.. ['-', Head],
          %  the variables named A, B, ... as in every other clause, not _123
          numbervars(Head, 0, _),
          format(string(L), "false :- ~W, ~W.",
                 [Head, [quoted(true), numbervars(true)], Opp, [quoted(true), numbervars(true)]])
        ),
        Lines0),
    sort(Lines0, Lines).

		 /*******************************
		 *       RULE / FACT EMIT       *
		 *******************************/

emit_rules(_KB, [], [], []).
emit_rules(KB, [rule(ID,_S,_E,Head,Body)|T], Lines, Issues) :-
    b_setval(le_scasp_rule, Head-Body), b_setval(le_scasp_aux, []),
    ( catch(lower_body(KB, ID, Body, SBody, BIssues), Err, true) ->
        ( var(Err) ->
            % s(CASP) forbids ;/2 in a clause body: DNF-expand into one clause
            % per conjunction (each printed whole so head/body vars correspond).
            body_to_dnf(SBody, Conjs),
            to_classical(Head, CHead),
            b_getval(le_scasp_aux, Aux), reverse(Aux, AuxInOrder),
            (   leftover_in_clauses([(CHead :- SBody)|AuxInOrder], Left)
            ->  %  a construct the lowering left as it was: s(CASP) would
                %  call it as a predicate of the program, which it is not
                Lines0 = [],
                scasp_issue(untranslatable_rule, ID, scasp_leftover_construct, [construct-Left], I),
                Issues0 = [I]
            ;   maplist(clause_line(CHead), Conjs, RLines0),
                findall(AL, ( member((AH :- AB), AuxInOrder), body_to_dnf(AB, ACs),
                              member(AC, ACs), clause_line(AH, AC, AL) ), AuxLines),
                append(RLines0, AuxLines, RLines),
                Lines0 = RLines, maplist(issue_of_rule(ID), BIssues, Issues0)
            )
        ; Err = le_scasp_untranslatable(Key) ->
            % A construct we recognise but cannot express in s(CASP) (e.g. double
            % negation): report a targeted issue rather than crashing the runner.
            Lines0 = [], scasp_issue(untranslatable_rule, ID, Key, [], I), Issues0 = [I]
        ; Lines0 = [],
          scasp_issue(untranslatable_rule, ID, scasp_untranslatable_rule, [], I), Issues0 = [I]
        )
    ;   Lines0 = [],
        scasp_issue(untranslatable_rule, ID, scasp_untranslatable_rule, [], I), Issues0 = [I]
    ),
    emit_rules(KB, T, LT, IT),
    append(Lines0, LT, Lines),
    append(Issues0, IT, Issues).

%   A leaf's issue names the rule it is in (lower_leaf/3 does not know it).
issue_of_rule(ID, le_scasp_issue(K, unknown, M), le_scasp_issue(K, ID, M)) :- !.
issue_of_rule(_, I, I).

		 /*******************************
		 *    REFUSING TO EMIT (check)  *
		 *******************************/

%!  le_scasp_blocking_issue(+Issue) is semidet.
%
%   An emitter issue that loses meaning: the rule it is in is left out, or a
%   condition of it is (a construct with no s(CASP) lowering is written as
%   `true`, which WIDENS the rule). A program with one is not shown as
%   s(CASP) nor run by it (See s(CASP), the s(CASP) engine): an s(CASP)
%   program that means something else than its Logical English would be
%   worse than none. The engine's own conditions (not installed, a time
%   limit, a construct it rejects while running) are not the program's.
le_scasp_blocking_issue(le_scasp_issue(Kind, _, _)) :-
    \+ memberchk(Kind, [no_pack, timeout, unsupported_construct]).

%!  le_scasp_check(+KB, +Issues, -Problems) is det.
%
%   The blocking issues among Issues (le_scasp_program_text/3's), as
%   problem(Where, Message) for le_import:export_refusal/4: Where the
%   offsets of the rule the issue is in (at(Start, End)), or none.
le_scasp_check(KB, Issues, Problems) :-
    findall(problem(Where, Msg),
            ( member(I, Issues), le_scasp_blocking_issue(I),
              I = le_scasp_issue(_, ID, Msg0),
              ( string(Msg0) -> Msg = Msg0 ; format(string(Msg), "~w", [Msg0]) ),
              (   ID \== unknown, current_predicate(KB:le_source_info/4),
                  once(KB:le_source_info(_, S, E, ID)), integer(S)
              ->  Where = at(S, E)
              ;   Where = none
              ) ),
            Problems0),
    list_to_set(Problems0, Problems).

%!  leftover_in_clauses(+Clauses, -Construct) is semidet.
%
%   A literal of the lowered clauses (Head :- Body) that is still one of LE's
%   own connectives or records (and/2, or/2, le_at/3, an le_* builtin, a
%   Prolog control construct): the lowering has no case for where it stands.
%   s(CASP) would call it as a predicate of the unit and throw (`existence
%   error: scasp_predicate ...:and/2`), so it is reported instead, as the
%   F/N it is. The helpers the lowering itself writes (le_forall_<n>,
%   le_query) are the program's.
leftover_in_clauses(Clauses, F/N) :-
    member((H :- B), Clauses),
    ( leftover_literal(H, L) ; body_to_dnf(B, Cs), member(C, Cs), member(Lit, C), leftover_literal(Lit, L) ),
    !,
    functor(L, F, N).

leftover_literal(G, _) :- var(G), !, fail.
leftover_literal(not(G), L) :- !, leftover_literal(G, L).
leftover_literal(-(G), L) :- compound(G), !, leftover_literal(G, L).
%   a comparison's operands are terms: an LE goal inside one (a condition the
%   grammar read as an operand) is left over too
leftover_literal(G, L) :-
    compound(G), functor(G, F, 2), memberchk(F, [#=, #<>, #<, #>, #=<, #>=, =, \=]), !,
    sub_term(L, G), compound(L), L \== G,
    leftover_literal(L, L), !.
leftover_literal(G, G) :-
    callable(G), functor(G, F, N),
    (   memberchk(F/N, [','/2, ';'/2, '->'/2, '*->'/2, '\\+'/1, call/1, findall/3, forall/2,
                        aggregate_all/3, setof/3, bagof/3])
    ->  true
    ;   atom(F), \+ scasp_helper_functor(F),
        (   le_builtin_functor(F)
        ;   le_internal_functor(F)
        ;   le_i18n:system_template_row(F, _, _)          % an LE built-in condition
        ), !
    ).

%   LE's own goal wrappers that no lowering case expects to meet (a user
%   template's functor never collides with them: le_prix_de... is French).
le_internal_functor(le_flip).
le_internal_functor(le_scoped).
le_internal_functor(le_table).
le_internal_functor(le_query_fails_at_section).
le_internal_functor(le_fails_at_section).
le_internal_functor(unknown_template).

scasp_helper_functor(le_query).
scasp_helper_functor(F) :- sub_atom(F, 0, _, _, le_forall_).

clause_line(Head, ConjList, Line) :-
    ( ConjList == [] -> Body = true ; list_to_conj(ConjList, Body) ),
    copy_term(Head-Body, H1-B1),
    ( B1 == true ->
        format(string(Line), "~W.", [H1, [quoted(true), numbervars(true)]])
    ;   numbervars(H1-B1, 0, _),
        format(string(Line), "~W :-~n    ~W.",
               [H1, [quoted(true), numbervars(true)],
                B1, [quoted(true), numbervars(true)]])
    ).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G,Rest)) :- list_to_conj(Gs, Rest).

% body_to_dnf(+Body, -Conjunctions): distribute ;/2 over ,/2, yielding a list of
% conjunction-lists. not/1 and CLP/leaf goals are opaque literals. Uses only
% append/3 (never findall) so variable sharing with the rule head is preserved;
% clause_line/3 copies each emitted clause independently afterwards.
body_to_dnf((A,B), Conjs) :- !,
    body_to_dnf(A, CA), body_to_dnf(B, CB),
    cross_concat(CA, CB, Conjs).
body_to_dnf((A;B), Conjs) :- !,
    body_to_dnf(A, CA), body_to_dnf(B, CB), append(CA, CB, Conjs).
body_to_dnf(true, [[]]) :- !.
body_to_dnf(Leaf, [[Leaf]]).

% cross_concat(+ListsA, +ListsB, -Product): for each Ca in A and Cb in B, the
% concatenation Ca++Cb, without copying (preserves shared variables).
cross_concat([], _, []).
cross_concat([Ca|CAs], CB, Out) :-
    append_each(Ca, CB, Part),
    cross_concat(CAs, CB, Rest),
    append(Part, Rest, Out).

append_each(_, [], []).
append_each(Ca, [Cb|CBs], [C|Cs]) :- append(Ca, Cb, C), append_each(Ca, CBs, Cs).

emit_facts(_KB, [], [], []).
emit_facts(KB, [fact(ID,_S,_E,Head0)|T], LT, [I|Issues]) :-     % a sentence with no template, say
    leftover_in_clauses([(Head0 :- true)], Left), !,
    scasp_issue(untranslatable_rule, ID, scasp_leftover_construct, [construct-Left], I),
    emit_facts(KB, T, LT, Issues).
emit_facts(KB, [fact(_ID,_S,_E,Head0)|T], [L|LT], Issues) :-
    to_classical(Head0, Head),
    format(string(L), "~W.", [Head, [quoted(true), numbervars(true)]]),
    emit_facts(KB, T, LT, Issues), !.
emit_facts(KB, [_|T], LT, Issues) :- emit_facts(KB, T, LT, Issues).

%!  lower_body(+KB, +RuleID, +Body, -SBody, -Issues) is det.
%
%   Translate an LE body tree into an s(CASP) body term, collecting issues.
lower_body(KB, ID, le_at(G, _, _), S, Is) :- !, lower_body(KB, ID, G, S, Is).
lower_body(KB, ID, and(A,B), (SA,SB), Is) :- !,
    lower_body(KB, ID, A, SA, Ia), lower_body(KB, ID, B, SB, Ib), append(Ia, Ib, Is).
lower_body(KB, ID, (A,B), (SA,SB), Is) :- !,
    lower_body(KB, ID, A, SA, Ia), lower_body(KB, ID, B, SB, Ib), append(Ia, Ib, Is).
lower_body(KB, ID, or(A,B), (SA;SB), Is) :- !,
    lower_body(KB, ID, A, SA, Ia), lower_body(KB, ID, B, SB, Ib), append(Ia, Ib, Is).
lower_body(KB, ID, (A;B), (SA;SB), Is) :- !,
    lower_body(KB, ID, A, SA, Ia), lower_body(KB, ID, B, SB, Ib), append(Ia, Ib, Is).
lower_body(KB, ID, not(G), NegBody, Is) :- !,
    lower_body(KB, ID, G, SG, Is),
    demorgan_negate(SG, NegBody).
%   `for all cases in which C it is the case that G`: s(CASP)'s forall/2
%   quantifies one variable and it has no call/1, so the universal is the
%   negation of a helper that finds a counterexample (Lloyd-Topor):
%       not le_forall_<rule>_<n>(Shared)
%       le_forall_<rule>_<n>(Shared) :- C, not G.
%   Shared are the variables the universal shares with the rest of the rule.
%   The helper's clauses follow the rule's (emit_rules/4); the s(CASP)
%   reader (le_writer:prolog_to_ir/3) folds them back into the universal.
lower_body(KB, ID, forall(C, G), not(Aux), Is) :- !,
    lower_body(KB, ID, C, SC, Ic), lower_body(KB, ID, G, SG, Ig), append(Ic, Ig, Is),
    demorgan_negate(SG, NG),
    b_getval(le_scasp_rule, Head-Body),
    term_variables(forall(C, G), FVs),
    replace_subterm(Body, forall(C, G), true, Rest),
    term_variables(Head-Rest, OVs),
    include(var_in(FVs), OVs, Shared),            % in the order the rule names them
    b_getval(le_scasp_aux, Aux0),
    ( nb_current(le_scasp_forall_n, K0) -> true ; K0 = 0 ), K is K0 + 1, nb_setval(le_scasp_forall_n, K),
    ignore(ID = _),
    format(atom(AF), 'le_forall_~w', [K]),
    Aux =.. [AF|Shared],
    record_forall_helper(KB, Aux, forall(C, G)),
    b_setval(le_scasp_aux, [(Aux :- (SC, NG))|Aux0]).
lower_body(_KB, _ID, le_scoped(_, _), true, _) :- !,
    throw(le_scasp_untranslatable(scasp_scoped_proof)).
lower_body(_KB, _ID, Leaf, SLeaf, Is) :- lower_leaf(Leaf, SLeaf, Is).

var_in(Vs, V) :- member(X, Vs), X == V, !.

%   forall_helper(KB, Helper, Universal): the helper le_forall_<n>(Shared)
%   stands for the universal of the Logical English program, forall(C, G),
%   their variables shared. An explanation shows the universal, not the
%   helper (node_json/3). The helpers are numbered afresh each time the
%   program is written (le_scasp_program_text/3), so a helper's entry is
%   replaced, never added to.
:- dynamic forall_helper/3.

record_forall_helper(KB, Aux, Universal) :-
    (   atom(KB)
    ->  functor(Aux, AF, _),
        strip_positions(Universal, U),
        retractall(forall_helper(KB, AF, _)),
        assertz(forall_helper(KB, AF, Aux-U))
    ;   true
    ).

replace_subterm(T, Old, New, New) :- T == Old, !.
replace_subterm(T, Old, New, R) :- compound(T), !,
    T =.. [F|As], replace_subterms(As, Old, New, Bs), R =.. [F|Bs].
replace_subterm(T, _, _, T).
replace_subterms([], _, _, []).
replace_subterms([A|As], Old, New, [B|Bs]) :- replace_subterm(A, Old, New, B), replace_subterms(As, Old, New, Bs).

% demorgan_negate(+Body, -Negated): push a negation inward so that no ;/2 or
% conjunction survives directly under a not/1 — s(CASP) accepts only
% `not <literal>` in a body (it rejects `not (a;b)`, `not (a,b)` and `not not a`).
% De Morgan turns disjunction into conjunction and vice-versa; this is sound for
% default negation (`not (A or B)` ≡ `not A and not B`). Any ;/2 it introduces
% sits in a positive position and is lifted afterwards by body_to_dnf. Double
% negation cannot be expressed in this s(CASP), so it aborts the rule with a
% clear message (caught by emit_rules and reported as an issue).
demorgan_negate((A;B), (NA,NB)) :- !, demorgan_negate(A, NA), demorgan_negate(B, NB).
demorgan_negate((A,B), (NA;NB)) :- !, demorgan_negate(A, NA), demorgan_negate(B, NB).
demorgan_negate(not _, _) :- !,
    throw(le_scasp_untranslatable(scasp_double_negation)).
demorgan_negate(G, not G).

% lower_leaf(+Leaf, -SLeaf, -Issues): lower a single goal.
lower_leaf(le_ge(X,Y), (X #>= Y), []) :- !.
lower_leaf(le_le(X,Y), (X #=< Y), []) :- !.
lower_leaf(le_gt(X,Y), (X #> Y),  []) :- !.
lower_leaf(le_lt(X,Y), (X #< Y),  []) :- !.
lower_leaf(le_equal_to(X,Y), (X #= Y), []) :- number_ish(X,Y), !.
lower_leaf(le_equal_to(X,Y), (X = Y), []) :- !.
lower_leaf(le_not_equal_to(X,Y), (X #<> Y), []) :- number_ish(X,Y), !.
%   A non-numeric disequality is s(CASP)'s constructive one (`X \= Y`: a
%   constraint on X when it is unbound). With abducibles, s(CASP) 1.1.4
%   answers a NON-ground global constraint that uses it unsoundly (a model
%   can abduce what the constraint forbids); ground ones are sound.
lower_leaf(le_not_equal_to(X,Y), (X \= Y), []) :- !.
lower_leaf(le_is(X,Y), (X #= Y), []) :- arithmetic_term(Y), !.
lower_leaf(le_is(X,Y), (X = Y), []) :- !.
lower_leaf(le_assign(X,Y), (X #= Y), []) :- ( arithmetic_term(Y) ; arithmetic_term(X) ), !.   % `N mod 3 = 2` too
lower_leaf(le_assign(X,Y), (X = Y), []) :- !.
lower_leaf(le_known(X), scasp_known(X), [I]) :- scasp_issue(unsupported_known, unknown, scasp_unsupported_known, [], I), !.
lower_leaf(prolog_call(_), true, [I]) :- scasp_issue(prolog_goal, unknown, scasp_prolog_goal, [], I), !.
%   List membership is s(CASP)'s member/2, which it runs constructively
%   (under a negation, and with the element unknown, as in a universal).
lower_leaf(le_is_in(X,Y), member(X,Y), []) :- !.
lower_leaf(le_is_days_after(_,_,_), true, [I]) :- scasp_issue(date_arithmetic, unknown, scasp_date_arithmetic, [], I), !.
lower_leaf(le_is_months_after(_,_,_), true, [I]) :- scasp_issue(date_arithmetic, unknown, scasp_date_arithmetic, [], I), !.
lower_leaf(le_minimum(_,_,_), true, [I]) :- scasp_issue(min_max, unknown, scasp_min_max, [], I), !.
lower_leaf(le_maximum(_,_,_), true, [I]) :- scasp_issue(min_max, unknown, scasp_min_max, [], I), !.
lower_leaf(Aggr, true, [I]) :-
    reasoner:is_aggregate(Aggr, _, _, _, _), !,
    scasp_issue(aggregate, unknown, scasp_aggregate, [], I).
lower_leaf(for_all_cases(_), true, [I]) :- scasp_issue(universal, unknown, scasp_universal, [], I), !.
lower_leaf(le_table(_, _), true, [I]) :- scasp_issue(decision_table, unknown, scasp_decision_table, [], I), !.
lower_leaf(G, true, [I]) :-
    compound(G), functor(G, F, _), memberchk(F, [le_semantically_similar, le_best_match, le_satisfies_description]), !,
    scasp_issue(service, unknown, scasp_service, [], I).
lower_leaf(le_holds(_), true, [I]) :- scasp_issue(meta_call, unknown, scasp_meta_call, [], I), !.
lower_leaf(unknown_template(_), true, [I]) :- scasp_issue(missing_template, unknown, scasp_missing_template, [], I), !.
lower_leaf(Leaf, CLeaf, []) :- to_classical(Leaf, CLeaf).      % user domain predicate (an opposite form: -p)

number_ish(X, Y) :- ( arithmetic_term(X) ; arithmetic_term(Y) ), !.
arithmetic_term(T) :- compound(T), functor(T, F, A), A >= 1, arith_op(F, A), !.
arithmetic_term(T) :- number(T).
arith_op(+,2). arith_op(-,2). arith_op(*,2). arith_op(/,2). arith_op(-,1).
arith_op(abs,1). arith_op(min,2). arith_op(max,2). arith_op(mod,2).


		 /*******************************
		 *          RUNNER (WP3)        *
		 *******************************/

:- use_module(library(uuid)).
:- use_module(library(time)).

%!  le_scasp_query(+KBModule, +ScenarioName, +Goal, +Options, -Answers, -Issues)
%
%   Compile the KB (plus the named scenario's facts) into a fresh s(CASP) unit
%   module and solve Goal, backtracking over stable models. Answers is a list of
%   answer(Bindings, GoalInstance, Model, Tree) terms, one per model (bounded by
%   max_models); GoalInstance is Goal bound in that model.
%   Time-budgeted via time_limit (default 10s); on timeout Issues carries a
%   timeout marker and Answers holds whatever was found first.
%
%   Options: time_limit(Seconds), max_models(N), scenario_facts(List) to inject
%   facts directly instead of by name.
le_scasp_query(KBModule, ScenarioName, Goal, Options, Answers, Issues) :-
    le_scasp_available,
    le_scasp_program_text(KBModule, ProgText0, PIssues),
    %  a program s(CASP) cannot state faithfully is not run by it: the next
    %  clause answers nothing, with the issues that say why
    \+ ( member(PI, PIssues), le_scasp_blocking_issue(PI) ),
    %  a query's goal carries the source positions of its conditions
    %  (le_at/3), which the unit does not; a query of several conditions is
    %  lowered like a rule body (le_scasp_query_goal/6), and refused like one
    strip_positions(Goal, Goal1),
    le_scasp_query_goal(KBModule, Goal1, SQuery, Shown, QueryLines, QIssues),
    \+ ( member(QI, QIssues), le_scasp_blocking_issue(QI) ),
    !,
    option(time_limit(TL), Options, 10),
    option(max_models(Max), Options, 25),
    scenario_facts(KBModule, ScenarioName, Options, Items),
    %  a scenario may hold rules too ("a thing belongs to a set if the thing
    %  is in the set"): they are lowered like the program's own, since
    %  written as they are their conditions (le_at/3, le_is_in/2, ...) name
    %  no predicate of the unit and the rule would never hold
    partition(scenario_rule, Items, ScenRules0, Facts0),
    maplist(scenario_rule_record, ScenRules0, ScenRules),
    emit_rules(KBModule, ScenRules, ScenLines, SIssues),
    (   member(SI, SIssues), le_scasp_blocking_issue(SI)
    ->  Answers = [], RIssues = []
    ;   %  an opposite form is -p in the unit (its variables shared, so the
        %  answers bind the caller's goal)
        maplist(classical_deep, Facts0, Facts),
        atomic_list_concat(QueryLines, '\n', QT),
        atomic_list_concat(ScenLines, '\n', ST),
        format(string(ProgText), "~w~n% the scenario's rules~n~w~n% the query~n~w~n", [ProgText0, ST, QT]),
        setup_call_cleanup(
            load_scasp_unit(ProgText, Facts, Unit, File),
            run_models(Unit, SQuery, Shown, TL, Max, Answers, RIssues),
            cleanup_scasp_unit(Unit, File))
    ),
    append([PIssues, QIssues, SIssues, RIssues], Issues).

scenario_rule((_ :- _)).

scenario_rule_record((Head :- Body), rule(scenario, 0, 0, Head, Body)).
le_scasp_query(KBModule, _, Goal, _, [], Issues) :-
    le_scasp_available, !,
    le_scasp_program_text(KBModule, _, PIssues),
    (   \+ ( member(PI, PIssues), le_scasp_blocking_issue(PI) )
    ->  strip_positions(Goal, Goal1),
        le_scasp_query_goal(KBModule, Goal1, _, _, _, QIssues),
        append(PIssues, QIssues, Issues)
    ;   Issues = PIssues
    ).
le_scasp_query(_, _, _, _, [], [I]) :- scasp_issue(no_pack, unknown, scasp_engine_not_installed, [], I).

%!  le_scasp_query_goal(+KB, +Goal, -Query, -Shown, -Lines, -Issues) is det.
%
%   The s(CASP) query for an LE query goal (positions stripped). A query is
%   the body of a rule with no head — conditions joined by and/2, or/2, not/1,
%   universals, comparisons — so it is lowered exactly like one (lower_body/5,
%   the same issues, the same leftover check) into the clauses (Lines) of the
%   helper predicate le_query(Vars), Query, whose arguments are the query's
%   variables so the answers bind the caller's goal. Asking the helper rather
%   than the conditions themselves also keeps s(CASP) from refusing a query
%   whose predicate has no clause in the unit (no rule, and no fact in this
%   scenario): s(CASP) checks that a query's literals exist, and throws, where
%   in a clause body such a literal just fails, as in Prolog. (Handing it the
%   LE goal itself asked for a predicate and/2 of the unit.)
%   Shown is the goal an answer renders: the lowered literal of a one-literal
%   query (an opposite form's -p), else the LE goal.
le_scasp_query_goal(KB, Goal, QHead, Shown, Lines, Issues) :-
    opposite_map(KB, Map), b_setval(le_scasp_opposites, Map),
    %  a universal's own variables are not the query's (the helper of the
    %  universal shares with the rest only the others, lower_body/5)
    without_universals(Goal, Outer),
    term_variables(Outer, Vs),
    QHead =.. [le_query|Vs],
    b_setval(le_scasp_rule, QHead-Goal), b_setval(le_scasp_aux, []),
    (   catch(lower_body(KB, query, Goal, SBody, BIssues0), Err, true)
    ->  true
    ;   Err = failed
    ),
    (   nonvar(Err)
    ->  ( Err = le_scasp_untranslatable(Key) -> true ; Key = scasp_untranslatable_rule ),
        scasp_issue(untranslatable_rule, unknown, Key, [], I),
        Shown = Goal, Lines = [], Issues = [I]
    ;   body_to_dnf(SBody, Conjs),
        b_getval(le_scasp_aux, Aux), reverse(Aux, AuxInOrder),
        maplist(issue_of_rule(unknown), BIssues0, BIssues),
        (   leftover_in_clauses([(QHead :- SBody)|AuxInOrder], Left)
        ->  scasp_issue(untranslatable_rule, unknown, scasp_leftover_construct, [construct-Left], I),
            Shown = Goal, Lines = [], Issues = [I|BIssues]
        ;   ( classical_deep(Goal, CG), Conjs == [[CG]] -> Shown = CG ; Shown = Goal ),
            findall(L, ( member(C, Conjs), clause_line(QHead, C, L) ), QLines),
            findall(AL, ( member((AH :- AB), AuxInOrder), body_to_dnf(AB, ACs),
                          member(AC, ACs), clause_line(AH, AC, AL) ), AuxLines),
            append(QLines, AuxLines, Lines),
            Issues = BIssues
        )
    ).

without_universals(V, V) :- var(V), !.
without_universals(forall(_, _), true) :- !.
without_universals(T, S) :- compound(T), functor(T, F, _), memberchk(F, [and, or, not, ',', ';']), !,
    T =.. [F|As], maplist(without_universals, As, Bs), S =.. [F|Bs].
without_universals(T, T).

strip_positions(V, V) :- var(V), !.
strip_positions(le_at(G, _, _), S) :- !, strip_positions(G, S).
strip_positions(T, S) :- compound(T), !, T =.. [F|As], maplist(strip_positions, As, Bs), S =.. [F|Bs].
strip_positions(T, T).

% scenario_facts(+KB, +Name, +Options, -Facts): ground fact terms for the scenario.
scenario_facts(_KB, _Name, Options, Facts) :-
    option(scenario_facts(Facts), Options), !.
scenario_facts(KB, Name, _Options, Facts) :-
    Name \== none, catch(KB:scenario(Name, Items), _, fail), !,
    findall(F, ( member(I, Items),
                 ( I = fact_with_source(F, _, _) -> true ; F = I ) ),
            Facts).
scenario_facts(_, _, _, []).

% load_scasp_unit(+ProgText, +Facts, -Unit, -File): write a module file holding
% the program as plain s(CASP) clauses (Mode A — no begin_scasp; that form is not
% queryable via scasp/2) and consult it into a fresh module. The #pred /
% #abducible / opposite directives are emitted as clause-level terms, which
% library(scasp)'s term expansion registers on load.
load_scasp_unit(ProgText, Facts, Unit, File) :-
    uuid(U0), atom_string(U0, US0),
    split_string(US0, "-", "", Parts), atomic_list_concat(Parts, '', UClean),
    atom_concat(le_scasp_u, UClean, Unit),
    tmp_file_stream(text, File, S),
    format(S, ":- module(~q, []).~n", [Unit]),
    format(S, ":- use_module(library(scasp)).~n~n", []),
    write(S, ProgText), nl(S),
    ( Facts == [] -> true
    ; format(S, "~n% scenario facts~n", []),
      forall(member(F, Facts), format(S, "~q.~n", [F]))
    ),
    close(S),
    load_files(File, [module(Unit), silent(true), if(true)]).

cleanup_scasp_unit(Unit, File) :-
    catch(ignore(scasp_clear_unit(Unit)), _, true),
    catch(ignore(delete_file(File)), _, true).

scasp_clear_unit(_Unit).      % placeholder; temporary module GC handled by SWI

% run_models(+Unit, +Query, +Shown, +TimeLimit, +Max, -Answers, -Issues): solve
% Query; each answer carries Shown (the goal the answer sentence renders, its
% variables Query's) as the goal instance.
run_models(Unit, Query, Shown, TL, Max, Answers, Issues) :-
    catch(
        call_with_time_limit(TL, collect_models(Unit, Query, Shown, Max, Answers)),
        Error,
        run_models_recover(Error, Answers, Issues0)),
    ( var(Issues0) -> Issues = [] ; Issues = Issues0 ).

% run_models_recover(+Error, -Answers, -Issues): turn a raw s(CASP) execution
% failure into a user-facing issue instead of letting it escape (which would
% surface as an HTTP 500). Constructs s(CASP) cannot run — e.g. a ;/2 or a
% conjunction the emitter did not lift out from under a negation — throw a
% permission_error/determinism_error here; report them as an unsupported
% construct and fall back to the Prolog engine. Genuinely unexpected errors are
% re-thrown so real bugs are not masked.
run_models_recover(time_limit_exceeded, [], [I]) :- !,
    scasp_issue(timeout, unknown, scasp_timeout, [], I).
run_models_recover(error(permission_error(scasp, _, _), _), [], [I]) :- !,
    scasp_issue(unsupported_construct, unknown, scasp_unsupported_construct, [], I).
run_models_recover(error(determinism_error(_,_,_,_), _), [], [I]) :- !,
    scasp_issue(unsupported_construct, unknown, scasp_unsupported_construct, [], I).
%   A predicate the unit does not define, which the leftover check
%   (leftover_in_clauses/2) should already have refused: said, not a 500.
run_models_recover(error(existence_error(scasp_predicate, PI0), _), [], [I]) :- !,
    ( PI0 = _:PI -> true ; PI = PI0 ),
    scasp_issue(unsupported_construct, unknown, scasp_leftover_construct, [construct-PI], I).
run_models_recover(Error, _, _) :- throw(Error).

collect_models(Unit, Query, Shown, Max, Answers) :-
    % Pair each query variable with a name BEFORE solving; scasp binds the vars
    % in place, and findnsols copies each answer (name=boundValue) out.
    term_variables(Shown, Vars),
    name_bindings(Vars, 1, Bindings),
    ( findnsols(Max, answer(Bindings, Shown, Model, Tree),
        scasp(Unit:Query, [model(Model), tree(Tree)]),
        Answers)
    -> true
    ; Answers = []
    ), !.

% name_bindings(+Vars, +N, -Pairs): positional Name=Var pairs (V1, V2, ...); the
% web layer may later substitute the query's own variable names.
name_bindings([], _, []).
name_bindings([V|Vs], I, [Name=V|T]) :-
    format(atom(Name), 'V~w', [I]),
    I1 is I + 1,
    name_bindings(Vs, I1, T).

		 /*******************************
		 *      NORMALISER (WP4)        *
		 *******************************/

%!  le_scasp_tree_json(+KBModule, +Tree, +Options, -JSON) is det.
%
%   Convert an s(CASP) justification tree into the explanation-tree JSON schema
%   the UI already consumes ({type, literal, children[, start, end, naf,
%   assumed]}). Internal NMR/consistency-check nodes (o_*) are dropped for
%   parity with the Prolog explanation.
le_scasp_tree_json(KB, _:Tree, Options, JSON) :- !,
    le_scasp_tree_json(KB, Tree, Options, JSON).
le_scasp_tree_json(KB, query-Children0, _Options, JSON) :- !,
    foldl(unwrap_query_helper, Children0, Children1, []), reverse(Children1, Children),
    exclude(nmr_node, Children, Real),
    maplist(node_json(KB), Real, ChildJSON0),
    exclude(==(skip), ChildJSON0, ChildJSON),
    ( ChildJSON = [Single] -> JSON = Single
    ; JSON = _{type: "success", literal: "the query holds", children: ChildJSON}
    ).
le_scasp_tree_json(KB, Node, _Options, JSON) :-
    node_json(KB, Node, JSON).

% unwrap_query_helper(+Node, -Acc, +Acc0): the query's own helper le_query/N
% (le_scasp_query_goal/5) is not a sentence of the program: its children, the
% query's conditions, stand in its place (Acc reversed).
unwrap_query_helper(Node, Acc, Acc0) :-
    (   Node = N-Ch, node_atom_status(N, A, "success", _), callable(A), functor(A, le_query, _)
    ->  reverse(Ch, RCh), append(RCh, Acc0, Acc)
    ;   Acc = [Node|Acc0]
    ).

% nmr_node(+NodeChildren): internal consistency-check subtree, dropped.
nmr_node(N-_) :- nmr_atom(N).
nmr_atom(A) :- unwrap_origin(A, A1), internal_atom(A1).
internal_atom(o_nmr_check).
internal_atom(A) :- compound(A), functor(A, F, _), atom(F), sub_atom(F, 0, 2, _, o_), !.
internal_atom(not X) :- internal_atom(X).

unwrap_origin(goal_origin(A, _), A) :- !.
unwrap_origin(A, A).

% node_json(+KB, +NodeChildren, -JSON)
node_json(KB, NodeChildren, JSON) :-
    ( NodeChildren = N-Children0 -> true ; N = NodeChildren, Children0 = [] ),
    ( nmr_atom(N) -> JSON = skip
    ; membership_node(N, open) -> JSON = skip
    ; ( membership_node(N, _) -> Children = [] ; Children = Children0 ),
      node_atom_status(N, Atom0, Status0, Flags0),
      universal_node(KB, Atom0, Status0, Flags0, Atom, Status, Flags),
      literal_of(KB, Atom, Literal),
      exclude(nmr_node, Children, RealCh),
      maplist(node_json(KB), RealCh, ChJSON0),
      exclude(==(skip), ChJSON0, ChJSON),
      base_node(Status, Literal, ChJSON, J0),
      apply_source(KB, Atom, J0, J1),
      apply_flags(Flags, J1, JSON)
    ).

% node_atom_status(+Node, -Atom, -Status, -Flags)
node_atom_status(assume(N),  A, S, [assumed|F]) :- !, node_atom_status(N, A, S, F).
node_atom_status(abduced(N), A, S, [assumed|F]) :- !, node_atom_status(N, A, S, F).
node_atom_status(chs(N),     A, S, F)           :- !, node_atom_status(N, A, S, F).
node_atom_status(proved(N),  A, S, F)           :- !, node_atom_status(N, A, S, F).
node_atom_status(goal_origin(N, _), A, S, F)    :- !, node_atom_status(N, A, S, F).
node_atom_status(not(-(A)),  A, "failure", [naf]) :- !.
node_atom_status(not(A),     A, "failure", [naf]) :- !.
node_atom_status(-(A),       A, "failure", [classical]) :- !.
node_atom_status(A,          A, "success", []).

% membership_node(+Node, -Element): Node is s(CASP)'s member/2, the
% lowering of "is in" (lower_leaf/3). It is one step, "Alice is in [Alice
% Bob]": the library's own steps below it (lists:member_/3) are not the
% program's. Element is `open` when the element is not known; that step says
% nothing its parent does not, and is left out.
membership_node(N, Element) :-
    node_atom_status(N, A0, _, _),
    ( A0 = _:A -> true ; A = A0 ),
    compound(A), A = member(X, _),
    ( var(X) -> Element = open ; Element = X ).

% universal_node(+KB, +Atom0, +Status0, +Flags0, -Atom, -Status, -Flags): a
% helper of a universal (lower_body/5) is shown as the universal it stands
% for. "not le_forall_1(alice)" (no counter-example) is the universal
% holding; le_forall_1(alice) proved is the universal failing. Its children,
% the search for a counter-example, stay as they are.
universal_node(KB, Atom0, Status0, Flags0, Atom, Status, Flags) :-
    (   compound(Atom0), functor(Atom0, AF, _),
        forall_helper(KB, AF, Helper-Universal0)
    ->  copy_term(Helper-Universal0, Atom0-Atom),
        (   Status0 == "failure", memberchk(naf, Flags0)
        ->  Status = "success", subtract(Flags0, [naf], Flags)
        ;   Status = "failure", Flags = Flags0
        )
    ;   ( Atom0 = _:member(X, L) ; Atom0 = member(X, L) )
    ->  Atom = le_is_in(X, L), Status = Status0, Flags = Flags0
    ;   Atom = Atom0, Status = Status0, Flags = Flags0
    ).

base_node(Status, Literal, Children, _{type: Status, literal: Literal, children: Children}).

apply_flags([], J, J).
apply_flags([assumed|T], J0, J) :- !, apply_flags(T, J0.put(assumed, true).put(type, "unknown"), J).
apply_flags([naf|T], J0, J)     :- !, apply_flags(T, J0.put(naf, true), J).
apply_flags([classical|T], J0, J) :- !, apply_flags(T, J0.put(classicalNegation, true), J).
apply_flags([_|T], J0, J) :- apply_flags(T, J0, J).

% literal_of(+KB, +Atom, -String): render a goal in LE; tolerate non-ground.
%   A universal names each of its own variables by its type in the condition
%   ("alice is a parent of a dragon") and refers back to it in the
%   conclusion ("the dragon is healthy"), as the program writes it; rendered
%   as one sentence, the conclusion named it afresh ("a creature is healthy").
literal_of(KB, forall(C, G), Literal) :-
    copy_term(C-G, C1-G1),
    catch(( le_kbs:item_to_instance(KB, C1, CondLE),
            term_variables(C1, Vs),
            universal_var_types(KB, C1, Typed),
            maplist(name_universal_var(Typed), Vs),
            le_kbs:item_to_instance(KB, G1, ConsLE),
            le_kbs:forall_render_words(ForallW),
            le_kbs:it_the_case_render_words(ItW),
            append([ForallW, CondLE, ItW, ConsLE], Tokens),
            le_kbs:canonical_string(Tokens, Literal) ), _, fail),
    !.
literal_of(KB, Atom, Literal) :-
    ( catch((le_kbs:item_to_instance(KB, Atom, Tokens),
             le_kbs:canonical_string(Tokens, S)), _, fail)
    -> Literal = S
    ; term_string(Atom, Literal)
    ).

% name_universal_var(+Typed, ?V): V, if still open and typed, becomes the
% definite reference to its type ("the dragon"). (Not forall/2, which this
% module has from library(scasp), with s(CASP)'s meaning.)
name_universal_var(Typed, V) :-
    (   var(V), member(V0-T, Typed), V0 == V
    ->  le_kbs:variable_reference(T, Ref), V = '$le_var_name'(Ref)
    ;   true
    ).

% universal_var_types(+KB, +Cond, -Pairs): Var-Type for the variables of the
% condition's sentences, typed by their templates (goal_arg_types/4). The
% pairs hold the condition's own variables (so no findall/3, which copies).
universal_var_types(KB, Cond, Pairs) :-
    conj_leaves(Cond, Leaves),
    foldl(leaf_var_types(KB), Leaves, [], Pairs).

leaf_var_types(KB, L, Ps0, Ps) :-
    (   compound(L), L =.. [F|Args],
        goal_arg_types(KB, F, Args, Types)
    ->  foldl(typed_var, Args, Types, Ps0, Ps)
    ;   Ps = Ps0
    ).

typed_var(A, T, Ps0, Ps) :-
    ( var(A), T \== value -> Ps = [A-T|Ps0] ; Ps = Ps0 ).

conj_leaves(G, []) :- var(G), !.
conj_leaves(le_at(G, _, _), Ls) :- !, conj_leaves(G, Ls).
conj_leaves(and(A, B), Ls) :- !, conj_leaves(A, LA), conj_leaves(B, LB), append(LA, LB, Ls).
conj_leaves((A, B), Ls) :- !, conj_leaves(A, LA), conj_leaves(B, LB), append(LA, LB, Ls).
conj_leaves(G, [G]).

% apply_source(+KB, +Atom, +J0, -J): attach start/end from the template/rule that
% defines Atom's functor (head-granularity click-to-source).
apply_source(KB, Atom, J0, J) :-
    ( compound(Atom), functor(Atom, F, A), kb_pred_source(KB, F/A, Start, End)
    -> J = J0.put(start, Start).put(end, End)
    ; J = J0
    ).

%!  kb_pred_source(+KB, +F/A, -Start, -End) is semidet.
%
%   Source span of the definition of predicate F/A: prefer a rule head, else the
%   template declaration.
kb_pred_source(KB, F/A, Start, End) :-
    functor(Head, F, A),
    ( KB:le_source_info(Ref, Start, End, _), clause(KB:Head, B, Ref), B \== true -> true
    ; KB:le_source_info(Ref, Start, End, _), clause(KB:Head, _, Ref) -> true
    ; template_source(KB, F, A, Start, End)
    ), !.

template_source(KB, F, A, Start, End) :-
    KB:le_source_info(Ref, Start, End, _),
    clause(KB:le_dict(dict([F|Args], _, _, _, _, _, _)), _, Ref),
    length(Args, A), !.

		 /*******************************
		 *  CONSTRAINT ANSWERS (§5b)    *
		 *******************************/

%!  le_scasp_symbolic_goal(+KB, +GoalInstance, -DisplayGoal, -Constraints) is det.
%
%   Turn an s(CASP) answer — whose variables may be non-ground or carry CLP(ℚ)
%   constraints — into a goal ready to render through the LE template, plus a
%   list of human constraint strings. A constrained argument becomes a phrase
%   like `any amount greater than 25000` (using the slot's type noun from the
%   template), so `a claim of an amount is covered` reads as `a claim of any
%   amount greater than 25000 is covered`. This is the headline "answer with no
%   concrete scenario" feature.
le_scasp_symbolic_goal(KB, Goal, Display, Constraints) :-
    %  a query of several conditions: each literal on its own
    compound(Goal), functor(Goal, C, N), memberchk(C/N, [and/2, or/2, (not)/1, ','/2, ';'/2]), !,
    Goal =.. [C|Gs],
    foldl(symbolic_part(KB), Gs, Ds, [], Constraints),
    Display =.. [C|Ds].
le_scasp_symbolic_goal(KB, Goal, Display, Constraints) :-
    Goal =.. [F|Args],
    goal_arg_types(KB, F, Args, Types),
    symbolic_args(KB, Args, Types, DisplayArgs, Constraints),
    Display =.. [F|DisplayArgs].

symbolic_part(KB, G, D, Cs0, Cs) :-
    le_scasp_symbolic_goal(KB, G, D, Cs1),
    append(Cs0, Cs1, Cs).

% goal_arg_types(+KB, +F, +Args, -Types): the declared type noun per argument
% position (from the template dict), or `value` when unknown.
goal_arg_types(KB, F, Args, Types) :-
    length(Args, N),
    ( KB:le_dict(dict([F|DArgs], NTs, _, _, _, _, _)), length(DArgs, N)
    -> maplist(darg_type(NTs), DArgs, Types)
    ;  maplist(default_value_type, Args, Types)
    ).

default_value_type(_, value).

darg_type(NTs, DArg, Type) :-
    ( member(V-T, NTs), V == DArg -> Type = T ; Type = value ).

%   Only the open values become `any <type>`: an argument that is itself a
%   sentence or a compound with an open value inside (a requirement "the
%   borrower pays 525 to the lender on a date") keeps what is known of it,
%   as the explanation does. Replacing it whole ("any requirement") made the
%   answer say less than its own explanation.
symbolic_args(_, [], [], [], []).
symbolic_args(KB, [A|As], [T|Ts], [D|Ds], Cs) :-
    ( ground(A) ->
        D = A, Cs = Rest
    ; compound(A) ->
        le_scasp_symbolic_goal(KB, A, D, Cs0),
        append(Cs0, Rest, Cs)
    ;   copy_term(A, _, Attrs),
        ( attrs_constraint_phrase(Attrs, Phrase, CText) ->
            format(atom(Name), 'any ~w ~w', [T, Phrase]),
            Cs = [CText|Rest]
        ;   format(atom(Name), 'any ~w', [T]),
            Cs = Rest
        ),
        %  as a variable's name, which the sentence renders as it is and
        %  which a typed place (a date, a number) accepts
        D = '$le_var_name'(Name)
    ),
    symbolic_args(KB, As, Ts, Ds, Rest).

% attrs_constraint_phrase(+Attrs, -Phrase, -Text): a readable phrase for the
% CLP(ℚ) constraints attached to a variable (from copy_term/3), e.g.
% "greater than 25000". Attrs is a list of {Constraint} residual goals.
attrs_constraint_phrase(Attrs, Phrase, Text) :-
    findall(P, ( member(A, Attrs), residual_atoms(A, Gs), member(G, Gs),
                 constraint_atom_phrase(G, P) ), Ps),
    Ps \== [],
    atomic_list_concat(Ps, ' and ', Phrase),
    Text = Phrase.

% residual_atoms(+Residual, -Atoms): flatten a {A, B, ...} residual (or a bare
% goal) into a list of atomic constraint goals.
residual_atoms({Body}, Gs) :- !, conj_atoms(Body, Gs).
residual_atoms(Body, Gs) :- conj_atoms(Body, Gs).

conj_atoms((A, B), Gs) :- !, conj_atoms(A, GA), conj_atoms(B, GB), append(GA, GB, Gs).
conj_atoms(A, [A]).

% constraint_atom_phrase(+Goal, -Phrase): "greater than 25000" for `V > 25000`
% (the variable is the subject; a reversed `25000 < V` is flipped).
constraint_atom_phrase(G, Phrase) :-
    G =.. [Op, L, R],
    op_phrase(Op, _),
    ( var(L), number(R) -> Bound = R, Op1 = Op
    ; var(R), number(L) -> Bound = L, flip_op(Op, Op1)
    ),
    op_phrase(Op1, Words),
    format(atom(Phrase), '~w ~w', [Words, Bound]).

op_phrase(>,  'greater than').
op_phrase(<,  'less than').
op_phrase(>=, 'greater than or equal to').
op_phrase(=<, 'less than or equal to').
op_phrase(=:=, 'equal to').
op_phrase(=,  'equal to').

flip_op(>, <).
flip_op(<, >).
flip_op(>=, =<).
flip_op(=<, >=).
flip_op(=:=, =:=).
flip_op(=, =).

		 /*******************************
		 *    ABDUCTION SET (§5c)       *
		 *******************************/

%!  le_scasp_assumptions(+KB, +Tree, -Assumptions:list(string)) is det.
%
%   The assumption set of a model: the literals s(CASP) had to *assume* (abducibles
%   / `; assumable`) to make the query hold, rendered in LE. Collected from the
%   justification tree's `abduced`/`assume` nodes (ground, in the actual proof —
%   the internal NMR subtree is skipped), deduplicated. Powers the per-model
%   "this holds if we assume: …" header.
le_scasp_assumptions(KB, _:Tree, Assumptions) :- !,
    le_scasp_assumptions(KB, Tree, Assumptions).
le_scasp_assumptions(KB, Tree, Assumptions) :-
    ( Tree = query-Children -> true ; Tree = _-Children -> true ; Children = [Tree] ),
    exclude(nmr_node, Children, Real),
    foldl(collect_assumed(KB), Real, [], A0),
    list_to_set(A0, Assumptions).

% collect_assumed(+KB, +NodeChildren, +Acc0, -Acc): gather rendered assumed atoms
% from this node and its (non-NMR) descendants.
collect_assumed(KB, NodeChildren, Acc0, Acc) :-
    ( NodeChildren = N-Ch -> true ; N = NodeChildren, Ch = [] ),
    ( nmr_atom(N) ->
        Acc = Acc0
    ;   ( assumed_atom(N, Atom) ->
            literal_of(KB, Atom, S), Acc1 = [S|Acc0]
        ;   Acc1 = Acc0
        ),
        exclude(nmr_node, Ch, RealCh),
        foldl(collect_assumed(KB), RealCh, Acc1, Acc)
    ).

% assumed_atom(+Node, -Atom): the (ground) atom of an abduced/assume node, seen
% through goal_origin/chs/proved wrappers.
assumed_atom(abduced(N), Atom) :- !, inner_atom(N, Atom), ground(Atom).
assumed_atom(assume(N),  Atom) :- !, inner_atom(N, Atom), ground(Atom).
assumed_atom(goal_origin(N, _), Atom) :- !, assumed_atom(N, Atom).
assumed_atom(chs(N),     Atom) :- !, assumed_atom(N, Atom).
assumed_atom(proved(N),  Atom) :- !, assumed_atom(N, Atom).

inner_atom(goal_origin(N, _), A) :- !, inner_atom(N, A).
inner_atom(A, A).

		 /*******************************
		 *   STRATIFICATION (WP7)       *
		 *******************************/

%!  le_scasp_stratification(+KBModule, -NegativeCycles:list) is det.
%
%   Detect loops through negation in the predicate dependency graph: cycles that
%   traverse at least one `not` edge. Such a program is not stratified — the
%   Prolog engine may loop or give unsound answers, and s(CASP) is advised. Each
%   cycle is a list of F/A predicate indicators.
le_scasp_stratification(KB, Cycles) :-
    findall(From-To-Kind, dep_edge(KB, From, To, Kind), Edges0),
    sort(Edges0, Edges),
    findall(F-T, member(F-T-_, Edges), Pairs0),
    sort(Pairs0, Pairs),
    findall(P, ( member(P-_, Pairs) ; member(_-P, Pairs) ), Ps0),
    sort(Ps0, Ps),
    vertices_edges_to_ugraph(Ps, Pairs, Graph),
    transpose_ugraph(Graph, Reversed),
    findall(Cycle,
            ( member(A-B-neg, Edges),
              negation_cycle(A, B, Graph, Reversed, Cycle) ),
            Cycles0),
    sort(Cycles0, Cycles).

% negation_cycle(+A, +B, +Graph, +Reversed, -Cycle): the negative edge A -> B
% closes a cycle when B reaches A again; the cycle's predicates are those on
% the paths from B back to A (sorted). Reachability over the dependency graph
% (library(ugraphs)) keeps the check linear per negative edge: enumerating
% every simple path instead grew exponentially with the size of the program
% (a 250-predicate program spent seconds here on every load).
negation_cycle(A, B, Graph, Reversed, Cycle) :-
    reachable(B, Graph, FromB),
    ord_memberchk(A, FromB),
    reachable(A, Reversed, ToA),
    ord_intersection(FromB, ToA, Cycle).

% dep_edge(+KB, -HeadPI, -BodyPI, -Kind): Kind is neg for a body literal under
% not/1, pos otherwise.
dep_edge(KB, HeadPI, BodyPI, Kind) :-
    KB:le_source_info(Ref, _, _, _),
    clause(KB:Head, Body, Ref), Body \== true,
    user_predicate(KB, Head),
    functor(Head, HF, HA), HeadPI = HF/HA,
    body_literal(Body, Lit, Kind),
    lit_pi(Lit, BodyPI).

body_literal(le_at(G,_,_), L, K) :- !, body_literal(G, L, K).
body_literal(and(A,B), L, K) :- !, ( body_literal(A, L, K) ; body_literal(B, L, K) ).
body_literal((A,B), L, K) :- !, ( body_literal(A, L, K) ; body_literal(B, L, K) ).
body_literal(or(A,B), L, K) :- !, ( body_literal(A, L, K) ; body_literal(B, L, K) ).
body_literal((A;B), L, K) :- !, ( body_literal(A, L, K) ; body_literal(B, L, K) ).
body_literal(not(G), L, neg) :- !, body_inner(G, L).
body_literal(le_scoped(G, _), L, K) :- !, body_literal(G, L, K).
body_literal(G, G, pos) :- callable(G), \+ le_builtin_functor_g(G).

body_inner(le_at(G,_,_), L) :- !, body_inner(G, L).
body_inner(G, G).

le_builtin_functor_g(G) :- functor(G, F, _), le_builtin_functor(F).

lit_pi(G, F/A) :- functor(G, F, A).

:- if(\+ current_predicate(have_scasp/0)).
% Stubs so the file compiles without the pack; runtime entries fail cleanly.
% They are deliberately at the END of the file, far from the real clauses of
% the same predicates, so declare that: the discontiguity is intentional, and
% without this the loader warns four times on every start of a server that has
% no s(CASP) installed.
:- discontiguous le_scasp_program_text/3.
:- discontiguous le_scasp_query/6.
:- discontiguous le_scasp_tree_json/4.
:- discontiguous le_scasp_stratification/2.
le_scasp_program_text(_, "", [I]) :- scasp_issue(no_pack, unknown, scasp_engine_not_installed, [], I).
le_scasp_query(_, _, _, _, [], [I]) :- scasp_issue(no_pack, unknown, scasp_engine_not_installed, [], I).
le_scasp_tree_json(_, _, _, _{type:"unknown", literal:"s(CASP) not installed", children:[]}).
le_scasp_stratification(_, []).
:- endif.

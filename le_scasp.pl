/** <module> s(CASP) backend for Logical English 2

    A second execution target, sibling to the Prolog backend. It emits an
    s(CASP) program from a loaded LE knowledge base (the same clauses the Prolog
    reasoner uses, but lowered to s(CASP) constructs), runs it in-process via
    `library(scasp)`, and normalises the resulting justification tree into the
    same explanation-tree JSON the existing UI consumes.

    Design notes (see docs/sCASP_plan.md):
      - The LE clause bodies are trees of and/2, or/2, not/1 and le_at/3 wrappers
        over leaf goals; we strip le_at, translate the connectives, and lower
        each leaf.
      - Arithmetic and comparisons are lowered *relationally* to CLP(Q)
        constraints (#=, #>, #>=, ...) rather than functional is/2, so an answer
        may come back as a constraint (the headline feature).
      - Every user template becomes a `#pred` directive carrying its LE sentence,
        so s(CASP)'s own --human output reads in the program's domain language
        and cross-checks our normaliser.
      - Constructs s(CASP) cannot run (aggregates, `prolog` goals, universals,
        date arithmetic) are reported as le_scasp_issue/3 terms; such a program
        is Prolog-only.
*/
:- module(le_scasp, [
    le_scasp_available/0,
    le_scasp_program_text/3,     % +KBModule, -Text, -Issues
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
    kb_rule_clauses(KBModule, Rules),
    kb_fact_clauses(KBModule, Facts),
    findall(P, pred_directive(KBModule, P), Preds0),
    sort(Preds0, Preds),
    findall(A, abducible_directive(KBModule, A), Abds0),
    sort(Abds0, Abds),
    emit_rules(KBModule, Rules, RuleLines, RuleIssues),
    emit_facts(KBModule, Facts, FactLines, FactIssues),
    opposite_constraints(KBModule, OppLines),
    append(RuleIssues, FactIssues, Issues),
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
    \+ reasoner:le_metadata_predicate(F/A),
    \+ le_builtin_functor(F),
    ( known_template(KB, F, A) -> true ; true ).

% Functors that are LE plumbing / builtins, never emitted as domain predicates.
le_builtin_functor(le_at).
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
le_builtin_functor(le_known).
le_builtin_functor(prolog_call).
le_builtin_functor(and).
le_builtin_functor(or).
le_builtin_functor(not).
le_builtin_functor(for_all_cases).

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
    Head =.. [F|Args1],
    numbervars(t(Head, NTs1, WV1), 0, _),
    format_from_wv(WV1, NTs1, Parts),
    atomic_list_concat(Parts, ' ', Fmt),
    format(string(HeadS), "~W", [Head, [numbervars(true), quoted(true)]]),
    format(string(Line), "#pred ~w :: '~w'.", [HeadS, Fmt]).

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
    nonvar(Unknown),
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
    findall(L,
        ( KB:le_dict(dict([F|Args], _, _, _, Opposite, _, _)),
          nonvar(Opposite),
          \+ le_builtin_functor(F),
          length(Args, A),
          functor(Head, F, A),
          Head =.. [F|Vs],
          Opp =.. ['-', Head],
          format(string(L), "false :- ~q, ~q.", [Head, Opp]),
          ignore(Vs = Vs)          % keep Vs referenced
        ),
        Lines0),
    sort(Lines0, Lines).

		 /*******************************
		 *       RULE / FACT EMIT       *
		 *******************************/

emit_rules(_KB, [], [], []).
emit_rules(KB, [rule(ID,_S,_E,Head,Body)|T], Lines, Issues) :-
    ( catch(lower_body(KB, ID, Body, SBody, BIssues), Err, true) ->
        ( var(Err) ->
            % s(CASP) forbids ;/2 in a clause body: DNF-expand into one clause
            % per conjunction (each printed whole so head/body vars correspond).
            body_to_dnf(SBody, Conjs),
            maplist(clause_line(Head), Conjs, RLines),
            Lines0 = RLines, Issues0 = BIssues
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
emit_facts(KB, [fact(_ID,_S,_E,Head)|T], [L|LT], Issues) :-
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
lower_body(_KB, _ID, Leaf, SLeaf, Is) :- lower_leaf(Leaf, SLeaf, Is).

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
lower_leaf(le_not_equal_to(_,_), true, [I]) :- scasp_issue(term_disequality, unknown, scasp_term_disequality, [], I), !.
lower_leaf(le_is(X,Y), (X #= Y), []) :- arithmetic_term(Y), !.
lower_leaf(le_is(X,Y), (X = Y), []) :- !.
lower_leaf(le_assign(X,Y), (X #= Y), []) :- arithmetic_term(Y), !.
lower_leaf(le_assign(X,Y), (X = Y), []) :- !.
lower_leaf(le_known(X), scasp_known(X), [I]) :- scasp_issue(unsupported_known, unknown, scasp_unsupported_known, [], I), !.
lower_leaf(prolog_call(_), true, [I]) :- scasp_issue(prolog_goal, unknown, scasp_prolog_goal, [], I), !.
lower_leaf(le_is_in(_,_), true, [I]) :- scasp_issue(list_membership, unknown, scasp_list_membership, [], I), !.
lower_leaf(le_is_days_after(_,_,_), true, [I]) :- scasp_issue(date_arithmetic, unknown, scasp_date_arithmetic, [], I), !.
lower_leaf(Aggr, true, [I]) :-
    reasoner:is_aggregate(Aggr, _, _, _, _), !,
    scasp_issue(aggregate, unknown, scasp_aggregate, [], I).
lower_leaf(for_all_cases(_), true, [I]) :- scasp_issue(universal, unknown, scasp_universal, [], I), !.
lower_leaf(Leaf, Leaf, []).      % user domain predicate: pass through

number_ish(X, Y) :- ( number(X) ; number(Y) ), !.
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
    !,
    option(time_limit(TL), Options, 10),
    option(max_models(Max), Options, 25),
    le_scasp_program_text(KBModule, ProgText, PIssues),
    scenario_facts(KBModule, ScenarioName, Options, Facts),
    setup_call_cleanup(
        load_scasp_unit(ProgText, Facts, Unit, File),
        run_models(Unit, Goal, TL, Max, Answers, RIssues),
        cleanup_scasp_unit(Unit, File)),
    append(PIssues, RIssues, Issues).
le_scasp_query(_, _, _, _, [], [I]) :- scasp_issue(no_pack, unknown, scasp_engine_not_installed, [], I).

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

% run_models(+Unit, +Goal, +TimeLimit, +Max, -Answers, -Issues)
run_models(Unit, Goal, TL, Max, Answers, Issues) :-
    catch(
        call_with_time_limit(TL, collect_models(Unit, Goal, Max, Answers)),
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
run_models_recover(Error, _, _) :- throw(Error).

collect_models(Unit, Goal, Max, Answers) :-
    % Pair each query variable with a name BEFORE solving; scasp binds the vars
    % in place, and findnsols copies each answer (name=boundValue) out.
    term_variables(Goal, Vars),
    name_bindings(Vars, 1, Bindings),
    ( findnsols(Max, answer(Bindings, Goal, Model, Tree),
        scasp(Unit:Goal, [model(Model), tree(Tree)]),
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
le_scasp_tree_json(KB, query-Children, _Options, JSON) :- !,
    exclude(nmr_node, Children, Real),
    maplist(node_json(KB), Real, ChildJSON0),
    exclude(==(skip), ChildJSON0, ChildJSON),
    ( ChildJSON = [Single] -> JSON = Single
    ; JSON = _{type: "success", literal: "the query holds", children: ChildJSON}
    ).
le_scasp_tree_json(KB, Node, _Options, JSON) :-
    node_json(KB, Node, JSON).

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
    ( NodeChildren = N-Children -> true ; N = NodeChildren, Children = [] ),
    ( nmr_atom(N) -> JSON = skip
    ; node_atom_status(N, Atom, Status, Flags),
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

base_node(Status, Literal, Children, _{type: Status, literal: Literal, children: Children}).

apply_flags([], J, J).
apply_flags([assumed|T], J0, J) :- !, apply_flags(T, J0.put(assumed, true).put(type, "unknown"), J).
apply_flags([naf|T], J0, J)     :- !, apply_flags(T, J0.put(naf, true), J).
apply_flags([classical|T], J0, J) :- !, apply_flags(T, J0.put(classicalNegation, true), J).
apply_flags([_|T], J0, J) :- apply_flags(T, J0, J).

% literal_of(+KB, +Atom, -String): render a goal in LE; tolerate non-ground.
literal_of(KB, Atom, Literal) :-
    ( catch((le_kbs:item_to_instance(KB, Atom, Tokens),
             le_kbs:canonical_string(Tokens, S)), _, fail)
    -> Literal = S
    ; term_string(Atom, Literal)
    ).

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
    Goal =.. [F|Args],
    goal_arg_types(KB, F, Args, Types),
    symbolic_args(Args, Types, DisplayArgs, Constraints),
    Display =.. [F|DisplayArgs].

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

symbolic_args([], [], [], []).
symbolic_args([A|As], [T|Ts], [D|Ds], Cs) :-
    ( ground(A) ->
        D = A, Cs = Rest
    ;   copy_term(A, _, Attrs),
        ( attrs_constraint_phrase(Attrs, Phrase, CText) ->
            format(atom(D), 'any ~w ~w', [T, Phrase]),
            Cs = [CText|Rest]
        ;   format(atom(D), 'any ~w', [T]),
            Cs = Rest
        )
    ),
    symbolic_args(As, Ts, Ds, Rest).

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
    findall(From-To-Kind, dep_edge(KB, From, To, Kind), Edges),
    findall(P, ( member(P-_-_, Edges) ; member(_-P-_, Edges) ), Ps0),
    sort(Ps0, Ps),
    findall(Cycle,
            ( member(Start, Ps),
              neg_cycle(Start, Edges, Cycle) ),
            Cycles0),
    maplist(canonical_cycle, Cycles0, Cycles1),
    sort(Cycles1, Cycles).

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
body_literal(G, G, pos) :- callable(G), \+ le_builtin_functor_g(G).

body_inner(le_at(G,_,_), L) :- !, body_inner(G, L).
body_inner(G, G).

le_builtin_functor_g(G) :- functor(G, F, _), le_builtin_functor(F).

lit_pi(G, F/A) :- functor(G, F, A).

% neg_cycle(+Start, +Edges, -Cycle): a cycle back to Start using ≥1 neg edge.
neg_cycle(Start, Edges, [Start|Path]) :-
    reach(Start, Start, Edges, [Start], Path, false, true).

reach(Cur, Goal, Edges, Visited, [Next|Rest], NegSoFar, NegOut) :-
    member(Cur-Next-Kind, Edges),
    ( Kind == neg -> Neg1 = true ; Neg1 = NegSoFar ),
    ( Next == Goal ->
        Rest = [], NegOut = Neg1, NegOut == true
    ; \+ memberchk(Next, Visited),
      reach(Next, Goal, Edges, [Next|Visited], Rest, Neg1, NegOut)
    ).

canonical_cycle(Cycle, Canon) :-
    ( Cycle = [_|_] -> last(Cycle, L), ( Cycle = [L|_] -> Trimmed = Cycle ; Trimmed = Cycle ) ; Trimmed = Cycle ),
    sort(Trimmed, Canon).


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

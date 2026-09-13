/** <module> The general writer's round trip: LE -> internal -> LE -> internal

    For every program of the example corpus (the core suite's trees):

        LE  ->  knowledge base  ->  Migration IR  ->  LE  ->  knowledge base

    and the two knowledge bases must hold the same clauses, scenario facts,
    expectations, queries and table rows, up to the naming of variables
    (variant/2) and the source positions LE records.

        ./myswipl.sh -q -g "consult('testing/le_writer_roundtrip.pl')" -g "le_writer_roundtrip:main" -t halt

    As in testing/lps_roundtrip.pl, what this claims is that the written
    document carries everything the knowledge base did — not that the two
    English texts are equal (comments, layout, synonym choice and variable
    names are not recoverable). Programs that do not round-trip for a
    stated reason are listed in excluded/2, and an exclusion that starts
    passing is reported as stale.
*/

:- module(le_writer_roundtrip, [main/0, main/1, roundtrip_file/2, kb_digest/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).
:- use_module('../le_kbs').
:- use_module('../le_writer').

%!  excluded(?Base, ?Reason) is nondet.
%
%   Stated, not silent: constructs of these programs the writer does not put
%   back into English, each a claim about what the IR does not (yet) carry.
excluded(augmentedsem,
         'a rule written inside the ontology section, among its facts: the writer puts \c
          the section''s facts in the ontology and its rules in the knowledge base, which \c
          reorders the clauses of is_a/2.').
excluded(payg_buggy,
         'a deliberately broken program (examples/moreExamples/testing): a rule head read \c
          through the generic "is a" form, whose written form is read through it again with \c
          another variable.').

corpus(Files) :-
    findall(F, ( member(Dir, ['examples/moreExamples', 'examples/RulesRus', 'examples/pt',
                              'examples/es', 'examples/fr', 'examples/it']),
                 directory_member(Dir, F, [extensions([le]), recursive(true)]),
                 \+ sub_atom(F, _, _, _, 'insureLE2'),
                 \+ sub_atom(F, _, _, _, 'InsurLE2') ),
            Files0),
    sort(Files0, Files).

%!  roundtrip_file(+File, -Outcome) is det.
%
%   Outcome is same, differs(What), or error(Why).
roundtrip_file(File, Outcome) :-
    catch(call_with_time_limit(60, roundtrip_file_(File, Outcome)), E,
          ( message_to_string(E, S), Outcome = error(S) )), !.
roundtrip_file(_, error(failed)).

roundtrip_file_(File, Outcome) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    file_directory_name(File, Dir),
    quietly_load(Text, Dir, KB1),
    le_writer:kb_to_ir(KB1, IR),
    le_writer:le_write(IR, Text2, _),
    quietly_load(Text2, Dir, KB2),
    kb_digest(KB1, D1),
    kb_digest(KB2, D2),
    same_digest(D1, D2, What),
    ( What == same -> Outcome = same ; Outcome = differs(What) ).

message_to_string(E, S) :- catch(message_to_codes(E, _, C), _, fail), !, string_codes(S, C).
message_to_string(E, S) :- term_string(E, S).

quietly_load(Text, Dir, KB) :-
    setup_call_cleanup(
        ( retractall(le_kbs:le_include_base(_)), assertz(le_kbs:le_include_base(Dir)),
          le_kbs:set_le_issue_reporting(false) ),
        le_kbs:load_text(Text, KB),
        ( retractall(le_kbs:le_include_base(_)), le_kbs:set_le_issue_reporting(true) )).

%!  kb_digest(+KB, -Digest) is det.
%
%   What must survive the round trip, position-free: d(Clauses, Scenarios,
%   Expectations, Queries, Tables).
kb_digest(KB, d(Clauses, Scenarios, Expected, Queries, Tables)) :-
    findall(P-C, own_clause(KB, P, C), Clauses0), msort_by_pred(Clauses0, Clauses),
    findall(N-Fs, ( current_predicate(KB:scenario/2), KB:scenario(N, Ts),
                    maplist(scenario_fact, Ts, Fs) ), Scenarios0),
    msort(Scenarios0, Scenarios),
    findall(e(Q, S, A, U), ( current_predicate(KB:le_expected/4), KB:le_expected(Q, S, A0, U0),
                             maplist(plain_string, A0, A), maplist(plain_string, U0, U) ), E0),
    msort(E0, Expected),
    findall(N-G, ( current_predicate(KB:query_info/3), KB:query_info(N, G0, _), normal_body(G0, G) ), Q0),
    msort(Q0, Queries),
    findall(T-Rows, ( current_predicate(KB:le_table/6), KB:le_table(T, P, FA, Cols, _, _),
                      findall(r(Id, Cs), KB:le_table_row(T, _, Id, Cs, _, _), Rows0),
                      Rows = [P, FA, Cols|Rows0] ), T0),
    msort(T0, Tables).

own_clause(KB, F/N, (H :- B)) :-
    current_predicate(KB:F/N),
    ( \+ le_kbs:is_system_predicate(F/N) ; F/N == is_a/2 ),
    \+ memberchk(F/N, [le_target_language/1, le_lang/1, le_kb_module_fact/1,
                       le_program_base/1, le_tests_skipped/0, le_dict_fa/3]),
    functor(H, F, N),
    le_kbs:kb_own_predicate(KB, H),
    clause(KB:H, B0, Ref),
    catch(KB:le_source_info(Ref, S, _, _), _, fail),
    integer(S), S < 10000000,
    normal_body(B0, B).

%   Clauses of one predicate keep their order; predicates are sorted.
msort_by_pred(Pairs, Sorted) :-
    findall(P, member(P-_, Pairs), Ps0), sort(Ps0, Ps),
    findall(P-Cs, ( member(P, Ps), findall(C, member(P-C, Pairs), Cs) ), Sorted).

scenario_fact(fact_with_source(F, _, _), N) :- !, normal_body(F, N).
scenario_fact(F, N) :- normal_body(F, N).

plain_string(string(S, _), T) :- !, plain_string(S, T).
plain_string(S, T) :- ( string(S) -> T = S ; term_string(S, T) ).

normal_body(V, V) :- var(V), !.
normal_body(le_at(G, _, _), N) :- !, normal_body(G, N).
normal_body(and(true, B), N) :- !, normal_body(B, N).
normal_body(and(A, true), N) :- !, normal_body(A, N).
normal_body((H :- B), (NH :- NB)) :- !, normal_body(H, NH), normal_body(B, NB).
normal_body(T, N) :-
    compound(T), T =.. [F|Args], memberchk(F, [and, or, not, forall, le_scoped]), !,
    maplist(normal_body, Args, NArgs), N =.. [F|NArgs].
normal_body(T, N) :-
    compound(T), T =.. [Op, [each|E], G, R], memberchk(Op, [sum, count, average, min, max]), !,
    maplist(agg_var, E, E1), maplist(agg_var, R, R1),
    normal_body(G, G1), N =.. [Op, [each|E1], G1, R1].
normal_body(le_flip(G, C), le_flip(NG, C)) :- !, normal_body(G, NG).
normal_body(unknown_template(Ts), unknown(Ws)) :- !, token_words(Ts, Ws).
normal_body(unknown_template(Ts, _, _), unknown(Ws)) :- !, token_words(Ts, Ws).
normal_body(unknown_tokens(Ts), unknown(Ws)) :- !, token_words(Ts, Ws).
normal_body(T, T).

%   A sentence LE could not read: its words, without their positions.
token_words(Ts, Ws) :-
    findall(W, ( member(T, Ts), compound(T), T \= indent(_, _), arg(1, T, W) ), Ws).

agg_var(var(_, V), V) :- !.
agg_var(V, V).

%   same_digest(+D1, +D2, -What): What is `same`, or the first difference.
same_digest(D1, D2, What) :-
    D1 = d(C1, S1, E1, Q1, T1), D2 = d(C2, S2, E2, Q2, T2),
    (   \+ variant(C1, C2) -> first_difference(clauses, C1, C2, What)
    ;   \+ variant(S1, S2) -> first_difference(scenarios, S1, S2, What)
    ;   E1 \== E2 -> first_difference(expectations, E1, E2, What)
    ;   \+ variant(Q1, Q2) -> first_difference(queries, Q1, Q2, What)
    ;   \+ variant(T1, T2) -> first_difference(tables, T1, T2, What)
    ;   What = same
    ).

first_difference(Kind, L1, L2, diff(Kind, X, Y)) :-
    (   nth1(I, L1, X), nth1(I, L2, Y), \+ variant(X, Y) -> true
    ;   length(L1, N1), length(L2, N2), X = count(N1), Y = count(N2)
    ).

		 /*******************************
		 *           THE GATE           *
		 *******************************/

main :- main([]).

main(Opts) :-
    corpus(Files),
    foldl(check(Opts), Files, s(0,0,0), s(Pass, Fail, Excl)),
    Total is Pass + Fail + Excl,
    format('~nle_writer round trip: ~w of ~w; ~w excluded, ~w failing~n',
           [Pass, Total, Excl, Fail]),
    ( Fail =:= 0 -> true ; memberchk(no_halt, Opts) -> true ; halt(1) ).

check(Opts, File, s(P0,F0,X0), s(P,F,X)) :-
    file_base_name(File, BaseFile), file_name_extension(Base, _, BaseFile),
    roundtrip_file(File, Outcome),
    (   excluded(Base, Reason)
    ->  ( Outcome == same -> format('  STALE ~w — excluded, but it round-trips now~n', [File])
        ; format('  excl  ~w — ~w~n', [File, Reason]) ),
        P = P0, F = F0, X is X0 + 1
    ;   Outcome == same
    ->  ( memberchk(verbose, Opts) -> format('  ok    ~w~n', [File]) ; true ),
        P is P0 + 1, F = F0, X = X0
    ;   format('  FAIL  ~w~n', [File]),
        \+ \+ ( numbervars(Outcome, 0, _), format('        ~p~n', [Outcome]) ),
        P = P0, F is F0 + 1, X = X0
    ).

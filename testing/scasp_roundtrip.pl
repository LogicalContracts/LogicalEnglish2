/** <module> The s(CASP) round trip: LE -> s(CASP) -> LE -> s(CASP)

    The gate of MiggratingFromOtherSystems.md Phase 2c for the s(CASP)
    reader (le_writer:prolog_file_to_ir/3): for every program of the core
    example corpus that LE's s(CASP) target can emit,

        LE  ->  s(CASP) (le_scasp)  ->  Migration IR (the reader)  ->  LE
            ->  s(CASP) again

    and the two s(CASP) programs must hold the same clauses, abducibles and
    classical-negation constraints, up to the naming of variables — the
    `#pred` wording is compared too, since the reader takes the templates
    from it. What this claims is that reading s(CASP) back loses nothing LE
    put into it: the reader is the emitter's inverse on LE's own output.

        ./myswipl.sh -q -g "consult('testing/scasp_roundtrip.pl')" -g "scasp_roundtrip:main" -t halt

    A program the emitter reports issues for (a construct with no s(CASP)
    lowering) is skipped, and said so.
*/

:- module(scasp_roundtrip, [main/0, roundtrip_file/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).
:- use_module(library(readutil)).
:- use_module('../le_kbs').
:- use_module('../le_writer').

:- if(exists_source(library(scasp))).
:- use_module('../le_scasp').
scasp_available.
:- else.
scasp_available :- fail.
:- endif.

corpus(Files) :-
    %  The example suite's trees (le_kbs), but the migration twins: the
    %  translators' own tests check those.
    findall(F, ( (   le_kbs:le_examples_dir(Dir)
                 ;   le_kbs:le_extra_examples_dir(Root, Dir), Root \== migration
                 ;   le_kbs:language_examples_dir(_, Dir)
                 ),
                 exists_directory(Dir),
                 directory_member(Dir, F, [extensions([le]), recursive(true)]),
                 \+ sub_atom(F, _, _, _, 'insureLE2'),
                 \+ sub_atom(F, _, _, _, 'InsurLE2') ),
            Files0),
    sort(Files0, Files).

%!  roundtrip_file(+File, -Outcome) is det.
%
%   Outcome: same, differs(Only1, Only2), skipped(Why) or error(Why).
roundtrip_file(File, Outcome) :-
    catch(call_with_time_limit(60, roundtrip_file_(File, Outcome)), E,
          ( message_to_string(E, S), Outcome = error(S) )), !.
roundtrip_file(_, error(failed)).

roundtrip_file_(File, Outcome) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    file_directory_name(File, Dir),
    le_kbs:load_text(Text, Dir, KB1),
    le_scasp:le_scasp_program_text(KB1, S1, Issues1),
    (   Issues1 \== []
    ->  length(Issues1, N), format(string(W), "~w construct(s) with no s(CASP) lowering", [N]),
        Outcome = skipped(W)
    ;   tmp_file_stream(text, Tmp, Out), write(Out, S1), close(Out),
        file_base_name(File, B), file_name_extension(Name, _, B),
        ( catch(le_kbs:text_language(Text, Lang), _, fail) -> true ; Lang = en ),
        prolog_file_to_ir(Tmp, [kb(Name), language(Lang)], IR),
        delete_file(Tmp),
        le_write(IR, LE2, _),
        le_kbs:load_text(LE2, Dir, KB2),
        le_scasp:le_scasp_program_text(KB2, S2, _),
        program_terms(S1, T1), program_terms(S2, T2),
        subtract(T1, T2, Only1), subtract(T2, T1, Only2),
        (   Only1 == [], Only2 == [] -> Outcome = same ; Outcome = differs(Only1, Only2) )
    ).

%   The s(CASP) text's terms, each as a string with its variables named in
%   order (so variants compare equal), sorted; comments and blank lines are
%   not terms.
program_terms(S, Terms) :-
    setup_call_cleanup(open_string(S, In), ( ops, read_all(In, Ts) ), close(In)),
    maplist(normal_string, Ts, Ss),
    msort(Ss, Terms).

read_all(In, Ts) :-
    read_term(In, T, [module(scasp_roundtrip_ops)]),
    ( T == end_of_file -> Ts = [] ; Ts = [T|R], read_all(In, R) ).

normal_string(T, S) :-
    copy_term(T, C), numbervars(C, 0, _),
    format(string(S0), "~W", [C, [quoted(true), numbervars(true), module(scasp_roundtrip_ops), spacing(next_argument)]]),
    normalize_space(string(S), S0).

ops :-
    op(1150, fx, scasp_roundtrip_ops:(#)),
    op(1100, fx, scasp_roundtrip_ops:pred),
    op(1100, fx, scasp_roundtrip_ops:abducible),
    op(1000, xfx, scasp_roundtrip_ops:(::)),
    op(900, fy, scasp_roundtrip_ops:not),
    forall(member(O, [#=, #<>, #<, #>, #=<, #>=]), op(700, xfx, scasp_roundtrip_ops:O)).

main :-
    (   scasp_available
    ->  corpus(Files),
        findall(F-O, ( member(F, Files), roundtrip_file(F, O) ), Rs),
        forall(member(F-O, Rs), report(F, O)),
        aggregate_all(count, member(_-same, Rs), NS),
        aggregate_all(count, member(_-differs(_, _), Rs), ND),
        aggregate_all(count, member(_-skipped(_), Rs), NK),
        aggregate_all(count, member(_-error(_), Rs), NE),
        length(Rs, N),
        format("~nThe s(CASP) round trip: ~w programs; ~w the same, ~w differ, ~w skipped (no s(CASP) lowering), ~w errors.~n",
               [N, NS, ND, NK, NE])
    ;   format("library(scasp) is not installed: nothing to check.~n")
    ).

report(F, same) :- !, format("  same     ~w~n", [F]).
report(F, skipped(W)) :- !, format("  skipped  ~w (~w)~n", [F, W]).
report(F, error(W)) :- !, format("  ERROR    ~w: ~w~n", [F, W]).
report(F, differs(A, B)) :-
    format("  DIFFERS  ~w~n", [F]),
    forall(( member(X, A), nth1(I, A, X), I =< 3 ), format("      only before: ~w~n", [X])),
    forall(( member(X, B), nth1(I, B, X), I =< 3 ), format("      only after:  ~w~n", [X])).

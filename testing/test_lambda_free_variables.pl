/** <module> No lambda relies on a variable of its clause without declaring it

    A yall lambda (`[X]>>Goal`) passed to a meta-predicate (maplist/N,
    foldl/N, include/3, exclude/3, partition/4, ...) behaves in two ways:

      * called at run time, the lambda is copied, so a variable of the clause
        that is already bound (`Consts` in `[T, V]>>memberchk(T-V, Consts)`)
        keeps its value in the copy;
      * compiled — which happens when library(yall) (or apply_macros) is
        loaded before the file is — the lambda becomes an auxiliary predicate
        that receives only its parameters: `Consts` is a fresh variable.

    The same file can then work from the command line and fail in the server,
    where the load order differs. (The LegalRuleML importer wrote SPINdle's
    answers as unbound templates on File ▸ Open in the editor, and passed its
    tests in a shell.) A clause variable a lambda uses must be declared free:
    `{Consts}/[T, V]>>memberchk(T-V, Consts)`, which means the same in both.

    This test reads the Prolog files of the repository (and, when installed,
    of the extensions' translators) and lists every lambda that uses a
    variable of its clause without declaring it.

    Run with:  swipl -g run_tests -t halt testing/test_lambda_free_variables.pl
*/

:- module(test_lambda_free_variables, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
%   the server and what it loads: their operators, to read their files
:- use_module('../classic_web_api', []).

:- prolog_load_context(directory, D), file_directory_name(D, Root),
   retractall(repo_root(_)), assertz(repo_root(Root)).
:- dynamic repo_root/1.

%   The files: the repository's own (its root and lib/), and the translators
%   of the extensions when le_extensions.pl links to them.
checked_file(F) :-
    repo_root(Root),
    member(Pattern, ['*.pl', 'lib/*.pl', 'testing/*.pl']),
    atomic_list_concat([Root, '/', Pattern], P),
    expand_file_name(P, Fs), member(F, Fs).
checked_file(F) :-
    repo_root(Root),
    atomic_list_concat([Root, '/le_extensions.pl'], Ext),
    exists_file(Ext),
    catch(read_link(Ext, _, Target), _, fail),
    file_directory_name(Target, ExtRoot),
    member(Pattern, ['/migration/*.pl', '/migration/*/*.pl']),
    atomic_list_concat([ExtRoot, Pattern], P),
    expand_file_name(P, Fs), member(F, Fs).

%   A lambda using a variable of its clause: File:Line and the variables.
undeclared_lambda(F, Line, Names) :-
    checked_file(F),
    ( module_property(M, file(F)) -> true ; M = user ),
    catch(setup_call_cleanup(open(F, read, S), file_lambda(S, M, Line, Names), close(S)), _, fail).

file_lambda(S, M, Line, Names) :-
    repeat,
    catch(read_term(S, T, [variable_names(Vn), term_position(P), syntax_errors(quiet), module(M)]), _, T = skip),
    (   T == end_of_file
    ->  !, fail
    ;   T \== skip, nonvar(T),
        sub_term(L, T), compound(L), L = (Ps>>Body), nonvar(Ps), \+ Ps = _/_,
        term_variables(Ps, PV), term_variables(Body, BV),
        vars_not_in(BV, PV, Local),
        replace_subterm(T, L, T2), term_variables(T2, Outer),
        vars_in(Local, Outer, Shared0),
        %  a variable of an enclosing lambda's parameters is that lambda's
        exclude(enclosing_parameter(T, L), Shared0, Shared),
        Shared \== [],
        stream_position_data(line_count, P, Line),
        var_names(Shared, Vn, Names)
    ).

enclosing_parameter(T, L, V) :-
    sub_term(E, T), compound(E), E = (Ps>>Body), E \== L,
    sub_term(L1, Body), L1 == L,
    term_variables(Ps, PV), var_member(V, PV).

vars_not_in([], _, []).
vars_not_in([V|Vs], L, R) :- ( var_member(V, L) -> R = R1 ; R = [V|R1] ), vars_not_in(Vs, L, R1).
vars_in([], _, []).
vars_in([V|Vs], L, R) :- ( var_member(V, L) -> R = [V|R1] ; R = R1 ), vars_in(Vs, L, R1).
var_member(X, [Y|Ys]) :- ( X == Y -> true ; var_member(X, Ys) ).

replace_subterm(T, L, R) :-
    (   T == L -> R = '$lambda'
    ;   compound(T) -> T =.. [N|As], replace_args(As, L, Bs), R =.. [N|Bs]
    ;   R = T
    ).
replace_args([], _, []).
replace_args([A|As], L, [B|Bs]) :- replace_subterm(A, L, B), replace_args(As, L, Bs).

var_names([], _, []).
var_names([V|Vs], Vn, [N|Ns]) :-
    ( member(N=V0, Vn), V0 == V -> true ; N = '_' ),
    var_names(Vs, Vn, Ns).

:- begin_tests(lambda_free_variables).

test(no_undeclared_clause_variables) :-
    findall(F:Line-Names, undeclared_lambda(F, Line, Names), Found),
    (   Found == []
    ->  true
    ;   forall(member(F:Line-Names, Found),
               ( atomic_list_concat(Names, ', ', Vars),
                 format(user_error, "~w:~w: the lambda uses ~w of its clause; declare it: {~w}/[...]>>...~n",
                        [F, Line, Vars, Vars]) )),
        fail
    ).

%   The two readings agree once the variable is declared.
test(declared_free_variable_compiled_and_called) :-
    Consts = [c1-ann, c2-ben],
    Lambda = {Consts}/[T, V]>>memberchk(T-V, Consts),
    maplist(Lambda, [c1, c2], Vs),
    Vs == [ann, ben].

:- end_tests(lambda_free_variables).

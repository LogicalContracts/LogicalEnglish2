/** <module> Logical English System Templates

    This module defines the built-in system templates for Logical English:
    comparison operators, assignment, and other core language constructs.

    The word-based surface phrases (e.g. "is equal to", "é igual a") live in
    i18n/system_templates.csv, one column per language; this module builds the
    template dicts for the ACTIVE language (see le_i18n). Symbolic operator
    templates (>=, <=, =, ...) are language-neutral and stay defined here.
*/

:- module(le_system_templates, [le_system_template/1]).

:- use_module(le_i18n).

% le_system_template(dict(FunctorArgs, NamesTypes, WordsAndVars))

% Word-based templates, from i18n/system_templates.csv for the active language.
le_system_template(dict(FunctorArgs, NTs, WV)) :-
    le_i18n:system_template_row(Functor, Types, Parts),
    build_sys_dict(Functor, Types, Parts, FunctorArgs, NTs, WV).

% Symbolic operator templates (language-neutral).
le_system_template(dict([le_ge, V1, V2], [V1-number, V2-number], [V1, '>=', V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, '<=', V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, '=<', V2])).
le_system_template(dict([le_gt, V1, V2], [V1-number, V2-number], [V1, '>', V2])).
le_system_template(dict([le_lt, V1, V2], [V1-number, V2-number], [V1, '<', V2])).
le_system_template(dict([le_assign, V1, V2], [V1-any, V2-any], [V1, '=', V2])).

%!  build_sys_dict(+Functor, +Types, +Parts, -FunctorArgs, -NTs, -WV) is det.
%
%   Builds a template dict from a CSV row: Types gives the argument types (and
%   arity), Parts is the surface phrase where slot(N) marks the N-th argument.
build_sys_dict(Functor, Types, Parts, [Functor|Args], NTs, WV) :-
    length(Types, N),
    length(Args, N),
    pairs_keys_values(NTs, Args, Types),
    maplist(part_to_wv(Args), Parts, WV).

part_to_wv(Args, slot(N), V) :- !, nth1(N, Args, V).
part_to_wv(_, Word, Word).

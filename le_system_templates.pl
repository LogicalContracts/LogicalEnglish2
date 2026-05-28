/** <module> Logical English System Templates
    
    This module defines the built-in system templates for Logical English.
    These include comparison operators, assignment, and other core
    language constructs.
*/

:- module(le_system_templates, [le_system_template/1]).

% le_system_template(dict(FunctorArgs, NamesTypes, WordsAndVars))

le_system_template(dict([le_equal_to, V1, V2], [V1-any, V2-any], [V1, is, equal, to, V2])).
le_system_template(dict([le_ge, V1, V2], [V1-number, V2-number], [V1, is, greater, than, or, equal, to, V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, is, less, than, or, equal, to, V2])).
le_system_template(dict([le_gt, V1, V2], [V1-number, V2-number], [V1, is, greater, than, V2])).
le_system_template(dict([le_lt, V1, V2], [V1-number, V2-number], [V1, is, less, than, V2])).
le_system_template(dict([le_ge, V1, V2], [V1-date, V2-date], [V1, is, after, or, equal, to, V2])).
le_system_template(dict([le_le, V1, V2], [V1-date, V2-date], [V1, is, before, or, equal, to, V2])).
le_system_template(dict([le_gt, V1, V2], [V1-date, V2-date], [V1, is, after, V2])).
le_system_template(dict([le_lt, V1, V2], [V1-date, V2-date], [V1, is, before, V2])).
le_system_template(dict([le_ge, V1, V2], [V1-number, V2-number], [V1, '>=', V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, '<=', V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, '=<', V2])).
le_system_template(dict([le_gt, V1, V2], [V1-number, V2-number], [V1, '>', V2])).
le_system_template(dict([le_lt, V1, V2], [V1-number, V2-number], [V1, '<', V2])).
le_system_template(dict([le_known, V], [V-any], [V, is, known])).
le_system_template(dict([le_assign, V1, V2], [V1-any, V2-any], [V1, '=', V2])).
le_system_template(dict([le_is, V1, V2], [V1-any, V2-any], [V1, is, V2])).
le_system_template(dict([le_is_in, V1, V2], [V1-any, V2-list], [V1, is, in, V2])).
le_system_template(dict([le_is_days_after, V1, V2, V3], [V1-date, V2-number, V3-date], [V1, is, V2, days, after, V3])).

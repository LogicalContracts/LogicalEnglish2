:- module(le_system_templates, [le_system_template/1]).

% le_system_template(dict(FunctorArgs, NamesTypes, WordsAndVars))

le_system_template(dict([le_equal_to, V1, V2], [V1-any, V2-any], [V1, is, equal, to, V2])).
le_system_template(dict([le_assign, V1, V2], [V1-any, V2-any], [V1, '=', V2])).
le_system_template(dict([le_is, V1, V2], [V1-any, V2-any], [V1, is, V2])).
le_system_template(dict([le_ge, V1, V2], [V1-number, V2-number], [V1, '>=', V2])).
le_system_template(dict([le_le, V1, V2], [V1-number, V2-number], [V1, '<=', V2])).
le_system_template(dict([le_gt, V1, V2], [V1-number, V2-number], [V1, '>', V2])).
le_system_template(dict([le_lt, V1, V2], [V1-number, V2-number], [V1, '<', V2])).

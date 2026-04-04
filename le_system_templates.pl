:- module(le_system_templates, [le_system_template/1]).

% le_system_template(dict(FunctorArgs, NamesTypes, WordsAndVars))

le_system_template(dict([equal_to, V1, V2], [V1-any, V2-any], [V1, is, equal, to, V2])).
le_system_template(dict([=, V1, V2], [V1-any, V2-any], [V1, '=', V2])).
le_system_template(dict([is, V1, V2], [V1-any, V2-any], [V1, is, V2])).
le_system_template(dict([>=, V1, V2], [V1-number, V2-number], [V1, '>=', V2])).
le_system_template(dict([<=, V1, V2], [V1-number, V2-number], [V1, '<=', V2])).
le_system_template(dict([>, V1, V2], [V1-number, V2-number], [V1, '>', V2])).
le_system_template(dict([<, V1, V2], [V1-number, V2-number], [V1, '<', V2])).

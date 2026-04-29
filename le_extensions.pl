% WARNING: PROPRIETARY MATERIAL
% Optional file to define LE syntax extensions

:- multifile le_grammar:extract_var_name_extension/2.
:- multifile le_grammar:unify_with_vmap_extension/5.
:- multifile le_grammar:post_parse_literal_hook/4.
:- multifile le_grammar:parse_node_extension/6.

% 1. Recognize 'which' as a variable name
le_grammar:extract_var_name_extension([which], which).

% 2. Resolve 'which' to the last variable in the VM
le_grammar:unify_with_vmap_extension(which, Var, VMIn, VMIn, _IsVar) :-
    member('$last_var'-Var, VMIn), !.

% 3. After parsing a literal, record the last variable found
le_grammar:post_parse_literal_hook(WordsAndVars, _Literal, VMIn, VMOut) :-
    reverse(WordsAndVars, Rev),
    ( member(Var, Rev), var(Var) ->
        % Found the last variable. Update VM.
        % Remove any existing $last_var to avoid multiple entries
        exclude(is_last_var_entry, VMIn, VM1),
        VMOut = ['$last_var'-Var | VM1]
    ; VMOut = VMIn
    ).

is_last_var_entry('$last_var'-_).

% 4. Optional: handle 'which' at the start of a node if needed
% (Currently handled by the default 'and' in strip_op + unify_with_vmap_extension)

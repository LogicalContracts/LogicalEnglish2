:- set_prolog_flag(verbose, silent).
:- use_module(le_tools).
:- use_module(le_kbs).
:- use_module(library(http/json)).

main :-
    current_prolog_flag(argv, [File|_]),
    read_file_to_string(File, Text, []),
    le_tools:le_tool_verify(Text, VR),
    get_dict(issues, VR, Issues),
    ( Issues == [] -> format("ISSUES: none~n")
    ; format("ISSUES:~n"), forall(member(I,Issues), format("  ~w~n",[I])) ),
    le_kbs:load_text(Text, KB),
    ( current_predicate(KB:le_expected/4) ->
        findall(test(Q,S,A,U), KB:le_expected(Q,S,A,U), Tests),
        ( Tests == [] -> format("TESTS: none defined~n")
        ; forall(member(T,Tests),
            ( catch(le_kbs:run_one_test(KB,T,R),E,(R=error(E))),
              ( R = pass(Q,S) -> format("PASS  q=~w scn=~w~n",[Q,S])
              ; R = fail(Q,S,Ex,Ac) -> format("FAIL  q=~w scn=~w~n   expected=~w~n   actual  =~w~n",[Q,S,Ex,Ac])
              ; format("ERROR ~w~n",[R]) )) ) )
    ; format("TESTS: no le_expected~n") ),
    halt.
main :- format("HARNESS_ERROR~n"), halt(1).

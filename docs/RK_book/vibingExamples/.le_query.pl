:- set_prolog_flag(verbose, silent).
:- use_module(le_tools).
:- use_module(library(http/json)).
main :-
    current_prolog_flag(argv, [File, Scn, Query]),
    read_file_to_string(File, Text, []),
    le_tools:le_tool_query(_{program_text:Text, scenario_name:Scn, query:Query}, R),
    json_write_dict(user_output, R, [width(0)]), nl, halt.
main :- format("QUERY_ERROR~n"), halt(1).

/** <module> Every message the LPS target asks the dictionary for exists

    le_lps.pl and its neighbours ask le_i18n:le_msg/3 for the wording of
    their diagnostics. A key with no row in i18n/messages.csv is shown to the
    reader as "missing message: lps_several_scenarios_desc" — which two L4
    twins did, in the LPS2 editor, until the rows were added. This test reads
    the keys out of the source and looks each one up.

    Run with:  swipl -q -g run_tests -t halt testing/test_le_lps_messages.pl
*/

:- module(test_le_lps_messages, []).

:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- use_module(library(pcre)).
:- use_module('../le_i18n').

%!  missing_keys(-Keys) is det.
%
%   The keys asked for in the source that the dictionary has no row for.
missing_keys(Missing) :-
    findall(K, asked_key(K), Ks0), sort(Ks0, Ks),
    findall(K, ( member(K, Ks), \+ catch(le_i18n:le_msg(K, [], _), _, fail) ), Missing).

source_file_(F) :-
    member(B, ['le_lps.pl', 'le_lps_write.pl', 'le_lps_legal.pl']),
    module_property(test_le_lps_messages, file(Here)),
    file_directory_name(Here, D),
    atomic_list_concat([D, '/../', B], F0),
    absolute_file_name(F0, F),
    exists_file(F).

asked_key(Key) :-
    source_file_(F),
    read_file_to_string(F, S, [encoding(utf8)]),
    re_foldl([M, L0, [K|L0]]>>( get_dict(1, M, KS), atom_string(K, KS) ),
             "le_msg\\(([a-z][a-z0-9_]*)", S, [], Ks, []),
    member(Key, Ks).

:- begin_tests(le_lps_messages).

test(every_key_has_a_row, Missing == []) :-
    findall(K, asked_key(K), Ks0), Ks0 \== [],
    missing_keys(Missing).

test(the_scenario_messages_say_the_names) :-
    le_i18n:le_msg(lps_several_scenarios_desc, [name-one, names-'one, two'], D1),
    assertion(sub_atom(D1, _, _, _, 'one, two')),
    le_i18n:le_msg(lps_no_such_scenario_desc, [name-three, names-'one, two'], D2),
    assertion(sub_atom(D2, _, _, _, three)).

:- end_tests(le_lps_messages).

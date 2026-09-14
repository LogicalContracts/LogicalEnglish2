/** <module> Opening another system's files (le_import.pl)

    The registry and the upload door, with a translator of its own made up
    for the test: a file of "rules" lines, each `A => B` becoming an LE rule
    and any other line a TODO block. What is tested is the door, not a
    source system: routing by extension and by Detect, archives (one folder
    or several, members leaving the tree skipped), the fallback when no
    translator reads a file or the one that claimed it throws, and the
    program opening where its includes resolve (`imported/<id>/<name>`).

    Run with:  swipl -q -g run_tests -t halt testing/test_le_import.pl
*/

:- module(test_le_import, []).

:- use_module(library(plunit)).
:- use_module(library(zip)).
:- use_module(library(base64)).
:- use_module(library(readutil)).
:- use_module(library(filesex)).
:- use_module('../le_kbs').
:- use_module('../le_import').
:- use_module('../classic_web_api').
:- use_module('../le_documents').

:- prolog_load_context(file, F), retractall(this_file(_)), assertz(this_file(F)).
:- dynamic this_file/1.

%   The made-up translator: extension `arrows`, and, in an archive, a
%   directory holding a `rules.arrows` file.
:- multifile le_import:importer/6.
le_import:importer(arrows, "Arrow rules (test)", [arrows, zip], File,
                   test_le_import:import_arrows, test_le_import:detect_arrows) :-
    this_file(File).

detect_arrows(Input) :-
    (   exists_directory(Input)
    ->  atomic_list_concat([Input, '/rules.arrows'], F), exists_file(F)
    ;   file_name_extension(_, arrows, Input)
    ).

import_arrows(Input0, OutDir, imported(LEFile, Notes)) :-
    ( exists_directory(Input0) -> atomic_list_concat([Input0, '/rules.arrows'], Input) ; Input = Input0 ),
    read_file_to_string(Input, Text, []),
    ( sub_string(Text, _, _, _, "THROW") -> throw(error(domain_error(arrows, Text), _)) ; true ),
    split_string(Text, "\n", " \r", Lines0), exclude(==(""), Lines0, Lines),
    atomic_list_concat([OutDir, '/arrows.le'], LEFile),
    setup_call_cleanup(open(LEFile, write, S),
        ( format(S, "the target language is: prolog.~n~nthe templates are:~n    *a thing* is ready.~n~nthe knowledge base arrows includes:~n~n", []),
          forall(member(L, Lines),
                 (   split_string(L, "=", " >", [A, B]), A \== "", B \== ""
                 ->  format(S, "~w is ready if~n    ~w is ready.~n~n", [B, A])
                 ;   format(S, "% TODO: not an arrow~n%   | ~w~n~n", [L])
                 )) ),
        close(S)),
    Notes = ["arrows read"].

%   The made-up exporter: a program with `*a thing* is ready` rules written
%   back as arrows (the importer's own format), with a link.
:- multifile le_import:exporter/6.
le_import:exporter(arrows, "Arrow rules (test)", arrows, File,
                   test_le_import:export_arrows, test_le_import:applies_arrows) :-
    this_file(File).

applies_arrows(KB) :- catch(current_predicate(KB:is_ready/1), _, fail).

export_arrows(KB, _Options, exported('rules.arrows', Text, ["arrows written"], [link("A sandbox", "https://example.org/#x")])) :-
    findall(L, ( catch(clause(KB:is_ready(B), Body), _, fail),
                 strip_ready(Body, A), format(string(L), "~w => ~w", [A, B]) ), Ls),
    atomic_list_concat(Ls, '\n', Text).

strip_ready(Body, A) :- sub_term(is_ready(A0), Body), !, A = A0.

zip_of(Zip, Members) :-
    setup_call_cleanup(zip_open(Zip, write, Z, []),
        forall(member(Name-Content, Members),
               setup_call_cleanup(zipper_open_new_file_in_zip(Z, Name, Out, []),
                                  write(Out, Content), close(Out))),
        zip_close(Z)).

base64_of_file(File, B64) :-
    read_file_to_codes(File, Codes, [type(binary)]),
    atom_codes(A, Codes),
    base64(A, B64).

:- begin_tests(le_import).

test(text_file_by_extension) :-
    import_upload("my rules.arrows", text("a => b\nnot an arrow\n"), R, []),
    R.importer == "Arrow rules (test)",
    once(sub_string(R.document, _, _, _, "b is ready if")),
    once(sub_string(R.document, _, _, _, "% TODO: not an arrow")),
    R.fileName == 'arrows.le',
    R.notes == ["arrows read"],
    sub_atom(R.source, 0, _, _, 'imported/').

test(program_opens_where_it_was_written) :-
    import_upload("r.arrows", text("x => y\n"), R, []),
    le_example_relpath(R.source, Path),
    atom_concat(Path, '.le', File),
    exists_file(File).

test(unknown_file_becomes_a_todo) :-
    import_upload("notes.xyz", text("some text\nmore"), R, []),
    R.importer == null,
    once(sub_string(R.document, _, _, _, "% TODO: translate notes.xyz")),
    once(sub_string(R.document, _, _, _, "%   | more")),
    once(sub_string(R.document, 0, _, _, "the target language is: prolog.")).

test(a_translator_that_throws_leaves_a_todo) :-
    import_upload("bad.arrows", text("THROW\n"), R, []),
    R.importer == "Arrow rules (test)",
    once(sub_string(R.document, _, _, _, "% TODO")),
    once(sub_string(R.document, _, _, _, "%   | THROW")).

test(archive_of_one_folder) :-
    tmp_file_stream(Zip, S, [extension(zip)]), close(S),
    zip_of(Zip, ['proj/rules.arrows'-"p => q\n", 'proj/readme.txt'-"hello"]),
    base64_of_file(Zip, B64),
    import_upload("proj.zip", base64(B64), R, []),
    R.importer == "Arrow rules (test)",
    once(sub_string(R.document, _, _, _, "q is ready if")).

test(archive_members_leaving_the_tree_are_skipped) :-
    tmp_file_stream(Zip, S, [extension(zip)]), close(S),
    zip_of(Zip, ['rules.arrows'-"m => n\n", '../escaped.arrows'-"x"]),
    base64_of_file(Zip, B64),
    import_upload("two.zip", base64(B64), R, []),
    once(sub_string(R.document, _, _, _, "n is ready if")),
    imported_dir(Root),
    atomic_list_concat([Root, '/', escaped, '.arrows'], Escaped),
    \+ exists_file(Escaped).

test(archive_nobody_reads) :-
    tmp_file_stream(Zip, S, [extension(zip)]), close(S),
    zip_of(Zip, ['x/other.txt'-"nothing"]),
    base64_of_file(Zip, B64),
    import_upload("other.zip", base64(B64), R, []),
    get_dict(error, R, _).

test(file_names_are_names, [fail]) :-
    import_upload("..", text("a => b"), _, []).

test(a_path_is_taken_as_its_name) :-
    import_upload("../../up.arrows", text("a => b"), R, []),
    le_example_relpath(R.source, Path),
    imported_dir(Root),
    sub_atom(Path, 0, _, _, Root).

test(a_translator_can_be_named) :-
    import_upload("rules.txt", text("c => d\n"), R, [importer("arrows")]),
    R.importer == "Arrow rules (test)",
    once(sub_string(R.document, _, _, _, "d is ready if")).

test(formats_listed) :-
    import_formats(Fs),
    once(( member(F, Fs), F.id == arrows )).

%   What was uploaded stays beside the program, in sources/: the editor's
%   File > Show the Original lists that folder (operation originals).
test(originals_kept_beside_the_program) :-
    import_upload("my rules.arrows", text("a => b\n"), R, []),
    classic_web_api:handle_originals(_{source: R.source}, O),
    O.files == ["sources/my rules.arrows"],
    le_example_relpath(R.source, Path), file_directory_name(Path, Dir),
    le_documents:document_text("sources/my rules.arrows", Dir, [], T),
    T == "a => b\n".

test(originals_of_an_archive) :-
    tmp_file_stream(Zip, S, [extension(zip)]), close(S),
    zip_of(Zip, ['proj/rules.arrows'-"p => q\n", 'proj/readme.txt'-"hello"]),
    base64_of_file(Zip, B64),
    import_upload("proj.zip", base64(B64), R, []),
    classic_web_api:handle_originals(_{source: R.source}, O),
    O.files == ["sources/readme.txt", "sources/rules.arrows"].

test(no_originals_for_a_program_not_converted) :-
    classic_web_api:handle_originals(_{source: "moreExamples/citizenship"}, O),
    O.files == [].

%   The way back: only the exporters that can write a program are offered,
%   and an export returns the text, the notes and the links.
test(export_way_back) :-
    le_kbs:load_text("the target language is: prolog.\n\nthe templates are:\n    *a thing* is ready.\n\nthe knowledge base t includes:\n\nb is ready if\n    a is ready.\n", KB),
    export_formats(KB, Fs),
    assertion(( member(F, Fs), get_dict(id, F, arrows) )),
    export_kb(arrows, KB, [], R),
    assertion(R.document == "a => b"),
    assertion(R.notes == ["arrows written"]),
    R.links = [L],
    assertion(L.title == "A sandbox"),
    assertion(L.url == "https://example.org/#x"),
    export_kb(nobody, KB, [], R2),
    assertion(get_dict(error, R2, _)).

test(export_not_offered_when_it_does_not_apply) :-
    le_kbs:load_text("the target language is: prolog.\n\nthe templates are:\n    *a thing* is green.\n\nthe knowledge base u includes:\n\nb is green.\n", KB),
    export_formats(KB, Fs),
    assertion(\+ ( member(F, Fs), get_dict(id, F, arrows) )).

:- end_tests(le_import).

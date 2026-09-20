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
:- use_module('../le_api').
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

%   Its check (le_import:export_check/2): arrows say only `A => B`, so a
%   rule with any other condition cannot be written — each such condition
%   is a problem, where it stands.
:- multifile le_import:export_check/2.
le_import:export_check(arrows, test_le_import:check_arrows).

check_arrows(KB, _Options, Problems) :-
    findall(problem(at(S, E), "arrows have no form for this condition"),
            ( catch(clause(KB:is_ready(_), Body), _, fail),
              sub_term(X, Body), compound(X), X = le_at(G, S, E), \+ G = is_ready(_) ),
            Problems).

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
    le_api:handle_originals(_{source: R.source}, O),
    O.files == ["sources/my rules.arrows"],
    le_example_relpath(R.source, Path), file_directory_name(Path, Dir),
    le_documents:document_text("sources/my rules.arrows", Dir, [], T),
    T == "a => b\n".

test(originals_of_an_archive) :-
    tmp_file_stream(Zip, S, [extension(zip)]), close(S),
    zip_of(Zip, ['proj/rules.arrows'-"p => q\n", 'proj/readme.txt'-"hello"]),
    base64_of_file(Zip, B64),
    import_upload("proj.zip", base64(B64), R, []),
    le_api:handle_originals(_{source: R.source}, O),
    O.files == ["sources/readme.txt", "sources/rules.arrows"].

test(no_originals_for_a_program_not_converted) :-
    le_api:handle_originals(_{source: "moreExamples/citizenship"}, O),
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

%   A program with something the target cannot say is refused before
%   anything is written: the reply is the error and the problems, each with
%   its line and the program's words there — and no document.
test(export_refused_before_writing) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a thing* is ready.\n\nthe knowledge base t includes:\n\nb is ready if\n    a is ready\n    and 3 > 2.\n",
    le_kbs:load_text(Doc, KB),
    export_formats(KB, Fs),
    assertion(( member(F, Fs), get_dict(id, F, arrows) )),     % offered, and then refused
    export_kb(arrows, KB, [text(Doc)], R),
    assertion(\+ get_dict(document, R, _)),
    assertion(sub_string(R.error, _, _, _, "Arrow rules (test)")),
    assertion(R.exporter == "Arrow rules (test)"),
    R.problems = [P],
    assertion(P.line == 10),
    assertion(P.text == "3 > 2"),
    assertion(P.message == "arrows have no form for this condition").

%   Without the program's text there is no line to give: the problem stays.
test(export_refused_without_text) :-
    le_kbs:load_text("the target language is: prolog.\n\nthe templates are:\n    *a thing* is ready.\n\nthe knowledge base t includes:\n\nb is ready if\n    a is ready\n    and 3 > 2.\n", KB),
    export_kb(arrows, KB, [], R),
    R.problems = [P],
    assertion(P.line == null).

%   The shared shape of a refusal, for any converter (See s(CASP), ...):
%   problems in the order of their lines, those with no line last, no
%   repeats.
test(refusal_shape) :-
    Doc = "one\ntwo\nthree\n",
    export_refusal("X", [problem(none, "c"), problem(line(3), "b"), problem(at(4, 7), "a"), problem(line(3), "b")],
                   [text(Doc)], R),
    assertion(R.exporter == "X"),
    findall(L-M, ( member(P, R.problems), L = P.line, M = P.message ), LMs),
    assertion(LMs == [2-"a", 3-"b", null-"c"]),
    R.problems = [P1|_],
    assertion(P1.text == "two").

%   LE's integrity constraints are not in the Migration IR: an exporter
%   whose target has none asks for them by name, so it cannot drop them.
test(constraints_are_problems_for_a_target_without_them) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a thing* is ready.\n    *a thing* is late.\n\nthe knowledge base t includes:\n\nit must not be true that\n    a thing is ready\n    and the thing is late.\n",
    le_kbs:load_text(Doc, KB),
    kb_constraint_problems(KB, "Arrows", Ps),
    Ps = [problem(at(S, _), M)],
    assertion(sub_string(M, _, _, _, "Arrows has no form for it")),
    export_refusal("Arrows", Ps, [text(Doc)], R),
    R.problems = [P],
    assertion(P.line == 9),
    assertion(integer(S)).

test(export_not_offered_when_it_does_not_apply) :-
    le_kbs:load_text("the target language is: prolog.\n\nthe templates are:\n    *a thing* is green.\n\nthe knowledge base u includes:\n\nb is green.\n", KB),
    export_formats(KB, Fs),
    assertion(\+ ( member(F, Fs), get_dict(id, F, arrows) )).

:- end_tests(le_import).

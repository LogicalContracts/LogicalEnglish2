/** <module> Opening another system's files as Logical English

    File ▸ Open in the editor accepts, besides `.le`, the files of the
    systems a translator is registered for (InsurLE2/docs/
    MiggratingFromOtherSystems.md, docs/le_migration.md). This module is the
    door they all go through; it knows no source system. A translator
    registers itself with one clause of importer/6:

        le_import:importer(Id, Title, Extensions, File, Import, Detect)

      - Id           an atom naming the source (`solidity`)
      - Title        what the editor says it is ("Solidity contract")
      - Extensions   the file extensions it reads, lower case, no dot
                     (`[sol]`); `zip` for an archive of a source tree
      - File         the Prolog file defining Import and Detect, loaded on
                     first use (so registering costs nothing at start-up)
      - Import       Module:Name, called as call(Import, +Input, +OutDir,
                     -imported(LEFile, Notes)): Input is the uploaded file,
                     or the directory an uploaded archive was extracted into;
                     the translation (the .le and what it includes or cites)
                     is written into the empty directory OutDir; Notes is a
                     list of strings. A fragment the translator cannot
                     translate is written into the .le as a comment block
                     carrying the word TODO and the fragment verbatim — it
                     never makes the whole import fail.
      - Detect       Module:Name, call(Detect, +Input) succeeds when Input
                     is this source's material; it decides between
                     translators that share an extension (`zip`, `xml`).

    An upload is kept in its own directory under tmp/imports/, and the
    program is opened as `imported/<id>/<name>`, which le_example_relpath/2
    resolves there: the program's includes and the documents it cites are
    found beside it, exactly as for an example.

    When no translator accepts a text file, or the one that claimed it
    fails outright, the result is still a program: the file's text as a TODO
    comment, with the reason.
*/

:- module(le_import, [import_upload/4, import_formats/1, imported_dir/1]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(zip)).
:- use_module(library(base64)).

:- multifile importer/6.
:- dynamic importer/6.

%!  imported_dir(-Dir) is det.
%
%   Where uploads and their translations are kept (relative to the server's
%   working directory, like the example trees).
imported_dir('tmp/imports').

%!  import_formats(-Formats:list(dict)) is det.
%
%   The registered translators, for the editor's file picker and its help:
%   `{id, title, extensions}`.
import_formats(Formats) :-
    findall(_{id: Id, title: Title, extensions: Exts},
            importer(Id, Title, Exts, _, _, _),
            Formats).

%!  import_upload(+FileName, +Content, -Reply:dict, +Options) is det.
%
%   Content is `text(String)` or `base64(String)` (a binary upload, such as
%   a zip archive). Reply is a dict: `document` (the program's text),
%   `fileName` (`<stem>.le`), `source` (`imported/<id>/<stem>`: open it as
%   that, so its includes resolve), `importer` (the translator's title, or
%   null), `notes` (strings), `files` (what was written beside it). Or
%   `error` when nothing could be read. Options: `importer(Id)` forces a
%   translator; `root(Dir)` keeps the upload elsewhere than imported_dir/1
%   (another server embedding LE, with a scratch directory of its own).
import_upload(FileName0, Content, Reply, Options) :-
    atom_string(FileName1, FileName0),
    file_base_name(FileName1, FileName),
    safe_name(FileName),
    ( memberchk(root(Root), Options) -> true ; imported_dir(Root) ),
    new_upload_dir(Root, Id, Dir),
    atomic_list_concat([Dir, '/in'], InDir),
    atomic_list_concat([Dir, '/out'], OutDir),
    make_directory_path(InDir), make_directory_path(OutDir),
    atomic_list_concat([InDir, '/', FileName], InFile),
    write_upload(InFile, Content),
    file_name_extension(Stem0, Ext0, FileName),
    downcase_atom(Ext0, Ext),
    (   Ext == zip
    ->  atomic_list_concat([InDir, '/', Stem0], Tree),
        extract_zip(InFile, Tree),
        single_subdir(Tree, Input)
    ;   Input = InFile
    ),
    le_stem(Stem0, Stem),
    (   choose_importer(Ext, Input, Options, importer(_, Title, _, File, Import, _))
    ->  load_importer(File),
        catch(( call(Import, Input, OutDir, imported(LEFile0, Notes0)) -> Outcome = ok(LEFile0, Notes0)
              ; Outcome = failed("the translator failed") ),
              E, ( error_text(E, Msg), Outcome = failed(Msg) )),
        keep_originals(Input, OutDir),
        (   Outcome = ok(LEFile, Notes)
        ->  imported_reply(Id, OutDir, LEFile, Title, Notes, Reply)
        ;   Outcome = failed(Why),
            fallback(Id, OutDir, Stem, Input, Title, Why, Reply)
        )
    ;   Ext == zip
    ->  le_i18n:le_msg(import_no_translator, [file-FileName], M),
        Reply = _{error: M}
    ;   le_i18n:le_msg(import_no_translator, [file-FileName], Why),
        keep_originals(Input, OutDir),
        fallback(Id, OutDir, Stem, Input, null, Why, Reply)
    ).

%   What was uploaded, beside the program in sources/: the editor's File ▸
%   Show the Original lists that folder. An importer that keeps the sources
%   it cites there itself (under the paths its citations use) is left alone.
keep_originals(Input, OutDir) :-
    atomic_list_concat([OutDir, '/sources'], SDir),
    (   exists_directory(SDir)
    ->  true
    ;   exists_directory(Input)
    ->  catch(copy_directory(Input, SDir), _, true)
    ;   make_directory_path(SDir),
        file_base_name(Input, B), atomic_list_concat([SDir, '/', B], To),
        catch(copy_file(Input, To), _, true)
    ).

%   A file name from the client is a name, not a path.
safe_name(Name) :-
    Name \== '', Name \== '.', Name \== '..',
    \+ sub_atom(Name, _, _, _, '/'),
    \+ sub_atom(Name, _, _, _, '\\').

new_upload_dir(Root, Id, Dir) :-
    catch(forget_old_uploads(Root), _, true),
    repeat,
    random_between(0, 0xffffffff, R),
    get_time(T), S is floor(T),
    format(atom(Id), '~36r~36r', [S, R]),
    atomic_list_concat([Root, '/', Id], Dir),
    \+ exists_directory(Dir), !,
    make_directory_path(Dir).

%   Uploads are kept a day: long enough to work on the translation (its
%   includes and cited documents are read from there), not forever.
forget_old_uploads(Root) :-
    exists_directory(Root), !,
    get_time(Now),
    directory_files(Root, Es),
    forall(( member(E, Es), \+ sub_atom(E, 0, 1, _, '.'),
             atomic_list_concat([Root, '/', E], D),
             exists_directory(D),
             time_file(D, T), Now - T > 86400 ),
           catch(delete_directory_and_contents(D), _, true)).
forget_old_uploads(_).

%!  max_upload_bytes(-N) is det.
max_upload_bytes(20000000).

write_upload(File, text(S)) :- !,
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       write(Out, S), close(Out)).
write_upload(File, base64(B64)) :-
    atom_string(A, B64),
    base64(Bytes, A),                    % an atom whose characters are the bytes
    atom_codes(Bytes, Codes),
    setup_call_cleanup(open(File, write, Out, [type(binary)]),
                       forall(member(C, Codes), put_byte(Out, C)),
                       close(Out)).

%   A program's name is an atom LE reads back: letters, digits, underscores.
le_stem(Stem0, Stem) :-
    downcase_atom(Stem0, L),
    atom_codes(L, Cs0),
    maplist(stem_code, Cs0, Cs1),
    atom_codes(S1, Cs1),
    atomic_list_concat(Parts0, '_', S1),
    exclude(==(''), Parts0, Parts),
    (   Parts == [] -> Stem = imported
    ;   atomic_list_concat(Parts, '_', S2),
        ( sub_atom(S2, 0, 1, _, F), char_type(F, digit) -> atom_concat(p_, S2, Stem) ; Stem = S2 )
    ).
stem_code(C, C) :- code_type(C, alnum), C < 128, !.
stem_code(_, 0'_).

		 /*******************************
		 *          ARCHIVES            *
		 *******************************/

%   Every member of the archive, below Tree. A member whose name would leave
%   Tree (an absolute path, `..`) is skipped.
extract_zip(Zip, Tree) :-
    make_directory_path(Tree),
    setup_call_cleanup(
        zip_open(Zip, read, Z, []),
        ( zipper_goto(Z, first)
        ->  extract_members(Z, Tree)
        ;   true ),
        zip_close(Z)).

extract_members(Z, Tree) :-
    zipper_file_info(Z, Name, _Info),
    (   safe_member(Name)
    ->  atomic_list_concat([Tree, '/', Name], Path),
        (   sub_atom(Name, _, 1, 0, '/')
        ->  make_directory_path(Path)
        ;   file_directory_name(Path, PD), make_directory_path(PD),
            setup_call_cleanup(zipper_open_current(Z, In, [type(binary)]),
                               setup_call_cleanup(open(Path, write, Out, [type(binary)]),
                                                  copy_stream_data(In, Out),
                                                  close(Out)),
                               close(In))
        )
    ;   true
    ),
    (   zipper_goto(Z, next)
    ->  extract_members(Z, Tree)
    ;   true
    ).

safe_member(Name) :-
    atom_string(Name, S),
    S \== "",
    \+ sub_string(S, 0, 1, _, "/"),
    split_string(S, "/\\", "", Parts),
    \+ memberchk("..", Parts),
    \+ ( sub_string(S, 1, 1, _, ":") ),
    \+ sub_string(S, 0, _, _, "__MACOSX").

%   An archive of one folder is that folder.
single_subdir(Tree, Input) :-
    directory_files(Tree, Es0),
    exclude(hidden_entry, Es0, Es),
    (   Es = [One],
        atomic_list_concat([Tree, '/', One], Sub),
        exists_directory(Sub)
    ->  Input = Sub
    ;   Input = Tree
    ).
hidden_entry(E) :- sub_atom(E, 0, 1, _, '.').

		 /*******************************
		 *     CHOOSING A TRANSLATOR    *
		 *******************************/

choose_importer(_, _, Options, Imp) :-
    memberchk(importer(Id0), Options), !,
    atom_string(Id, Id0),
    Imp = importer(Id, _, _, _, _, _),
    call(Imp), !,
    load_importer_of(Imp).
choose_importer(Ext, Input, _, Imp) :-
    findall(importer(Id, T, Es, F, I, D),
            ( importer(Id, T, Es, F, I, D), memberchk(Ext, Es) ),
            Cands),
    Cands \== [],
    (   Cands = [Imp0], \+ generic_extension(Ext)
    ->  Imp = Imp0,
        load_importer_of(Imp)
    ;   member(Imp, Cands),
        load_importer_of(Imp),
        Imp = importer(_, _, _, _, _, Detect),
        catch(call(Detect, Input), _, fail)
    ), !.

%   Extensions many systems use: the translator's Detect decides even when
%   only one translator is registered for them. A specific extension (`sol`)
%   goes to its translator, which reports what it cannot read.
generic_extension(zip).
generic_extension(txt).
generic_extension(json).
generic_extension(xml).

load_importer_of(importer(_, _, _, File, _, _)) :-
    exists_file(File),
    catch(load_importer(File), E, ( print_message(warning, E), fail )).

load_importer(File) :-
    load_files(File, [if(not_loaded)]).

		 /*******************************
		 *            REPLIES           *
		 *******************************/

imported_reply(Id, OutDir, LEFile, Title, Notes, Reply) :-
    read_file_to_string(LEFile, Text, [encoding(utf8)]),
    atomic_list_concat([OutDir, '/'], OutSlash),
    (   atom_concat(OutSlash, Rel, LEFile) -> true ; file_base_name(LEFile, Rel) ),
    file_name_extension(RelStem, _, Rel),
    file_base_name(LEFile, Base),
    format(atom(Source), 'imported/~w/~w', [Id, RelStem]),
    written_files(OutDir, Files),
    maplist(to_string, Notes, NoteStrs),
    Reply = _{document: Text, fileName: Base, source: Source,
              importer: Title, notes: NoteStrs, files: Files}.

error_text(E, S) :-
    catch(( '$messages':translate_message(E, Lines, []),
            with_output_to(string(S0), print_message_lines(current_output, '', Lines)),
            normalize_space(string(S), S0) ), _, fail), !.
error_text(E, S) :- format(string(S), "~q", [E]).

to_string(X, S) :- ( string(X) -> S = X ; atomic(X) -> atom_string(X, S) ; format(string(S), "~w", [X]) ).

written_files(OutDir, Files) :-
    atomic_list_concat([OutDir, '/'], OutSlash),
    findall(Rel,
            ( directory_member(OutDir, F, [recursive(true)]),
              exists_file(F),
              atom_concat(OutSlash, Rel0, F), atom_string(Rel0, Rel) ),
            Files0),
    msort(Files0, Files).

%   Nothing translated: the source itself, as a TODO, in a program that
%   says why. Only text is copied; an archive has nothing to show.
fallback(Id, OutDir, Stem, Input, Title, Why, Reply) :-
    (   exists_file(Input),
        catch(read_file_to_string(Input, Src, [encoding(utf8)]), _, fail),
        string_length(Src, Len), Len < 2000000
    ->  true
    ;   Src = ""
    ),
    file_base_name(Input, InName),
    to_string(Why, Why0),
    ( string_concat(WhyBare, ".", Why0) -> true ; WhyBare = Why0 ),
    le_i18n:le_msg(import_fallback_todo, [file-InName, reason-WhyBare], Todo),
    with_output_to(string(Text),
        ( format("the target language is: prolog.~n~n"),
          format("the knowledge base ~w includes:~n~n", [Stem]),
          format("% TODO: ~w~n", [Todo]),
          (   Src == "" -> true
          ;   format("%~n"),
              split_string(Src, "\n", "\r", Ls),
              forall(member(L, Ls), format("%   | ~w~n", [L]))
          ) )),
    atomic_list_concat([OutDir, '/', Stem, '.le'], LEFile),
    setup_call_cleanup(open(LEFile, write, S, [encoding(utf8)]), write(S, Text), close(S)),
    to_string(Why, WhyS),
    imported_reply(Id, OutDir, LEFile, Title, [WhyS], Reply).

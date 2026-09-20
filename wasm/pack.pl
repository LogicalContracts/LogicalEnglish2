/** <module> What goes into a WebAssembly build, and what must not

    The browser build carries its own file system: the examples, the i18n
    dictionaries, the shared LE libraries and LE2's own Prolog, unpacked into
    the virtual file system of the worker before the first request. This file
    decides what that is — and, more to the point, what it is not.

    **The rule.** A file goes in only if an anonymous visitor to the server
    deployment could already read it. That is not a judgement made here: it is
    restricted_paths.pl's `is_path_allowed(Path, [])`, the same call the /leapi
    operations make for a request with no session. The WASM build has no
    accounts and cannot have any — it is a static site, and every byte it
    ships is a byte the visitor has — so anything a server would have asked a
    user to log in for is not shippable, and is left out.

    On top of that rule, two exclusions of its own:

      * **symbolic links.** `le_extensions.pl`, `le_importers.pl` and the
        `insureLE2`/`lpsPlus` example trees are links into private sibling
        repositories. A link resolves perfectly well on the machine that
        builds, which is exactly what makes it dangerous: the proprietary
        grammar extensions would be published by accident. Links are skipped,
        and `--private` is the one way to include them, for a deployment that
        is not public.
      * **anything with an account in it**: `le_users.db`.

    `payload_files(-Files)` is the list, relative to the repository root, in
    the order they should be unpacked. build.sh asks for it and hands it to
    the packer; nothing else decides what ships.
*/

:- module(le_wasm_pack, [
    payload_files/1,            % -Files:list(atom)
    payload_files/2,            % +Options, -Files
    print_payload_files/0,
    print_payload_files/1       % +Options
    ]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%  The repository, as a search path, before anything is loaded from it.
:- multifile user:file_search_path/2.
:- prolog_load_context(directory, WasmDir),
   file_directory_name(WasmDir, RepoDir),
   ( user:file_search_path(le2, RepoDir) -> true
   ; assertz(user:file_search_path(le2, RepoDir)) ).

:- use_module(le2(restricted_paths)).

%!  payload_tree(?Spec) is nondet.
%
%   Spec is dir(Rel, Extensions) — every file under Rel whose extension is in
%   the list (`any` for all of them) — or files(Rel, Extensions) for one
%   directory without its subdirectories.
payload_tree(files('.',      [pl])).           % LE2 itself
payload_tree(dir('wasm',     [pl])).           % this build's entry and its shims
payload_tree(dir('i18n',     [csv, pl])).      % the dictionaries, read at load
payload_tree(files('llm',    [pl])).
payload_tree(dir('lib',      [le, pl])).       % the shared LE libraries
payload_tree(dir('examples', [le, pl, md, csv, json, txt, png, jpg, svg])).
%   The originals a migrated twin was converted from, which live in a
%   `sources/` folder beside it: View ▸ The original this was converted from
%   (le_original_text.pl) reads them by name, so a build without them has a
%   menu entry that finds nothing. Their own formats, which are nobody else's
%   extensions — a LegalRuleML file, an OIA policy, a Daml or Solidity source.
payload_tree(dir('examples', [lrml, policy, yaml, html, cpp, py, sol, daml, drl, epilog])).

%!  never(+Rel) is semidet.
%
%   Excluded whatever else says otherwise.
never('le_users.db').
%   The two modules that are the *server*: they import library(socket) and
%   library(http/thread_httpd), neither of which the WebAssembly image has, so
%   they could not load here even if something tried. Left out deliberately,
%   as lps_http.pl is in LPS2's packer.
never('classic_web_api.pl').
never('dap_server.pl').
%   The build's own output, which lives under wasm/ and must not be packed
%   into the next build's payload.
never(Rel) :- sub_atom(Rel, 0, _, _, 'wasm/dist').
never(Rel) :- sub_atom(Rel, _, _, _, 'node_modules').
never(Rel) :- sub_atom(Rel, _, _, _, '/.').
never(Rel) :- sub_atom(Rel, 0, 1, _, '.').

payload_files(Files) :- payload_files([], Files).

%!  payload_files(+Options, -Files) is det.
%
%   Options: `private(true)` to follow the symbolic links into the private
%   repositories and to stop applying the anonymous-visitor rule. A build made
%   with it must not be deployed anywhere public; build.sh says so too.
payload_files(Options, Files) :-
    ( memberchk(private(true), Options) -> Private = true ; Private = false ),
    repo_root(Root),
    findall(Rel,
            ( payload_tree(Spec),
              tree_file(Root, Spec, Rel),
              includable(Root, Rel, Private) ),
            Files0),
    sort(Files0, Files).

repo_root(Root) :-
    module_property(le_wasm_pack, file(F)),
    file_directory_name(F, Dir),
    file_directory_name(Dir, Root).

tree_file(Root, dir(Sub, Exts), Rel) :-
    directory_member_rel(Root, Sub, true, Rel0),
    extension_ok(Rel0, Exts),
    Rel = Rel0.
tree_file(Root, files(Sub, Exts), Rel) :-
    directory_member_rel(Root, Sub, false, Rel0),
    extension_ok(Rel0, Exts),
    Rel = Rel0.

extension_ok(_, any) :- !.
extension_ok(Rel, Exts) :-
    file_name_extension(_, Ext, Rel),
    memberchk(Ext, Exts).

%   Walks Sub relative to Root, descending when Recurse, never through a
%   symbolic link (the whole point; see the header).
directory_member_rel(Root, Sub, Recurse, Rel) :-
    ( Sub == '.' -> Dir = Root ; atomic_list_concat([Root, '/', Sub], Dir) ),
    exists_directory(Dir),
    directory_files(Dir, Entries),
    member(Entry, Entries),
    Entry \== '.', Entry \== '..',
    atomic_list_concat([Dir, '/', Entry], Path),
    ( Sub == '.' -> Rel0 = Entry ; atomic_list_concat([Sub, '/', Entry], Rel0) ),
    (   exists_directory(Path)
    ->  Recurse == true,
        directory_member_rel(Root, Rel0, true, Rel)
    ;   Rel = Rel0
    ).

%!  includable(+Root, +Rel, +Private) is semidet.
includable(Root, Rel, Private) :-
    \+ never(Rel),
    atomic_list_concat([Root, '/', Rel], Path),
    (   Private == true
    ->  true
    ;   \+ is_link_path(Path),
        %  The anonymous visitor's rule, unchanged and not re-stated here.
        is_path_allowed(Rel, [])
    ).

%   A file reached through a link, at any level: read_link/3 on each prefix.
is_link_path(Path) :-
    atomic_list_concat(Parts, '/', Path),
    append(Prefix, _, Parts), Prefix \== [],
    atomic_list_concat(Prefix, '/', Sub),
    Sub \== '',
    catch(read_link(Sub, _, _), _, fail), !.

print_payload_files :- print_payload_files([]).
print_payload_files(Options) :-
    payload_files(Options, Files),
    forall(member(F, Files), writeln(F)).

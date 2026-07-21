/** <module> Logical English Knowledge Base Management
    
    This module provides predicates for loading Logical English files,
    managing reasoning sessions, running tests, and providing metadata
    about loaded KBs. It acts as the main interface for managing LE programs.
*/

:- module(le_kbs, [load/2, load/3, load_text/2, load_text/3, createSession/2, destroySession/1, note_session_use/1, start_session_reaper/0,
    addSessionFact/2, negateSessionFact/2, setScenarion/2, clearSession/1, printSession/1, query/5, queryScenario/4, queryScenario/6,
    runTestsFor/2, runTestsInDir/2, runTests/0, print_test_result/1, do_log/0, get_kb_metadata/2, is_system_predicate/1, ensure_kb_language/1, text_language/2,
    run_one_test/3, le_my_id/1, le_my_kb/1, kb_target_language/2, set_id_from_ref/2,
    set_kb_module/1, clear_kb_module/0,
    current_compiling_module/1, rule_counter/1,
    verify/1, edit/1, canonical_string/2, token_to_atom/2, item_to_instance/3, query_explain/5,
    topPredicates/2, kbSummary/2, kb_summary_safe/3, with_kb_reference/2, parse_custom_facts/3, parse_custom_query/3, is_a_hierarchy/2, fetch_resources/3,
    le_examples_dir/1, le_example_relpath/2, language_examples_dir/2, negation_words/1, user_rule_name/1]).

:- discontiguous process_section_acc/2.
:- discontiguous print_test_result/1.

:- meta_predicate set_id_from_ref(+, +).

:- use_module(le_grammar).
:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(le_i18n).
:- use_module(reasoner).
:- use_module(le_verifier, [verify/2, verify/3, find_in_body/2]).
:- use_module(library(uuid)).
:- use_module(library(pcre)).
:- use_module(library(www_browser)).
:- use_module(library(http/http_open)).

%!  le_examples_dir(-Dir:atom) is det.
%
%   Returns the base directory for Logical English examples.
le_examples_dir('examples/moreExamples').

%!  language_examples_dir(?Lang:atom, -Dir:atom) is nondet.
%
%   Dir is the per-language example tree examples/<Lang> (O-7 layout A) of a
%   registered non-English language, when that tree exists.
language_examples_dir(Lang, Dir) :-
    le_i18n:known_language(Lang),
    Lang \== en,
    atom_concat('examples/', Lang, Dir),
    exists_directory(Dir).

%!  le_example_relpath(+Name, -Path:atom) is det.
%
%   Resolves an example name as used by the web API/MCP — relative to the
%   examples directory, e.g. 'citizenship' or 'tax/vat' (no extension
%   handling) — to a repo-relative file path. A name whose first path
%   component is a registered non-English language code with an
%   examples/<Lang>/ tree resolves into that tree instead:
%   'pt/cidadania' -> 'examples/pt/cidadania'.
le_example_relpath(Name0, Path) :-
    ( atom(Name0) -> Name = Name0 ; atom_string(Name, Name0) ),
    (   sub_atom(Name, Before, _, _, '/'),
        sub_atom(Name, 0, Before, _, Lang),
        language_examples_dir(Lang, _)
    ->  atom_concat('examples/', Name, Path)
    ;   le_examples_dir(Dir),
        atomic_list_concat([Dir, '/', Name], Path)
    ).

:- (exists_file('le_extensions.pl') -> use_module('le_extensions') ; true).

%!  is_a_hierarchy(+KBmodule, -Hierarchy) is det.
%
%   Finds all is_a(Type, SuperType) relationships in the KB module and builds
%    a tree structure representing the type hierarchy.
is_a_hierarchy(KBmodule, Hierarchy) :-
    % 1. Collect all type atoms from the KB module
    findall(A, (
        KBmodule:clause(is_a(T, S), Body),
        (atom(T), A = T ; atom(S), A = S ; le_verifier:find_in_body(Body, is_a(_, A)), atom(A))
    ), AllAtoms0),
    sort(AllAtoms0, AllAtoms),
    % 2. Find all valid ISA relationships using the reasoner
    setup_call_cleanup(
        createSession(KBmodule, TempSession),
        findall(Sub-Type, (
            member(Sub, AllAtoms),
            member(Type, AllAtoms),
            Sub \== Type,
            once(reasoner:i(is_a(Sub, Type), TempSession, [], _))
        ), ValidISAs),
        destroySession(TempSession)
    ),
    % 3. Filter for direct edges (those with a source)
    findall(edge(Sub, Type, Start, End), (
        member(Sub-Type, ValidISAs),
        find_is_a_source(KBmodule, Sub, Type, Start, End),
        Start \== 0
    ), Edges),
    % 4. Build the tree
    findall(Root, (
        member(Root, AllAtoms),
        \+ member(edge(Root, _, _, _), Edges)
    ), Roots),
    maplist(build_hierarchy_node(KBmodule, Edges), Roots, Hierarchy).

% find_root_source(+KBmodule, +Root, -Start, -End)
% Finds the first mention of Root in an is_a clause.
find_root_source(KBmodule, Root, Start, End) :-
    (   setof(S-E, Body^Ref^ID^Other^(
            (KBmodule:clause(is_a(Root, Other), Body, Ref) ; KBmodule:clause(is_a(Other, Root), Body, Ref)),
            KBmodule:le_source_info(Ref, S, E, ID)
        ), [Start-End|_])
    ->  true
    ;   Start = 0, End = 0
    ).

% find_is_a_source(+KBmodule, +Type, +SuperType, -Start, -End)
% Tries to find the clause that defines Type as a SuperType.
find_is_a_source(KBmodule, Type, SuperType, Start, End) :-
    % Case 1: Direct fact is_a(Type, SuperType)
    (   KBmodule:clause(is_a(Type, SuperType), true, Ref)
    ->  KBmodule:le_source_info(Ref, Start, End, _)
    % Case 2: Rule is_a(X, SuperType) :- ... is_a(X, Type) ...
    ;   KBmodule:clause(is_a(X, SuperType), Body, Ref),
        contains_is_a_type(Body, X, Type)
    ->  KBmodule:le_source_info(Ref, Start, End, _)
    ;   Start = 0, End = 0
    ).

contains_is_a_type(Body, X, Type) :-
    le_verifier:find_in_body(Body, is_a(X1, Type)),
    X1 == X.

build_hierarchy_node(KBmodule, Edges, Type, _{type: Type, range: Range, children: Children}) :-
    (   member(edge(Type, _, Start, End), Edges), Start \== 0
    ->  Range = _{start: Start, end: End}
    ;   find_root_source(KBmodule, Type, S, E), S \== 0
    ->  Range = _{start: S, end: E}
    ;   Range = null
    ),
    findall(ChildType, member(edge(ChildType, Type, _, _), Edges), ChildTypes),
    sort(ChildTypes, UniqueChildTypes),
    maplist(build_hierarchy_node(KBmodule, Edges), UniqueChildTypes, Children).

% For friendlier messages
:- multifile prolog:message//1.
prolog:message(S-Args) --> {atomic(S),is_list(Args)}, !, [S-Args].
prolog:message(Msg) --> {string(Msg)}, !, [Msg].
prolog:message(Msg) --> {atom(Msg)}, !, [Msg].

%!  edit(+LEfilePath:atom) is det.
%
%   Fetches the LE file and opens the user browser to display/edit it.
edit(LEfilePath) :-
    read_file_to_string(LEfilePath, Text, []),
    www_form_encode(Text, Encoded),
    file_base_name(LEfilePath, FileName),
    www_form_encode(FileName, EncodedFileName),
    format(atom(URL), 'http://localhost:3050/editor/index.html?text=~w&filename=~w', [Encoded, EncodedFileName]),
    www_open_url(URL).

%!  do_log is det.
%
%   Dynamic predicate that controls whether debug messages are printed.
%!  current_compiling_module(-Module:atom) is semidet.
%
%   True if Module is the module currently being compiled.
:- dynamic do_log/0, current_compiling_module/1. % assert(do_log).
:- thread_local le_current_id/1, le_kb_module/1.

%!  rule_counter(-Count:integer) is det.
%
%   Gets or sets the current rule counter for generating IDs.
:- thread_local rule_counter/1.

%!  current_section(-Name:atom) is det.
%
%   The section that rules are currently being assigned to while processing a
%   knowledge base. Defaults to 'main' and is changed by section markers.
:- thread_local current_section/1.
% Include machinery state (per load): the base directory/URL of the file
% currently being included (for relative resource resolution), the include
% depth, and the set of canonical resource ids already loaded (cycle guard).
:- thread_local le_include_base/1, le_include_depth/1, le_include_seen/1.
% Cache of loaded Prolog resources: canonical id -> cache module + stamp
% (file modification time, or the atom url for one-per-server-run caching).
:- dynamic plres_cache/3.


%!  load(+FilePath:atom, -Module:atom) is det.
%
%   Loads a Logical English file from FilePath into a new generated Module.
load(FilePath, NewModule) :-
    load(FilePath, NewModule, []).

%!  load(+FilePath:atom, -Module:atom, +Options:list) is det.
%
%   As load/2. With Option skip_tests, verification does not run the KB's
%   embedded expected-answer tests (see le_verifier:verify/3) — for callers
%   like the example listings, which only need the KB loaded, not tested.
load(FilePath, NewModule, Options) :-
    (   var(NewModule) ->
        time_file(FilePath, Time),
        variant_sha1([FilePath, Time], Hash),
        atom_concat(m, Hash, NewModule)
    ;   true
    ),
    with_mutex(NewModule, load_sync(NewModule, FilePath, Options)).

load_sync(NewModule, FilePath, Options) :-
    absolute_file_name(FilePath, Abs),
    file_directory_name(Abs, Dir),
    setup_call_cleanup(
        ( retractall(le_include_base(_)), assertz(le_include_base(Dir)) ),
        load_common_sync(NewModule, parse_le_file(FilePath, doc(Sections), NewModule), Sections, "parse_le_file failed for ~w" - [FilePath], Options),
        retractall(le_include_base(_))).

%!  load_text(+Text:string, -Module:atom) is det.
%
%   Loads Logical English source text into a new generated Module.
load_text(Text, NewModule) :-
    load_text(Text, (-), NewModule).

%!  load_text(+Text, +Base, -NewModule) is det.
%
%   As load_text/2, but resolves relative include resources against Base (a
%   directory), so text loaded from the editor for a known example still finds
%   the example's sibling resources. Base = '-' keeps the default (cwd).
load_text(Text, Base, NewModule) :-
    (   var(NewModule) ->
        variant_sha1([Text, Base], Hash),
        atom_concat(m, Hash, NewModule)
    ;   true
    ),
    (   Base == (-)
    ->  with_mutex(NewModule, load_text_sync(NewModule, Text))
    ;   setup_call_cleanup(
            ( retractall(le_include_base(_)), assertz(le_include_base(Base)) ),
            with_mutex(NewModule, load_text_sync(NewModule, Text)),
            retractall(le_include_base(_)))
    ).

load_text_sync(NewModule, Text) :-
    load_common_sync(NewModule, parse_le_text(Text, doc(Sections), NewModule), Sections, "Parsing failed. Check for malformed sections or characters.", []).

load_common_sync(NewModule, ParseGoal, Sections, ErrorMsg, Options) :-
    (   current_module(NewModule),
        current_predicate(NewModule:le_source_info/4),
        % Already built and error-free: reuse it. (Checking for the *clause* — not
        % just the predicate, which is always declared dynamic — so a clean KB is
        % actually cached instead of being reparsed and re-verified every load.)
        \+ ( current_predicate(NewModule:le_issue/6), NewModule:le_issue(error, _, _, _, _, _) ),
        % A module verified with skip_tests lacks failed_test issues, so it only
        % satisfies loads that also skip them; a full load rebuilds it.
        (   memberchk(skip_tests, Options)
        ->  true
        ;   \+ current_predicate(NewModule:le_tests_skipped/0)
        )
    ->  true
    ;   % Ensure we start with a clean module
        forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
        NewModule:use_module(le_kbs),
        forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
        assertz(NewModule:le_kb_module_fact(NewModule)),
        retractall(rule_counter(_)),
        assertz(rule_counter(1)),
        (   setup_call_cleanup(
                asserta(current_compiling_module(NewModule)),
                ( catch(ParseGoal, EP, (print_message(error, EP), fail)),
                  collect_and_assert_types(NewModule) ),
                retractall(current_compiling_module(_))
            ) ->  
            forall(member(S, Sections), process_section(S, NewModule)),
            findall(D, le_system_template(D), SysDicts),
            forall(member(D, SysDicts), assertz(NewModule:le_dict(D))),
            (   memberchk(skip_tests, Options)
            ->  VerifyOptions = [skip_tests],
                assertz(NewModule:le_tests_skipped)
            ;   VerifyOptions = []
            ),
            (   catch(le_verifier:verify(NewModule, VerifyOptions, Issues), EV, (print_message(error, EV), Issues = [])) ->
                forall(member(issue(Type, Desc, Fix, Start, End), Issues), (
                    (Type == missing_template -> Severity = error; Severity = warning),
                    assertz(NewModule:le_issue(Severity, Type, Desc, Fix, Start, End))
                ))
            ;   true
            ),
            % Report ALL issues
            (   current_predicate(NewModule:le_issue/6)
            ->  forall(NewModule:le_issue(Severity, Type, Desc, _Fix, Start, End),
                       % A real format string consuming its args (the previous
                       % `Type - [Desc,Start,End]` used the Type atom as the format
                       % string, which threw "too many arguments"). Desc is an
                       % argument, so a literal ~ in it is not re-interpreted.
                       print_message(Severity, 'LE ~w: ~w (chars ~w-~w)' - [Type, Desc, Start, End]))
            ;   true
            )
        ;   % Parsing failed
            forall(current_predicate(NewModule:F/N), abolish(NewModule:F/N)),
            forall(is_system_predicate(F/N), dynamic(NewModule:F/N)),
            assertz(NewModule:le_issue(error, parse_error, ErrorMsg, "", 0, 0)),
            assertz(NewModule:le_source_info(none, 0, 0, none)),
            print_message(error, ErrorMsg)
        )
    ).

process_section(S, M) :-
    ( do_log -> print_message(informational,'Processing section: ~w' - [S]); true),
    retractall(rule_counter(_)),
    assertz(rule_counter(1)),
    retractall(current_section(_)),
    assertz(current_section(main)),
    (process_section_acc(S, M) -> true ; writeln(user_error, failed_section(S)), fail).

process_section_acc(kb(Name, Content, Start, End), M) :-
    assertz(M:le_kb(Name), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(scenario(Name, Content, Start, End), M) :-
    dynamic(M:le_expected/4),
    partition(is_expected_item, Content, ExpectedItems, FactItems),
    findall(D, M:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, AllTemplates),
    maplist(item_to_term_with_source(M, AllTemplates), FactItems, Terms),
    assertz(M:scenario(Name, Terms), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)),
    forall(member(expected(Q, A, U, S, E), ExpectedItems), (
        assertz(M:le_expected(Q, Name, A, U), ERef),
        assertz(M:le_source_info(ERef, S, E, Q))
    )).

process_section_acc(query(Name, Content, Start, End), M) :-
    findall(D, M:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, AllTemplates),
    maplist(item_to_term(AllTemplates, M), Content, Terms),
    list_to_conj(Terms, Goal),
    assertz(M:query_info(Name, Goal, Content), Ref),
    assertz(M:le_source_info(Ref, Start, End, Name)).



process_section_acc(ontology(Content, Start, End), M) :-
    assertz(M:ontology(Content), Ref),
    assertz(M:le_source_info(Ref, Start, End, ontology)),
    forall(member(Item, Content), process_item(Item, M)).

process_section_acc(resources(_, Resources, Start, End), M) :-
    forall(member(R, Resources), assertz(M:le_included_resource(R, Start, End))).

process_section_acc(predicates(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(templates(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(fluents(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(events(Dicts), M) :- forall(member(D, Dicts), assert_dict_with_source(D, M)).
process_section_acc(meta(Target), M) :-
    ( atom(Target) -> assertz(M:le_target_language(Target))
    ; forall(member(D, Target), assert_dict_with_source(D, M))
    ).

% A misplaced expectation (e.g. "query one expects answers [...]"): the syntactic
% error was already recorded by the grammar during parsing, so nothing more to do.
process_section_acc(misplaced_expectation(_Start, _End), _M).

process_section_acc(unknown_section(Tokens, Start, End), M) :-
    le_grammar:reconstruct_name(Tokens, FullName),
    ( atom_length(FullName, L), L > 100 -> sub_atom(FullName, 0, 100, _, Sub), atom_concat(Sub, '...', Name); Name = FullName),
    format(atom(Desc), "Unknown or malformed section starting with: ~w", [Name]),
    assertz(M:le_issue(error, unknown_section, Desc, Start, End)).

%!  fetch_resources(+Sections, -MergedSections, +M) is det.
%
%   Loads the resources named in a document's "includes these resources:"
%   section. .le resources (the default; the extension is implicit) merge
%   their templates/rules/ontology into the KB; resources named with an
%   explicit .pl extension are Prolog resources: their clauses are loaded
%   (assert-only, sandboxed — see load_prolog_resource/4) into a cache module
%   that reasoning sessions import.
%
%   Includes are transitive with a depth cap (prolog flag
%   le_include_max_depth, default 5), a cycle/duplicate guard on canonical
%   resource ids, and RELATIVE resolution against the including file's
%   directory or URL. This entry point initialises that state when it is the
%   top-level call of a load (nested calls arrive via parse_resource_text
%   with the state already set).
fetch_resources(Sections, MergedSections, M) :-
    (   member(resources(_, Resources, _, _), Sections)
    ->  (   le_include_depth(_)
        ->  fetch_all_resources(Resources, M, IncludedSections)      % nested
        ;   setup_call_cleanup(
                ( assertz(le_include_depth(0)),
                  retractall(le_include_seen(_)) ),
                fetch_all_resources(Resources, M, IncludedSections),
                ( retractall(le_include_depth(_)),
                  retractall(le_include_seen(_)) ))
        ),
        append(IncludedSections, Sections, MergedSections)
    ;   MergedSections = Sections
    ).

fetch_all_resources([], _, []).
fetch_all_resources([R|Rs], M, AllSections) :-
    fetch_resource(R, M, Sections),
    fetch_all_resources(Rs, M, RestSections),
    append(Sections, RestSections, AllSections).

include_max_depth(Max) :-
    ( current_prolog_flag(le_include_max_depth, Max0), integer(Max0) -> Max = Max0 ; Max = 5 ).

current_include_base(Base) :-
    ( le_include_base(Base0) -> Base = Base0
    ; working_directory(Base, Base) ).

fetch_resource(Resource, M, Sections) :-
    current_include_base(Base),
    resolve_resource(Resource, Base, Kind, Id),
    (   le_include_seen(Id)
    ->  Sections = []                       % already loaded (diamond or cycle)
    ;   le_include_depth(Depth),
        include_max_depth(Max),
        (   Depth >= Max
        ->  format(atom(Desc), "Include too deep (max ~w): ~w", [Max, Resource]),
            (nonvar(M) -> assertz(M:le_issue(error, include_too_deep, Desc, "Flatten the include chain, or raise the le_include_max_depth flag.", 0, 0)) ; true),
            Sections = []
        ;   assertz(le_include_seen(Id)),
            fetch_resource_kind(Kind, Id, Resource, M, Sections)
        )
    ).

%!  resolve_resource(+Resource, +Base, -Kind, -Id) is det.
%
%   Kind: le_url(URL) | le_file(AbsPath) | pl_url(URL) | pl_file(AbsPath).
%   Id is the canonical identity used for the seen-set and the .pl cache.
resolve_resource(Resource, Base, Kind, Id) :-
    (   is_url(Resource)
    ->  Full = Resource
    ;   is_url(Base)
    ->  uri_resolve(Resource, Base, Full)            % relative to including URL
    ;   absolute_file_name(Resource, Full, [relative_to(Base)])
    ),
    (   sub_atom(Full, _, 3, 0, '.pl')
    ->  ( is_url(Full) -> Kind = pl_url(Full) ; Kind = pl_file(Full) ),
        Id = Full
    ;   atom_concat(Full, '.le', WithExt),
        ( is_url(Full) -> Kind = le_url(WithExt) ; Kind = le_file(WithExt) ),
        Id = WithExt
    ).

is_url(A) :- atom(A), ( sub_atom(A, 0, _, _, 'http://') ; sub_atom(A, 0, _, _, 'https://') ), !.

% Local resources are restricted: a file may be included when it lives under
% the including file's own directory tree, or when it is a world-readable
% server file (under the working directory and not role-gated in
% restricted_paths). External URLs are unrestricted by design.
local_resource_allowed(Abs, Base) :-
    ( is_url(Base) -> working_directory(BaseDir, BaseDir) ; BaseDir = Base ),
    (   sub_atom(Abs, 0, _, _, BaseDir)
    ->  true
    ;   working_directory(CWD, CWD),
        sub_atom(Abs, 0, _, _, CWD),
        catch(restricted_paths:is_path_allowed(Abs, []), _, fail)
    ).

fetch_resource_kind(le_url(URL), _Id, Resource, M, Sections) :-
    catch(fetch_url(URL, Text), FetchErr, true),
    (   var(FetchErr)
    ->  include_resource_text(Text, URL, M, Sections),
        count_rules_and_templates(Sections, RuleCount, TemplateCount),
        assertz(M:le_resource_stats(Resource, RuleCount, TemplateCount))
    ;   fetch_error_desc(URL, FetchErr, Desc),
        (nonvar(M) -> assertz(M:le_issue(error, missing_resource, Desc, "", 0, 0)) ; true),
        Sections = []
    ).
fetch_resource_kind(le_file(File), _Id, Resource, M, Sections) :-
    current_include_base(Base),
    (   \+ local_resource_allowed(File, Base)
    ->  format(atom(Desc), "Resource path not allowed: ~w", [Resource]),
        (nonvar(M) -> assertz(M:le_issue(error, restricted_resource, Desc, "Local includes must live under the including file's directory or in a world-readable server path.", 0, 0)) ; true),
        Sections = []
    ;   exists_file(File)
    ->  read_file_to_string(File, Text, []),
        include_resource_text(Text, File, M, Sections),
        count_rules_and_templates(Sections, RuleCount, TemplateCount),
        assertz(M:le_resource_stats(Resource, RuleCount, TemplateCount))
    ;   format(atom(Desc), "Resource not found: ~w", [Resource]),
        (nonvar(M) -> assertz(M:le_issue(error, missing_resource, Desc, "", 0, 0)) ; true),
        Sections = []
    ).
fetch_resource_kind(pl_url(URL), Id, Resource, M, []) :-
    catch(fetch_url(URL, Text), FetchErr, true),
    (   var(FetchErr)
    ->  load_prolog_resource(Id, text(Text), M, Resource)
    ;   fetch_error_desc(URL, FetchErr, Desc),
        (nonvar(M) -> assertz(M:le_issue(error, missing_resource, Desc, "", 0, 0)) ; true)
    ).
fetch_resource_kind(pl_file(File), Id, Resource, M, []) :-
    current_include_base(Base),
    (   \+ local_resource_allowed(File, Base)
    ->  format(atom(Desc), "Resource path not allowed: ~w", [Resource]),
        (nonvar(M) -> assertz(M:le_issue(error, restricted_resource, Desc, "Local includes must live under the including file's directory or in a world-readable server path.", 0, 0)) ; true)
    ;   exists_file(File)
    ->  load_prolog_resource(Id, file(File), M, Resource)
    ;   format(atom(Desc), "Resource not found: ~w", [Resource]),
        (nonvar(M) -> assertz(M:le_issue(error, missing_resource, Desc, "", 0, 0)) ; true)
    ).

% Parse an included .le with the include state advanced: depth+1 and the base
% rebased to the included file's own location, so ITS relative includes
% resolve against it.
include_resource_text(Text, IdOrPath, M, Sections) :-
    ( is_url(IdOrPath) -> resource_base_of_url(IdOrPath, NewBase)
    ; file_directory_name(IdOrPath, NewBase) ),
    le_include_depth(Depth), Depth1 is Depth + 1,
    ( le_include_base(OldBase) -> true ; working_directory(OldBase, OldBase) ),
    setup_call_cleanup(
        ( retractall(le_include_base(_)), assertz(le_include_base(NewBase)),
          retractall(le_include_depth(_)), assertz(le_include_depth(Depth1)) ),
        parse_resource_text(Text, M, Sections),
        ( retractall(le_include_base(_)), assertz(le_include_base(OldBase)),
          retractall(le_include_depth(_)), assertz(le_include_depth(Depth)) )).

resource_base_of_url(URL, Base) :-
    ( sub_atom(URL, B, _, _, '/'), \+ (sub_atom(URL, B2, _, _, '/'), B2 > B)
    -> sub_atom(URL, 0, B, _, Base0), atom_concat(Base0, '/', Base)
    ;  Base = URL ).

%!  load_prolog_resource(+Id, +Source, +M, +ResourceName) is det.
%
%   Loads a .pl resource into a stable, content-addressed cache module
%   (plres_<hash of Id>) and records it in the KB as
%   le_prolog_resource(CacheModule, Id) so createSession/2 can import it into
%   reasoning sessions (where `prolog` bodies run).
%
%   Loading is ASSERT-ONLY, never consult: clause terms are asserted; the only
%   directives honoured are dynamic/1, discontiguous/1 and
%   use_module(library(Lib)) for atomic library names (system libraries are
%   trusted code; arbitrary file paths are not). A module/2 directive is
%   stripped with a warning — the clauses load into the cache module
%   regardless. Anything else (initialization/1, arbitrary goals, ...) is
%   skipped with a warning: a remote .pl must not execute code at load time.
%   Runtime safety is enforced separately: every `prolog` body goal passes
%   library(sandbox)'s safe_goal/1 in the reasoner.
%
%   Caching: a file resource reloads when its modification time changes; a
%   URL resource is fetched once per server run.
load_prolog_resource(Id, Source, M, ResourceName) :-
    variant_sha1(Id, Hash),
    atom_concat(plres_, Hash, Cache),
    resource_stamp(Source, Stamp),
    (   plres_cache(Id, Cache, Stamp)
    ->  Loaded = cached
    ;   forall(current_predicate(Cache:F/A), abolish(Cache:F/A)),
        retractall(plres_cache(Id, _, _)),
        (   catch(load_pl_source(Source, Cache, M, Counts), LoadErr,
                  ( term_string(LoadErr, ES),
                    format(atom(Desc), "Error loading Prolog resource ~w: ~w", [ResourceName, ES]),
                    (nonvar(M) -> assertz(M:le_issue(error, missing_resource, Desc, "", 0, 0)) ; true),
                    fail ))
        ->  assertz(plres_cache(Id, Cache, Stamp)),
            Loaded = Counts
        ;   Loaded = failed
        )
    ),
    (   Loaded == failed
    ->  true
    ;   ( current_predicate(M:le_prolog_resource/2), M:le_prolog_resource(Cache, Id) -> true
        ; assertz(M:le_prolog_resource(Cache, Id)) ),
        (   Loaded = counts(Facts, Rules)
        ->  assertz(M:le_resource_stats(ResourceName, Rules, Facts))
        ;   assertz(M:le_resource_stats(ResourceName, cached, cached))
        )
    ).

resource_stamp(file(File), mtime(T)) :- !, time_file(File, T).
resource_stamp(text(_), url).

load_pl_source(file(File), Cache, M, Counts) :- !,
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       load_pl_stream(In, Cache, M, 0-0, Counts),
                       close(In)).
load_pl_source(text(Text), Cache, M, Counts) :-
    setup_call_cleanup(open_string(Text, In),
                       load_pl_stream(In, Cache, M, 0-0, Counts),
                       close(In)).

load_pl_stream(In, Cache, M, F0-R0, Counts) :-
    read_term(In, Term, [module(Cache)]),
    (   Term == end_of_file
    ->  Counts = counts(F0, R0)
    ;   Term = (:- Directive)
    ->  handle_pl_directive(Directive, Cache, M),
        load_pl_stream(In, Cache, M, F0-R0, Counts)
    ;   Term = (_ :- _)
    ->  assertz(Cache:Term),
        R1 is R0 + 1,
        load_pl_stream(In, Cache, M, F0-R1, Counts)
    ;   assertz(Cache:Term),
        F1 is F0 + 1,
        load_pl_stream(In, Cache, M, F1-R0, Counts)
    ).

handle_pl_directive(dynamic(Spec), Cache, _M) :- !, Cache:dynamic(Spec).
handle_pl_directive(discontiguous(Spec), Cache, _M) :- !, Cache:discontiguous(Spec).
handle_pl_directive(module(Name, _Exports), _Cache, M) :- !,
    format(atom(Desc), "module directive (:- module(~w, ...)) in a Prolog resource is stripped: the clauses load into the resource's cache module", [Name]),
    (nonvar(M) -> assertz(M:le_issue(warning, module_directive_stripped, Desc, "Remove the module directive, or ignore this warning.", 0, 0)) ; true).
handle_pl_directive(use_module(library(Lib)), Cache, M) :- atom(Lib), !,
    catch(Cache:use_module(library(Lib)), E,
          ( term_string(E, ES),
            format(atom(Desc), "use_module(library(~w)) failed: ~w", [Lib, ES]),
            (nonvar(M) -> assertz(M:le_issue(warning, skipped_directive, Desc, "", 0, 0)) ; true) )).
handle_pl_directive(D, _Cache, M) :-
    format(atom(Desc), "Directive skipped in Prolog resource (not on the safe whitelist): :- ~w", [D]),
    (nonvar(M) -> assertz(M:le_issue(warning, skipped_directive, Desc, "Only dynamic, discontiguous and use_module(library(...)) run at load time.", 0, 0)) ; true).

count_rules_and_templates(Sections, RuleCount, TemplateCount) :-
    findall(1, (member(kb(_, Content, _, _), Sections), member(rule(_,_,_,_,_,_), Content)), Rules),
    length(Rules, RuleCount),
    findall(1, (member(S, Sections), (S = templates(Dicts) ; S = predicates(Dicts)), member(_, Dicts)), Templates),
    length(Templates, TemplateCount).

parse_resource_text(Text, M, FilteredMergedSections) :-
    tokenizer:tokenize_lang(Text, Tokens),
    (   phrase(le_grammar:doc(Sections), Tokens)
    ->  fetch_resources(Sections, MergedSections, M),
        exclude(is_scenario_or_query, MergedSections, FilteredMergedSections)
    ;   FilteredMergedSections = []
    ).

is_scenario_or_query(scenario(_, _, _, _)).
is_scenario_or_query(query(_, _, _, _)).

fetch_error_desc(URL, Err, Desc) :-
    term_string(Err, ES),
    format(atom(Desc), "Failed to fetch URL ~w: ~w", [URL, ES]).

fetch_url(URL, Text) :-
    setup_call_cleanup(
        http_open(URL, In, []),
        read_string(In, _, Text),
        close(In)
    ).

assert_dict_with_source(dict(FA, NTs, WV, Start, End, Globals, Opposite, Prep, Unknown), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, Globals, Opposite, Prep, Unknown)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)),
    (   Unknown == unknown ->
        Goal =.. FA,
        assertz(M:le_unknown(Goal), URef),
        assertz(M:le_source_info(URef, Start, End, template_unknown))
    ;   true
    ).
assert_dict_with_source(dict(FA, NTs, WV, Start, End, Globals, Opposite, Prep), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, Globals, Opposite, Prep, _)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)).
assert_dict_with_source(dict(FA, NTs, WV, Start, End, Globals, Opposite), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, Globals, Opposite, _, _)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)).
assert_dict_with_source(dict(FA, NTs, WV, Start, End, Globals), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, Globals, _, _, _)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)).
assert_dict_with_source(dict(FA, NTs, WV, Start, End), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, [], _, _, _)), Ref),
    assertz(M:le_source_info(Ref, Start, End, template)).
assert_dict_with_source(dict(FA, NTs, WV), M) :-
    assertz(M:le_dict(dict(FA, NTs, WV, [], _, _, _))).

% A section marker switches the section that subsequent rules are recorded under.
process_item(section_marker(Name, _Start, _End), _M) :-
    retractall(current_section(_)),
    assertz(current_section(Name)).

process_item(clause(Head, _Body, _Start, _End, _ID), _M) :-
    functor(Head, F, N),
    is_builtin_functor(F, N), !,
    % Cannot define clauses for a Prolog built-in head (true/0, false/0, ...).
    ( do_log -> print_message(informational, 'Skipping clause with built-in head ~w' - [Head]); true).
process_item(clause(Head, Body, Start, End, ID), M) :-
    ( var(ID) ->
        format(atom(ActualID), 'rule_~w', [Start])
    ; ActualID = ID
    ),
    ( Body == true -> Clause = Head; Clause = (Head :- Body)),
    functor(Head, F, N),
    dynamic(M:F/N),
    ( current_section(Section) -> true ; Section = main ),
    ( clause(M:Head, Body) -> true
    ; assertz(M:Clause, Ref),
      assertz(M:le_source_info(Ref, Start, End, ActualID)),
      assertz(M:le_source_section(Section, ActualID))
    ).

%!  le_my_id(-ID:atom) is det.
%
%   Gets the current Logical English rule or fact ID.
le_my_id(ID) :-
    le_current_id(ID).

%!  le_my_kb(-KB:atom) is det.
%
%   Gets the current Logical English KB module.
le_my_kb(KB) :-
    ( le_kb_module(K), K \== none -> KB = K
    ; current_predicate(le_kb_module_fact/1) -> le_kb_module_fact(KB)
    ; context_module(KB)
    ).

%!  kb_target_language(+Module:atom, -Target:atom) is det.
%
%   The execution backend a KB/session module declared via its target-language
%   opener line (an atom from le_grammar:le_allowed_target/1). Defaults to
%   `prolog` when the program declares nothing.
kb_target_language(Module, Target) :-
    ( catch(Module:le_target_language(T), _, fail) -> Target = T
    ; Target = prolog
    ).

%!  set_kb_module(+KB:atom) is det.
%
%   Sets the current Logical English KB module.
set_kb_module(KB) :-
    retractall(le_kb_module(_)),
    assertz(le_kb_module(KB)).

%!  clear_kb_module is det.
%
%   Clears the current Logical English KB module.
clear_kb_module :-
    retractall(le_kb_module(_)).

%!  set_id_from_ref(+Ref:reference, +M:atom) is det.
%
%   Sets the current LE ID based on a clause reference in module M.
set_id_from_ref(Ref, M) :-
    ( M:le_source_info(Ref, _, _, ID) -> retractall(le_current_id(_)), assertz(le_current_id(ID)) ; true ).


%!  createSession(+KBmodule:atom, -SessionModule:atom) is det.
%
%   Creates a new reasoning session module for the given KB module.
createSession(KBmodule, SessionModule) :-
    ensure_kb_language(KBmodule),
    uuid(UUID),
    atom_concat(s, UUID, SessionModule),
    % Use add_import_module to make all exported predicates of le_kbs 
    % available in the session module. This is more robust for dynamic modules.
    add_import_module(SessionModule, le_kbs, start),
    dynamic(SessionModule:le_kb_module_fact/1),
    dynamic(SessionModule:debug_mode/0),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source_info/4),
    % Register the KB reference and the in-use timestamp atomically under the
    % same mutex the reaper uses, so maybe_destroy_kb/1 reliably sees this new
    % session as a live reference and will not reclaim a shared KB module out
    % from under a session that is still being created.
    % Prolog resources included by the KB become visible to `prolog` bodies
    % (which the reasoner runs as SessionModule:call/1) via import links.
    (   current_predicate(KBmodule:le_prolog_resource/2)
    ->  forall(KBmodule:le_prolog_resource(Cache, _),
               add_import_module(SessionModule, Cache, end))
    ;   true
    ),
    get_time(Now),
    with_mutex(le_sessions, (
        assertz(SessionModule:le_kb_module_fact(KBmodule)),
        retractall(session_last_used(SessionModule, _)),
        assertz(session_last_used(SessionModule, Now))
    )).

%!  addSessionFact(+SessionModule:atom, +Fact:term) is det.
%
%   Adds a fact to the reasoning session. Fact can be a term or
%   fact_with_source(Term, Start, End).
addSessionFact(_SessionModule, Fact) :-
    ( Fact = fact_with_source(ActualFact, _, _) -> true; ActualFact = Fact ),
    fact_head(ActualFact, Head),
    functor(Head, F, N),
    is_builtin_functor(F, N), !,
    % Facts whose functor is a Prolog built-in (true/0, false/0, fail/0, ...)
    % cannot be asserted (static procedure), and need not be: the reasoner
    % handles such goals directly. Skip instead of raising a permission error.
    ( do_log -> print_message(informational, 'Skipping built-in session fact ~w (handled directly by the reasoner)' - [ActualFact]); true).
addSessionFact(SessionModule, Fact) :-
    ( Fact = fact_with_source(ActualFact, Start, End) -> true; ActualFact = Fact, Start = 0, End = 0),
    ( do_log -> print_message(informational, 'Adding session fact: ~w' - [ActualFact]); true),
    % A scenario element may be a plain fact OR a rule (Head :- Body); use the
    % head's predicate for the dynamic declaration / duplicate check.
    fact_head(ActualFact, Head),
    functor(Head, F, N),
    SessionModule:dynamic(F/N),
    (   % Collapse duplicate plain facts (not rules) that are variants.
        ActualFact \= (_ :- _),
        current_predicate(SessionModule:F/N), functor(Template, F, N), SessionModule:clause(Template, true),
        copy_term(Template, ECopy), copy_term(ActualFact, ACopy), numbervars(ECopy, 0, _), numbervars(ACopy, 0, _), ECopy == ACopy ->
            ( do_log -> print_message(informational, 'Fact already exists (variant): ~w' - [ActualFact]); true)
        ; assertz(SessionModule:ActualFact, Ref),
          assertz(SessionModule:sessionClause(Ref)),
          ( Start \== 0 -> assertz(SessionModule:le_source_info(Ref, Start, End, session_fact)); true)
    ).

% fact_head(+FactOrRule, -Head): the head predicate term of a session element.
fact_head((Head :- _Body), Head) :- !.
fact_head(Head, Head).

%!  is_builtin_functor(+F:atom, +N:integer) is semidet.
%
%   True when F/N names a Prolog built-in (e.g. true/0, false/0, fail/0). Such
%   predicates are static and cannot be declared dynamic or asserted into.
is_builtin_functor(F, N) :-
    functor(G, F, N),
    catch(predicate_property(G, built_in), _, fail).

%!  negateSessionFact(+SessionModule:atom, +Fact:term) is det.
%
%   Negates a fact in the reasoning session.
negateSessionFact(SessionModule, Fact) :-
    forall(clause(SessionModule:Fact, _, Ref),
           (erase(Ref), retractall(SessionModule:sessionClause(Ref)))),
    assertz(SessionModule:le_neg(Fact), NewRef),
    assertz(SessionModule:sessionClause(NewRef)).

%!  setScenarion(+SessionModule:atom, +ScenarioName:atom) is det.
%
%   Loads facts from a named scenario into the reasoning session.
setScenarion(SessionModule, ScenarioName) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( current_predicate(KBmodule:scenario/2) -> 
        (   KBmodule:scenario(ScenarioName, Facts) -> true
        ;   atom(ScenarioName), atom_number(ScenarioName, Num), KBmodule:scenario(Num, Facts) -> true
        ;   fail
        ),
        forall(member(Fact, Facts), addSessionFact(SessionModule, Fact))
    ; fail).

%!  clearSession(+SessionModule:atom) is det.
%
%   Clears all facts and state from a reasoning session.
clearSession(SessionModule) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true; KBmodule = none),
    forall(current_predicate(SessionModule:F/N), abolish(SessionModule:F/N)),
    ( KBmodule \== none -> 
        dynamic(SessionModule:le_kb_module_fact/1),
        assertz(SessionModule:le_kb_module_fact(KBmodule))
    ; true),
    dynamic(SessionModule:le_neg/1),
    dynamic(SessionModule:debug_mode/0),
    dynamic(SessionModule:sessionClause/1),
    dynamic(SessionModule:le_source_info/4).

% --- Session lifecycle / garbage collection ---------------------------------
%
% Every session created by createSession/2 is a fresh module that holds dynamic
% clauses (session facts, le_source_info, ...) and an import of le_kbs. Nothing
% reclaimed them, so modules accumulated on every load/query. We now track each
% session's last-use time and reclaim it, either explicitly (single-use internal
% sessions) or via an idle reaper (client sessions that are abandoned when the
% editor reloads or the tab is closed).

:- dynamic session_last_used/2.   % SessionModule, EpochSeconds

session_max_idle(1800).           % reap client sessions idle for > 30 min
session_reaper_interval(300).     % check every 5 min

%!  note_session_use(+SessionModule:atom) is det.
%
%   Records that a session is in use now, protecting it from the idle reaper.
note_session_use(SessionModule) :-
    get_time(Now),
    with_mutex(le_sessions, (
        retractall(session_last_used(SessionModule, _)),
        assertz(session_last_used(SessionModule, Now))
    )).

%!  destroySession(+SessionModule:atom) is det.
%
%   Frees all memory held by a reasoning session module: abolishes its dynamic
%   predicates (their clauses), drops the le_kbs import and forgets it.
destroySession(SessionModule) :-
    with_mutex(le_sessions, retractall(session_last_used(SessionModule, _))),
    (   atom(SessionModule), current_module(SessionModule)
    ->  forall(current_predicate(SessionModule:F/N),
               catch(abolish(SessionModule:F/N), _, true)),
        catch(delete_import_module(SessionModule, le_kbs), _, true)
    ;   true
    ).

% A KB module is generated (and therefore reclaimable) when it records itself as
% its own KB module; session modules instead point at a *different* KB module.
is_generated_kb_module(M) :-
    atom(M), current_module(M),
    current_predicate(M:le_kb_module_fact/1),
    catch(M:le_kb_module_fact(M), _, fail).

%!  maybe_destroy_kb(+KBmodule:atom) is det.
%
%   Reclaims a generated KB module once no live session references it. The
%   liveness check and the abolish run under the le_sessions mutex so a session
%   being registered concurrently (createSession asserts le_kb_module_fact and
%   then note_session_use) is reliably seen as a live reference, and the abolish
%   cannot interleave with a registry update. A module held by a sessionless
%   reader (with_kb_reference/2, e.g. the example listings summarizing every KB)
%   is likewise left intact — abolishing it mid-read made the reader crash with
%   existence_error(le_dict/1).
maybe_destroy_kb(KBmodule) :-
    with_mutex(le_sessions, (
        (   is_generated_kb_module(KBmodule),
            \+ kb_module_in_use(KBmodule),
            \+ ( session_last_used(SM, _),
                 SM \== KBmodule,
                 catch(SM:le_kb_module_fact(KBmodule), _, fail) )
        ->  forall(current_predicate(KBmodule:F/N),
                   catch(abolish(KBmodule:F/N), _, true))
        ;   true
        )
    )).

% One fact per active reader of a KB module (duplicates act as a ref-count);
% guarded by the le_sessions mutex, the same one maybe_destroy_kb reclaims under.
:- dynamic kb_module_in_use/1.

%!  with_kb_reference(+KB:atom, :Goal) is semidet.
%
%   Runs Goal while holding a liveness reference on KB, so maybe_destroy_kb/1
%   cannot reclaim (abolish) the module mid-Goal. For readers that inspect a KB
%   module without owning a session — e.g. kbSummary over every example — whose
%   modules are otherwise reclaimable the moment any concurrent request tears
%   down a session that shared them.
:- meta_predicate with_kb_reference(+, 0).
with_kb_reference(KB, Goal) :-
    setup_call_cleanup(
        with_mutex(le_sessions, assertz(kb_module_in_use(KB))),
        Goal,
        with_mutex(le_sessions, once(retract(kb_module_in_use(KB))))
    ).

%!  kb_summary_safe(+Path:atom, +Options:list, -Summary) is semidet.
%
%   load/3 + kbSummary/2, reclaim-safe and cached: the summary runs under
%   with_kb_reference/2 (with a retry, because the module can still be
%   reclaimed in the gap between load/3 returning and the reference being
%   registered — the next load/3 rebuilds it), and the result is cached by the
%   file's modification time. Bulk listings (landing page, MCP, REST) request
%   every example's summary and each one costs a full KB load, while the result
%   only changes when the file does; the compute runs under a mutex so two
%   concurrent listings do the expensive pass ONCE between them (the second
%   gets cache hits) instead of doubling the load on the shared server. Fails —
%   never throws — when the KB cannot be loaded or summarized (also cached, so
%   a broken example is not re-parsed on every listing), letting callers
%   degrade per example instead of failing the whole request.
kb_summary_safe(Path, Options, Summary) :-
    catch(absolute_file_name(Path, Abs), _, fail),
    catch(time_file(Abs, Time), _, fail),
    (   kb_summary_cache(Abs, Time, Cached)
    ->  Cached \== failed, Summary = Cached
    ;   with_mutex(kb_summary_cache,
            (   kb_summary_cache(Abs, Time, Cached2)   % filled while we waited
            ->  Result = Cached2
            ;   ( kb_summary_compute(Path, Options, Summary0)
                -> Result = Summary0 ; Result = failed ),
                retractall(kb_summary_cache(Abs, _, _)),
                assertz(kb_summary_cache(Abs, Time, Result))
            )),
        Result \== failed,
        Summary = Result
    ).

% Cached summaries keyed by absolute path + modification time (cf. plres_cache).
:- dynamic kb_summary_cache/3.

kb_summary_compute(Path, Options, Summary) :-
    between(1, 3, _),
    catch(load(Path, KB, Options), _, fail),
    (   catch(with_kb_reference(KB, kbSummary(KB, Summary0)), _, fail)
    ->  !, Summary = Summary0
    ;   fail
    ).

%!  reap_idle_sessions is det.
%
%   Destroys sessions (and their now-orphaned KB modules) idle beyond the limit.
reap_idle_sessions :-
    get_time(Now),
    session_max_idle(MaxIdle),
    findall(SM, (session_last_used(SM, T), Now - T > MaxIdle), Candidates),
    forall(member(SM, Candidates), maybe_reap_session(SM, Now, MaxIdle)).

%!  maybe_reap_session(+SM:atom, +Now:number, +MaxIdle:number) is det.
%
%   Reaps a single candidate session, but only after atomically re-confirming
%   under the le_sessions mutex that it is still idle and claiming it (removing
%   its registry entry). This closes the time-of-check/time-of-use race against
%   note_session_use/1: a request that touches SM after the stale snapshot but
%   before reaping refreshes the timestamp, so the re-check fails and the live
%   session (and the shared KB module it references) is left intact.
maybe_reap_session(SM, Now, MaxIdle) :-
    (   with_mutex(le_sessions, (
            session_last_used(SM, T),
            Now - T > MaxIdle,
            retractall(session_last_used(SM, _))
        ))
    ->  ( catch(SM:le_kb_module_fact(KB), _, fail) -> true ; KB = none ),
        destroySession(SM),
        ( KB \== none, KB \== SM -> maybe_destroy_kb(KB) ; true )
    ;   true   % refreshed by a concurrent request since the snapshot — keep it
    ).

:- dynamic session_reaper_running/0.

%!  start_session_reaper is det.
%
%   Starts (once) a background thread that periodically reaps idle sessions.
start_session_reaper :-
    ( session_reaper_running -> true
    ; assertz(session_reaper_running),
      catch(thread_create(session_reaper_loop, _,
                          [alias(le_session_reaper), detached(true)]),
            _, true)
    ).

session_reaper_loop :-
    session_reaper_interval(Interval),
    sleep(Interval),
    catch(reap_idle_sessions, E, print_message(warning, E)),
    session_reaper_loop.

%!  printSession(+SessionModule:atom) is det.
%
%   Prints the current state of a reasoning session.
printSession(SessionModule) :-
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( KBmodule \== none -> KBmodule:le_kb(KBName) ; KBName = unknown ),
    format('Session: ~w~nKB: ~w (~w)~nFacts:~n', [SessionModule, KBName, KBmodule]),
    forall((SessionModule:sessionClause(Ref), clause(H, B, Ref)),
           (H \= sessionClause(_), format('  ~w :- ~w~n', [H, B]))).

%!  query(+SessionModule:atom, +Template:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is det.
%
%   Executes a query against a reasoning session. Template can be a list of tokens,
%   a string, a named query, or an already-parsed compound goal (e.g. produced by
%   parse_custom_query/3 for the editor's custom-query field).
query(SessionModule, Goal, TemplateInstance, Unknowns, Why) :-
    compound(Goal), \+ is_list(Goal), !,
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( do_log -> print_message(informational, 'Executing compound query goal: ~w' - [Goal]); true),
    reasoner:i(Goal, SessionModule, Unknowns, Why0),
    ( (KBmodule \== none, item_to_instance(KBmodule, Goal, Tokens)) -> TemplateInstance = Tokens ; TemplateInstance = [Goal] ),
    postprocess_why(Why0, SessionModule, Why).
query(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    ( do_log -> print_message(informational, 'Querying KB ~w in session ~w with tokens ~w' - [KBmodule, SessionModule, Tokens]); true),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), (KBmodule:query_info(QueryName, Goal, Items) ; (atom(QueryName), atom_number(QueryName, Num), KBmodule:query_info(Num, Goal, Items)))) ->  
            ( do_log -> print_message(informational, 'Executing named query ~w: ~w' - [QueryName, Goal]); true),
            reasoner:i(Goal, SessionModule, Unknowns, Why0),
            ( do_log -> print_message(informational, 'Named query solution found for ~w' - [QueryName]); true),
            maplist(item_to_instance(KBmodule), Items, Instances),
            flatten(Instances, TemplateInstance),
            postprocess_why(Why0, SessionModule, Why)
        ; ( do_log -> print_message(informational, 'Parsing free-text query tokens: ~w' - [Tokens]); true),
            (   parse_query_to_goal(KBmodule, Tokens, Goal, TemplateInstance) ->
                ( do_log -> print_message(informational, 'Executing query goal: ~w' - [Goal]); true),
                reasoner:i(Goal, SessionModule, Unknowns, Why0),
                ( do_log -> print_message(informational, 'Query goal solution found: ~w' - [Goal]); true),
                postprocess_why(Why0, SessionModule, Why)
            ;   format(string(Error), "Query does not match any template: ~w", [Template]),
                throw(error(le_parse_error(Error), _))
            )
    ).

%!  parse_query_to_goal(+KBmodule:atom, +Tokens:list, -Goal:term, -Instance:list) is nondet.
%
%   Parses free-text query Tokens into a Goal using the chaining-aware literal
%   parser, folding any prepositional (extra) goals into a conjunction — exactly
%   as queries are parsed at load time (see second_pass_query_item/4) and by
%   parse_custom_query/3. Without this, a query with prepositional additions
%   (e.g. "we will make which payment under this policy in respect of this claim")
%   would only match a single prepositional fragment, yielding bogus answers and
%   results inconsistent with the named-query / editor paths.
parse_query_to_goal(KBmodule, Tokens, Goal, Instance) :-
    findall(D, KBmodule:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    le_grammar:parse_literal(Tokens, Templates, [], VMOut, Literal, Instance, true),
    le_grammar:collect_extra_goals(VMOut, ExtraGoals),
    ( ExtraGoals == [] -> Goal = Literal ; le_grammar:list_to_conj([Literal | ExtraGoals], Goal) ).

%!  query_explain(+SessionModule:atom, +Goal:term, -TemplateInstance:list, -Unknowns:list, -Why:term) is det.
%
%   Executes a query and returns a detailed explanation.
query_explain(SessionModule, Goal, TemplateInstance, Unknowns, Why) :-
    compound(Goal), \+ is_list(Goal), !,
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    reasoner:explain(Goal, SessionModule, Unknowns, Why0),
    ( (KBmodule \== none, item_to_instance(KBmodule, Goal, _Tokens)) -> true ; TemplateInstance = [Goal] ),
    postprocess_why(Why0, SessionModule, Why).
query_explain(SessionModule, Template, TemplateInstance, Unknowns, Why) :-
    ensure_tokens(Template, Tokens),
    ( SessionModule:le_kb_module_fact(KBmodule) -> true ; KBmodule = none ),
    (   ((atom(Template) ; string(Template)), atom_string(QueryName, Template), current_predicate(KBmodule:query_info/3), (KBmodule:query_info(QueryName, Goal, Items) ; (atom(QueryName), atom_number(QueryName, Num), KBmodule:query_info(Num, Goal, Items)))) ->  
            ( do_log -> print_message(informational, 'Executing named query explain ~w: ~w' - [QueryName, Goal]); true),
            reasoner:explain(Goal, SessionModule, Unknowns, Why0),
            ( (maplist(item_to_instance(KBmodule), Items, Instances), flatten(Instances, TemplateInstance)) -> true; TemplateInstance = []),
            postprocess_why(Why0, SessionModule, Why)
        ;   (   parse_query_to_goal(KBmodule, Tokens, Goal, TemplateInstance) ->
                    ( do_log -> print_message(informational, 'Executing query goal explain: ~w' - [Goal]); true),
                    reasoner:explain(Goal, SessionModule, Unknowns, Why0),
                    postprocess_why(Why0, SessionModule, Why)
                ;   format(string(Error), "Query does not match any template: ~w", [Template]),
                    throw(error(le_parse_error(Error), _))
            )
    ).

postprocess_why(repeated_group(N, Why), SM, Out) :- !,
    postprocess_why(Why, SM, WhyOut),
    ( WhyOut == omitted -> Out = omitted ; Out = repeated_group(N, WhyOut) ).
% A successful type guard (le_type_check, rendered "X is a Y") is kept in the
% explanation only when it actually says something: the type membership is
% derivable from is_a facts, or the user explicitly assumed it. The guard is
% lenient — it also succeeds when nothing at all is known about X's type — and
% in that case reporting "X is a Y" as true would be unfounded, so the node is
% omitted (the parent drops it via postprocess_why_children/3).
postprocess_why(success(Goal0, _Ref, _Children), SM, omitted) :-
    ( Goal0 = le_at(G, _, _) -> true ; G = Goal0 ),
    G = le_type_check(Arg, Type),
    \+ is_session_assumption(SM, G),
    \+ type_check_founded(SM, Arg, Type),
    !.
postprocess_why(success(Goal0, Ref, Children), SM, success(Goal, Range, LE, ChildrenOut)) :- !,
    ( Goal0 = le_at(Goal, _, _) -> true; Goal = Goal0),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( (SM:le_source_info(Ref, Start, End, _); (KB \== none, KB:le_source_info(Ref, Start, End, _))) -> Range0 = range(Start, End); Range0 = Ref),
    ( (KB \== none, item_to_instance_ranged(KB, Goal, Range0, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    % A condition the user explicitly assumed in THIS scenario ("it is unknown
    % whether …", e.g. the Assume checkbox) is shown as an assumption (unknown /
    % yellow) EVEN when it was independently provable — reflecting the "consider this
    % unknown" intent. Display-only: the actual answers and unknowns list (from i/4)
    % are unchanged, so KB-level unknowns and the "definite proof wins" rule still hold.
    ( is_session_assumption(SM, Goal)
    -> ( Range0 = range(RS, RE) -> Range = unknown(RS, RE) ; Range = unknown )
    ;  Range = Range0
    ),
    postprocess_why_children(SM, Children, ChildrenOut).
postprocess_why(failed_rule(Ref, Children), SM, failure(rule_attempt(Ref), Range, LE, ChildrenOut)) :- !,
    % An intermediate "failed rule" node (detailed failure explanations): label it
    % with the rule's head and point its range at the whole rule for navigation.
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( ( SM:le_source_info(Ref, Start, End, RuleID0)
      ; (KB \== none, KB:le_source_info(Ref, Start, End, RuleID0)) )
    -> Range = range(Start, End), RuleID = RuleID0
    ;  Range = none, RuleID = '' ),
    ( user_rule_name(RuleID) -> format(atom(LE), 'rule ~w', [RuleID])
    ; rule_head_text(Ref, SM, KB, HeadStr) -> format(atom(LE), 'rule: ~w', [HeadStr])
    ; RuleID \== '' -> format(atom(LE), 'rule ~w', [RuleID])
    ; LE = "failed rule" ),
    postprocess_why_children(SM, Children, ChildrenOut).
postprocess_why(failure(Goal0, Children), SM, failure(Goal, Range, LE, ChildrenOut)) :- !,
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( Goal0 = le_at(Goal, Start, End) -> Range = range(Start, End)
    ; Goal = Goal0, ( find_first_range(Goal, SM, KB, Range) -> true ; Range = none )
    ),
    ( (KB \== none, item_to_instance_ranged(KB, Goal, Range, Tokens)) -> canonical_string(Tokens, LE); term_string(Goal, LE)),
    postprocess_why_children(SM, Children, ChildrenOut).
postprocess_why(Whys, SM, WhysOut) :-
    is_list(Whys), !,
    postprocess_why_children(SM, Whys, WhysOut).
postprocess_why(Other, _, Other).

% Postprocess a sibling list, dropping the nodes postprocessing omitted.
postprocess_why_children(SM, Children, ChildrenOut) :-
    maplist(postprocess_why_child(SM), Children, ChildrenOut0),
    exclude(==(omitted), ChildrenOut0, ChildrenOut).

%!  type_check_founded(+SM, +Arg, +Type) is semidet.
%
%   The type membership tested by a le_type_check guard is actually derivable:
%   Arg is bound and is_a facts (in the session or its KB module) establish that
%   it is of Type.
type_check_founded(SM, Arg, Type) :-
    nonvar(Arg),
    ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
    catch(reasoner:type_compatible(Arg, Type, SM, KB), _, fail).

% A user-given rule name (from "rule <name>:"), as opposed to an auto-generated
% 'rule_<pos>' id.
user_rule_name(RuleID) :- atom(RuleID), RuleID \== '', \+ atom_concat('rule_', _, RuleID).

%!  aggregate_render_words(+Op, -Words) is det.
%
%   The words rendered between an aggregate's result and element variables:
%   "is the <op> of each" in English, from the aggregate lexicon keys.
aggregate_render_words(Op, Words) :-
    ( le_i18n:kw_main_words(is_the, IsThe) -> true ; IsThe = [is, the] ),
    ( le_i18n:kw_main_words(Op, OpWords) -> true ; OpWords = [Op] ),
    ( le_i18n:kw_main_words(of_each, OfEach) -> true ; OfEach = [of, each] ),
    append([IsThe, OpWords, OfEach], Words).

forall_render_words(Words) :-
    ( le_i18n:kw_main_words(forall, Words) -> true
    ; Words = [for, all, cases, in, which] ).

it_the_case_render_words(Words) :-
    ( le_i18n:kw_main_words(it_the_case, Words) -> true
    ; Words = [it, is, the, case, that] ).

and_render_word(W) :-
    ( le_i18n:kw_main_words(and, [W]) -> true ; W = and ).

or_render_word(W) :-
    ( le_i18n:kw_main_words(or, [W]) -> true ; W = or ).

copula_render_word(W) :-
    ( le_i18n:kw_main_words(copula, [W]) -> true ; W = is ).

%!  text_language(+Text, -Lang) is det.
%
%   The language an LE source text declares in its first statement (en when no
%   registered opener matches — decision O-1). Only the head of the text is
%   tokenized.
text_language(Text, Lang) :-
    (   catch(( sub_string(Text, 0, 500, _, Head0) -> true ; Head0 = Text ), _, Head0 = Text),
        catch(tokenizer:tokenize(Head0, Tokens), _, fail),
        le_i18n:detect_language_tokens(Tokens, Lang0)
    ->  Lang = Lang0
    ;   Lang = en
    ).

%!  ensure_kb_language(+KBmodule) is det.
%
%   Sets the active language (for keyword rendering and messages) from the
%   language recorded in the KB module at parse time. A no-op for modules
%   parsed before language support or for 'none'.
ensure_kb_language(KBmodule) :-
    (   atom(KBmodule), KBmodule \== none,
        catch(KBmodule:le_lang(Lang), _, fail)
    ->  le_i18n:set_le_language(Lang)
    ;   true
    ).

%!  negation_words(-Words:list) is det.
%
%   The Logical English phrase for negation-as-failure, as a word list. Single source
%   of truth so the phrase is not pasted in every place that renders "it is not the
%   case that <goal>".
negation_words(Words) :-
    ( le_i18n:kw_main_words(not_the_case, Words) -> true
    ; Words = [it, is, not, the, case, that] ).

% rule_head_text(+Ref, +SM, +KB, -HeadStr): the LE text of the head of the clause
% referenced by Ref (in the session or KB module).
rule_head_text(Ref, SM, KB, HeadStr) :-
    ( catch(clause(SM:Head, _Body, Ref), _, fail) -> true
    ; KB \== none, catch(clause(KB:Head, _Body, Ref), _, fail) ),
    nonvar(Head),
    ( (KB \== none, item_to_instance(KB, Head, Toks)) -> canonical_string(Toks, HeadStr)
    ; term_string(Head, HeadStr) ).

find_first_range(Goal, SM, KB, range(Start, End)) :-
    functor(Goal, F, A),
    functor(Skeleton, F, A),
    findall(S-E, (
        (SM:clause(Skeleton, _, Ref) ; (KB \== none, KB:clause(Skeleton, _, Ref))),
        (SM:le_source_info(Ref, S, E, _) ; (KB \== none, KB:le_source_info(Ref, S, E, _)))
    ), Ranges),
    Ranges \== [],
    sort(Ranges, [Start-End|_]).

postprocess_why_child(SM, Child, ChildOut) :-
    postprocess_why(Child, SM, ChildOut).

%!  is_session_assumption(+SM, +Goal) is semidet.
%
%   True when Goal corresponds to a condition the user explicitly assumed in the
%   current scenario — i.e. a SESSION-level le_unknown/1 clause matches it ("it is
%   unknown whether …"). A type-guard goal le_type_check(Arg, Type) (rendered
%   "Arg is a Type") is assumed via the equivalent is_a(Arg, Type) fact. Scoped to
%   the session module only, so KB-level unknowns keep their fallback semantics.
is_session_assumption(SM, Goal0) :-
    ( Goal0 = le_type_check(Arg, Type) -> Probe = is_a(Arg, Type) ; Probe = Goal0 ),
    \+ \+ catch(clause(SM:le_unknown(Probe), _), _, fail).

ensure_tokens(Template, Tokens) :-
    is_list(Template), !, Tokens = Template.
ensure_tokens(Template, Tokens) :-
    (atom(Template) ; string(Template)), !,
    tokenizer:tokenize_lang(Template, RawTokens),
    exclude(is_noise_token, RawTokens, Tokens).

is_noise_token(indent(_, _)).
is_noise_token(line_comment(_, _)).
is_noise_token(multi_comment(_, _)).

%!  queryScenario(+SessionModule:atom, +ScenarioName:atom, +Template:term, -TemplateInstance:list) is det.
%
%   Clears the session, sets a scenario, and runs a query.
queryScenario(SessionModule, ScenarioName, Template, TemplateInstance) :-
    queryScenario(SessionModule, ScenarioName, Template, TemplateInstance, _, _).

queryScenario(SessionModule, ScenarioName, Template, TemplateInstance, Unknowns, Why) :-
    clearSession(SessionModule),
    setScenarion(SessionModule, ScenarioName),
    query(SessionModule, Template, TemplateInstance,Unknowns, Why).

%!  canonical_string(+Instance:list, -String:string) is det.
%
%   Converts a list of tokens/instances into a space-separated string.
canonical_string(Instance, String) :-
    (   is_list(Instance) ->
        maplist(token_to_atom, Instance, Atoms),
        % Always produce a genuine string. atomic_list_concat/3 yields an atom,
        % and for a one-token instance that atom can be 'false'/'true', which
        % would serialize to a JSON boolean (and then render as [object Object]
        % in the UI). atom_string/2 keeps it a string.
        ( maplist(var, Atoms) -> String = ""; catch((atomic_list_concat(Atoms, ' ', Atom0), atom_string(Atom0, String)), _, String = "error"))
        ;
        token_to_atom(Instance, Atom),
        atom_string(Atom, String)
    ).

%!  token_to_atom(+Token:term, -Atom:atom) is det.
%
%   Converts a Logical English token into its atomic representation.
token_to_atom(X, Atom) :- var(X), !, Atom = '_'.
token_to_atom(var(Words, loc(_, _)), Atom) :- !, token_to_atom(var(Words), Atom).
token_to_atom(var(Name, Value), Atom) :- !,
    ( nonvar(Value) -> token_to_atom(Value, Atom); token_to_atom(Name, Atom)).
token_to_atom(var(Words, _), Atom) :- !, token_to_atom(var(Words), Atom).
token_to_atom(word(W, _), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(word(W), Atom) :- !, (var(W) -> Atom = '_' ; Atom = W).
token_to_atom(var(Words), Atom) :- !, 
    ( var(Words) -> Atom = '_'; is_list(Words) -> (maplist(token_to_atom, Words, Atoms), atomic_list_concat(Atoms, ' ', Atom)); atom_string(Atom, Words)).
token_to_atom(number(N, _), Atom) :- !, (var(N) -> Atom = '0' ; number_locale_atom(N, Atom)).
token_to_atom(number(N), Atom) :- !, (var(N) -> Atom = '0' ; number_locale_atom(N, Atom)).
token_to_atom(string(S, _), Atom) :- !, (string(S) -> atom_string(Atom, S) ; atom(S) -> Atom = S ; term_to_atom(S, Atom)).
token_to_atom(punctuation(P, _), P) :- !.
token_to_atom(punctuation(P), P) :- !.
token_to_atom(punct(P, _), P) :- !.
token_to_atom(punct(P), P) :- !.
token_to_atom(date(date(Y,M,D), _), Atom) :- !, 
    ( number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]); Atom = 'date').
token_to_atom(date(Y,M,D), Atom) :- !,
    ( number(Y), number(M), number(D) -> format(atom(Atom), '~w-~w-~wT0:0:0.0', [Y,M,D]); Atom = 'date').
token_to_atom(N, Atom) :- number(N), !, number_locale_atom(N, Atom).
token_to_atom(S, Atom) :- string(S), !, atom_string(Atom, S).
token_to_atom(A, Atom) :- atom(A), !, 
    ( (A \== '_', sub_atom(A, _, _, _, '_')) -> re_replace("_"/g, " ", A, Atom); Atom = A).
token_to_atom(X, Atom) :- term_to_atom(X, Atom).

%!  number_locale_atom(+N:number, -Atom) is det.
%
%   Renders a number using the active language's decimal separator (English:
%   '1.5'; Portuguese and friends: '1,5'). No thousands grouping is added, in
%   either language, mirroring the previous English behavior.
number_locale_atom(N, Atom) :-
    atom_number(Atom0, N),
    (   le_i18n:le_active_language(Lang),
        Lang \== en,
        catch(le_i18n:language_param(Lang, decimal_sep, Dec), _, fail),
        Dec \== '.', Dec \== '',
        sub_atom(Atom0, _, _, _, '.')
    ->  atomic_list_concat(Parts, '.', Atom0),
        atomic_list_concat(Parts, Dec, Atom)
    ;   Atom = Atom0
    ).

%!  item_to_instance(+KBmodule:atom, +Head:term, -WordsAndVars:list) is det.
%
%   Converts a Prolog term back into its Logical English token representation
%   using the templates in the KB module.
item_to_instance(KBmodule, le_at(Goal, _, _), WordsAndVars) :- !,
    item_to_instance(KBmodule, Goal, WordsAndVars).
item_to_instance(_KBmodule, var(Name, Value), [var(Name, Value)]) :- !.
item_to_instance(KBmodule, query_clause(_Goal, _, InstantiatedTokens, _, _), Tokens) :- !,
    maplist(bracket_list_token(KBmodule), InstantiatedTokens, Tokens).
item_to_instance(KBmodule, query_clause(_Goal, _, _, InstantiatedTokens, _, _, _, _), Tokens) :- !,
    maplist(bracket_list_token(KBmodule), InstantiatedTokens, Tokens).
% A multi-condition query: render its goal (with bindings) — e.g.
% "alice is happy and alice is healthy".
item_to_instance(KBmodule, query_body(Goal, _, _, _), Tokens) :- !,
    ( item_to_instance(KBmodule, Goal, Tokens) -> true ; term_string(Goal, S), Tokens = [S] ).
item_to_instance(KBmodule, Head, WordsAndVars) :-
    (   Head = is_a(Type, SuperType) ->
        maybe_transform_value(KBmodule, Type, TypeI),
        maybe_transform_value(KBmodule, SuperType, SuperTypeI),
        ( le_i18n:kw_main_words(is_a, IsAWords) -> true ; IsAWords = [is, a] ),
        flatten([TypeI, IsAWords, SuperTypeI], WordsAndVars)
    ;   Head = le_type_check(Arg, Type) ->
        % A type-restriction goal renders like the type assertion it checks:
        % le_type_check('this payment', payment) -> "this payment is a payment".
        maybe_transform_value(KBmodule, Arg, ArgI),
        le_i18n:indefinite_isa_words(Type, IsaWords),
        flatten([ArgI, IsaWords, Type], WordsAndVars)
    ;   Head = sum([each, Var], _Goal, [Result]) ->
        extract_name(Var, VarName),
        extract_name(Result, ResultName),
        aggregate_render_words(sum, OpWords),
        ( le_i18n:kw_main_words(such_that, SuchThat) -> true ; SuchThat = [such, that] ),
        flatten([ResultName, OpWords, VarName, SuchThat], WordsAndVars)
    ;   Head = count([each, Var], _Goal, [Result]) ->
        extract_name(Var, VarName),
        extract_name(Result, ResultName),
        aggregate_render_words(count, OpWords),
        ( le_i18n:kw_main_words(such_that, SuchThat) -> true ; SuchThat = [such, that] ),
        flatten([ResultName, OpWords, VarName, SuchThat], WordsAndVars)
    ;   Head = min([each, Var], _Goal, [Result]) ->
        extract_name(Var, VarName),
        extract_name(Result, ResultName),
        aggregate_render_words(min, OpWords),
        ( le_i18n:kw_main_words(such_that, SuchThat) -> true ; SuchThat = [such, that] ),
        flatten([ResultName, OpWords, VarName, SuchThat], WordsAndVars)
    ;   Head = max([each, Var], _Goal, [Result]) ->
        extract_name(Var, VarName),
        extract_name(Result, ResultName),
        aggregate_render_words(max, OpWords),
        ( le_i18n:kw_main_words(such_that, SuchThat) -> true ; SuchThat = [such, that] ),
        flatten([ResultName, OpWords, VarName, SuchThat], WordsAndVars)
    ;   Head = average([each, Var], _Goal, [Result]) ->
        extract_name(Var, VarName),
        extract_name(Result, ResultName),
        aggregate_render_words(average, OpWords),
        ( le_i18n:kw_main_words(such_that, SuchThat) -> true ; SuchThat = [such, that] ),
        flatten([ResultName, OpWords, VarName, SuchThat], WordsAndVars)
    ;   Head = not(Goal) ->
        negation_words(Neg),
        ( item_to_instance(KBmodule, Goal, GoalLE) -> append(Neg, GoalLE, WordsAndVars); append(Neg, [Goal], WordsAndVars))
    ;   Head = forall(Cond, Cons) ->
        forall_render_words(ForallWords), it_the_case_render_words(ItCaseWords),
        ( item_to_instance(KBmodule, Cond, CondLE), item_to_instance(KBmodule, Cons, ConsLE) ->
            append(ForallWords, CondLE, FW1), append(ItCaseWords, ConsLE, IW1),
            append(FW1, IW1, WordsAndVars)
        ; append(ForallWords, [Cond|ItCaseWords], FW2), append(FW2, [Cons], WordsAndVars))
    ;   % Pseudo-goals used by the reasoner to render a forall explanation as a
        % nested branch (see solve_real_actual/8 for forall in reasoner.pl). The
        % condition is now a separate child branch, so the header carries no
        % condition; the for_all_cases(Cond) form is kept for compatibility.
        Head == for_all_cases ->
        forall_render_words(WordsAndVars)
    ;   Head = for_all_cases(Cond) ->
        forall_render_words(ForallWords1),
        ( item_to_instance(KBmodule, Cond, CondLE) ->
            append(ForallWords1, CondLE, WordsAndVars)
        ; append(ForallWords1, [Cond], WordsAndVars))
    ;   % One universal case: the instantiated condition being considered.
        Head = for_case(Cond) ->
        ( le_i18n:kw_main_words(for_case, ForCase) -> true ; ForCase = [for, case] ),
        ( item_to_instance(KBmodule, Cond, CondLE) ->
            append(ForCase, CondLE, WordsAndVars)
        ; append(ForCase, [Cond], WordsAndVars))
    ;   % One universal case: the consequent that holds for that case.
        Head = it_is_true_that(Cons) ->
        ( le_i18n:kw_main_words(it_is_true_that, TrueThat) -> true ; TrueThat = [it, is, true, that] ),
        ( item_to_instance(KBmodule, Cons, ConsLE) ->
            append(TrueThat, ConsLE, WordsAndVars)
        ; append(TrueThat, [Cons], WordsAndVars))
    ;   Head == it_is_the_case ->
        it_the_case_render_words(WordsAndVars)
    ;   Head = and(A, B) ->
        (   fold_prep_chain(KBmodule, Head, Folded) -> WordsAndVars = Folded
        ;   A == true -> item_to_instance(KBmodule, B, WordsAndVars)
        ;   B == true -> item_to_instance(KBmodule, A, WordsAndVars)
        ;   item_to_instance(KBmodule, A, ALE), item_to_instance(KBmodule, B, BLE) ->
            and_render_word(AndW),
            append(ALE, [AndW | BLE], WordsAndVars)
        ; and_render_word(AndW), WordsAndVars = [A, AndW, B])
    ;   Head = or(A, B) -> 
        ( item_to_instance(KBmodule, A, ALE), item_to_instance(KBmodule, B, BLE) ->
            or_render_word(OrW),
            append(ALE, [OrW | BLE], WordsAndVars)
        ; or_render_word(OrW), WordsAndVars = [A, OrW, B])
    ;   % A "defines global" template's goal renders by its global name, e.g.
        % "the period of insurance is 123" rather than "our period of insurance
        % is 123" — matching how the global reads at its use sites.
        Head =.. [Functor, Value],
        global_template_name(KBmodule, Functor, GlobalName) ->
        maybe_transform_value(KBmodule, Value, ValueI),
        copula_render_word(Cop),
        flatten([GlobalName, Cop, ValueI], WordsAndVars)
    ;   copy_term(Head, HeadCopy),
        (   (KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _, _, _, _)) ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _)) ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0))), HeadCopy =.. [Functor|Args],
            check_types(NTs)
        ->  maplist(maybe_transform_value(KBmodule), WordsAndVars0, WordsAndVars1),
            maplist(fill_variable_name(NTs), WordsAndVars1, WordsAndVars2),
            flatten(WordsAndVars2, WordsAndVars)
        ;   term_string(Head, Str), WordsAndVars = [Str]
        )
    ).

%!  item_to_instance_ranged(+KBmodule, +Head, +Range, -WordsAndVars) is det.
%
%   Like item_to_instance/3, but Range (range(Start,End) or another Ref) is the
%   source location the goal was written at. When a synonym surface form was
%   recorded there (see le_grammar:maybe_record_synonym_use/5), render with that
%   form; otherwise fall back to the main template. This is how explanations show
%   a goal with the alternative wording actually used in the source.
item_to_instance_ranged(KBmodule, Head, range(Start, End), WordsAndVars) :-
    integer(Start),
    KBmodule \== none,
    KBmodule:le_synonym_at(Start, End, Skel),
    item_to_instance_with_skeleton(KBmodule, Head, Skel, WordsAndVars),
    !.
item_to_instance_ranged(KBmodule, Head, _Range, WordsAndVars) :-
    item_to_instance(KBmodule, Head, WordsAndVars).

% Render Head using the KB template whose words match Skel (a synonym form).
item_to_instance_with_skeleton(KBmodule, Head, Skel, WordsAndVars) :-
    copy_term(Head, HeadCopy),
    HeadCopy =.. [Functor|HeadArgs],
    ( KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _, _, _, _))
    ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _))
    ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0)) ),
    same_length(Args, HeadArgs),
    synonym_skeleton(WordsAndVars0, DictSkel),
    DictSkel == Skel,
    Args = HeadArgs,
    check_types(NTs),
    !,
    maplist(maybe_transform_value(KBmodule), WordsAndVars0, WordsAndVars1),
    maplist(fill_variable_name(NTs), WordsAndVars1, WordsAndVars2),
    flatten(WordsAndVars2, WordsAndVars).

% synonym_skeleton(+WordsAndVars, -Skeleton): variables -> '$v', atoms kept. Must
% match le_grammar's wv_skeleton so recorded and candidate forms compare equal.
synonym_skeleton([], []).
synonym_skeleton([X|Xs], [S|Ss]) :- ( var(X) -> S = '$v' ; S = X ), synonym_skeleton(Xs, Ss).

%!  fold_prep_chain(+KBmodule, +Goal, -Tokens) is semidet.
%
%   Re-folds the "unfolded" prepositional-chain form of a goal back into the
%   compact single sentence the user wrote. A prepositional template used in a
%   chain (e.g. "we will make *a payment* under *a policy* in respect of *a
%   claim*") is compiled into a conjunction of a main literal (we_will_make/1) plus
%   one prepositional goal per phrase (under/2, in_respect_of/2). Rendering that
%   conjunction directly gives the verbose "... and this payment under this policy
%   and this payment in respect of this claim"; this predicate instead renders the
%   main literal followed by each prepositional PHRASE (its template words after the
%   omitted leading argument), in source order. Fails (so the caller renders the
%   goal normally) unless the goal really is a main literal plus prepositional goals
%   that all share the main literal's first argument.
fold_prep_chain(KBmodule, Goal, Tokens) :-
    KBmodule \== none,
    ( Goal = and(_, _) ; Goal = (_ , _) ),
    answer_conjuncts(Goal, Conjuncts),
    % Split into the single non-prepositional main literal and the prepositional
    % conjuncts, wherever the main sits: a QUERY solves the prepositional
    % constraints first, so the main verb may be the LAST conjunct rather than the
    % first (see query_chain_goal/3 and parse_node/6 in le_grammar.pl).
    select_main_literal(KBmodule, Conjuncts, Main0, Preps0),
    Preps0 \== [],
    unwrap_le_at_all(Main0, Main),
    callable(Main), \+ prep_goal(KBmodule, Main),
    Main =.. [_ | MainArgs], MainArgs = [Subject | _],
    maplist(positioned_prep(KBmodule, Subject), Preps0, Positioned),
    sort(1, @=<, Positioned, Sorted),
    item_to_instance(KBmodule, Main, MainTokens),
    findall(Phrase, ( member(_-PG, Sorted), prep_phrase(KBmodule, PG, Phrase) ), PhraseLists),
    length(PhraseLists, NP), length(Preps0, NP),   % every prep folded, else fail
    append([MainTokens | PhraseLists], Tokens).

% select_main_literal(+KB, +Conjuncts, -Main, -Preps): split a prepositional
% chain's conjuncts into the single non-prepositional main literal and the
% prepositional conjuncts, regardless of the main's position in the list. Commits
% to the first non-prepositional conjunct as the main (a well-formed chain has
% exactly one); the surrounding conjuncts stay in Preps in their original order
% (fold_prep_chain re-sorts them by source position anyway).
select_main_literal(KBmodule, Conjuncts, Main, Preps) :-
    select_main_literal_(KBmodule, Conjuncts, Main, Preps), !.
select_main_literal_(KBmodule, [C | Rest], Main, Preps) :-
    unwrap_le_at_all(C, CU),
    (   callable(CU), \+ prep_goal(KBmodule, CU)
    ->  Main = C, Preps = Rest
    ;   Preps = [C | Preps0], select_main_literal_(KBmodule, Rest, Main, Preps0)
    ).

% Flatten an and/','-tree into conjuncts, dropping `true` and unwrapping a le_at
% that only groups a conjunction (leaf goals keep their le_at for source position).
answer_conjuncts(true, []) :- !.
answer_conjuncts(and(A, B), Cs) :- !, answer_conjuncts(A, CA), answer_conjuncts(B, CB), append(CA, CB, Cs).
answer_conjuncts((A , B), Cs) :- !, answer_conjuncts(A, CA), answer_conjuncts(B, CB), append(CA, CB, Cs).
answer_conjuncts(le_at(G, S, E), Cs) :- !,
    ( (G = and(_, _) ; G = (_ , _)) -> answer_conjuncts(G, Cs) ; Cs = [le_at(G, S, E)] ).
answer_conjuncts(G, [G]).

unwrap_le_at_all(le_at(G, _, _), Out) :- !, unwrap_le_at_all(G, Out).
unwrap_le_at_all(G, G).

% positioned_prep(+KB, +Subject, +Conjunct, -Start-PrepGoal): a conjunct that is a
% prepositional goal sharing Subject as its first argument, paired with its source
% start (from its le_at wrapper, else 0) so folded phrases can be source-ordered.
positioned_prep(KBmodule, Subject, Conjunct, Start-PG) :-
    ( Conjunct = le_at(PG, Start, _) -> true ; PG = Conjunct, Start = 0 ),
    prep_goal(KBmodule, PG),
    PG =.. [_ | [First | _]],
    First == Subject.

% prep_goal(+KB, +Goal): Goal's functor/arity is a prepositional template. The Prep
% field is checked with ==, NOT unified — unifying would bind the (unbound) Prep slot
% of a non-prepositional template and match everything.
prep_goal(KBmodule, Goal) :-
    callable(Goal),
    Goal =.. [F | Args], Args \== [],
    once(( KBmodule:le_dict(dict([F | FormalArgs], _, _, _, _, Prep, _)),
           Prep == prepositional,
           same_length(FormalArgs, Args) )).

% prep_phrase(+KB, +PrepGoal, -Phrase): the prepositional template's words AFTER its
% omitted leading argument, with the remaining argument(s) rendered — e.g.
% under(P, 'this policy') -> [under, this, policy].
prep_phrase(KBmodule, PrepGoal, Phrase) :-
    PrepGoal =.. [F | Args],
    once(( KBmodule:le_dict(dict([F | FormalArgs], NTs, [_Leading | RestWV], _, _, Prep, _)),
           Prep == prepositional,
           same_length(FormalArgs, Args) )),
    copy_term(fa(FormalArgs, NTs, RestWV), fa(FormalArgsC, NTsC, RestWVC)),
    FormalArgsC = Args,
    maplist(maybe_transform_value(KBmodule), RestWVC, RestWV1),
    maplist(fill_variable_name(NTsC), RestWV1, RestWV2),
    flatten(RestWV2, Phrase).

% global_template_name(+KBmodule, +Functor, -GlobalName): the (first) global name
% declared with "defines global" for the template whose predicate is Functor.
global_template_name(KBmodule, Functor, GlobalName) :-
    KBmodule:le_dict(dict([Functor|_], _, _, Globals, _, _, _)),
    is_list(Globals), Globals = [GlobalName|_].

check_types([]).
check_types([Var-Type|NTs]) :-
    (   var(Var) -> true
    ;   Type == date ->
        ( Var = date(_) ; Var = date(_,_,_) ; Var = date(_,_,_,_,_,_,_,_,_) )
    ;   Type == number ->
        number(Var)
    ;   true
    ),
    check_types(NTs).

fill_variable_name(NTs, V, Name) :-
    var(V),
    member(V1-Type, NTs),
    V1 == V, !,
    (   atom(Type) -> 
        atom_codes(Type, [C|_]),
        ( memberchk(C, [97, 101, 105, 111, 117, 65, 69, 73, 79, 85]) -> Art = an ; Art = a ),
        format(atom(Name), "~w ~w", [Art, Type])
    ;   Name = 'a variable'
    ).
fill_variable_name(_, V, V).

maybe_transform_value(KBmodule, Val, Transformed) :-
    (   is_list(Val)
    ->  render_list_value(KBmodule, Val, Transformed)   % e.g. [Alice, Bob] -> '[Alice Bob]'
    ;   compound(Val), Val \= date(_), Val \= date(_,_,_), item_to_instance(KBmodule, Val, Transformed)
    ->  true
    ;   Transformed = Val
    ).

%!  render_list_value(+KBmodule, +List, -Atom) is det.
%
%   Renders a list value as a single bracketed atom whose elements are
%   space-separated, e.g. [Alice, Bob] -> '[Alice Bob]', [] -> '[]'. Producing a
%   single atom (rather than leaving a sublist) keeps the brackets visible: the
%   surrounding flatten/2 in item_to_instance/3 and query/5 would otherwise
%   splice the elements into the sentence and lose the list structure.
render_list_value(KBmodule, List, Atom) :-
    maplist(render_list_element(KBmodule), List, ElemAtoms),
    atomic_list_concat(ElemAtoms, ' ', Inner),
    atomic_list_concat(['[', Inner, ']'], Atom).

render_list_element(KBmodule, E, A) :-
    (   is_list(E) -> render_list_value(KBmodule, E, A)
    ;   nonvar(E), compound(E), E \= date(_,_,_), E \= date(_), item_to_instance(KBmodule, E, WV)
    ->  canonical_string(WV, S), atom_string(A, S)
    ;   token_to_atom(E, A)
    ).

% In a (flat) query instance, a token bound to a list value is rendered as a
% single bracketed atom so flatten/2 in query/5 keeps its brackets.
bracket_list_token(KBmodule, Token, Out) :-
    ( is_list(Token) -> render_list_value(KBmodule, Token, Out) ; Out = Token ).

extract_name(var(Name, _), Name) :- !.
extract_name(V, V).

%!  get_kb_metadata(+KB:atom, -Metadata:dict) is det.
%
%   Returns metadata about a loaded KB, including its name, templates,
%   queries, and scenarios.
get_kb_metadata(KB, Metadata) :-
    ( current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true; KBName = null),
    findall(TemplateStr, (
        KB:le_dict(Dict),
        (Dict = dict(FA, NTs, WV, _, _, _, _) ; Dict = dict(FA, NTs, WV, _, _, _) ; Dict = dict(FA, NTs, WV, _, _) ; Dict = dict(FA, NTs, WV, _) ; Dict = dict(FA, NTs, WV)),
        \+ le_system_templates:le_system_template(dict(FA, NTs, WV)),
        copy_term(NTs-WV, NTsC-WVC),
        maplist(fill_type, NTsC),
        canonical_string(WVC, TemplateStr)
    ), Templates),
    (   current_predicate(KB:query_info/3) ->  
        findall(_{name: Name, template: QueryStr, le: LEStr}, (
            KB:query_info(Name, Goal, Items),
            copy_term(Goal, GoalCopy),
            term_string(GoalCopy, QueryStr),
            maplist(item_to_le_string, Items, LEStrings),
            atomic_list_concat(LEStrings, ' and ', LEStr)
        ), Queries)
        ;   
        Queries = []
    ),
    (   current_predicate(KB:scenario/2) ->  
        findall(_{name: Name}, KB:scenario(Name, _), Scenarios)
        ;   
        Scenarios = []
    ),
    (   current_predicate(KB:le_included_resource/3) ->
        findall(_{resource: R, start: Start, end: End, rules: RuleCount, templates: TemplateCount}, (
            KB:le_included_resource(R, Start, End),
            ( KB:le_resource_stats(R, RuleCount, TemplateCount) -> true ; RuleCount = 0, TemplateCount = 0 )
        ), IncludedResources)
    ;   IncludedResources = []
    ),
    % Per-fact images ("<fact>; image "URL"."), keyed by the fact's source
    % range — the same range its explanation nodes carry, which is how the
    % Bento Box window matches a leaf to its image.
    (   current_predicate(KB:le_fact_image/3)
    ->  findall(_{start: IS, end: IE, url: IU}, KB:le_fact_image(IS, IE, IU), FactImages)
    ;   FactImages = []
    ),
    % Template images (no-variable templates only), keyed by the template's
    % canonical rendering — the very text an explanation leaf for that literal
    % carries, which is how the Bento Box matches them.
    (   current_predicate(KB:le_template_image/2)
    ->  findall(_{literal: TLit, url: TU}, (
            KB:le_template_image(TF, TU),
            (   catch(item_to_instance(KB, TF, TToks), _, fail),
                canonical_string(TToks, TLitA)
            ->  atom_string(TLitA, TLit)
            ;   term_string(TF, TLit)
            )
        ), TemplateImages)
    ;   TemplateImages = []
    ),
    Metadata = _{ kb: KBName, templates: Templates, queries: Queries, examples: Scenarios, included_resources: IncludedResources, fact_images: FactImages, template_images: TemplateImages }.

%!  topPredicates(+KB:atom, -TopPreds:list) is det.
%
%   Finds the "top-level" predicates in a KB (those not used in the body
%   of other rules).
topPredicates(KB, TopPreds) :-
    findall(F/A, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(G, F, A),
        \+ predicate_property(KB:G, imported_from(_)),
        le_verifier:is_intensional(KB, F, A),
        \+ is_used_by_other_rules(KB, F, A)
    ), Preds),
    sort(Preds, UniquePreds),
    maplist(pred_to_template(KB), UniquePreds, TopPreds).

is_used_by_other_rules(KB, F, A) :-
    current_predicate(KB:F2/A2),
    F2/A2 \== F/A,
    \+ is_system_predicate(F2/A2),
    functor(G2, F2, A2),
    KB:clause(G2, Body),
    le_verifier:find_in_body(Body, Literal),
    functor(Literal, F, A).

pred_to_template(KB, F/A, TemplateStr) :-
    (   (KB:le_dict(dict([F|_], NTs, WordsAndVars, _, _, _, _)) ; KB:le_dict(dict([F|_], NTs, WordsAndVars, _)))
    ->  copy_term(NTs-WordsAndVars, NTsCopy-WordsAndVarsCopy),
        maplist(fill_type, NTsCopy),
        canonical_string(WordsAndVarsCopy, TemplateStr)
    ;   functor(Head, F, A),
        item_to_instance(KB, Head, Tokens),
        canonical_string(Tokens, TemplateStr)
    ).

fill_type(V-Type) :-
    (   atom(Type) -> format(atom(V), "a ~w", [Type])
    ;   V = 'a variable'
    ).

%!  kbSummary(+KB:atom, -Summary:string) is det.
%
%   Returns a short string summarizing the KB and its top predicates.
kbSummary(KB, Summary) :-
    (current_predicate(KB:le_kb/1), KB:le_kb(KBName) -> true ; KBName = KB),
    ensure_kb_language(KB),
    topPredicates(KB, TopPreds),
    atomic_list_concat(TopPreds, '; ', PredsStr),
    le_i18n:le_msg(kb_summary, [kb-KBName, predicates-PredsStr], SummaryAtom),
    atom_string(SummaryAtom, Summary).

%!  parse_custom_facts(+KB:atom, +Text:string, -Terms:list) is det.
%
%   Parses a string of Logical English facts using the templates in the KB.
parse_custom_facts(KB, Text, Terms) :-
    tokenizer:tokenize_lang(Text, Tokens),
    le_grammar:set_token_pos(0),
    ( phrase(le_grammar:kb_items(Items), Tokens) -> true ; Items = [] ),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    % Custom facts ARE scenario facts: use the scenario second pass so a definite
    % phrase like "the UK" stays a concrete individual. The regular KB pass would
    % treat it as an anaphoric variable, silently dropping the value (so editing
    % such an argument would have no effect).
    maplist(scenario_item_to_term(Templates, KB), Items, Terms).

scenario_item_to_term(Templates, M, Item, Term) :-
    ( le_grammar:second_pass_scenario_item_with_module(Templates, M, Item, NewItem) ->
        clause_item_to_term(NewItem, Term)
    ; Item = Term ).

clause_item_to_term(clause(Head, true, _, _, _), Head) :- !.
clause_item_to_term(clause(Head, Body, _, _, _), (Head :- Body)) :- !.
clause_item_to_term(clause(Head, true, _, _), Head) :- !.
clause_item_to_term(clause(Head, Body, _, _), (Head :- Body)) :- !.
clause_item_to_term(Other, Other).

%!  parse_custom_query(+KB:atom, +Text:string, -Goal:term) is det.
%
%   Parses a Logical English query string using the templates in the KB.
parse_custom_query(KB, Text, Goal) :-
    tokenizer:tokenize_lang(Text, Tokens),
    le_grammar:set_token_pos(0),
    (   parse_query_to_goal(KB, Tokens, Goal, _Instance) -> true
    ;   format(string(Error), "Query does not match any template: ~w", [Text]),
        throw(error(le_parse_error(Error), _))
    ).

%!  is_system_predicate(?Pred:term) is semidet.
%
%   True if Pred is a system-defined predicate used by the LE engine.
is_system_predicate(le_source_element/3).
is_system_predicate(le_source_section/2).
is_system_predicate(le_kb/1).
is_system_predicate(le_source_info/4).
is_system_predicate(scenario/2).
is_system_predicate(le_expected/4).
is_system_predicate(query_info/3).
is_system_predicate(ontology/1).
is_system_predicate(le_dict/1).
is_system_predicate(unknown_template/1).
is_system_predicate(le_issue/6).
is_system_predicate(le_kb_module_fact/1).
is_system_predicate(le_neg/1).
is_system_predicate(sessionClause/1).
is_system_predicate(is_a/2).
is_system_predicate(le_type/1).
is_system_predicate(le_unknown/1).
% Per-rule map of explicit source variable identifiers (e.g. X, Y), keyed by
% rule ID, recorded at parse time so the Proof Game can show variable names.
is_system_predicate(le_var_names/2).
% Per-use-site record that a goal at source range Start-End was written with a
% synonym surface form (Skeleton = its word pattern, arg positions as '$v'). Lets
% explanations render the goal with the form actually written, rather than the
% main template. Populated at parse time by le_grammar:maybe_record_synonym_use/5.
is_system_predicate(le_synonym_at/3).
% Per-fact image addition ("<fact>; image "URL"."), keyed by the fact's source
% range; recorded at parse time, rendered by the Bento Box.
is_system_predicate(le_fact_image/3).
% Per-template image addition (no-variable templates only), keyed by functor;
% the Bento Box falls back to it when a fact carries no image of its own.
is_system_predicate(le_template_image/2).
% Include bookkeeping (see fetch_resources/3 and load_prolog_resource/4).
is_system_predicate(le_included_resource/3).
is_system_predicate(le_resource_stats/3).
is_system_predicate(le_prolog_resource/2).


collect_and_assert_types(M) :-
    forall(le_grammar:is_a_type(T), assertz(M:le_type(T))).

is_expected_item(expected(_, _, _, _, _)).

%!  verify(+LEfilePath:atom) is det.
%
%   Loads and verifies a Logical English file, printing any issues found.
verify(LEfilePath) :-
    uuid(UUID), atom_concat(v, UUID, KBmodule),
    forall(is_system_predicate(F/N), dynamic(KBmodule:F/N)),
    setup_call_cleanup(
        asserta(current_compiling_module(KBmodule)),
        le_grammar:parse_le_file(LEfilePath, doc(Sections), KBmodule),
        retractall(current_compiling_module(_))
    ),
    collect_and_assert_types(KBmodule),
    forall(member(S, Sections), process_section(S, KBmodule)),
    findall(D, le_system_template(D), SysDicts),
    forall(member(D, SysDicts), assertz(KBmodule:le_dict(D))),
    le_verifier:verify(KBmodule, Issues),
    forall(member(Issue, Issues), le_verifier:print_issue(Issue)),
    % Also report asserted issues
    ( current_predicate(KBmodule:le_issue/6) ->
      forall(KBmodule:le_issue(Severity, Type, Desc, _Fix, Start, End),
             print_message(Severity, Type - [Desc, Start, End]))
    ; true ),
    atom_concat(LEfilePath, '.tests', TestsFile),
    (   exists_file(TestsFile) ->  
        setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, LegacyTests), close(Stream))
        ; LegacyTests = []
    ),
    ( current_predicate(KBmodule:le_expected/4) -> findall(test(Q, S, A, U), KBmodule:le_expected(Q, S, A, U), EmbeddedTests); EmbeddedTests = []),
    append(LegacyTests, EmbeddedTests, AllTests),
    (   AllTests \== [] ->  
        maplist(run_one_test(KBmodule), AllTests, TestResults),
        print_test_result(test_file(LEfilePath, TestResults))
        ;   
        true
    ),
    forall(current_predicate(KBmodule:F/N), abolish(KBmodule:F/N)).

item_to_le_string(query_clause(_, OriginalTokens, _, _, _), String) :- !,
    tokens_to_string(OriginalTokens, String).
item_to_le_string(query_clause(_, OriginalTokens, _, _, _, _, _, _), String) :- !,
    tokens_to_string(OriginalTokens, String).
item_to_le_string(query_body(_, OriginalTokens, _, _), String) :- !,
    tokens_to_string(OriginalTokens, String).
item_to_le_string(Item, String) :-
    term_string(Item, String).

item_to_term(_Templates, _M, query_clause(Head, _, _, _, _), Head) :- !.
item_to_term(_Templates, _M, query_clause(Head, _, _, _, _, _, _, _), Head) :- !.
item_to_term(_Templates, _M, query_body(Goal, _, _, _), Goal) :- !.
item_to_term(_Templates, _M, clause(Head, true, _, _, _), Head) :- !.
item_to_term(_Templates, _M, clause(Head, Body, _, _, _), (Head :- Body)) :- !.
item_to_term(_Templates, _M, clause(Head, true, _, _), Head) :- !.
item_to_term(_Templates, _M, clause(Head, Body, _, _), (Head :- Body)) :- !.
item_to_term(Templates, M, Item, Term) :-
    ( le_grammar:second_pass_item_with_module(Templates, M, Item, NewItem) -> item_to_term(Templates, M, NewItem, Term)
    ; Item = Term
    ).

item_to_term_with_source(_M, _Templates, query_clause(Head, _, _, Start, End), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, query_clause(Head, _, _, _, _, Start, End, _ID), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, query_body(Goal, _, Start, End), fact_with_source(Goal, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, true, Start, End, _ID), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, true, Start, End), fact_with_source(Head, Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, Body, Start, End, _ID), fact_with_source((Head :- Body), Start, End)) :- !.
item_to_term_with_source(_M, _Templates, clause(Head, Body, Start, End), fact_with_source((Head :- Body), Start, End)) :- !.
item_to_term_with_source(M, Templates, Item, Term) :-
    ( le_grammar:second_pass_item_with_module(Templates, M, Item, NewItem) -> item_to_term_with_source(M, Templates, NewItem, Term)
    ; Item = Term
    ).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], (G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

normalize_string(string(S, _), N) :- !, normalize_string(S, N).
normalize_string(S, N) :-
    (   number(S) -> atom_string(S, N)
    ;   (atom(S) ; string(S)) ->  
        split_string(S, "_- ", "_- ", Words),
        atomic_list_concat(Words, ' ', Atom),
        atom_string(Atom, N)
    ;   N = S
    ).
%!  run_one_test(+KBmodule:atom, +Test:term, -Result:term) is det.
%
%   Runs a single test case against a KB module.

strip_string_wrapper(string(S, _), S) :- !.
strip_string_wrapper(S, S).

read_tests(Stream, Tests) :-
    read(Stream, Term),
    ( Term == end_of_file -> Tests = []; Term = expected(Q, S, E, U) -> Tests = [test(Q, S, E, U)|Rest], read_tests(Stream, Rest); read_tests(Stream, Tests)).

%!  runTestsInDir(+Dir:atom, -Results:list) is det.
%
%   Runs all Logical English tests found in Dir and any immediate subdirectories.
runTestsInDir(Dir, Results) :-
    directory_files(Dir, Files),
    findall(LEFile, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        directory_file_path(Dir, F, LEFile)
    ), LEFiles0),
    sort(LEFiles0, LEFiles),
    findall(SubResults, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        runTestsInDir(SubDir, SubResults)
    ), SubResultsLists),
    maplist(runTestsFor, LEFiles, FileResults),
    append(SubResultsLists, SubResultsFlat),
    append(FileResults, SubResultsFlat, Results).

%!  runTestsFor(+LEFile:atom, -Result:term) is det.
%
%   Runs all tests associated with a specific Logical English file.
runTestsFor(LEFile, Result) :-
    print_message(informational,"Running tests for ~w"-[LEFile]),
    % skip_tests: run_one_test below runs every embedded test itself, so
    % letting load-time verification run them too would execute the whole
    % suite TWICE per file (for the largest example that alone is ~24s). The
    % 30s limit still catches runaway loads while leaving headroom for big
    % programs (the largest takes ~4.5s to parse+verify on a warm machine,
    % more under suite load — the old 5s limit made it flaky).
    (   catch(call_with_time_limit(30, load(LEFile, KBmodule, [skip_tests])), E, (format('Error loading ~w: ~w~n', [LEFile, E]), fail)) ->
        atom_concat(LEFile, '.tests', TestsFile),
        (   exists_file(TestsFile) ->  
            setup_call_cleanup(open(TestsFile, read, Stream), read_tests(Stream, LegacyTests), close(Stream))
            ; LegacyTests = []
        ),
        ( current_predicate(KBmodule:le_expected/4) -> findall(test(Q, S, A, U), KBmodule:le_expected(Q, S, A, U), EmbeddedTests); EmbeddedTests = []),
        append(LegacyTests, EmbeddedTests, AllTests),
        maplist(run_one_test(KBmodule), AllTests, TestResults),
        Result = test_file(LEFile, TestResults)
        ;   
        Result = test_file(LEFile, [error(load, LEFile, 'Failed to load or timeout loading LE file')])
    ).

%!  runTests is det.
%
%   Runs all tests in the default examples directory and prints a summary.
runTests :-
    le_examples_dir(Dir), runTestsInDir(Dir, Results0),
    % Per-language example trees (O-7 layout A): examples/<lang>/ for every
    % language registered in i18n/languages.csv beyond English (whose tree is
    % the main examples directory).
    findall(R,
            ( le_i18n:known_language(Lang), Lang \== en,
              atomic_list_concat([examples, /, Lang], LangDir),
              exists_directory(LangDir),
              runTestsInDir(LangDir, Rs),
              member(R, Rs) ),
            LangResults),
    append(Results0, LangResults, Results),
    print_test_summary(Results),
    setup_call_cleanup(open('testSuiteStatus.txt', write, Stream), with_output_to(Stream, print_test_summary(Results)), close(Stream)),
    forall(member(R, Results), print_test_result(R)).

print_test_summary(Results) :-
    findall(P, (member(test_file(_, FileResults), Results), member(pass(_,_), FileResults), P = 1), Passes),
    findall(F, (member(test_file(_, FileResults), Results), member(fail(_,_,_,_), FileResults), F = 1), Fails),
    findall(E, (member(test_file(_, FileResults), Results), member(error(_,_,_), FileResults), E = 1), Errs),
    length(Results, FileCount), length(Passes, PassCount), length(Fails, FailCount), length(Errs, ErrCount),
    Total is PassCount + FailCount + ErrCount,
    format('~nTest Summary:~n-------------~nFiles processed: ~w~nTotal tests:     ~w~nPassed:          ~w~nFailed:          ~w~nErrors/Timeouts: ~w~n-------------~n~nDetailed File Summary:~n', [FileCount, Total, PassCount, FailCount, ErrCount]),
    forall(member(test_file(File, FileResults), Results),
           (   findall(1, member(pass(_,_), FileResults), PFile),
               findall(1, member(fail(_,_,_,_), FileResults), FFile),
               findall(1, member(error(_,_,_), FileResults), EFile),
               length(PFile, PC), length(FFile, FC), length(EFile, EC),
               ( (FC > 0 ; EC > 0) -> Status = '[FAIL]' ; (PC == 0, FC == 0, EC == 0) -> Status = '[NONE]' ; Status = '[PASS]' ),
               format('  ~w ~w: ~w Pass, ~w Fail, ~w Error~n', [Status, File, PC, FC, EC])
           )),
    format('-------------~n~n').

%!  print_test_result(+Result:term) is det.
%
%   Prints the detailed results of a test file.
print_test_result(test_file(File, FileResults)) :-
    format('File: ~w~n', [File]),
    forall(member(R, FileResults),
           ( R = pass(Q, S) -> format('  PASS: ~w (~w)~n', [Q, S]); R = fail(Q, S, E, A) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n', [Q, S, E, A]); R = fail(Q, S, E, A, EU, AU) -> format('  FAIL: ~w (~w)~n    Expected: ~w~n    Actual:   ~w~n    Expected Unknowns: ~w~n    Actual Unknowns: ~w~n', [Q, S, E, A, EU, AU]); format('  ERROR: ~w~n', [R]))).
run_one_test(KBmodule, test(QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns), Result) :-
    createSession(KBmodule, SM),
    setup_call_cleanup(
        true,
        run_one_test_body(KBmodule, QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns, SM, Result),
        destroySession(SM)
    ).

run_one_test_body(KBmodule, QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns, SM, Result) :-
    (   setScenarion(SM, ScenarioName) ->
        (   ((KBmodule:query_info(QueryName, FullGoal, Items) ; (normalize_string(QueryName, NormName), KBmodule:query_info(InfoName, FullGoal, Items), normalize_string(InfoName, NormName)))) ->  
            (   catch(call_with_time_limit(30, 
                    findall(S-ActualUnknownStrings, 
                        (
                            reasoner:i(FullGoal, SM, ActualUnknownsList, _Why), 
                            maplist(item_to_instance(KBmodule), Items, Instances), 
                            flatten(Instances, TemplateInstance), 
                            canonical_string(TemplateInstance, Atom), 
                            atom_string(Atom, S), 
                            maplist(item_to_instance(KBmodule), ActualUnknownsList, UnknownInstances), 
                            maplist(flatten, UnknownInstances, FlatUnknownInstances), 
                            maplist(canonical_string, FlatUnknownInstances, UnknownAtoms), 
                            maplist(atom_string, UnknownAtoms, ActualUnknownStrings)
                        ), 
                        ActualResults
                    )
                ), time_limit_exceeded, (ActualResults = timeout)) ->  
                    (   ActualResults == timeout -> 
                            Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                        ; 
                        pairs_keys_values(ActualResults, ActualStrings, ActualUnknownsLists),
                        flatten(ActualUnknownsLists, FlatActualUnknowns),
                        sort(FlatActualUnknowns, SortedActualUnknowns),
                        maplist(normalize_string, ExpectedStrings, NormExpected),
                        maplist(normalize_string, ActualStrings, NormActual),
                        sort(NormExpected, SortedExpected),
                        sort(NormActual, SortedActual),
                        maplist(normalize_string, ExpectedUnknowns, NormExpectedUnknowns),
                        maplist(normalize_string, SortedActualUnknowns, NormActualUnknowns),
                        sort(NormExpectedUnknowns, SortedExpectedUnknowns),
                        sort(NormActualUnknowns, SortedActualUnknownsFinal),
                        (   SortedExpected == SortedActual, SortedExpectedUnknowns == SortedActualUnknownsFinal -> 
                                Result = pass(QueryName, ScenarioName)
                            ; 
                            maplist(strip_string_wrapper, ExpectedStrings, CleanExpected),
                            Result = fail(QueryName, ScenarioName, CleanExpected, ActualStrings, ExpectedUnknowns, SortedActualUnknownsFinal)
                        )
                    )
                ; Result = error(QueryName, ScenarioName, 'Test execution failed')
            )
            ;   
            % Try to parse QueryName as a custom query if not found in query_info
            (   catch(parse_custom_query(KBmodule, QueryName, FullGoal), _, fail) ->
                (   catch(call_with_time_limit(30, 
                        findall(S-ActualUnknownStrings, 
                            (
                                reasoner:i(FullGoal, SM, ActualUnknownsList, _Why), 
                                item_to_instance(KBmodule, FullGoal, TemplateInstance), 
                                canonical_string(TemplateInstance, Atom), 
                                atom_string(Atom, S), 
                                maplist(item_to_instance(KBmodule), ActualUnknownsList, UnknownInstances), 
                                maplist(flatten, UnknownInstances, FlatUnknownInstances), 
                                maplist(canonical_string, FlatUnknownInstances, UnknownAtoms), 
                                maplist(atom_string, UnknownAtoms, ActualUnknownStrings)
                            ), 
                            ActualResults
                        )
                    ), time_limit_exceeded, (ActualResults = timeout)) ->
                    (   ActualResults == timeout -> Result = error(QueryName, ScenarioName, 'Timeout exceeded')
                    ;   
                        pairs_keys_values(ActualResults, ActualStrings, ActualUnknownsLists),
                        flatten(ActualUnknownsLists, FlatActualUnknowns),
                        sort(FlatActualUnknowns, SortedActualUnknowns),
                        maplist(normalize_string, ExpectedStrings, NormExpected),
                        maplist(normalize_string, ActualStrings, NormActual),
                        sort(NormExpected, SortedExpected),
                        sort(NormActual, SortedActual),
                        maplist(normalize_string, ExpectedUnknowns, NormExpectedUnknowns),
                        maplist(normalize_string, SortedActualUnknowns, NormActualUnknowns),
                        sort(NormExpectedUnknowns, SortedExpectedUnknowns),
                        sort(NormActualUnknowns, SortedActualUnknownsFinal),
                        (   SortedExpected == SortedActual, SortedExpectedUnknowns == SortedActualUnknownsFinal -> Result = pass(QueryName, ScenarioName)
                        ;   maplist(strip_string_wrapper, ExpectedStrings, CleanExpected),
                            Result = fail(QueryName, ScenarioName, CleanExpected, ActualStrings, ExpectedUnknowns, SortedActualUnknownsFinal)
                        )
                    )
                ;   Result = error(QueryName, ScenarioName, 'Test execution failed')
                )
            ;   Result = error(QueryName, ScenarioName, 'Query not found')
            )
        )
    ;   Result = error(QueryName, ScenarioName, 'Scenario not found')
    ).

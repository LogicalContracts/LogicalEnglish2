% Tests for Prolog resources included by LE programs: assert-only loading into
% cache modules, sandboxing of `prolog` body goals, transitive includes with a
% depth cap and cycle guard, and local-path restriction.

:- use_module('../le_kbs').
:- use_module('../le_verifier').
:- use_module('../le_grammar').
:- use_module('../tokenizer').

% Reconstruct the single resource of a one-resource includes-section.
parse_single_resource(ResourceLiteral, Got) :-
    format(atom(Src),
        "the knowledge base k includes these resources:\n    ~w.\n\nthe templates are:\n    *a thing* is ok.\n",
        [ResourceLiteral]),
    tokenizer:tokenize(Src, Toks),
    phrase(le_grammar:doc(Secs), Toks),
    member(resources(_, [Got], _, _), Secs).

tmp_dir(Dir) :-
    tmp_file(le_plres, Base),
    atom_concat(Base, '_d', Dir),
    ( exists_directory(Dir) -> true ; make_directory(Dir) ).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S, [encoding(utf8)]), write(S, Text), close(S)).

has_issue(KB, Type) :- KB:le_issue(_, Type, _, _, _, _).

% ── The bundled postcodes example loads its .pl and reasons through it ────────
:- begin_tests(prolog_resource_example).

test(postcodes_example_all_pass) :-
    runTestsFor('examples/moreExamples/prolog_resources/postcodes.le', test_file(_, Results)),
    forall(member(R, Results), assertion(R = pass(_, _))).

:- end_tests(prolog_resource_example).

% ── Loading, sandboxing, directives, cycles, depth, paths ────────────────────
% Resource-name reconstruction must preserve URLs/paths exactly. The tokenizer
% splits digit<->letter boundaries, so a UUID in a URL (89d78cb0-7d73-...) used
% to come back with spurious spaces ("89 d78cb0-7 d73-..."), breaking the fetch.
:- begin_tests(resource_name_parsing).

test(url_with_uuid_preserved) :-
    parse_single_resource(
        'http://localhost:8080/pub/89d78cb0-7d73-11f1-9b0d-27da04e3cb2f.pl', Got),
    assertion(Got == 'http://localhost:8080/pub/89d78cb0-7d73-11f1-9b0d-27da04e3cb2f.pl').

test(plain_url_preserved) :-
    parse_single_resource(
        'https://raw.githubusercontent.com/mcalejo/LogicalEnglish2/main/examples/moreExamples/royal_family', Got),
    assertion(Got == 'https://raw.githubusercontent.com/mcalejo/LogicalEnglish2/main/examples/moreExamples/royal_family').

test(local_path_preserved) :-
    parse_single_resource('examples/moreExamples/testing/citizenship_premier', Got),
    assertion(Got == 'examples/moreExamples/testing/citizenship_premier').

test(pl_extension_preserved) :-
    parse_single_resource('postcodes_facts.pl', Got),
    assertion(Got == 'postcodes_facts.pl').

:- end_tests(resource_name_parsing).

:- begin_tests(prolog_resources).

% A minimal facts .pl + thin layer + main program, all in a temp dir.
setup_kb(Dir, MainFile) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/facts.pl'], Facts),
    atomic_list_concat([Dir, '/layer.le'], Layer),
    atomic_list_concat([Dir, '/main.le'], MainFile),
    write_file(Facts,
        "colour(sky, blue).\ncolour(grass, green).\nbright(X) :- colour(X, _).\n"),
    write_file(Layer,
        "the knowledge base layer includes these resources:\n    facts.pl.\n\nthe templates are:\n    *a thing* has colour *a colour*.\n    *a thing* is bright.\n\nthe knowledge base layer includes:\n\na thing has colour a colour if\n    prolog colour(the thing, the colour).\n\na thing is bright if\n    prolog bright(the thing).\n"),
    write_file(MainFile,
        "the knowledge base main includes these resources:\n    layer.\n\nthe templates are:\n    *a thing* is colourful.\n\nthe knowledge base main includes:\n\na thing is colourful if the thing has colour a colour.\n\nscenario s is:\n    q expects answers [\"sky is colourful\"].\n\nquery q is:\n    sky is colourful.\n").

test(pl_resource_loads_and_reasons) :-
    setup_kb(_Dir, Main),
    load(Main, KB),
    % the cache module was recorded and imported facts are reachable
    assertion(KB:le_prolog_resource(_, _)),
    runTestsFor(Main, test_file(_, [pass(q, s)])).

test(pl_resource_cache_module_holds_the_clauses) :-
    setup_kb(_Dir, Main),
    load(Main, KB),
    KB:le_prolog_resource(Cache, _),
    assertion(Cache:colour(sky, blue)),
    assertion(Cache:bright(grass)).

% A dangerous goal in a `prolog` body is blocked at run time and does not run.
test(unsafe_prolog_goal_is_blocked) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/evil.le'], Evil),
    atomic_list_concat([Dir, '/pwned'], Marker),
    format(atom(Src),
        "the templates are:\n    *a thing* is doomed.\n\nthe knowledge base evil includes:\n\na thing is doomed if\n    prolog shell(\"touch ~w\").\n\nquery bad is:\n    which thing is doomed.\n", [Marker]),
    write_file(Evil, Src),
    load(Evil, KB),
    createSession(KB, SM),
    KB:query_info(bad, Goal, _),
    catch(( reasoner:i(Goal, SM, _, _), Ran = true ),
          error(le_unsafe_prolog_goal(_), _), Ran = blocked),
    assertion(Ran == blocked),
    assertion(\+ exists_file(Marker)),
    destroySession(SM).

% A module/2 directive is stripped (with a warning); the clauses still load.
test(module_directive_is_stripped) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/mod.pl'], PL),
    atomic_list_concat([Dir, '/m.le'], LE),
    write_file(PL, ":- module(should_be_ignored, [foo/1]).\nfoo(bar).\n"),
    write_file(LE,
        "the knowledge base m includes these resources:\n    mod.pl.\n\nthe templates are:\n    *a thing* is fooish.\n\nthe knowledge base m includes:\n\na thing is fooish if prolog foo(the thing).\n\nquery q is:\n    which thing is fooish.\n"),
    load(LE, KB),
    assertion(has_issue(KB, module_directive_stripped)),
    KB:le_prolog_resource(Cache, _),
    assertion(Cache:foo(bar)).

% An unsafe directive (initialization) is skipped and does not run at load.
test(unsafe_directive_is_skipped) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/init.pl'], PL),
    atomic_list_concat([Dir, '/pwned2'], Marker),
    atomic_list_concat([Dir, '/i.le'], LE),
    format(atom(Src), ":- initialization(shell(\"touch ~w\")).\nok(1).\n", [Marker]),
    write_file(PL, Src),
    write_file(LE,
        "the knowledge base i includes these resources:\n    init.pl.\n\nthe templates are:\n    *a number* is okay.\n\nthe knowledge base i includes:\n\na number is okay if prolog ok(the number).\n\nquery q is:\n    which number is okay.\n"),
    load(LE, KB),
    assertion(has_issue(KB, skipped_directive)),
    assertion(\+ exists_file(Marker)).

% A -> B -> A cycle terminates (the seen-set stops the re-entry).
test(include_cycle_terminates) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/a.le'], A),
    atomic_list_concat([Dir, '/b.le'], B),
    write_file(A, "the knowledge base a includes these resources:\n    b.\n\nthe templates are:\n    *a thing* is a.\n"),
    write_file(B, "the knowledge base b includes these resources:\n    a.\n\nthe templates are:\n    *a thing* is b.\n"),
    catch(( load(A, _KB), Loaded = true ), _, Loaded = error),
    assertion(Loaded == true).

% A chain deeper than the cap raises include_too_deep. Set the cap low so the
% test stays small.
test(include_depth_cap) :-
    tmp_dir(Dir),
    forall(between(0, 4, I),
        ( atomic_list_concat([Dir, '/n', I, '.le'], F),
          I1 is I + 1,
          ( I < 4
          -> format(atom(Src), "the knowledge base n~w includes these resources:\n    n~w.\n\nthe templates are:\n    *a thing* is level ~w.\n", [I, I1, I])
          ;  format(atom(Src), "the templates are:\n    *a thing* is level ~w.\n", [I]) ),
          write_file(F, Src) )),
    atomic_list_concat([Dir, '/n0.le'], Top),
    setup_call_cleanup(
        set_prolog_flag(le_include_max_depth, 2),
        load(Top, KB),
        set_prolog_flag(le_include_max_depth, 5)),
    assertion(has_issue(KB, include_too_deep)).

% Text loaded WITHOUT a file path (as the editor does) still finds relative
% resources when given the source's base directory via load_text/3 — and fails
% to find them without it (the reported bug).
test(load_text_with_base_resolves_relative_resource) :-
    setup_kb(Dir, MainFile),
    read_file_to_string(MainFile, Text, []),
    % No base: the relative include cannot be resolved from cwd.
    load_text(Text, KB0),
    assertion(has_issue(KB0, missing_resource)),
    % With the file's directory as base: it resolves and the .pl loads.
    load_text(Text, Dir, KB1),
    assertion(\+ has_issue(KB1, missing_resource)),
    assertion(KB1:le_prolog_resource(_, _)).

% A local include escaping the base directory is refused.
test(local_path_escape_is_refused) :-
    tmp_dir(Dir),
    atomic_list_concat([Dir, '/main.le'], Main),
    write_file(Main,
        "the knowledge base m includes these resources:\n    ../../../../../etc/hosts.pl.\n\nthe templates are:\n    *a thing* is here.\n"),
    load(Main, KB),
    assertion(has_issue(KB, restricted_resource)).

:- end_tests(prolog_resources).

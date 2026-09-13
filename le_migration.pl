/** <module> Migrations into Logical English: the ledger and the source tests

    What every translator into LE shares after the writer (le_writer.pl):
    extension E14 of InsurLE2/docs/MiggratingFromOtherSystems.md (§4.3, §4.5,
    §7.2) — the MIGRATION LEDGER and the SCENARIO GENERATOR — and the check
    that joins them, the migration's FIDELITY.

    ## The ledger

    One entry per element of the source (a field, a rule, a table, a
    function, a test), with one of three verdicts:

      - encoded      mapped by a documented rule, meaning unchanged;
      - approximated mapped, with a documented change of meaning (closed-world
                     negation for an unknown value, a rational for a float,
                     first-hit order written as exceptions);
      - residue      not mapped: left as a residue marker for the Contract
                     Assistant, an assumable template, or a comment.

    The ledger, not the pass rate, is what a customer signs off. Its
    in-program half is the provenance trailers the IR carries (`rule r12
    with provenance policy.json at perils collision:`): the same source
    locator appears in both, so one can be read from the other.

    ## Source tests as scenarios

    The source system's own tests (OIA test scripts, Socotra rating tests,
    Miniscript satisfactions, on-chain transactions) become LE scenarios with
    `expects` lines, each scenario citing the test it comes from in its header
    (`scenario t3 is, as stated in "tests.xlsx" at case 3:`), so an
    explanation of any of its facts names its source.

    ## Fidelity

    migration_fidelity/3 runs the written program's tests (runTestsFor/2)
    and reports, per source test, whether the translation reproduces the
    source's behaviour — the pass rate beside the ledger's counts.

    ## The migration term

        migration(Meta, IR, Ledger, Tests)

        Meta    source(System), artifacts([Path|Name, ...]), translator(Name),
                program(Name), date(Stamp) — as known
        IR      program(Header, Items), le_writer's Migration IR
        Ledger  [entry(Element, Kind, Verdict, Mapping, InProgram, Note), ...]
        Tests   [test(Id, Document, Locator, Facts, Expectations), ...]
                Facts: IR literals, or fact(Literal, Provenance)
                Expectations: expects(Query, Answers) / expects(Query,
                Answers, Unknowns), answers as IR literals or strings
*/

:- module(le_migration, [
    source_tests_scenarios/2,    % +Tests, -ScenarioItems
    migration_text/3,            % +Migration, -LEText, -Issues
    ledger_counts/2,             % +Ledger, -Counts
    ledger_markdown/3,           % +Migration, +Fidelity, -Markdown
    ledger_dict/3,               % +Migration, +Fidelity, -Dict
    migration_fidelity/3,        % +LEFile, +Tests, -Fidelity
    write_migration/4,           % +Migration, +Dir, +BaseName, -Report
    copy_library/2               % +Name, +Dir
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(library(http/json)).
:- use_module(le_writer).
:- use_module(le_kbs).

		 /*******************************
		 *      SOURCE TESTS -> LE      *
		 *******************************/

%!  source_tests_scenarios(+Tests, -Items) is det.
%
%   One IR scenario per source test, its header citing the test.
source_tests_scenarios(Tests, Items) :-
    maplist(test_scenario, Tests, Items).

test_scenario(test(Id, Doc, Loc, Facts, Expects), scenario(Name, Lines, Opts)) :-
    scenario_name(Id, Name),
    maplist(test_fact_line, Facts, FactLines),
    append(FactLines, Expects, Lines),
    (   Doc == none -> Opts = []
    ;   Loc == none -> Opts = [as_stated_in(Doc)]
    ;   Opts = [as_stated_in(Doc), at(Loc)]
    ).

test_fact_line(fact(L, P), fact(L, P)) :- !.
test_fact_line(unknown(L), unknown(L)) :- !.
test_fact_line(comment(C), comment(C)) :- !.
test_fact_line(L, fact(L)).

name_code(C, D) :- ( code_type(C, alnum) -> D = C ; D = 0'_ ).

%   A scenario name is one word: the test id with every non-alphanumeric
%   character replaced.
scenario_name(Id, Name) :-
    format(atom(A), '~w', [Id]),
    atom_codes(A, Cs),
    maplist(name_code, Cs, Ds0),
    ( Ds0 = [D0|_], code_type(D0, digit) -> Ds = [0't|Ds0] ; Ds = Ds0 ),
    atom_codes(Name, Ds).

		 /*******************************
		 *        THE PROGRAM           *
		 *******************************/

%!  migration_text(+Migration, -Text, -Issues) is det.
%
%   The LE document of a migration: its IR with the source tests appended as
%   scenarios (before the queries, where scenarios go).
migration_text(Migration0, Text, Issues) :-
    migration_pending(Migration0, migration(_Meta, program(Header, Items0), _Ledger, Tests)),
    source_tests_scenarios(Tests, Scenarios),
    append(Items0, Scenarios, Items),
    le_write(program(Header, Items), Text, Issues).

		 /*******************************
		 *   EXPECTATIONS NOT YET DUE   *
		 *******************************/

%!  migration_pending(+Migration0, -Migration) is det.
%
%   An expectation whose query depends on what an untranslated residue block
%   must conclude cannot hold until the block is translated: it becomes
%   pending(residue(Id), Expectation) — written as a comment in its scenario,
%   counted in the ledger — instead of a test the twin fails by
%   construction. A residue item declares what it concludes with the option
%   concludes([F, ...]) (IR functors); a query depends on it when its body
%   reaches one of them through the IR's rules. A reader may also mark an
%   expectation pending itself: pending(Reason, expects(...)) in a test.
migration_pending(migration(Meta, IR, Ledger, Tests0), migration(Meta, IR, Ledger, Tests)) :-
    IR = program(_, Items),
    findall(Id-Fs, ( member(residue(Id, Opts), Items), memberchk(concludes(Fs), Opts), Fs \== [] ), Rs),
    (   Rs == []
    ->  Tests = Tests0
    ;   rule_graph(Items, Graph),
        findall(Q-Id, ( member(query(Q, B), Items), member(Id-Fs, Rs),
                        body_functors(B, QFs), reaches_any(Graph, QFs, Fs) ), Waits),
        maplist(pending_test(Waits), Tests0, Tests)
    ).

pending_test(Waits, test(I, D, L, F, E0), test(I, D, L, F, E)) :-
    maplist(pending_expectation(Waits), E0, E).

pending_expectation(Waits, E0, E) :-
    (   E0 = expects(Q, _) ; E0 = expects(Q, _, _) ),
    findall(Id, member(Q-Id, Waits), Ids0), sort(Ids0, Ids), Ids \== []
    ->  atomic_list_concat(Ids, ', ', IdsA),
        format(atom(Why), 'waits for residue ~w', [IdsA]),
        E = pending(Why, E0)
    ;   E = E0.

%   F-[Callee, ...] for each rule head functor (several rules merge).
rule_graph(Items, Graph) :-
    findall(F-Cs, ( ( member(rule(H, B, _), Items) ; member(rule(H, B), Items) ),
                    callable(H), functor(H, F, _), body_functors(B, Cs) ), Pairs),
    findall(F-All, ( member(F-_, Pairs), findall(C, ( member(F-Cs, Pairs), member(C, Cs) ), All0),
                     sort(All0, All) ), Graph0),
    sort(Graph0, Graph).

body_functors(B, Fs) :-
    findall(F, ( sub_term(G, B), compound(G), \+ connective(G), functor(G, F, _) ), Fs0),
    findall(F, ( sub_term(G, B), atom(G), G \== true, F = G ), Fs1),
    append(Fs0, Fs1, Fs2), sort(Fs2, Fs).

connective(G) :- functor(G, F, N), memberchk(F/N, [and/2, or/2, not/1, (',')/2, (;)/2, (\+)/1,
                                                   forall/2, agg/4, otherwise/1, according_to/2]).

reaches_any(_Graph, Starts, Targets) :-
    member(T, Targets), memberchk(T, Starts), !.
reaches_any(Graph, Starts, Targets) :-
    reach(Graph, Starts, [], Seen),
    member(T, Targets), memberchk(T, Seen), !.

reach(_, [], Seen, Seen).
reach(Graph, [F|Fs], Seen0, Seen) :-
    (   memberchk(F, Seen0) -> reach(Graph, Fs, Seen0, Seen)
    ;   ( memberchk(F-Cs, Graph) -> true ; Cs = [] ),
        append(Fs, Cs, Next),
        reach(Graph, Next, [F|Seen0], Seen)
    ).

pending_count(Tests, N) :-
    aggregate_all(count, ( member(test(_, _, _, _, Es), Tests), member(pending(_, _), Es) ), N).

		 /*******************************
		 *          THE LEDGER          *
		 *******************************/

%!  ledger_counts(+Ledger, -Counts) is det.
%
%   Counts is counts(Encoded, Approximated, Residue).
ledger_counts(Ledger, counts(E, A, R)) :-
    aggregate_all(count, member(entry(_, _, encoded, _, _, _), Ledger), E),
    aggregate_all(count, member(entry(_, _, approximated, _, _, _), Ledger), A),
    aggregate_all(count, member(entry(_, _, residue, _, _, _), Ledger), R).

%!  ledger_markdown(+Migration, +Fidelity, -Markdown) is det.
%
%   Fidelity is migration_fidelity/3's result, or `none`.
ledger_markdown(Migration0, Fidelity, Markdown) :-
    migration_pending(Migration0, migration(Meta, _IR, Ledger, Tests)),
    with_output_to(string(Markdown), write_ledger(Meta, Ledger, Tests, Fidelity)).

write_ledger(Meta, Ledger, Tests, Fidelity) :-
    option(program(Program), Meta, program),
    option(source(System), Meta, 'the source'),
    format("# Migration ledger: ~w~n~n", [Program]),
    format("Source: ~w", [System]),
    (   option(artifacts(As), Meta), As \== []
    ->  atomic_list_concat(As, ', ', AT), format(" — ~w", [AT])
    ;   true
    ),
    nl,
    ( option(translator(Tr), Meta) -> format("Translator: ~w~n", [Tr]) ; true ),
    ( option(date(D), Meta) -> format("Date: ~w~n", [D]) ; true ),
    ( option(licence(L), Meta) -> format("Source licence: ~w~n", [L]) ; true ),
    nl,
    ledger_counts(Ledger, counts(E, A, R)),
    Total is E + A + R,
    format("## Summary~n~n| Verdict | Source elements |~n|---|---|~n"),
    format("| encoded | ~w |~n| approximated | ~w |~n| residue | ~w |~n| **total** | ~w |~n~n", [E, A, R, Total]),
    write_fidelity_summary(Fidelity, Tests),
    format("A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.~n~n"),
    format("## Source elements~n~n| Source element | Kind | Verdict | Mapping | In the program | Note |~n|---|---|---|---|---|---|~n"),
    forall(member(entry(El, K, V, M, In, N), Ledger),
           ( maplist(md_cell, [El, K, V, M, In, N], Cs),
             atomic_list_concat(Cs, ' | ', Row),
             format("| ~w |~n", [Row]) )),
    nl,
    include(is_residue, Ledger, Residue),
    (   Residue == [] -> true
    ;   format("## Residue~n~n"),
        forall(member(entry(El, K, _, M, In, N), Residue),
               ( md_cell(El, ElT), md_cell(In, InT), md_cell(M, MT), md_cell(N, NT),
                 format("- **~w** (~w) — ~w; in the program: ~w. ~w~n", [ElT, K, MT, InT, NT]) )),
        nl
    ),
    write_fidelity_detail(Fidelity).

is_residue(entry(_, _, residue, _, _, _)).

write_fidelity_summary(none, Tests) :- !,
    length(Tests, N),
    format("Fidelity: ~w source test(s) translated to scenarios; not run.~n~n", [N]),
    write_pending_summary(Tests).
write_fidelity_summary(fidelity(Pass, Fail, Err, _), Tests) :-
    Total is Pass + Fail + Err,
    (   Total > 0 -> Pct is round(1000 * Pass / Total) / 10 ; Pct = 0 ),
    format("Fidelity: **~w of ~w** source test expectation(s) reproduced (~w%)", [Pass, Total, Pct]),
    ( Fail + Err > 0 -> format("; ~w fail, ~w could not be run", [Fail, Err]) ; true ),
    format(".~n~n"),
    write_pending_summary(Tests).

write_pending_summary(Tests) :-
    pending_count(Tests, N),
    (   N =:= 0 -> true
    ;   findall(W, ( member(test(_, _, _, _, Es), Tests), member(pending(W, _), Es) ), Ws0),
        sort(Ws0, Ws), atomic_list_concat(Ws, '; ', WT),
        format("**~w further expectation(s) are pending** (~w): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.~n~n", [N, WT])
    ).

write_fidelity_detail(none) :- !.
write_fidelity_detail(fidelity(_, _, _, Rows)) :-
    format("## Source tests~n~n| Source test | Query | Result | Detail |~n|---|---|---|---|~n"),
    forall(member(row(S, Q, R, D), Rows),
           ( md_cell(D, DT), format("| ~w | ~w | ~w | ~w |~n", [S, Q, R, DT]) )),
    nl.

md_cell(X, T) :-
    (   X == none -> T = ''
    ;   format(string(S0), '~w', [X]),
        split_string(S0, "|\n", "", Parts), atomic_list_concat(Parts, ' ', T)
    ).

%!  ledger_dict(+Migration, +Fidelity, -Dict) is det.
%
%   The ledger as JSON-ready data.
ledger_dict(Migration0, Fidelity, Dict) :-
    migration_pending(Migration0, migration(Meta, _, Ledger, Tests)),
    ledger_counts(Ledger, counts(E, A, R)),
    maplist(entry_dict, Ledger, Entries),
    length(Tests, NT),
    pending_count(Tests, NPending),
    fidelity_dict(Fidelity, FD),
    meta_dict(Meta, MD),
    Dict = _{meta: MD, counts: _{encoded: E, approximated: A, residue: R},
             entries: Entries, source_tests: NT, pending_expectations: NPending, fidelity: FD}.

entry_dict(entry(El, K, V, M, In, N), _{element: ElS, kind: KS, verdict: VS,
                                        mapping: MS, in_program: InS, note: NS}) :-
    maplist(json_text, [El, K, V, M, In, N], [ElS, KS, VS, MS, InS, NS]).

json_text(X, S) :- ( X == none -> S = "" ; format(string(S), '~w', [X]) ).

fidelity_dict(none, null) :- !.
fidelity_dict(fidelity(P, F, E, Rows), _{passed: P, failed: F, errors: E, tests: Ts}) :-
    maplist(row_dict, Rows, Ts).

row_dict(row(S, Q, R, D), _{scenario: SS, query: QS, result: RS, detail: DS}) :-
    maplist(json_text, [S, Q, R, D], [SS, QS, RS, DS]).

meta_dict(Meta, D) :-
    findall(K-V, ( member(M, Meta), M =.. [K, V0], meta_value(V0, V) ), Pairs),
    dict_pairs(D, _, Pairs).

meta_value(V0, V) :- is_list(V0), !, maplist(json_text, V0, V).
meta_value(V0, V) :- json_text(V0, V).

		 /*******************************
		 *           FIDELITY           *
		 *******************************/

%!  migration_fidelity(+LEFile, +Tests, -Fidelity) is det.
%
%   Runs the written program's expectations (runTestsFor/2) and reports each
%   one against the source test its scenario came from:
%   fidelity(Passed, Failed, Errors, Rows), Rows of row(Scenario, Query,
%   pass|fail|error, Detail).
migration_fidelity(File, Tests, fidelity(P, F, E, Rows)) :-
    le_kbs:runTestsFor(File, test_file(_, Results)),
    findall(S, ( member(test(Id, _, _, _, _), Tests), scenario_name(Id, S) ), Names),
    include(result_of_tests(Names), Results, Mine),
    maplist(result_row, Mine, Rows),
    aggregate_all(count, member(row(_, _, pass, _), Rows), P),
    aggregate_all(count, member(row(_, _, fail, _), Rows), F),
    aggregate_all(count, member(row(_, _, error, _), Rows), E).

result_of_tests(Names, R) :-
    result_scenario(R, S),
    ( Names == [] -> true ; memberchk(S, Names) ).

result_scenario(pass(_, S), S).
result_scenario(fail(_, S, _, _, _, _), S).
result_scenario(fail(_, S, _, _), S).
result_scenario(error(_, S, _), S).

result_row(pass(Q, S), row(S, Q, pass, none)).
result_row(fail(Q, S, Exp, Act, _, _), row(S, Q, fail, D)) :-
    format(string(D), "expected ~w, got ~w", [Exp, Act]).
result_row(fail(Q, S, Exp, Act), row(S, Q, fail, D)) :-
    format(string(D), "expected ~w, got ~w", [Exp, Act]).
result_row(error(Q, S, M), row(S, Q, error, M)).

		 /*******************************
		 *       WRITING IT ALL OUT     *
		 *******************************/

%!  write_migration(+Migration, +Dir, +BaseName, -Report) is det.
%
%   Writes <Dir>/<BaseName>.le, runs its source tests, and writes
%   <Dir>/<BaseName>.ledger.md and .ledger.json. Report is
%   report(LEFile, Issues, Counts, Fidelity).
write_migration(Migration0, Dir, Base, report(LEFile, Issues, Counts, Fidelity)) :-
    migration_pending(Migration0, Migration),
    make_directory_path(Dir),
    migration_text(Migration, Text, Issues),
    atomic_list_concat([Dir, '/', Base, '.le'], LEFile),
    write_text(LEFile, Text),
    Migration = migration(_, _, Ledger, Tests),
    ledger_counts(Ledger, Counts),
    (   Tests == [] -> Fidelity = none
    ;   catch(migration_fidelity(LEFile, Tests, Fidelity), E,
              ( print_message(error, E), Fidelity = none ))
    ),
    ledger_markdown(Migration, Fidelity, MD),
    atomic_list_concat([Dir, '/', Base, '.ledger.md'], MDFile),
    write_text(MDFile, MD),
    ledger_dict(Migration, Fidelity, Dict),
    atomic_list_concat([Dir, '/', Base, '.ledger.json'], JFile),
    setup_call_cleanup(open(JFile, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, Dict, [width(100)]),
                       close(Out)).

%!  copy_library(+Name, +Dir) is det.
%
%   Copies the shipped library lib/<Name>.le (and lib/<Name>.pl when there
%   is one) into Dir, beside the program that includes it: a migrated twin
%   is a self-contained directory. The library of E3, `temporal`, is the one
%   the translators use.
copy_library(Name, Dir) :-
    lib_dir(Lib),
    make_directory_path(Dir),
    forall(( member(Ext, [le, pl]),
             atomic_list_concat([Lib, '/', Name, '.', Ext], Src),
             exists_file(Src) ),
           ( atomic_list_concat([Dir, '/', Name, '.', Ext], Dst),
             copy_file(Src, Dst) )).

:- dynamic migration_dir/1.
:- prolog_load_context(directory, D), retractall(migration_dir(_)), assertz(migration_dir(D)).

lib_dir(Lib) :- migration_dir(D), atomic_list_concat([D, '/lib'], Lib).

write_text(File, Text) :-
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       write(Out, Text),
                       close(Out)).

/** <module> lib/temporal.le — the temporal and period library (E3)

    InsurLE2/docs/migration/roadmap.md §7.2: dates, periods and
    lock times as a library the migrations share, not syntax.

    Run with:  swipl -q -g run_tests -t halt testing/test_temporal_lib.pl
*/

:- module(test_temporal_lib, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_migration').

:- consult('../lib/temporal.pl').

:- begin_tests(temporal_lib_prolog).

test(day_numbers_round_trip) :-
    forall(member(D, [date(1970,1,1), date(2000,2,29), date(2024,12,31), date(1899,3,1)]),
           ( le_temporal_day_number(D, N), le_temporal_date_of_day(N, D2), assertion(D2 == D) )),
    le_temporal_day_number(date(1970,1,1), Z), assertion(Z =:= 0).

test(ages_and_months) :-
    le_temporal_years_between(date(2008,3,15), date(2026,3,14), A1), assertion(A1 =:= 17),
    le_temporal_years_between(date(2008,3,15), date(2026,3,15), A2), assertion(A2 =:= 18),
    le_temporal_months_between(date(2026,8,28), date(2027,2,28), M1), assertion(M1 =:= 6),
    le_temporal_months_between(date(2026,8,28), date(2027,2,27), M2), assertion(M2 =:= 5).

test(adding_months_clamps_the_day) :-
    le_temporal_add_months(date(2026,8,31), 6, D1), assertion(D1 == date(2027,2,28)),
    le_temporal_add_months(date(2027,8,31), 6, D2), assertion(D2 == date(2028,2,29)),
    le_temporal_add_years(date(2024,2,29), 1, D3), assertion(D3 == date(2025,2,28)),
    le_temporal_add_days(date(2026,12,30), 3, D4), assertion(D4 == date(2027,1,2)).

test(windows_and_periods) :-
    assertion(le_temporal_within_months_before(date(2026,8,1), 3, date(2026,9,13))),
    assertion(\+ le_temporal_within_months_before(date(2026,5,1), 3, date(2026,9,13))),
    assertion(le_temporal_in_period(date(2026,1,1), date(2026,1,1), date(2026,12,31))),
    le_temporal_weekday(date(2026,9,13), W), assertion(W =:= 7).

test(lock_times) :-
    assertion(le_temporal_lock_is_height(840000)),
    assertion(le_temporal_lock_is_time(1735689600)).

:- end_tests(temporal_lib_prolog).

:- begin_tests(temporal_lib_le).

%   A program including the library, copied beside it as the translators do.
test(included_library_answers, [setup(tmp_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    copy_library(temporal, Dir),
    atomic_list_concat([Dir, '/uses_temporal.le'], File),
    copy_file('testing/fixtures/temporal/uses_temporal.le', File),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    assertion(Results = [_, _, _]),
    assertion(forall(member(R, Results), R = pass(_, _))).

tmp_dir(Dir) :- tmp_file(temporal, Dir), make_directory(Dir).

:- end_tests(temporal_lib_le).

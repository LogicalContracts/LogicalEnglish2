/*  lib/temporal.pl — the date arithmetic behind lib/temporal.le

    Extension E3 of InsurLE2/docs/MiggratingFromOtherSystems.md (§7.2): a
    library, not syntax. Dates are LE's own date(Year, Month, Day) terms.
    Pure arithmetic only (days from the civil calendar, no clock), so every
    predicate passes the sandbox LE applies to `prolog` goals.

    Loaded assert-only as a Prolog resource (docs/le_summary.md §14.1).
*/

%   Days since 1970-01-01 of a civil date (Howard Hinnant's algorithm).
le_temporal_day_number(date(Y0, M, D), N) :-
    ( M =< 2 -> Y is Y0 - 1 ; Y = Y0 ),
    Era is Y // 400,
    YoE is Y - Era * 400,
    ( M > 2 -> MP is M - 3 ; MP is M + 9 ),
    DoY is (153 * MP + 2) // 5 + D - 1,
    DoE is YoE * 365 + YoE // 4 - YoE // 100 + DoY,
    N is Era * 146097 + DoE - 719468.

le_temporal_date_of_day(N, date(Y, M, D)) :-
    Z is N + 719468,
    Era is Z // 146097,
    DoE is Z - Era * 146097,
    YoE is (DoE - DoE // 1460 + DoE // 36524 - DoE // 146096) // 365,
    Y0 is YoE + Era * 400,
    DoY is DoE - (365 * YoE + YoE // 4 - YoE // 100),
    MP is (5 * DoY + 2) // 153,
    D is DoY - (153 * MP + 2) // 5 + 1,
    ( MP < 10 -> M is MP + 3 ; M is MP - 9 ),
    ( M =< 2 -> Y is Y0 + 1 ; Y = Y0 ).

le_temporal_leap(Y) :- Y mod 4 =:= 0, ( Y mod 100 =\= 0 ; Y mod 400 =:= 0 ).

le_temporal_days_in_month(Y, 2, 29) :- le_temporal_leap(Y), !.
le_temporal_days_in_month(_, 2, 28) :- !.
le_temporal_days_in_month(_, M, 30) :- memberchk(M, [4, 6, 9, 11]), !.
le_temporal_days_in_month(_, _, 31).

%   The number of days from the first date to the second (negative when the
%   second is earlier).
le_temporal_days_between(D1, D2, N) :-
    le_temporal_day_number(D1, N1), le_temporal_day_number(D2, N2),
    N is N2 - N1.

%   The number of WHOLE years from the first date to the second: an age.
le_temporal_years_between(date(Y1, M1, D1), date(Y2, M2, D2), N) :-
    N0 is Y2 - Y1,
    ( ( M2 < M1 ; M2 =:= M1, D2 < D1 ) -> N is N0 - 1 ; N = N0 ).

%   The number of WHOLE calendar months from the first date to the second.
le_temporal_months_between(date(Y1, M1, D1), date(Y2, M2, D2), N) :-
    N0 is (Y2 - Y1) * 12 + (M2 - M1),
    ( D2 < D1, \+ le_temporal_last_day(date(Y2, M2, D2)) -> N is N0 - 1 ; N = N0 ).

le_temporal_last_day(date(Y, M, D)) :- le_temporal_days_in_month(Y, M, D).

%   The date N calendar months after a date (N may be negative): the same
%   day, or the last day of a shorter month (31 August + 6 months = 28/29
%   February), as LE's own `months after` does.
le_temporal_add_months(date(Y, M, D), N, date(Y2, M2, D2)) :-
    T is Y * 12 + (M - 1) + N,
    Y2 is T // 12, M2 is T mod 12 + 1,
    le_temporal_days_in_month(Y2, M2, L),
    D2 is min(D, L).

le_temporal_sub_months(Date, N, Earlier) :-
    M is -N,
    le_temporal_add_months(Date, M, Earlier).

le_temporal_add_years(Date, N, Later) :-
    M is N * 12,
    le_temporal_add_months(Date, M, Later).

le_temporal_add_days(Date, N, Later) :-
    le_temporal_day_number(Date, K), K2 is K + N,
    le_temporal_date_of_day(K2, Later).

le_temporal_month_start(date(Y, M, _), date(Y, M, 1)).

le_temporal_month_end(date(Y, M, _), date(Y, M, L)) :-
    le_temporal_days_in_month(Y, M, L).

le_temporal_year(date(Y, _, _), Y).
le_temporal_month(date(_, M, _), M).
le_temporal_day(date(_, _, D), D).

%   A date is in the period from Start to End, both included.
le_temporal_in_period(Date, Start, End) :-
    le_temporal_day_number(Date, N), le_temporal_day_number(Start, S), le_temporal_day_number(End, E),
    N >= S, N =< E.

%   "in the last N months" before a reference date: after the date N
%   calendar months before it, up to and including the reference date.
le_temporal_within_months_before(Date, N, Ref) :-
    Back is -N,
    le_temporal_add_months(Ref, Back, Start),
    le_temporal_day_number(Start, S), le_temporal_day_number(Date, K), le_temporal_day_number(Ref, R),
    K > S, K =< R.

le_temporal_within_days_before(Date, N, Ref) :-
    le_temporal_day_number(Date, K), le_temporal_day_number(Ref, R),
    K =< R, R - K < N.

%   ISO weekday, 1 (Monday) to 7 (Sunday).
le_temporal_weekday(Date, W) :-
    le_temporal_day_number(Date, N),
    W is (N + 3) mod 7 + 1.

%   Bitcoin lock times (BIP 65 / BIP 68): an absolute lock time below
%   500000000 is a block height, otherwise a Unix time; a relative lock
%   (nSequence, older(n)) counts blocks.
le_temporal_lock_is_height(T) :- integer(T), T < 500000000.
le_temporal_lock_is_time(T) :- integer(T), T >= 500000000.

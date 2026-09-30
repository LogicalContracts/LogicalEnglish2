% lib/l4_daydate.pl — the Prolog half of lib/l4_daydate.le: L4's dates as
% LE dates, date(Y, M, D), and L4's serial day numbers (its DATE_SERIAL:
% 1 January 2025 is day 739616). Written for the L4 translator
% (lpsPlus/docs/migration/l4.md, §3).

%   l4_date_serial(?Date, ?Serial): a date and its day number
l4_date_serial(Date, S) :- nonvar(Date), !,
    Date = date(Y, M, D),
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), T),
    S is round(T / 86400) + 719527.
l4_date_serial(Date, S) :-
    number(S), T is (S - 719527) * 86400,
    stamp_date_time(T, date(Y, M, D, _, _, _, _, _, _), 'UTC'),
    Date = date(Y, M, D).

%   l4_date_make(+Day, +Month, +Year, -Date): as L4's DATE_FROM_DMY, a day
%   or month past the end carried into the next
l4_date_make(D, M, Y, date(Y1, M1, D1)) :-
    Yi is integer(Y), Mi is integer(M), Di is integer(D),
    date_time_stamp(date(Yi, Mi, Di, 0, 0, 0, 0, -, -), T),
    stamp_date_time(T, date(Y1, M1, D1, _, _, _, _, _, _), 'UTC').

%   l4_date_parts(+Date, -Day, -Month, -Year)
l4_date_parts(date(Y, M, D), D, M, Y).

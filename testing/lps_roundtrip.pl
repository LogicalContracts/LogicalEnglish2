/** <module> The M8d gate: the LE <-> LPS round trip

    For every program in examples/lps/:

	LE  ->  internal  ->  LE  ->  internal

    and the two internal forms must be term-by-term `variant/2`-equal.

	./myswipl.sh -q -g "consult('testing/lps_roundtrip.pl')" -g "lps_roundtrip:main" -t halt

    What this claims, and what it does not: see the module header of
    le_lps_write.pl. In short, it claims the internal form carries everything
    the English did; it does not claim the two English texts are the same, and
    they are not.

    Programs that are known not to round-trip are listed in `excluded/2` with a
    reason, and are reported as excluded rather than silently skipped. An
    excluded program that starts passing is also reported, because a stale
    exclusion is a lie about the language.
*/

:- module(lps_roundtrip, [main/0, roundtrip/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../le_lps').
:- use_module('../le_lps_write').
:- use_module('../le_kbs').
:- use_module(library(time)).

%!  excluded(?Base, ?Reason) is nondet.
%
%   Stated, not silent. Each of these is a construct the writer cannot put
%   back into English, and each is a claim about the LANGUAGE, not about this
%   file being incomplete.
excluded(delivery_delay,
	 'real_date_add/3 is called with a date term -- 2018-04-01 -- and a \c
	  date constant has no LE surface form of its own, so the writer cannot \c
	  put it back.').
excluded(loan_agreement,
	 'the same: date(2014,6,1) appears as a constant in four rules.').

programs(Files) :-
	expand_file_name('examples/lps/*.le', Files0),
	sort(Files0, Files).

%!  roundtrip(+File, -First, -Second) is semidet.
%
%   First is the internal form of the document; Second is the internal form of
%   the English this module writes back from it.
roundtrip(File, First, Second) :-
	read_file_to_string(File, Text, [encoding(utf8)]),
	le_kbs:load_text(Text, KB1),
	le_lps:le_lps_module(KB1, Text, Internal1, _, _),
	terms_of(Internal1, First),
	le_lps_write:le_lps_document(KB1, First, LE2),
	le_kbs:load_text(LE2, KB2),
	le_lps:le_lps_module(KB2, LE2, Internal2, _, _),
	terms_of(Internal2, Second).

terms_of(Text, Terms) :-
	setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).

read_all(In, Terms) :-
	read_term(In, T, [module(lps_roundtrip)]),
	( T == end_of_file -> Terms = [] ; Terms = [T|Rest], read_all(In, Rest) ).

		 /*******************************
		 *	     the gate		*
		 *******************************/

main :-
	programs(Files),
	foldl(check, Files, s(0,0,0), s(Pass, Fail, Excl)),
	Total is Pass + Fail + Excl,
	format('~nM8d: ~w of ~w round-trip; ~w excluded, ~w failing~n',
	       [Pass, Total, Excl, Fail]),
	( Fail =:= 0 -> true ; halt(1) ).

check(File, s(P0,F0,X0), s(P,F,X)) :-
	file_base_name(File, BaseFile),
	atom_concat(Base, '.le', BaseFile),
	%  Bounded: a writer that loops must be a reported failure, not a hung
	%  suite. Sixty seconds is far more than any of these needs -- the
	%  slowest that passes is under three.
	(   catch(call_with_time_limit(60, roundtrip(File, A, B)),
		  E, (print_message(error, E), fail))
	->  ( same(A, B) -> Ok = true ; Ok = false )
	;   Ok = false
	),
	(   excluded(Base, Reason)
	->  (   Ok == true
	    ->  format('  STALE ~w — excluded, but it round-trips now~n', [Base])
	    ;   format('  excl  ~w — ~w~n', [Base, Reason])
	    ),
	    P = P0, F = F0, X is X0 + 1
	;   Ok == true
	->  length(A, N),
	    format('  ok    ~w (~w terms)~n', [Base, N]),
	    P is P0 + 1, F = F0, X = X0
	;   format('  FAIL  ~w~n', [Base]),
	    diff(A, B),
	    P = P0, F is F0 + 1, X = X0
	).

same(A, B) :-
	is_list(A), is_list(B),
	length(A, N), length(B, N),
	maplist([X,Y]>>variant(X, Y), A, B).

diff(A, B) :-
	(   \+ is_list(A) ; \+ is_list(B) ), !,
	format('        one side did not translate~n', []).
diff(A, B) :-
	length(A, NA), length(B, NB),
	( NA =:= NB -> true ; format('        ~w terms out, ~w back~n', [NA, NB]) ),
	first_diff(A, B, 1).

first_diff([], [], _) :- !.
first_diff([], [T|_], N) :- !, format('        ~w: extra ~q~n', [N, T]).
first_diff([T|_], [], N) :- !, format('        ~w: lost ~q~n', [N, T]).
first_diff([X|Xs], [Y|Ys], N) :-
	(   variant(X, Y)
	->  N1 is N + 1, first_diff(Xs, Ys, N1)
	;   format('        ~w~n          out:  ~q~n          back: ~q~n', [N, X, Y])
	).

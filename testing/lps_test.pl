/** <module> The M8c gate: Logical English for LPS

    Every program with an expectation in testing/fixtures/lps/
    (`<name>.expected.lpsw`) is translated to LPS internal syntax and compared,
    term by term and up to variable renaming (`variant/2`), with it.

    The programs are LPS2's Logical English examples (lps2/examples/le/): they
    are read from an LPS2 checkout when there is one ($LPS2_DIR, a sibling
    ../lps2, or /lps2), and otherwise from the few copies kept beside the
    expectations, so that the gate still runs on LE2 alone. A program with an
    expectation and no source is reported as skipped, not as passed.

	./myswipl.sh -q -g "consult('testing/lps_test.pl')" -g "lps_test:main" -t halt

    and, to re-record the expectations after a deliberate change:

	./myswipl.sh -q -g "consult('testing/lps_test.pl')" -g "lps_test:record" -t halt

    `record` is for when the *language* changes, not for when a test goes red.
    An expectation regenerated from the code it is meant to check is not a
    test, so read the diff before committing one.
*/

:- module(lps_test, [main/0, record/0, translate/2]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../le_lps').

fixtures_dir('testing/fixtures/lps').

%!  lps2_examples_dir(-Dir) is semidet.
%
%   examples/le of an LPS2 checkout: $LPS2_DIR, ../lps2 beside this
%   repository, or /lps2.
lps2_examples_dir(Dir) :-
	(   getenv('LPS2_DIR', D0), D0 \== '' ; D0 = '../lps2' ; D0 = '/lps2' ),
	atomic_list_concat([D0, '/examples/le'], Dir),
	exists_directory(Dir), !.

%!  programs(-Files) is det.
%
%   The source of every program with an expectation: LPS2's copy when there
%   is a checkout, else the fixture copy; a name with neither is reported.
programs(Files) :-
	fixtures_dir(Fix),
	atom_concat(Fix, '/*.expected.lpsw', Pattern),
	expand_file_name(Pattern, Exps0),
	sort(Exps0, Exps),
	findall(File,
		( member(Exp, Exps),
		  file_base_name(Exp, B), atom_concat(Name, '.expected.lpsw', B),
		  (   program_source(Name, File) -> true
		  ;   format('  skip  ~w — no source (no LPS2 checkout, no fixture copy)~n', [Name]), fail
		  ) ),
		Files).

program_source(Name, File) :-
	(   lps2_examples_dir(Dir) ; fixtures_dir(Dir) ),
	atomic_list_concat([Dir, '/', Name, '.le'], File),
	exists_file(File), !.

expected_file(LE, Expected) :-
	file_base_name(LE, B),
	atom_concat(Name, '.le', B),
	fixtures_dir(Fix),
	atomic_list_concat([Fix, '/', Name, '.expected.lpsw'], Expected).

%!  translate(+File, -Terms) is semidet.
translate(File, Terms) :-
	le_lps:le_lps_file(File, Text, _Prov, Issues),
	\+ ( member(le_lps_issue(error, _, _, _, _), Issues) ),
	Text \== "",
	text_terms(Text, Terms).

text_terms(Text, Terms) :-
	setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).

read_all(In, Terms) :-
	read_term(In, T, [module(lps_test)]),
	(   T == end_of_file
	->  Terms = []
	;   Terms = [T|Rest], read_all(In, Rest)
	).

		 /*******************************
		 *	     the gate		*
		 *******************************/

main :-
	programs(Files),
	foldl(check, Files, 0-0, Pass-Fail),
	Total is Pass + Fail,
	format('~nM8c: ~w of ~w programs match their expectation~n', [Pass, Total]),
	( Fail =:= 0 -> true ; halt(1) ).

check(File, P0-F0, P-F) :-
	file_base_name(File, Base),
	(   \+ translate(File, _)
	->  format('  FAIL  ~w — did not translate~n', [Base]), P = P0, F is F0 + 1
	;   translate(File, Terms),
	    expected_file(File, Exp),
	    (   \+ exists_file(Exp)
	    ->  format('  FAIL  ~w — no expectation recorded~n', [Base]),
		P = P0, F is F0 + 1
	    ;   read_expected(Exp, Want),
		(   terms_match(Want, Terms, Report)
		->  format('  ok    ~w (~w terms)~n', [Base, Report]),
		    P is P0 + 1, F = F0
		;   format('  FAIL  ~w~n', [Base]),
		    report_diff(Want, Terms),
		    P = P0, F is F0 + 1
		)
	    )
	).

read_expected(File, Terms) :-
	setup_call_cleanup(
	    open(File, read, In, [encoding(utf8)]),
	    read_all(In, Terms),
	    close(In)).

%   Term by term, in order, up to variable renaming. Order matters: the
%   emitter's families are deliberately ordered (settings, declarations,
%   initial state, then the rules in source order), and a program whose terms
%   came out in a different order is a program that changed.
terms_match(Want, Got, Count) :-
	length(Want, N), length(Got, N),
	maplist([A,B]>>variant(A, B), Want, Got),
	Count = N.

report_diff(Want, Got) :-
	length(Want, NW), length(Got, NG),
	( NW =:= NG -> true ; format('        ~w terms expected, ~w produced~n', [NW, NG]) ),
	first_difference(Want, Got, 1).

first_difference([], [], _) :- !.
first_difference([], [G|_], N) :- !, format('        term ~w: unexpected ~q~n', [N, G]).
first_difference([W|_], [], N) :- !, format('        term ~w: missing ~q~n', [N, W]).
first_difference([W|Ws], [G|Gs], N) :-
	(   variant(W, G)
	->  N1 is N + 1, first_difference(Ws, Gs, N1)
	;   format('        term ~w~n          expected: ~q~n          produced: ~q~n', [N, W, G])
	).

		 /*******************************
		 *	    recording		*
		 *******************************/

record :-
	programs(Files),
	forall(member(F, Files), record_one(F)).

record_one(File) :-
	file_base_name(File, Base),
	(   le_lps:le_lps_file(File, Text, _, Issues),
	    Text \== "",
	    \+ member(le_lps_issue(error, _, _, _, _), Issues)
	->  expected_file(File, Exp),
	    setup_call_cleanup(
		open(Exp, write, S, [encoding(utf8)]),
		( format(S, '% Generated by testing/lps_test.pl from ~w.~n', [Base]),
		  format(S, '% The internal syntax le_lps.pl must produce for it (M8c).~n~n', []),
		  write(S, Text) ),
		close(S)),
	    format('recorded ~w~n', [Base])
	;   format('SKIPPED  ~w — does not translate~n', [Base])
	).

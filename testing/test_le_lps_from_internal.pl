/** <module> An LPS program that never had a dictionary, written as Logical English

    `le_lps_write:le_lps_from_internal/4` takes the internal terms of an LPS
    program written in the older, Prolog-like syntax — a `.lps` file, which has
    no templates — invents a template for every relation the program mentions,
    and writes the document. LPS2's `src/syntax/lps_to_le.pl` reads the file and
    calls it; these tests call it directly, so they need no LPS2 checkout.

    The claim under test is the one that matters: the document says the same as
    the terms it was written from. So each test writes a document and reads it
    back through le_lps.pl, and compares the terms that come out with the terms
    that went in.

        ./myswipl.sh -q -g run_tests -t halt testing/test_le_lps_from_internal.pl
*/

:- module(test_le_lps_from_internal, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../le_lps_write').
:- use_module('../le_lps').
:- use_module('../le_kbs').

%!  written_and_read(+Terms, -Back, -Issues) is det.
%
%   Terms, written as a Logical English document and read back.
written_and_read(Terms, Back, Issues) :-
    le_lps_write:le_lps_from_internal(Terms, [kb(test)], Text, Issues),
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(( le_kbs:load_text(Text, KB),
                   le_lps:le_lps_module(KB, Text, Internal, _, _) ),
                 le_kbs:set_le_issue_reporting(true)),
    terms_of(Internal, Back).

terms_of(Text, Terms) :-
    setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).

read_all(In, Terms) :-
    read_term(In, T, [module(test_le_lps_from_internal)]),
    ( T == end_of_file -> Terms = [] ; Terms = [T|Rest], read_all(In, Rest) ).

%   True when Back holds a term that is a variant of Wanted.
has(Back, Wanted) :- member(T, Back), T =@= Wanted, !.

issue_of(Issues, Code) :- member(issue(_, Code, _), Issues), !.

:- begin_tests(le_lps_from_internal).

%   The shape of every LPS program: what may happen, what may be done, what
%   holds, what starts out holding, what an event changes, and a rule that
%   makes something happen.
test(a_whole_small_program) :-
    Terms = [ maxTime(10),
              fluents([has(_, _), near(_, _)]),
              events([sees(_, _)]),
              actions([pick_up(_, _)]),
              initial_state([has(crow, cheese), near(fox, crow)]),
              initiated(happens(pick_up(A, B), _, _), has(A, B), []),
              terminated(happens(pick_up(_, C), _, _), near(ground, C), []),
              reactive_rule([holds(near(fox, D), T)], [happens(pick_up(fox, D), T, _)]) ],
    written_and_read(Terms, Back, Issues),
    assertion(Issues == []),
    assertion(has(Back, maxTime(10))),
    assertion(has(Back, initial_state([has(crow, cheese), near(fox, crow)]))),
    assertion(( member(initiated(happens(pick_up(X, Y), _, _), has(X, Y), []), Back) )),
    assertion(( member(terminated(happens(pick_up(_, Z), _, _), near(ground, Z), []), Back) )),
    assertion(( member(reactive_rule([holds(near(fox, W), T1)],
                                     [happens(pick_up(fox, W), T1, _)]), Back) )).

%   An event or an action is worded as a verb, a fluent as a state. The
%   wording is a guess about English and nothing depends on it, but a reader
%   does, so it is worth a test.
test(the_wording_reads_as_English) :-
    Terms = [ fluents([fooled(_)]), actions([pick_up(_, _)]), events([sees(_, _)]) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(w)], Text, _),
    assertion(sub_string(Text, _, _, _, "*a thing* picks up *a second thing*")),
    assertion(sub_string(Text, _, _, _, "*a thing* sees *a second thing*")),
    assertion(sub_string(Text, _, _, _, "*a thing* is fooled")).

%   `sees(What) updates Old to What in ahead(Old)` carries a word across,
%   not a number. Writing it as `the new value is the old one` and reading
%   it back as arithmetic used to stop the program at the first update.
test(an_update_that_carries_a_word) :-
    Terms = [ fluents([ahead(_)]), events([sees(_)]),
              updated(happens(sees(V), _, _), ahead(O), O-V, []) ],
    written_and_read(Terms, Back, Issues),
    assertion(Issues == []),
    assertion(( member(updated(happens(sees(X), _, _), ahead(Y), Y-X, []), Back) )).

%   `divert updates Old to side in trolley_on(Old)`: the new value is a
%   constant. The whole law used to be dropped without a word.
test(an_update_that_carries_a_constant) :-
    Terms = [ fluents([trolley_on(_)]), actions([divert]),
              updated(happens(divert, _, _), trolley_on(O), O-side, []) ],
    written_and_read(Terms, Back, Issues),
    assertion(Issues == []),
    assertion(( member(updated(happens(divert, _, _), trolley_on(_), _-side, []), Back) )).

%   An update that works out a number keeps the goal that works it out.
test(an_update_that_works_out_a_number) :-
    Terms = [ fluents([battery(_)]), actions([drive]),
              updated(happens(drive, _, _), battery(O), O-N, [N is O - 10]) ],
    written_and_read(Terms, Back, Issues),
    assertion(Issues == []),
    assertion(( member(updated(happens(drive, _, _), battery(A), A-B, [B is A - 10]), Back) )).

%   A fluent called `target` would be worded `the target is ...`, which is
%   how `the target language is: lps.` opens. The reader stops reading the
%   section there and takes the rest of it with it, so the wording steps
%   aside.
test(a_name_that_opens_like_a_section) :-
    Terms = [ fluents([target(_), heating(_)]),
              initial_state([target(21), heating(off)]) ],
    written_and_read(Terms, Back, Issues),
    assertion(Issues == []),
    assertion(has(Back, initial_state([target(21), heating(off)]))).

%   Two relations that would be worded the same way: the event steps aside,
%   because English lets it (`does sing`), and the fluent keeps the words.
test(two_relations_worded_alike) :-
    Terms = [ fluents([sings(_)]), actions([sing(_)]),
              initiated(happens(sing(P), _, _), sings(P), []) ],
    written_and_read(Terms, Back, Issues),
    assertion(issue_of(Issues, lps_template_clash)),
    assertion(( member(initiated(happens(sing(X), _, _), sings(X), []), Back) )).

%   A relation used at an arity it was never declared at is still a fluent,
%   and the document must say so or the sentence loses its time.
test(a_relation_declared_at_another_arity) :-
    Terms = [ fluents([carrying(_)]), actions([take(_, _)]),
              initiated(happens(take(P, W), _, _), carrying(P, W), []) ],
    written_and_read(Terms, Back, _),
    assertion(( once(member(initiated(happens(take(A, B), _, _), carrying(A, B), []), Back)) )).

		 /*******************************
		 *   WHAT IT REFUSES TO GUESS   *
		 *******************************/

%   Drawing rules have no Logical English form at all. They are left out and
%   said out loud, not written as sentences that mean nothing.
test(drawing_rules_are_left_out) :-
    Terms = [ fluents([hot(_)]),
              display(hot(_), [type:circle]),
              (display(warm(T), [type:circle, label:T]) :- T > 20) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(d)], Text, Issues),
    assertion(issue_of(Issues, lps_drawing_rules)),
    assertion(\+ sub_string(Text, _, _, _, "display")).

%   The planning engine's settings are lost, and a converted program that had
%   quietly stopped planning the same way would be worse than one that refused.
test(the_planning_settings_are_reported) :-
    Terms = [ fluents([at(_)]), achieve([at(home)]),
              (:- lps_engine(planning, [search(auto), horizon(10)])) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(p)], _, Issues),
    assertion(issue_of(Issues, lps_directive_dropped)).

%   One name in two sections: here a sentence is an event or a fluent because
%   of the section its template stands in, so one name cannot be both.
test(one_name_in_two_sections_is_reported) :-
    Terms = [ fluents([temperature(_)]), events([temperature(_)]) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(t)], _, Issues),
    assertion(issue_of(Issues, lps_name_in_two_sections)).

%   A place of a sentence holds a name, a number, a date or a list — never a
%   term with a term inside it.
test(a_term_inside_a_term_is_reported) :-
    Terms = [ events([command(_)]), observe([command(open(case))], 2) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(n)], _, Issues),
    assertion(issue_of(Issues, lps_nested_term)).

%   An update can only change a relation's last place, because of how the
%   sentence that says it is put back together.
test(an_update_of_a_middle_place_is_reported) :-
    Terms = [ fluents([at(_, _)]), events([walks(_, _)]),
              updated(happens(walks(P, _), _, _), at(O, P), O-somewhere, []) ],
    le_lps_write:le_lps_from_internal(Terms, [kb(u)], _, Issues),
    assertion(issue_of(Issues, lps_update_not_last_place)).

:- end_tests(le_lps_from_internal).
